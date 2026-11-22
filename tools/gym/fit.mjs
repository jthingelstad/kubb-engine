// The Kubb Gym's fit (docs/notes/gym.md "Fitting the human thrower"): every recorded
// person's swing recovered from its launch, and the human thrower's model made from
// what people did at the meter.
//
//   node tools/gym.mjs fit <records dir> [--write]
//
// Each recorded throw is inverted (tools/gym/invert.lua) on every tagged engine and on
// this checkout: the snapshot before it, planned as the player's session planned it.
// The engine that rebuilds the recorded launch (relative error under 1e-6) is the one
// that planned it, and its plan gives the throw's misses: the backswing past the power
// target's centre, the stop past the release target's, the flick, the shake and the
// pull, and the nerves' draws (which should look like a standard normal). The model is
// those misses' quantiles per throw level and projectile, with counts and nothing else:
// no snapshot, action, name or room leaves this module. The records are private; they
// travel to the workers in a temporary folder that is removed before this returns.
import { mkdtempSync, rmSync, writeFileSync, readFileSync, chmodSync, mkdirSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readRecords } from './records.mjs';
import { browserToRoom } from './wasmreplay.mjs';
import { runPool, git, extractEngine, root } from './pool.mjs';

export const MODEL_VERSION = 2; // 2: refitted 2026-11-22 from the pitch server and browser records (engine 0.13.1); 1: 2026-11-20, rooms on 0.7.1 (human-model-0.7.json)
const ACCEPT = 1e-6;
const QS = Array.from({ length: 21 }, (_, i) => i / 20);

function quantiles(xs) {
  const v = [...xs].sort((a, b) => a - b);
  if (!v.length) return null;
  return QS.map(q => {
    const x = q * (v.length - 1), i = Math.floor(x), f = x - i;
    return +(i + 1 < v.length ? v[i] + (v[i + 1] - v[i]) * f : v[i]).toFixed(4);
  });
}
const mean = xs => xs.reduce((a, b) => a + b, 0) / (xs.length || 1);
const sd = xs => { const m = mean(xs); return Math.sqrt(mean(xs.map(x => (x - m) ** 2))); };
function corr(a, b) {
  const ma = mean(a), mb = mean(b);
  let s = 0, sa = 0, sb = 0;
  for (let i = 0; i < a.length; i++) { s += (a[i] - ma) * (b[i] - mb); sa += (a[i] - ma) ** 2; sb += (b[i] - mb) ** 2; }
  return sa > 0 && sb > 0 ? s / Math.sqrt(sa * sb) : 0;
}

// Every recorded throw recovered: { throws: [per throw: the worker's line plus engine],
// info, engines, tmp }. Keeps the temporary folder (the caller removes it with done()).
export async function recover(dir, { jobs = 4, played = true } = {}) {
  const read = readRecords(dir);
  const info = read.info;
  // a browser match replayed under wasmoon on its own engine: one line a throw, with
  // the snapshot its player saw (tools/gym/wasmreplay.mjs)
  const wasm = await browserToRoom(read.lines);
  const lines = wasm.lines;
  info.browserReplay = wasm.stats;
  const tmp = mkdtempSync(join(tmpdir(), 'kubb-gym-rec-'));
  chmodSync(tmp, 0o700);
  const done = () => rmSync(tmp, { recursive: true, force: true });
  try {
    const input = join(tmp, 'in.jsonl');
    writeFileSync(input, lines.map(l => JSON.stringify(l)).join('\n') + '\n');
    const tags = (git(['tag', '-l', 'v*', '--sort=version:refname']) || '').split('\n').filter(Boolean);
    const engines = [];
    for (const t of tags) {
      const d = join(tmp, 'eng', t);
      mkdirSync(d, { recursive: true });
      extractEngine(t, d);
      engines.push({ name: t, dir: d });
    }
    engines.push({ name: 'checkout', dir: root });
    const tasks = engines.map(e => ({ e, args: [join('tools', 'gym', 'invert.lua'), '--engine', e.dir, '--in', input,
      '--out', join(tmp, `inv-${e.name}.jsonl`)] }));
    await runPool(tasks, jobs);
    // The engine that planned a throw: the one its record names, when that one rebuilds
    // the launch; else the oldest that does (records without one predate the first tag).
    // Any engine whose plan is close enough rebuilds a launch exactly (the draws take up
    // the difference), so the error alone cannot choose.
    const named = new Map();
    for (const l of lines) if (l.e) named.set(l.k, `v${l.e}`);
    const best = new Map();
    const inverts = {};
    for (const e of engines) {
      let ok = 0;
      for (const line of readFileSync(join(tmp, `inv-${e.name}.jsonl`), 'utf8').split('\n')) {
        if (!line) continue;
        const o = JSON.parse(line);
        const key = `${o.k}:${o.i}`;
        const good = o.err != null && o.err < ACCEPT;
        if (good) ok++;
        const b = best.get(key);
        const mine = named.get(o.k) === e.name;
        const bGood = b && b.err != null && b.err < ACCEPT;
        if (!b || (good && (!bGood || (mine && !b.mine))) || (!good && !bGood && o.err != null && (b.err == null || o.err < b.err)))
          best.set(key, { ...o, eng: e.name, mine });
      }
      inverts[e.name] = ok;
    }
    const throws = [...best.values()];
    if (played) {
      // the recorded launch on the engine that planned it: what really happened, with forensics
      const byEng = new Map();
      for (const t of throws) if (t.err != null && t.err < ACCEPT) {
        if (!byEng.has(t.eng)) byEng.set(t.eng, new Set());
        byEng.get(t.eng).add(t.k);
      }
      const ptasks = [];
      for (const [name, ks] of byEng) {
        const e = engines.find(x => x.name === name);
        const sub = join(tmp, `in-${name}.jsonl`);
        writeFileSync(sub, lines.filter(l => ks.has(l.k)).map(l => JSON.stringify(l)).join('\n') + '\n');
        ptasks.push({ args: [join('tools', 'gym', 'invert.lua'), '--engine', e.dir, '--in', sub, '--played',
          '--out', join(tmp, `played-${name}.jsonl`)] });
      }
      await runPool(ptasks, jobs);
      const byKey = new Map(throws.map(t => [`${t.k}:${t.i}`, t]));
      for (const name of byEng.keys()) {
        for (const line of readFileSync(join(tmp, `played-${name}.jsonl`), 'utf8').split('\n')) {
          if (!line) continue;
          const o = JSON.parse(line);
          const t = byKey.get(`${o.k}:${o.i}`);
          if (t && t.eng === name) { t.played = o.played; t.same = o.same; }
        }
      }
    }
    return { throws, info, inverts, lines, tmp, engines, done };
  } catch (e) { done(); throw e; }
}

