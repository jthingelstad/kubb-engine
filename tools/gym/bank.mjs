// The Kubb Gym's recorded-throw bank (docs/notes/gym.md "The recorded-throw bank"):
// every recorded person's throw thrown again, with forensics, three ways:
//
//   as played    the recorded launch on the engine that planned it (what happened)
//   launch now   the recorded launch on this checkout's physics (or --engine DIR's)
//   re-planned   the recovered swing (its misses counted from this checkout's targets,
//                the same nerve draws) planned and thrown by this checkout
//
// beside the human thrower's own figures at the same levels when the scorecard has
// them. Whether each recorded throw replays to the recorded snapshot is checked under
// wasmoon (the reference, docs/DETERMINISM.md) and, for comparison, desktop Lua.
//
//   node tools/gym.mjs bank <records dir>       or   node tools/gym.mjs --records <dir>
//
// Private input: the records never enter this repository, and only counts leave here.
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { recover } from './fit.mjs';
import { runPool, root } from './pool.mjs';
import * as score from './score.mjs';

const ACCEPT = 1e-6;

function sourcesOf(dir) {
  const out = {};
  const walk = d => {
    for (const f of readdirSync(d)) {
      const p = join(d, f);
      if (statSync(p).isDirectory()) walk(p);
      else if (f.endsWith('.lua')) out[relative(dir, p).slice(0, -4)] = readFileSync(p, 'utf8');
    }
  };
  for (const sub of ['core', 'session', 'tune', 'room']) { try { walk(join(dir, sub)); } catch { /* an older engine without it */ } }
  out.version = readFileSync(join(dir, 'version.lua'), 'utf8');
  return out;
}

// Under wasmoon: of the room throws given, which replay to the recorded hash on engine dir.
async function wasmSame(dir, items) {
  const { createEngine } = await import('../../tests/node/wasm.mjs');
  const e = await createEngine({ sources: sourcesOf(dir) });
  try { e.call('useTune', { name: 'pointer' }); } catch { /* an engine without tunes */ }
  const out = new Map();
  for (const it of items) {
    try {
      const r = JSON.parse(e.text('restore', it.before));
      if (r && r.error) { out.set(it.key, null); continue; }
      e.call('need');
      e.call('apply', it.a);
      out.set(it.key, e.call('hash').hash === it.hash);
    } catch { out.set(it.key, false); }
  }
  return out;
}

function lineOf(t, rec, v, legal) {
  return { k: t.kind === 'drill' ? 'drill' : t.kind, f: rec, v, legal, dist: t.dist, drill: rec.drill };
}

