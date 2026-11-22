// The recorded online matches, read for the Kubb Gym's fit and bank (docs/notes/gym.md).
// The folder is the one the web's `npm run games:pull` fills: a folder per room of
// gzipped document versions, and browser/<day>/ for matches played in one browser.
// It is private (names, room codes): nothing read here goes into this repository.
// What leaves this module is anonymous: matches are numbered in the order read, and
// only the snapshots and actions the engine needs travel, to a temporary file that the
// caller removes.
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';

const GAP_MS = 24 * 3600 * 1000;

function parse(file) {
  const b = readFileSync(file);
  return JSON.parse((b[0] === 0x1f && b[1] === 0x8b ? gunzipSync(b) : b).toString('utf8'));
}

// A room's versions as matches (the web's tools/games.mjs matchesOf, condensed): runs of
// versions sharing doc.match.n, a silence of more than a day starting a new life.
function matchesOfRoom(records) {
  const byTime = [...records].sort((a, b) => a.t - b.t || a.v - b.v);
  const lives = [];
  let life = [];
  for (const r of byTime) {
    const last = life.at(-1);
    if (last && r.t - last.t > GAP_MS) { lives.push(life); life = []; }
    life.push(r);
  }
  if (life.length) lives.push(life);
  const matches = [];
  for (const l of lives) {
    l.sort((a, b) => a.v - b.v || a.t - b.t);
    let open = null;
    for (const r of l) {
      const m = r.doc && r.doc.started ? r.doc.match : null;
      if (!m || typeof m.snap !== 'string') { open = null; continue; }
      if (!open || open.n !== m.n || m.seq === 0) {
        open = { n: m.n, steps: [] };
        matches.push(open);
      }
      if (open.steps.at(-1)?.doc.match.seq === m.seq) continue;
      open.steps.push(r);
    }
  }
  return matches;
}

// Every recorded person's throw, as lines for tools/gym/invert.lua, and what they are:
// { lines, matches, clients, engines, rooms, browser }. Throws by the computer
// (scripted) are left out by the worker.
export function readRecords(dir) {
  if (!existsSync(dir)) throw new Error(`gym: no records folder at ${dir}`);
  const lines = [];
  const info = { matches: 0, rooms: 0, browser: 0, clients: new Set(), engines: new Set(), throwsRecorded: 0 };
  let k = 0;
  for (const name of readdirSync(dir).sort()) {
    const sub = join(dir, name);
    if (!statSync(sub).isDirectory()) continue;
    if (name === 'pitch') {
      // The pitch server's records (since 0.13; the web's backend/api/API.md "Pushes"):
      // pitch/<code>/<made>/<n>-<seq>.json.gz, the signed push byte for byte. A `start`
      // (seq 0) carries the first snapshot, each `act` its action and the snapshot
      // after it (backend/pitch-server/PROTOCOL.md: "snap: the snapshot after it"), so
      // a throw is paired with the snapshot of the push one seq before it, when that one
      // was kept.
      for (const code of readdirSync(sub).sort()) {
        const cd = join(sub, code);
        if (!statSync(cd).isDirectory()) continue;
        let codeHas = false;
        for (const made of readdirSync(cd).sort()) {
          const md = join(cd, made);
          if (!statSync(md).isDirectory()) continue;
          const byMatch = new Map();
          for (const f of readdirSync(md)) {
            if (!f.endsWith('.json.gz') && !f.endsWith('.json')) continue;
            const r = parse(join(md, f));
            const b = r && r.body;
            if (!b || typeof b.n !== 'number') continue;
            if (!byMatch.has(b.n)) byMatch.set(b.n, new Map());
            const seq = r.topic === 'start' ? 0 : b.seq;
            byMatch.get(b.n).set(seq, { topic: r.topic, b });
          }
          for (const [, steps] of [...byMatch].sort((x, y) => x[0] - y[0])) {
            const st = steps.get(0);
            const e = st && st.b.meta && st.b.meta.version ? st.b.meta.version : null;
            const mk = `m${k + 1}`;
            let any = false;
            for (const seq of [...steps.keys()].sort((x, y) => x - y)) {
              const s = steps.get(seq);
              if (s.topic !== 'act') continue;
              const a = s.b.a;
              const prev = steps.get(seq - 1);
              if (!a || a.type !== 'throw' || a.scripted || !a.swing) continue;
              info.throwsRecorded++;
              if (!prev || typeof prev.b.snap !== 'string') { info.unpaired = (info.unpaired || 0) + 1; continue; }
              lines.push({ k: mk, i: seq, kind: 'room', before: prev.b.snap, a, hash: s.b.h, e });
              any = true;
              info.clients.add(s.b.c || 'web');
              if (e) info.engines.add(e);
            }
            if (any) { k++; info.matches++; info.pitch = (info.pitch || 0) + 1; codeHas = true; }
          }
        }
        if (codeHas) info.rooms++;
      }
      continue;
    }
    if (name === 'browser') {
      for (const day of readdirSync(sub).sort()) {
        const dd = join(sub, day);
        if (!statSync(dd).isDirectory()) continue;
        for (const f of readdirSync(dd).sort()) {
          const g = parse(join(dd, f)).game;
          if (!g || typeof g.start !== 'string' || !Array.isArray(g.actions)) continue;
          const people = g.actions.filter(a => a.type === 'throw' && !a.scripted).length;
          if (!people) continue;
          k++;
          info.matches++; info.browser++; info.throwsRecorded += people;
          if (g.client) info.clients.add(String(g.client).split(' ')[0]);
          else info.clients.add('web');
          if (g.engine) info.engines.add(g.engine);
          lines.push({ k: `m${k}`, kind: 'browser', start: g.start, actions: g.actions, e: g.engine || null,
            hashes: Array.isArray(g.hashes) && g.hashes.length === g.actions.length ? g.hashes : null });
        }
      }
      continue;
    }
    const records = readdirSync(sub).filter(f => f.endsWith('.json') || f.endsWith('.json.gz')).map(f => parse(join(sub, f)));
    let roomHas = false;
    for (const m of matchesOfRoom(records)) {
      let prev = null, any = false;
      const mk = `m${k + 1}`;
      for (const r of m.steps) {
        const d = r.doc.match;
        const w = r.with;
        const a = w && w.n === d.n && w.seq === d.seq ? w.a : null;
        if (prev && prev.seq === d.seq - 1 && a && a.type === 'throw' && !a.scripted && a.swing) {
          lines.push({ k: mk, i: d.seq, kind: 'room', before: prev.snap, a, hash: d.hash, e: w.e || null });
          any = true;
          info.throwsRecorded++;
          info.clients.add(w.c || 'web');
          if (w.e) info.engines.add(w.e);
        }
        prev = { seq: d.seq, snap: d.snap };
      }
      if (any) { k++; info.matches++; roomHas = true; }
    }
    if (roomHas) info.rooms++;
  }
  return { lines, info: { ...info, clients: [...info.clients].sort(), engines: [...info.engines].sort() } };
}
