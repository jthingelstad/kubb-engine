// The Kubb Gym (docs/notes/gym.md): hundreds of seeded physics matches thrown the way people
// throw and the way the computer throws, every throw's forensics, the anomalies with a
// command to replay each, the real-games comparison, all on one page.
//
//   node tools/gym.mjs [run] [--quick | --full] [--n 40] [--seed 1]
//       [--throwers cpu,human] [--levels beginner,club,pro] [--surfaces Grass]
//       [--set path=value ...] [--jobs N] [--json file] [--out dir] [--real dir]
//       [--model file] [--records dir] [--maxturns 40] [--list 3] [--engine dir]
//   node tools/gym.mjs compare <A> <B> [run options]   A and B: scorecard JSON files,
//       engine folders (core, session, tune, room, version.lua) or git refs
//   node tools/gym.mjs sweep <path> <v1,v2,...> [run options]
//   node tools/gym.mjs bank <records dir> [--json file] [--engine dir]
//   node tools/gym.mjs fit <records dir> [--write]
//
// Quick (the default) plays 40 matches a configuration, full 300. --real is a
// pk-kubb-score checkout's games folder (default: $PK_KUBB_SCORE/games, else the sibling
// checkout's); without it the reference column is left out. --records is a folder of
// recorded online matches (private: never in this repository); with it the page adds
// the recorded-throw bank. A measuring tool: it changes nothing in the engine.
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, mkdtempSync } from 'node:fs';
import { availableParallelism, tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as score from './gym/score.mjs';
import { runPool, git, extractEngine } from './gym/pool.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

// ---------- options ----------

function parse(argv) {
  const o = { cmd: 'run', pos: [], sets: [], throwers: ['cpu', 'human'], levels: ['beginner', 'club', 'pro'],
    surfaces: ['Grass'], seed: 1, jobs: availableParallelism(), maxturns: 40, list: 3 };
  const cmds = new Set(['run', 'compare', 'sweep', 'bank', 'fit']);
  let i = 0;
  if (argv[0] && cmds.has(argv[0])) { o.cmd = argv[0]; i = 1; }
  for (; i < argv.length; i++) {
    const a = argv[i], v = argv[i + 1];
    const take = () => { i++; return v; };
    if (a === '--quick') o.mode = 'quick';
    else if (a === '--full') o.mode = 'full';
    else if (a === '--n') o.n = Number(take());
    else if (a === '--seed') o.seed = Number(take());
    else if (a === '--throwers') o.throwers = take().split(',');
    else if (a === '--levels') o.levels = take().split(',');
    else if (a === '--surfaces') o.surfaces = take().split(',');
    else if (a === '--set') o.sets.push(take());
    else if (a === '--jobs') o.jobs = Number(take());
    else if (a === '--json') o.json = take();
    else if (a === '--out') o.out = take();
    else if (a === '--real') o.real = take();
    else if (a === '--model') o.model = resolve(take());
    else if (a === '--records') o.records = take();
    else if (a === '--maxturns') o.maxturns = Number(take());
    else if (a === '--list') o.list = Number(take());
    else if (a === '--engine') o.engine = resolve(take());
    else if (a === '--write') o.write = true;
    else if (a === '--keep') o.keep = true;
    else if (a === '--gate') o.gate = true;
    else if (a.startsWith('--')) throw new Error(`gym: unknown option ${a}`);
    else o.pos.push(a);
  }
  if (!o.n) o.n = o.mode === 'full' ? 300 : 40;
  o.mode = o.mode || (o.n >= 300 ? 'full' : 'quick');
  if (!o.model) o.model = join(here, 'gym', 'human-model.json');
  if (o.real === 'none') o.real = null;
  else if (o.real === undefined) {
    const pk = process.env.PK_KUBB_SCORE || join(root, '..', 'pk-kubb-score');
    if (existsSync(join(pk, 'games'))) o.real = join(pk, 'games');
  }
  return o;
}

// ---------- the engine this runs ----------

function engineInfo(dir) {
  const v = readFileSync(join(dir, 'version.lua'), 'utf8').match(/VERSION <const> = "([^"]+)"/);
  const out = { version: v ? v[1] : null };
  if (dir === root) {
    out.commit = git(['rev-parse', 'HEAD']);
    const dirty = git(['status', '--porcelain', '--', 'core', 'session', 'tune', 'room', 'version.lua']);
    out.dirty = !!dirty;
  }
  return out;
}