export async function bank(dir, { jobs = 4, engine = null } = {}) {
  const here = engine || root; // the engine "now" means: this checkout, or --engine DIR
  const rec = await recover(dir, { jobs, played: true });
  try {
    const ok = rec.throws.filter(t => t.err != null && t.err < ACCEPT && t.played);
    // the recovered swings, re-planned and thrown on this checkout; and the recorded launch on its physics
    const rt = join(rec.tmp, 'rethrow.jsonl');
    writeFileSync(rt, ok.map(t => JSON.stringify({ k: `${t.k}:${t.i}`, db: t.back - t.solBack, dr: t.stop - t.solRelease,
      flick: t.flick, shake: t.shake, pull: t.pull, z: t.z, arcSet: t.arcSet, release: t.release, tiltPlan: t.tiltPlan,
      spinPlan: t.spinPlan })).join('\n') + '\n');
    const inp = join(rec.tmp, 'in.jsonl');
    await runPool([{ args: [join('tools', 'gym', 'invert.lua'), '--engine', here, '--in', inp, '--played', '--rethrow', rt, '--out', join(rec.tmp, 'now.jsonl')] }], 1);
    const now = new Map();
    for (const line of readFileSync(join(rec.tmp, 'now.jsonl'), 'utf8').split('\n')) {
      if (!line) continue;
      const o = JSON.parse(line);
      now.set(`${o.k}:${o.i}`, o);
    }
    // hash checks: each room throw on the engine that planned it, wasmoon and desktop
    const byKey = new Map(rec.lines.filter(l => l.kind === 'room').map(l => [`${l.k}:${l.i}`, l]));
    const hashes = { wasm: 0, desktop: 0, agree: 0, n: 0, nowWasm: 0 };
    const byEng = new Map();
    for (const t of ok) {
      const l = byKey.get(`${t.k}:${t.i}`);
      if (!l) continue;
      if (!byEng.has(t.eng)) byEng.set(t.eng, []);
      byEng.get(t.eng).push({ key: `${t.k}:${t.i}`, before: l.before, a: l.a, hash: l.hash, desktop: t.same });
    }
    for (const [name, items] of byEng) {
      const e = rec.engines.find(x => x.name === name);
      const w = await wasmSame(e.dir, items);
      for (const it of items) {
        const ws = w.get(it.key);
        hashes.n++;
        if (ws) hashes.wasm++;
        if (it.desktop) hashes.desktop++;
        if (!!ws === !!it.desktop) hashes.agree++;
      }
    }
    const allItems = [...byEng.values()].flat();
    const wNow = await wasmSame(here, allItems);
    for (const it of allItems) if (wNow.get(it.key)) hashes.nowWasm++;
    const cols = { played: {}, now: {}, replan: {} };
    const add = (col, level, line) => {
      for (const key of [level, 'all']) {
        if (!cols[col][key]) cols[col][key] = score.blankThrows();
        score.addThrow(cols[col][key], line);
      }
    };
    const levels = new Set();
    for (const t of ok) {
      levels.add(t.level);
      const vd = t.verdicts || {};
      const v = [vd.powerV, vd.releaseV, vd.steady, vd.sideV];
      add('played', t.level, lineOf(t, t.played, v, t.legal));
      const n = now.get(`${t.k}:${t.i}`);
      if (n && n.played) add('now', t.level, lineOf(t, n.played, v, t.legal));
      if (n && n.rethrow) add('replan', t.level, lineOf(t, n.rethrow, [n.rethrow.powerV, n.rethrow.releaseV, n.rethrow.steady, null], n.rethrow.legal !== false));
    }
    return {
      throws: ok.length, recorded: rec.info.throwsRecorded, matches: new Set(ok.map(t => t.k)).size,
      levels: [...levels].sort(), clients: rec.info.clients, engines: Object.fromEntries([...byEng].map(([k, v]) => [k, v.length])),
      hashes, cols,
    };
  } finally { rec.done(); }
}

export function printBank(b, card) {
  const l = [`Recorded-throw bank: ${b.throws} of ${b.recorded} recorded throws by people (${b.matches} matches; clients ${b.clients.join(', ')})`];
  const h = b.hashes;
  l.push(`  replayed from the snapshot before each on the engine that planned it, the recorded launch gives the recorded snapshot:`
    + ` wasmoon ${h.wasm} of ${h.n}, desktop Lua ${h.desktop} of ${h.n} (the two agree on ${h.agree});`
    + ` on the engine scored (wasmoon) ${h.nowWasm} of ${h.n}`);
  const names = [], colsOut = [];
  for (const lv of b.levels) {
    names.push(`played ${lv}`); colsOut.push(b.cols.played[lv]);
    const hc = card && card.results && card.results[`human ${lv}`];
    if (hc) { names.push(`gym human ${lv}`); colsOut.push(hc); }
  }
  names.push('played all', 'launch now', 're-planned now');
  colsOut.push(b.cols.played.all, b.cols.now.all, b.cols.replan.all);
  l.push('  played: the recorded launch on its own engine; launch now: on the scored engine\'s physics (this checkout, or --engine);'
    + ' re-planned now: the same swing and nerves planned and thrown by that engine; gym human: the human thrower\'s matches above', '');
  l.push(score.page(colsOut, names, { skip: k => k.startsWith('g.') || k.startsWith('d.spread') || k.startsWith('d.far2') }));
  return l.join('\n');
}