function part(ts) {
  if (!ts.length) return null;
  const full = ts.filter(t => t.flick >= 0.9999);
  const partial = ts.filter(t => t.flick < 0.9999).map(t => t.flick);
  return {
    n: ts.length,
    back: quantiles(ts.map(t => t.back - t.solBack)),
    release: quantiles(ts.map(t => t.stop - t.solRelease)),
    flickFull: +(full.length / ts.length).toFixed(4),
    flick: partial.length ? quantiles(partial) : null,
    shake: quantiles(ts.map(t => t.shake)),
    pullRight: +(ts.filter(t => t.pull > 0).length / ts.length).toFixed(4),
  };
}

export async function fit(dir, { jobs = 4 } = {}) {
  const rec = await recover(dir, { jobs, played: false });
  try {
    const ok = rec.throws.filter(t => t.err != null && t.err < ACCEPT && t.solBack != null);
    const levels = {};
    for (const lv of [...new Set(ok.map(t => t.level))].sort()) {
      const ts = ok.filter(t => t.level === lv);
      levels[lv] = { baton: part(ts.filter(t => t.how === 'baton')), drill: part(ts.filter(t => t.how === 'drill')) };
    }
    levels.pooled = { baton: part(ok.filter(t => t.how === 'baton')), drill: part(ok.filter(t => t.how === 'drill')) };
    const use = {};
    for (const lv of ['beginner', 'club', 'pro']) if (!levels[lv]) use[lv] = levels.club ? 'club' : 'pooled';
    const byLevel = {};
    for (const t of ok) byLevel[t.level] = (byLevel[t.level] || 0) + 1;
    const model = {
      version: MODEL_VERSION,
      fitted: {
        what: 'quantiles (0, 5%, ..., 100%) of the swing\'s misses, measured from recorded online matches',
        throws: ok.length, batons: ok.filter(t => t.how === 'baton').length, drills: ok.filter(t => t.how === 'drill').length,
        matches: new Set(ok.map(t => t.k)).size, levels: byLevel, clients: rec.info.clients,
        engineOfRecord: [...new Set(rec.info.engines)],
      },
      units: { back: 'deg past the power target centre', release: 'deg past the release target centre',
        flick: 'share of power, when not full', shake: '0..1', pullRight: 'share' },
      levels, use,
    };
    const z = [0, 1, 2].map(i => ok.map(t => t.z[i]));
    const zt = ok.filter(t => t.how === 'baton').map(t => t.z[2]);
    const parts = { back: ok.map(t => t.back - t.solBack), release: ok.map(t => t.stop - t.solRelease),
      flick: ok.map(t => t.flick), shake: ok.map(t => t.shake) };
    const names = Object.keys(parts);
    const correlations = {};
    for (let i = 0; i < names.length; i++) for (let j = i + 1; j < names.length; j++)
      correlations[`${names[i]}~${names[j]}`] = +corr(parts[names[i]], parts[names[j]]).toFixed(3);
    // (0.18.0) do a baton's misses grow with the backswing its plan asked for? The
    // backswing and release misses by the plan's backswing, in three bands: n, the median
    // absolute miss and the share past the 0.16 meter's power bar at that range would be
    // unknowable here (the meter came later), so the spread alone
    const byBack = {};
    const bats = ok.filter(t => t.how === 'baton');
    for (const [name, lo, hi] of [['under 110', -1e9, 110], ['110 to 125', 110, 125], ['125 and over', 125, 1e9]]) {
      const ts = bats.filter(t => t.solBack >= lo && t.solBack < hi);
      const med = xs => { const a = xs.map(Math.abs).sort((x, y) => x - y); return a.length ? +a[a.length >> 1].toFixed(2) : null; };
      byBack[name] = { n: ts.length, backMiss: med(ts.map(t => t.back - t.solBack)),
        releaseMiss: med(ts.map(t => t.stop - t.solRelease)), shake: med(ts.map(t => t.shake)) };
    }
    const engs = {};
    for (const t of ok) engs[t.eng] = (engs[t.eng] || 0) + 1;
    const report = {
      recorded: rec.info.throwsRecorded, attempted: rec.throws.length, recovered: ok.length,
      unrecovered: rec.throws.filter(t => !(t.err != null && t.err < ACCEPT)).map(t => t.error ? 'error' : t.err == null ? 'no plan' : `err ${t.err.toExponential(1)}`),
      engines: engs, inverts: rec.inverts, byBack,
      backMissByBack: +corr(bats.map(t => t.solBack), bats.map(t => Math.abs(t.back - t.solBack))).toFixed(3),
      nerves: { side: { mean: mean(z[0]), sd: sd(z[0]) }, length: { mean: mean(z[1]), sd: sd(z[1]) }, tumble: { mean: mean(zt), sd: sd(zt) } },
      correlations, arcSet: ok.filter(t => t.arcSet).length, tiltSet: ok.filter(t => t.how === 'baton' && t.tiltPlan !== 0).length,
    };
    return { model, report };
  } finally { rec.done(); }
}