// Anomaly kinds that are defects whatever their rate (--gate fails on them).
const HARD = ['unsettled', 'broken'];

// ---------- running workers ----------

function configsOf(o, hasModel) {
  const out = [];
  for (const th of o.throwers) {
    if (th === 'human' && !hasModel) continue;
    for (const lv of o.levels) for (const sf of o.surfaces) out.push({ thrower: th, level: lv, surface: sf });
  }
  return out;
}
const cfgName = c => `${c.thrower} ${c.level}${c.surface.toLowerCase() === 'grass' ? '' : ' ' + c.surface.toLowerCase()}`;
const cfgDir = c => `${c.thrower}-${c.level}-${c.surface.toLowerCase()}`;

function workerArgs(o, c, from, to, out) {
  const a = [join('tools', 'gym', 'match.lua'), '--out', out, '--thrower', c.thrower, '--level', c.level,
    '--surface', c.surface, '--seed', String(o.seed), '--from', String(from), '--to', String(to),
    '--maxturns', String(o.maxturns)];
  if (c.thrower === 'human') a.push('--model', o.model);
  for (const s of o.sets) a.push('--set', s);
  if (o.engine) a.push('--engine', o.engine);
  return a;
}

// The command that replays one throw: every option that shapes the simulation, so it
// plays the same match (paths inside this checkout are written relative to it).
export function reproOf(o, c, t) {
  const rel = p => (p.startsWith(root + '/') ? p.slice(root.length + 1) : p);
  const parts = ['lua5.4 tools/gym/match.lua', `--thrower ${c.thrower}`, `--level ${c.level}`,
    `--surface ${c.surface}`, `--seed ${o.seed}`, `--maxturns ${o.maxturns}`];
  if (c.thrower === 'human') parts.push(`--model ${rel(o.model)}`);
  for (const s of o.sets) parts.push(`--set ${s}`);
  if (o.engine) parts.push(`--engine ${rel(o.engine)}`);
  parts.push(`--repro ${t.m}:${t.t}`);
  return parts.join(' ');
}

