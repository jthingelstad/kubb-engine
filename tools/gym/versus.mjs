// The Kubb Gym's versus (docs/notes/gym.md "Versus"): two teams that play differently,
// every seed played twice with the teams swapped between the sides (and so the opening
// throw), games won with a paired interval, and each team's own scorecard rows side by
// side. The match worker is tools/gym/match.lua (--a, --b, --swap); the per-team
// switching of the tune tables is tools/gym/versus.lua. A measuring tool.
import { mkdirSync, readFileSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import * as score from './score.mjs';
import { runPool, root, LUA } from './pool.mjs';

const LEVELS = ['kid', 'beginner', 'club', 'pro'];
const THROWERS = ['cpu', 'human'];

// A team's spec: "level=pro;thrower=cpu;raise=apart;autothrow.tune.inkast.pro.row=0"
// (hand=k: the human thrower's recorded misses times k, tools/gym/human.lua human.scale)
// (parts split by ';' or ','). Returns { level, thrower, raise, sets: [[path, value]],
// text } with text the normal form the worker is given. Raising policy names and tune
// paths are checked by the worker, which has the engine.
export function parseSpec(str, label = 'A') {
  // raise: 'default' unless given: the engine's own for the team (tools/gym/versus.lua)
  const spec = { level: 'club', thrower: 'cpu', raise: 'default', sets: [] };
  const seen = new Set();
  for (let part of String(str || '').split(/[,;]/)) {
    part = part.trim();
    if (!part) continue;
    const m = part.match(/^([\w.]+)\s*=\s*(.*)$/);
    if (!m) throw new Error(`gym versus: team ${label}: not key=value: ${part}`);
    const [, k, v] = m;
    if (seen.has(k)) throw new Error(`gym versus: team ${label}: ${k} given twice`);
    seen.add(k);
    if (k === 'level') {
      if (!LEVELS.includes(v)) throw new Error(`gym versus: team ${label}: level ${LEVELS.join(', ')}, got ${v}`);
      spec.level = v;
    } else if (k === 'thrower') {
      if (!THROWERS.includes(v)) throw new Error(`gym versus: team ${label}: thrower cpu or human, got ${v}`);
      spec.thrower = v;
    } else if (k === 'raise') {
      if (!/^\w+$/.test(v)) throw new Error(`gym versus: team ${label}: raise is a policy name, got ${v}`);
      spec.raise = v;
    } else if (k === 'hand') {
      if (v === '' || !(Number(v) > 0)) throw new Error(`gym versus: team ${label}: hand is a positive number, got ${v}`);
      spec.hand = Number(v);
    } else if (k.includes('.')) {
      if (v === '' || !Number.isFinite(Number(v))) throw new Error(`gym versus: team ${label}: ${k} is not set to a number: ${v}`);
      spec.sets.push([k, Number(v)]);
    } else throw new Error(`gym versus: team ${label}: unknown part ${k} (level, thrower, raise, hand or a tune path)`);
  }
  spec.text = [`level=${spec.level}`, `thrower=${spec.thrower}`, `raise=${spec.raise}`,
    ...(spec.hand !== undefined ? [`hand=${spec.hand}`] : []), ...spec.sets.map(([p, v]) => `${p}=${v}`)].join(';');
  return spec;
}

// The side ("A" or "B") team `team` plays in a game of orientation `swap`.
export const sideOf = (team, swap) => (swap ? (team === 'A' ? 'B' : 'A') : team);

// ---------- games won ----------

// The 95% interval of games won, from the over lines of every game ({ m, swap,
// winnerTeam, firstTeam, limit }). Paired: a seed's two games (one each way round) give
// team A a score of 0, 0.5 or 1 (a game at the turn limit counts half to each), and the
// interval is the normal one of the mean of those scores over seeds, so the seed's luck
// and the opener's edge cancel inside each pair. Wilson: A's share of the decided games,
// as if every game were independent (wider than the paired one when the pairs agree).
export function tally(overs) {
  const out = { games: overs.length, A: 0, B: 0, limit: 0, byOpener: {}, seeds: 0 };
  for (const o of ['A', 'B']) out.byOpener[o] = { games: 0, A: 0, B: 0, limit: 0 };
  const bySeed = new Map();
  for (const g of overs) {
    const who = g.limit || !g.winnerTeam ? 'limit' : g.winnerTeam;
    out[who]++;
    const op = out.byOpener[g.firstTeam];
    if (op) { op.games++; op[who]++; }
    if (!bySeed.has(g.m)) bySeed.set(g.m, []);
    bySeed.get(g.m).push(who === 'limit' ? 0.5 : who === 'A' ? 1 : 0);
  }
  let n = 0, s = 0, q = 0;
  for (const v of bySeed.values()) {
    if (v.length !== 2) continue;
    const d = (v[0] + v[1]) / 2;
    n++; s += d; q += d * d;
  }
  out.seeds = n;
  if (n) {
    const mean = s / n;
    const sd = n > 1 ? Math.sqrt(Math.max(0, (q - s * s / n) / (n - 1))) : 0;
    const h = 1.96 * sd / Math.sqrt(n);
    out.paired = { v: mean, lo: Math.max(0, mean - h), hi: Math.min(1, mean + h), se: sd / Math.sqrt(n) };
  }
  const decided = out.A + out.B;
  if (decided) out.wilson = score.interval({ t: 'p', k: out.A, n: decided });
  for (const o of ['A', 'B']) {
    const b = out.byOpener[o];
    const d = b.A + b.B;
    if (d) b.wilson = score.interval({ t: 'p', k: b.A, n: d });
  }
  return out;
}

// z of B's figure less A's for every scorecard row, as compare reckons it (each side's
// standard error, combined). The two teams play the same games, so the rows are not
// independent; read a z past 2.58 as compare's "moved", nothing finer.
export function teamZ(a, b) {
  const out = {};
  for (const [k, , t] of score.KEYS) {
    if (!t) continue;
    const x = a[k], y = b[k];
    if (!x || !y || !x.n || !y.n) continue;
    const ia = score.interval(x), ib = score.interval(y);
    const se = Math.hypot(ia.se, ib.se);
    if (!(se > 0)) { if (ia.v !== ib.v) out[k] = ib.v > ia.v ? Infinity : -Infinity; continue; }
    out[k] = (ib.v - ia.v) / se;
  }
  return out;
}

// ---------- running ----------

function workerArgs(o, A, B, surface, swap, from, to, extra) {
  const a = [join('tools', 'gym', 'match.lua'), '--a', A.text, '--b', B.text, '--swap', String(swap),
    '--surface', surface, '--seed', String(o.seed), '--from', String(from), '--to', String(to),
    '--maxturns', String(o.maxturns)];
  if (A.thrower === 'human' || B.thrower === 'human') a.push('--model', o.model);
  for (const s of o.sets || []) a.push('--set', s);
  if (o.rules) a.push('--rules', o.rules);
  if (o.engine) a.push('--engine', o.engine);
  return a.concat(extra);
}

// The command that replays one throw of a versus game.
export function versusRepro(o, A, B, surface, swap, t) {
  const rel = p => (p.startsWith(root + '/') ? p.slice(root.length + 1) : p);
  const parts = ['lua5.4 tools/gym/match.lua', `--a "${A.text}"`, `--b "${B.text}"`, `--swap ${swap}`,
    `--surface ${surface}`, `--seed ${o.seed}`, `--maxturns ${o.maxturns}`];
  if (A.thrower === 'human' || B.thrower === 'human') parts.push(`--model ${rel(o.model)}`);
  for (const s of o.sets || []) parts.push(`--set ${s}`);
  if (o.rules) parts.push(`--rules ${o.rules}`);
  if (o.engine) parts.push(`--engine ${rel(o.engine)}`);
  parts.push(`--repro ${t.m}:${t.t}`);
  return parts.join(' ');
}

// Reads of each team's settings over a probe or a run: { path: { base, A, B, reads } } summed.
function addReads(into, sets) {
  for (const [p, e] of Object.entries(sets || {})) {
    const x = into[p] || (into[p] = { base: e.base, A: e.A, B: e.B, reads: { A: 0, B: 0, none: 0 } });
    for (const k of ['A', 'B', 'none']) x.reads[k] += e.reads[k] || 0;
  }
  return into;
}

// What a team sets that nothing reads while that team acts: the reasons to refuse.
export function unread(reads) {
  const out = [];
  for (const [p, e] of Object.entries(reads)) {
    for (const t of ['A', 'B']) if (e[t] !== undefined && e[t] !== null && !e.reads[t]) out.push({ team: t, path: p });
  }
  return out;
}

// Plays the first `probe` seeds both ways round without forensics, counting reads; throws
// when a team's setting is never read while that team acts (a number copied into a local
// at import, or one this team never reaches), or when the worker refuses the specs.
export function probeSpecs(o, A, B, surface) {
  const reads = {};
  for (const swap of [0, 1]) {
    let text;
    try {
      text = execFileSync(LUA, workerArgs(o, A, B, surface, swap, 1, o.probe, ['--probe']),
        { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) {
      const why = (e.stderr || e.message).toString().trim();
      // exit 2: the worker refused the specs; anything else: the engine failed under them
      throw new Error(e.status === 2 ? `gym versus: refused: ${why}` : `gym versus: the probe games failed under these specs:\n${why}`);
    }
    addReads(reads, JSON.parse(text.trim().split('\n').pop()).sets);
  }
  const bad = unread(reads);
  if (bad.length) {
    throw new Error('gym versus: refused: a setting nothing reads while its team acts, so it would measure nothing\n'
      + bad.map(b => `  team ${b.team}: ${b.path} (read ${reads[b.path].reads.A} times by A, ${reads[b.path].reads.B} by B, in ${2 * o.probe} probe games): `
        + 'a module copies it into a local when it is imported, or this team (its level, its thrower) never reaches it').join('\n')
      + `\n  (--probe N plays more probe games, for a number read only rarely)`);
  }
  return reads;
}

// Plays and counts one surface. Returns { tally, cards: { A, B }, z, reads, mirror, clusters }.
export async function versusRun(o, A, B, surface) {
  const reads = o.probe > 0 ? probeSpecs(o, A, B, surface) : {};
  const out = join(o.out || join(root, 'build', 'gym', `versus-${process.pid}-${Date.now()}`), surface.toLowerCase());
  rmSync(out, { recursive: true, force: true });
  const chunk = Math.max(2, Math.ceil(o.n * 2 / (o.jobs * 6)));
  const tasks = [];
  for (const swap of [0, 1]) {
    const dir = join(out, `swap${swap}`);
    mkdirSync(dir, { recursive: true });
    for (let f = 1; f <= o.n; f += chunk) tasks.push({ args: workerArgs(o, A, B, surface, swap, f, Math.min(o.n, f + chunk - 1), ['--out', dir]) });
  }
  const t0 = Date.now();
  await runPool(tasks, o.jobs, (d, n) => { if (process.stderr.isTTY) process.stderr.write(`\rgym versus: ${d}/${n} batches`); });
  if (process.stderr.isTTY) process.stderr.write('\n');
  const wallS = (Date.now() - t0) / 1000;
  const analyze = await score.analyzer();
  const cards = { A: { ...score.blankGames(), ...score.blankThrows() }, B: { ...score.blankGames(), ...score.blankThrows() } };
  const overs = [], runReads = {}, texts = [{}, {}];
  const clusters = { A: new Map(), B: new Map() };
  for (const swap of [0, 1]) {
    const dir = join(out, `swap${swap}`);
    const gdir = join(dir, 'games');
    for (const f of readdirSync(gdir).sort()) {
      if (!f.endsWith('.txt')) continue;
      const text = readFileSync(join(gdir, f), 'utf8');
      texts[swap][Number(f.slice(0, 5))] = text;
      for (const t of ['A', 'B']) score.addGameText(cards[t], analyze, text, sideOf(t, swap));
    }
    for (const f of readdirSync(dir).sort()) {
      if (!f.startsWith('throws-')) continue;
      for (const line of readFileSync(join(dir, f), 'utf8').split('\n')) {
        if (!line) continue;
        const j = JSON.parse(line);
        if (j.over) overs.push(j);
        else if (j.reads) addReads(runReads, j.reads);
      }
    }
    for (const t of ['A', 'B']) {
      score.throwsOf(dir, (an, x) => {
        const key = `${an.kind}: ${an.key}`;
        let e = clusters[t].get(key);
        if (!e) clusters[t].set(key, e = { kind: an.kind, key: an.key, count: 0, examples: [] });
        e.count++;
        if (e.examples.length < (o.list || 3)) e.examples.push({ cmd: versusRepro(o, A, B, surface, swap, x), detail: an.detail });
      }, x => x.team === t, cards[t]);
    }
  }
  // a seed's two games are the same game when the teams play alike: the game files match
  let same = 0, pairs = 0;
  for (const m of Object.keys(texts[0])) if (texts[1][m] !== undefined) { pairs++; if (texts[0][m] === texts[1][m]) same++; }
  if (!o.keep && !o.out) rmSync(out, { recursive: true, force: true });
  return {
    surface, wallS, tally: tally(overs), cards, z: teamZ(cards.A, cards.B), probeReads: reads, reads: runReads,
    mirror: { pairs, same },
    clusters: { A: [...clusters.A.values()].sort((a, b) => b.count - a.count), B: [...clusters.B.values()].sort((a, b) => b.count - a.count) },
  };
}

// ---------- printing ----------

const pct = (iv) => `${(iv.v * 100).toFixed(1)}% (${(iv.lo * 100).toFixed(1)} to ${(iv.hi * 100).toFixed(1)})`;

export function printVersus(o, A, B, r) {
  const T = r.tally;
  const l = [];
  l.push(`Kubb Gym versus, ${r.surface}: ${o.n} seeds (${T.games} games, each seed both ways round), seed ${o.seed}, `
    + `turn limit ${o.maxturns}, ${r.wallS.toFixed(0)} s on ${o.jobs} processes`);
  l.push(`  team A: ${A.text}`);
  l.push(`  team B: ${B.text}`);
  if (o.sets && o.sets.length) l.push(`  both: ${o.sets.join(', ')}`);
  l.push('');
  l.push(`Games won: A ${T.A}, B ${T.B}, at the turn limit ${T.limit} (of ${T.games})`);
  if (T.paired) l.push(`  A's score, paired by seed (a game at the turn limit counts half): ${pct(T.paired)}, 95% normal interval over ${T.seeds} seeds`);
  if (T.wilson) l.push(`  A's share of decided games, Wilson 95%: ${pct(T.wilson)}`);
  for (const op of ['A', 'B']) {
    const b = T.byOpener[op];
    l.push(`  ${op} opened (${b.games} games): A won ${b.A}, B won ${b.B}, turn limit ${b.limit}${b.wilson ? `; A's share ${pct(b.wilson)}` : ''}`);
  }
  if (A.text === B.text) {
    l.push(`  same spec both sides: ${r.mirror.same} of ${r.mirror.pairs} seeds played the same game both ways round`);
  }
  const readRows = Object.entries(r.reads);
  if (readRows.length) {
    l.push('', 'Tune settings, read while each team acted (the run; a team that does not set one reads the shipped value):');
    for (const [p, e] of readRows) {
      l.push(`  ${p}: shipped ${e.base}; A ${e.A ?? '-'} (read ${e.reads.A}), B ${e.B ?? '-'} (read ${e.reads.B}), outside a team's action ${e.reads.none}`);
    }
  }
  l.push('', 'Each team\'s own turns and throws (± 95% half width; z: B less A over the combined standard error, ! past 2.58)');
  const zcol = {};
  for (const [k, z] of Object.entries(r.z)) {
    zcol[k] = Number.isFinite(z) ? `${z > 0 ? '+' : ''}${z.toFixed(1)}${Math.abs(z) >= 2.58 ? ' !' : ''}` : `${z > 0 ? '+' : '-'}exact !`;
  }
  l.push(score.page([r.cards.A, r.cards.B, zcol], ['team A', 'team B', 'z']));
  const hard = [];
  for (const t of ['A', 'B']) for (const e of r.clusters[t]) if (e.kind === 'unsettled' || e.kind === 'broken') hard.push(`  team ${t}: ${e.kind}: ${e.key}: ${e.count}\n    ${e.examples[0].cmd}`);
  if (hard.length) l.push('', 'Hard defects:', ...hard);
  l.push('', 'Largest anomaly clusters (each command replays that throw):');
  for (const t of ['A', 'B']) {
    const throws = r.cards[t]['f.rest'].n;
    for (const e of r.clusters[t].slice(0, 2)) {
      l.push(`  team ${t}: ${e.kind}: ${e.key}: ${e.count} (${(1000 * e.count / throws).toFixed(1)} per 1000)`);
      l.push(`    ${e.examples[0].cmd}   # ${e.examples[0].detail}`);
    }
  }
  return l.join('\n');
}

export { existsSync };