const f2 = x => (x >= 0 ? ' ' : '') + x.toFixed(2);
function qline(q) { return q ? `median ${f2(q[10])}, 5% ${f2(q[1])}, 95% ${f2(q[19])}` : '-'; }

export function printFit({ model, report }) {
  const F = model.fitted;
  const l = [`Human thrower fit (model ${model.version}): ${report.recovered} of ${report.attempted} recorded throws recovered`
    + ` (${F.batons} batons, ${F.drills} drills) from ${F.matches} matches; levels ${Object.entries(F.levels).map(([k, v]) => `${k} ${v}`).join(', ')};`
    + ` clients ${F.clients.join(', ')}`];
  l.push(`  recovered on: ${Object.entries(report.engines).map(([k, v]) => `${k} ${v}`).join(', ')}`);
  l.push(`  each engine rebuilds: ${Object.entries(report.inverts).map(([k, v]) => `${k} ${v}`).join(', ')}`);
  if (report.unrecovered.length) l.push(`  not recovered: ${report.unrecovered.join(', ')}`);
  l.push(`  the player set the arc on ${report.arcSet}, a tilt on ${report.tiltSet}`);
  const n = report.nerves;
  l.push(`  nerves draws (a standard normal if the engine's nerves are what people show): side mean ${f2(n.side.mean)} sd ${n.side.sd.toFixed(2)};`
    + ` length mean ${f2(n.length.mean)} sd ${n.length.sd.toFixed(2)}; tumble mean ${f2(n.tumble.mean)} sd ${n.tumble.sd.toFixed(2)}`);
  l.push(`  correlations of the parts (the model draws each on its own): ${Object.entries(report.correlations).map(([k, v]) => `${k} ${v}`).join(', ')}`);
  if (report.byBack) {
    l.push(`  a baton's misses by the backswing its plan asked for (median absolute; correlation of |back miss| with the plan's backswing ${report.backMissByBack}): `
      + Object.entries(report.byBack).map(([k, v]) => `${k}: n ${v.n}, back ${v.backMiss}, release ${v.releaseMiss}, shake ${v.shake}`).join('; '));
  }
  for (const [lv, p] of Object.entries(model.levels)) {
    for (const proj of ['baton', 'drill']) {
      const q = p[proj];
      if (!q) continue;
      l.push(`  ${lv} ${proj} (${q.n}): back ${qline(q.back)}; release ${qline(q.release)};`
        + ` flick full ${(q.flickFull * 100).toFixed(0)}%${q.flick ? ` else ${qline(q.flick)}` : ''}; shake ${qline(q.shake)}; pulled right ${(q.pullRight * 100).toFixed(0)}%`);
    }
  }
  if (Object.keys(model.use).length) l.push(`  levels with no recorded swings use: ${Object.entries(model.use).map(([k, v]) => `${k} -> ${v}`).join(', ')}`);
  return l.join('\n');
}