// Plays every configuration and counts it. Returns the scorecard (JSON-able).
export async function scorecard(o) {
  const hasModel = existsSync(o.model);
  const configs = configsOf(o, hasModel);
  const out = o.out || join(root, 'build', 'gym', `run-${process.pid}-${Date.now()}`);
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  // about six batches a process, so the pool's tail is short
  const chunk = Math.max(2, Math.ceil(o.n * configs.length / (o.jobs * 6)));
  const tasks = [];
  for (const c of configs) {
    const dir = join(out, cfgDir(c));
    for (let f = 1; f <= o.n; f += chunk) tasks.push({ c, args: workerArgs(o, c, f, Math.min(o.n, f + chunk - 1), dir) });
  }
  const t0 = Date.now();
  // the longest configurations first, so the pool ends together
  tasks.sort((a, b) => (a.c.level === 'beginner' ? 0 : 1) - (b.c.level === 'beginner' ? 0 : 1));
  const cfgT = new Map();
  await runPool(tasks, o.jobs, (d, n) => { if (process.stderr.isTTY) process.stderr.write(`\rgym: ${d}/${n} batches`); });
  if (process.stderr.isTTY) process.stderr.write('\n');
  const wall = (Date.now() - t0) / 1000;
  const t1 = Date.now();
  const card = {
    tool: 'kubb-gym', format: 1, created: new Date().toISOString(), engine: { ...engineInfo(o.engine || root), ...(o.engine ? { dir: basename(o.engine) } : {}) }, mode: o.mode, n: o.n, seed: o.seed,
    sets: o.sets, maxturns: o.maxturns, wallS: wall, jobs: o.jobs,
    humanModel: hasModel ? modelInfo(o.model) : null, configs: [], results: {}, clusters: {},
  };
  if (!hasModel && o.throwers.includes('human')) card.notes = [`no human model at ${o.model}: the human thrower is left out (node tools/gym.mjs fit <records> --write)`];
  for (const c of configs) {
    const dir = join(out, cfgDir(c));
    const name = cfgName(c);
    const games = await score.gamesOf(join(dir, 'games'));
    const clusters = new Map();
    const { o: th, matches } = score.throwsOf(dir, (an, t) => {
      const key = `${an.kind}: ${an.key}`;
      let e = clusters.get(key);
      if (!e) clusters.set(key, e = { kind: an.kind, key: an.key, count: 0, examples: [] });
      e.count++;
      if (e.examples.length < o.list) e.examples.push({ cmd: reproOf(o, c, t), detail: an.detail });
    });
    card.configs.push({ ...c, name });
    card.results[name] = { ...games, ...th, matches };
    card.clusters[name] = [...clusters.values()].sort((a, b) => b.count - a.count);
  }
  card.countS = (Date.now() - t1) / 1000;
  card.out = out;
  return card;
}

function modelInfo(path) {
  try {
    const m = JSON.parse(readFileSync(path, 'utf8'));
    return { version: m.version, fitted: m.fitted };
  } catch { return { version: null }; }
}

// ---------- printing ----------

function header(card) {
  const e = card.engine;
  const l = [`Kubb Gym: engine ${e.version}${e.dir ? ` from folder ${e.dir}` : ''}${e.commit ? ` (${e.commit.slice(0, 10)}${e.dirty ? ', with local changes' : ''})` : ''}, `
    + `${card.mode} (${card.n} matches a configuration, seed ${card.seed}, ${card.wallS.toFixed(0)} s on ${card.jobs} processes)`];
  if (card.sets && card.sets.length) l.push(`  set: ${card.sets.join(', ')}`);
  if (card.humanModel) l.push(`  human thrower: model ${card.humanModel.version}`);
  for (const n of card.notes || []) l.push(`  note: ${n}`);
  l.push('  every figure: value ± the 95% interval\'s half width; shares in %, anomalies per 1000 throws');
  return l.join('\n');
}

export function printCard(card, real) {
  const names = card.configs.map(c => c.name);
  const cols = names.map(n => card.results[n]);
  const lines = [header(card), ''];
  const head = real ? [...names, 'real games'] : names;
  const cells = real ? [...cols, real] : cols;
  lines.push(score.page(cells, head));
  lines.push('', 'Anomaly clusters (most frequent first; each command replays that throw in full):');
  for (const n of names) {
    const cl = card.clusters[n] || [];
    if (!cl.length) continue;
    const throws = card.results[n]['f.rest'].n;
    lines.push(`  ${n} (${throws} throws):`);
    for (const e of cl.slice(0, 6)) {
      lines.push(`    ${e.kind}: ${e.key}: ${e.count} (${(1000 * e.count / throws).toFixed(1)} per 1000)`);
      for (const x of e.examples.slice(0, 1)) lines.push(`      ${x.cmd}   # ${x.detail}`);
    }
  }
  return lines.join('\n');
}

// ---------- compare ----------

// What moved beyond noise between two scorecards: z of the difference over 2.58
// (99%: a page has ~80 figures, so at 95% four would move by chance).
export function compareCards(A, B, zBar = 2.58) {
  const rows = [];
  const names = A.configs.map(c => c.name).filter(n => B.results[n]);
  for (const n of names) {
    for (const [k, label, t] of score.KEYS) {
      if (!t) continue;
      const a = A.results[n][k], b = B.results[n][k];
      if (!a || !b || !a.n || !b.n) continue;
      const ia = score.interval(a), ib = score.interval(b);
      const se = Math.hypot(ia.se, ib.se);
      // constant on both sides: a change with no noise at all is reported (z infinite),
      // the same constant is not
      if (!(se > 0)) { if (ia.v !== ib.v) rows.push({ config: n, key: k, label, a: score.cell(a), b: score.cell(b), z: ib.v > ia.v ? Infinity : -Infinity }); continue; }
      const z = (ib.v - ia.v) / se;
      if (Math.abs(z) >= zBar) rows.push({ config: n, key: k, label, a: score.cell(a), b: score.cell(b), z });
    }
  }
  return rows;
}

function printCompare(A, B, rows, nameA, nameB) {
  const l = [`Compare: A = ${nameA} (engine ${A.engine.version}${A.engine.dir ? ' folder ' + A.engine.dir : ''}${A.engine.commit ? ' ' + A.engine.commit.slice(0, 10) : ''}),`
    + ` B = ${nameB} (engine ${B.engine.version}${B.engine.dir ? ' folder ' + B.engine.dir : ''}${B.engine.commit ? ' ' + B.engine.commit.slice(0, 10) : ''}); ${A.n} and ${B.n} matches a configuration`];
  l.push(`Only figures whose difference is past 2.58 standard errors (99%) are shown.`);
  if (!rows.length) { l.push('', 'Nothing moved beyond noise.'); return l.join('\n'); }
  let last = null;
  const table = [];
  for (const r of rows) {
    if (r.config !== last) { table.push([r.config]); last = r.config; }
    table.push([r.label, r.a, r.b, Number.isFinite(r.z) ? (r.z > 0 ? '+' : '') + r.z.toFixed(1) : (r.z > 0 ? '+' : '-') + 'exact']);
  }
  l.push('', score.render(table, ['A', 'B', 'z']));
  return l.join('\n');
}

async function cardFor(spec, o) {
  if (existsSync(spec) && spec.endsWith('.json')) return JSON.parse(readFileSync(spec, 'utf8'));
  // an engine folder (core, session, tune, room, version.lua), e.g. a prototype copy
  if (existsSync(join(spec, 'version.lua')) && existsSync(join(spec, 'core'))) {
    const dir = resolve(spec);
    const card = await scorecard({ ...o, engine: dir, out: join(root, 'build', 'gym', `dir-${process.pid}-${Date.now()}`) });
    card.engine = { ...engineInfo(dir), dir: basename(dir) };
    return card;
  }
  // a git ref: its engine (core, session, tune, room, version.lua) into a temporary
  // folder, thrown by this checkout's gym tools
  const sha = git(['rev-parse', '--verify', `${spec}^{commit}`]);
  if (!sha) throw new Error(`gym compare: ${spec} is neither a scorecard file nor a git ref`);
  const tmp = mkdtempSync(join(tmpdir(), 'kubb-gym-'));
  try {
    extractEngine(sha, tmp);
    const card = await scorecard({ ...o, engine: tmp, out: join(root, 'build', 'gym', `ref-${sha.slice(0, 10)}-${process.pid}`) });
    card.engine = { version: engineInfo(tmp).version, commit: sha, ref: spec };
    return card;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// ---------- main ----------

async function main(argv) {
  const o = parse(argv);
  const real = o.real ? await score.gamesOf(o.real) : null;
  if (o.cmd === 'run') {
    const card = await scorecard(o);
    if (o.records) {
      const { bank } = await import('./gym/bank.mjs');
      card.bank = await bank(o.records, { jobs: o.jobs, engine: o.engine });
    }
    let text = printCard(card, real);
    if (card.bank) {
      const { printBank } = await import('./gym/bank.mjs');
      text += '\n\n' + printBank(card.bank, card);
    }
    console.log(text);
    if (o.json) writeFileSync(o.json, JSON.stringify({ ...card, out: undefined, real }, null, 0));
    if (!o.keep && !o.out) rmSync(card.out, { recursive: true, force: true });
    if (o.gate) {
      // hard defects only: never a rate
      const bad = [];
      for (const [name, cl] of Object.entries(card.clusters))
        for (const e of cl) if (HARD.includes(e.kind)) bad.push(`${name}: ${e.kind}: ${e.key}: ${e.count} (${e.examples[0] ? e.examples[0].cmd : ''})`);
      if (bad.length) { console.error(`gym --gate: hard defects\n  ${bad.join('\n  ')}`); return 1; }
      console.error('gym --gate: no hard defects');
    }
    return 0;
  }
  if (o.cmd === 'compare') {
    if (o.pos.length !== 2) { console.error('usage: node tools/gym.mjs compare <A> <B> [run options]'); return 2; }
    const A = await cardFor(o.pos[0], o), B = await cardFor(o.pos[1], o);
    for (const c of [A, B]) if (c.out && !o.keep) rmSync(c.out, { recursive: true, force: true });
    console.log(printCompare(A, B, compareCards(A, B), o.pos[0], o.pos[1]));
    if (o.json) writeFileSync(o.json, JSON.stringify({ A, B, moved: compareCards(A, B) }));
    return 0;
  }
  if (o.cmd === 'sweep') {
    if (o.pos.length !== 2) { console.error('usage: node tools/gym.mjs sweep <path> <v1,v2,...> [run options]'); return 2; }
    const [path, list] = o.pos;
    const cards = [];
    for (const v of list.split(',')) {
      const card = await scorecard({ ...o, sets: [...o.sets, `${path}=${v}`] });
      if (!o.keep) rmSync(card.out, { recursive: true, force: true });
      cards.push([v, card]);
    }
    const lines = [`Sweep of ${path} over ${list} (${o.n} matches a configuration, seed ${o.seed}); every figure ± its 95% half width`];
    for (const c of cards[0][1].configs) {
      const cols = cards.map(([, card]) => card.results[c.name]);
      lines.push('', `${c.name}:`, score.page(cols, cards.map(([v]) => `${path.split('.').pop()}=${v}`)));
    }
    console.log(lines.join('\n'));
    if (o.json) writeFileSync(o.json, JSON.stringify(cards.map(([v, c]) => ({ value: v, card: c }))));
    return 0;
  }
  if (o.cmd === 'bank') {
    if (o.pos.length !== 1) { console.error('usage: node tools/gym.mjs bank <records dir>'); return 2; }
    const { bank, printBank } = await import('./gym/bank.mjs');
    const b = await bank(o.pos[0], { jobs: o.jobs, engine: o.engine });
    console.log(printBank(b));
    if (o.json) writeFileSync(o.json, JSON.stringify(b));
    return 0;
  }
  if (o.cmd === 'fit') {
    if (o.pos.length !== 1) { console.error('usage: node tools/gym.mjs fit <records dir> [--write]'); return 2; }
    const { fit, printFit } = await import('./gym/fit.mjs');
    const r = await fit(o.pos[0], { jobs: o.jobs });
    console.log(printFit(r));
    if (o.write) {
      writeFileSync(o.model, JSON.stringify(r.model, null, 1).replace(/\[\s*(-?[\d.e+-]+(?:,\s*-?[\d.e+-]+)*)\s*\]/g, (m, x) => `[${x.split(/,\s*/).join(', ')}]`) + '\n');
      console.log(`\nwrote ${o.model}`);
    }
    return 0;
  }
  return 2;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(c => process.exit(c), e => { console.error(e.message || e); process.exit(1); });
}
