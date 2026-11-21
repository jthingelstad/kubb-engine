// Baton value: the batons a position costs, counted from scored games (docs/notes/real-games.md
// "Baton value").
//
//   node tools/batonvalue.mjs <games dir> [--json] [--tiers] [--boot N] [--seed S]
//
// Chris Hodges (Des Moines Kubb, 2014, "Advantage, Efficiency, and Game Theory", part 2)
// published the average batons a team needs to finish a position: n field kubbs from the
// baseline or from an advantage line, a base kubb from 8 m or from an advantage line, the
// king. This rebuilds that table from a folder of Planet Kubb Notation files (the 150 scored
// games of a pk-kubb-score checkout, read only, or the Gym's games), read with the vendored
// kubb.js and counted as tools/realgames.mjs counts (tools/sheets.mjs).
//
// The estimator ("single-baton chain"). Every thrown baton is one step from a state: n field
// kubbs standing, thrown from the baseline or from an advantage line; it toppled k of them.
// p(k | n) is the share of batons from n that took k, and the batons to clear n are
//   E[n] = 1 + sum over k of p(k | n) E[n - k],  E[0] = 0,
// solved upward from n = 1. Unlike the mean over turns that cleared (printed beside it as
// "cleared turns"), it keeps the turns that ran out of batons. It assumes a baton's chances
// depend on n and the line only, not on how the turn got there: n kubbs left after a double
// count as n kubbs thrown in. They are not (a turn's first baton takes more), so a second
// figure, "fresh", is n just thrown in: the turn's first baton from the first batons' own
// outcomes, then the chain over the later batons only.
//   A state with fewer than MIN_BATONS batons is pooled with its neighbours: from n = 1
// upward, states are joined until the group holds MIN_BATONS or spans POOL_WIDTH states, and
// a short group left at the top joins the one below when the two span no more than that. A
// pool's states share one outcome distribution, with k capped at n (taking more than stand
// takes them all); one still under MIN_BATONS is thin and marked. Pools are fixed on the
// whole sample and kept in every bootstrap resample.
//   A base kubb: batons thrown at base kubbs (no field kubb standing, a base kubb left) over
// the base kubbs they toppled; that is 1 / hit rate when no baton takes two. A baton that
// takes its last field kubbs and then a base kubb (FB) is a field step; its base kubbs are
// counted apart (fieldToBase) and left out of the base figure. The king: shots (K and =) over
// kings toppled.
//   Intervals: 2.5th and 97.5th percentiles over bootstrap resamples of whole games (batons
// within a game are not independent), with a fixed seed so the output repeats.
//
// What a score sheet says and what this infers. A sheet records what each baton took, not
// where anything stood or where the thrower stood.
// - Field kubbs standing at each baton: kubb.js's startField for the turn (the kubbs thrown in
//   plus those left standing, less rescues) less what earlier batons in the turn took. Taken
//   from the counts, never from positions; a baton written as taking more than stood is
//   capped, as kubb.js caps it.
// - Field kubbs to base kubbs: inferred. A baton is "at field kubbs" while one stands and "at
//   base kubbs" once none does (the rules raise a base kubb toppled first, II.B.4a), so a
//   miss is charged to whatever stood. A thrower who threw a baton away on purpose is
//   counted as a miss.
// - The advantage line: kubb.js's `advantage` for the turn, marked (A, nA) or inferred from
//   field kubbs left standing in the thrower's own half; the line applies to every baton of
//   the turn but the king. Its distance is not used (most sheets do not give it).
// - Not throws: X, void batons, W and G. An illegal throw (Z) is a spent baton that took
//   nothing, charged to the state it was thrown from. A baton at nothing (no kubb standing,
//   not a king shot) is counted apart as stray.
// - Tiers (--tiers): tools/realtiers.mjs's ranking by kubbs toppled a baton, the measure the
//   estimate is made of, so the top third's figures are flattered by its selection. The
//   held-out rows rank each team on the even-numbered files and count it on the odd ones,
//   and the other way round, which removes that.
//
// A measuring tool: it changes nothing in the engine and never writes into the folder.

import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadGames, thrown } from './sheets.mjs';
import { rankTeams, tierOfSide, MIN_BATONS as MIN_RANKED } from './realtiers.mjs';

export const ESTIMATOR = 'single-baton chain';
export const MIN_BATONS = 30;
// a pool joins at most this many neighbouring states
export const POOL_WIDTH = 3;
// a team ranked on half its games needs half of realtiers' 60 batons
const HELD_OUT_MIN = 30;
const SPLITS = ['all', 'top', 'mid', 'low', 'top (held out)', 'mid (held out)', 'low (held out)'];
export const SIDES = ['line', 'adv'];
const SIDE_LABEL = { line: 'from the baseline', adv: 'from an advantage line' };

// Hodges 2014, the Baton Value table (base kubb from an advantage line: 1.63 in the table,
// 1.65 in the text).
export const HODGES = {
  field: {
    line: [null, 1.53, 2.36, 3.04, 3.63, 4.18, 4.68, 5.15, 5.59, 6.02, 6.43],
    adv: [null, 1.11, 1.74, 2.27, 2.74, 3.16, 3.56, 3.94, 4.30, 4.64],
  },
  base: { line: 2.85, adv: 1.63 },
  king: 1.2,
};

// ---------- counting ----------

export function blankCounts() {
  return {
    field: { line: [], adv: [] },            // field[side][n][k]: batons from n field kubbs that took k
    first: { line: [], adv: [] },            // the same for each turn's first baton at field kubbs
    plain: { line: [], adv: [] },            // plain[side][n]: turns that began with n, cleared, batons to clear
    base: { line: { batons: 0, kubbs: 0, hits: 0 }, adv: { batons: 0, kubbs: 0, hits: 0 } },
    king: { shots: 0, hits: 0 },
    fieldToBase: { batons: 0, kubbs: 0 },
    illegal: 0, stray: 0, batons: 0, turns: 0,
  };
}

function fieldRow(c, side, n, key = 'field') {
  const a = c[key][side];
  if (!a[n]) a[n] = new Array(n + 1).fill(0);
  return a[n];
}
function plainRow(c, side, n) {
  const a = c.plain[side];
  if (!a[n]) a[n] = { turns: 0, cleared: 0, btc: 0 };
  return a[n];
}

// One turn (a kubb.js row) into a counts object.
export function addRow(c, r) {
  const side = r.advantage ? 'adv' : 'line';
  c.turns++;
  if (r.startField > 0) {
    const p = plainRow(c, side, r.startField);
    p.turns++;
    if (r.btc !== null && r.btc !== undefined) { p.cleared++; p.btc += r.btc; }
  }
  let f = r.startField, b = r.startBase, first = true;
  for (const x of r.batons) {
    if (!thrown(x) || x.kind === 'illegalking') continue;
    c.batons++;
    if (x.kind === 'king' || x.kind === 'kingmiss') {
      c.king.shots++;
      if (x.kind === 'king') c.king.hits++;
      continue;
    }
    const illegal = x.kind === 'illegal';
    if (illegal) c.illegal++;
    const xf = illegal ? 0 : Math.min(x.f || 0, f), xb = illegal ? 0 : Math.min(x.b || 0, b);
    if (f > 0) {
      fieldRow(c, side, f)[xf]++;
      if (first) fieldRow(c, side, f, 'first')[xf]++;
      first = false;
      if (xb > 0) { c.fieldToBase.batons++; c.fieldToBase.kubbs += xb; }
    } else if (b > 0) {
      const t = c.base[side];
      t.batons++; t.kubbs += xb;
      if (xb > 0) t.hits++;
    } else c.stray++;
    f -= xf; b -= xb;
  }
}

// dst += w * src
export function addCounts(dst, src, w = 1) {
  for (const s of SIDES) {
    for (const key of ['field', 'first']) {
      src[key][s].forEach((row, n) => { if (row) { const d = fieldRow(dst, s, n, key); for (let k = 0; k <= n; k++) d[k] += w * row[k]; } });
    }
    src.plain[s].forEach((p, n) => { if (p) { const d = plainRow(dst, s, n); d.turns += w * p.turns; d.cleared += w * p.cleared; d.btc += w * p.btc; } });
    for (const k of ['batons', 'kubbs', 'hits']) dst.base[s][k] += w * src.base[s][k];
  }
  dst.king.shots += w * src.king.shots; dst.king.hits += w * src.king.hits;
  dst.fieldToBase.batons += w * src.fieldToBase.batons; dst.fieldToBase.kubbs += w * src.fieldToBase.kubbs;
  for (const k of ['illegal', 'stray', 'batons', 'turns']) dst[k] += w * src[k];
  return dst;
}

// One game's counts by split: labelOf(row) gives the splits a turn belongs to.
export function countGame(g, labelOf) {
  const out = {};
  for (const r of g.rows) for (const l of labelOf(r)) addRow(out[l] || (out[l] = blankCounts()), r);
  return out;
}

// ---------- the estimator ----------

const sum = a => a.reduce((x, y) => x + y, 0);
const batonsAt = (rows, n) => (rows[n] ? sum(rows[n]) : 0);

// Pools of states for one side's field counts: from n = 1 upward, join states until a group
// holds `min` batons or spans `width` states; a group left short at the top joins the one
// below when the two together span no more than `width`. A pool still under `min` is thin
// (the report marks it). [[lo, hi], ...]
export function poolsOf(rows, min = MIN_BATONS, width = POOL_WIDTH) {
  let top = 0;
  rows.forEach((r, n) => { if (r && sum(r) > 0) top = n; });
  const pools = [];
  let lo = 1, acc = 0;
  for (let n = 1; n <= top; n++) {
    acc += batonsAt(rows, n);
    if (acc >= min || n - lo + 1 >= width) { pools.push([lo, n]); lo = n + 1; acc = 0; }
  }
  if (lo <= top) {
    const last = pools[pools.length - 1];
    if (last && top - last[0] + 1 <= width) last[1] = top;
    else pools.push([lo, top]);
  }
  return pools;
}

// E[n] for every n the pools cover. rows[n][k] are counts; pools from poolsOf (by default on
// these rows). Returns [{ n, E, batons, pool }] for n = 1..top, E null where the pool has no
// batons (or a state below it has none), Infinity where nothing was ever toppled.
export function solveField(rows, pools = poolsOf(rows)) {
  const E = [0], out = [];
  for (const [lo, hi] of pools) {
    const pooled = new Array(hi + 1).fill(0);
    for (let n = lo; n <= hi; n++) if (rows[n]) rows[n].forEach((v, k) => { pooled[k] += v; });
    const total = sum(pooled);
    for (let n = lo; n <= hi; n++) {
      let e = null;
      if (total > 0) {
        // p(k | n) from the pool, k capped at n
        const p = new Array(n + 1).fill(0);
        pooled.forEach((v, k) => { p[Math.min(k, n)] += v / total; });
        if (p[0] >= 1) e = Infinity;
        else {
          let acc = 1;
          for (let k = 1; k < n; k++) {
            if (p[k] === 0) continue;
            if (E[n - k] === null) { acc = null; break; }
            acc += p[k] * E[n - k];
          }
          e = acc === null ? null : acc / (1 - p[0]);
        }
      }
      E[n] = e;
      out.push({ n, E: e, batons: batonsAt(rows, n), pool: [lo, hi] });
    }
  }
  return out;
}

// The batons after a turn's first: every baton less the first ones.
export function laterRows(c, side) {
  const out = [];
  c.field[side].forEach((row, n) => { if (row) out[n] = row.map((v, k) => v - ((c.first[side][n] || [])[k] || 0)); });
  return out;
}

// A position just thrown in ("fresh"): the turn's first baton from its own outcomes, then the
// chain over the later batons. E[n] = 1 + sum over k of pFirst(k | n) Elater[n - k], where a
// first baton that takes nothing leaves n kubbs to the later chain. Pools as solveField's.
export function solveFresh(first, later, poolsFirst = poolsOf(first), poolsLater = poolsOf(later)) {
  const El = [0];
  for (const r of solveField(later, poolsLater)) El[r.n] = r.E;
  const out = [];
  for (const [lo, hi] of poolsFirst) {
    const pooled = new Array(hi + 1).fill(0);
    for (let n = lo; n <= hi; n++) if (first[n]) first[n].forEach((v, k) => { pooled[k] += v; });
    const total = sum(pooled);
    for (let n = lo; n <= hi; n++) {
      let e = null;
      if (total > 0) {
        const p = new Array(n + 1).fill(0);
        pooled.forEach((v, k) => { p[Math.min(k, n)] += v / total; });
        e = 1;
        for (let k = 0; k < n; k++) {
          if (p[k] === 0) continue;
          const rest = El[n - k];
          if (rest === null || rest === undefined) { e = null; break; }
          e += p[k] * rest;
        }
      }
      out.push({ n, E: e, batons: batonsAt(first, n), pool: [lo, hi] });
    }
  }
  return out;
}

export function poolsOfCounts(c, min = MIN_BATONS) {
  const o = {};
  for (const s of SIDES) o[s] = { all: poolsOf(c.field[s], min), first: poolsOf(c.first[s], min), later: poolsOf(laterRows(c, s), min) };
  return o;
}

const ratio = (a, b) => (a === 0 && b === 0 ? null : b === 0 ? Infinity : a / b);

// Every figure of one counts object as a flat map, for the bootstrap.
export function figures(c, pools) {
  const o = {};
  for (const s of SIDES) {
    for (const r of solveField(c.field[s], pools[s].all)) o[`field.${s}.${r.n}`] = r.E;
    for (const r of solveFresh(c.first[s], laterRows(c, s), pools[s].first, pools[s].later)) o[`fresh.${s}.${r.n}`] = r.E;
    c.plain[s].forEach((p, n) => { if (p) o[`plain.${s}.${n}`] = p.cleared ? p.btc / p.cleared : null; });
    o[`base.${s}`] = ratio(c.base[s].batons, c.base[s].kubbs);
    o[`baseHit.${s}`] = ratio(c.base[s].batons, c.base[s].hits);
  }
  o.king = ratio(c.king.shots, c.king.hits);
  return o;
}

// A small seeded generator (mulberry32), so the resamples repeat.
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function percentile(sorted, p) {
  if (!sorted.length) return null;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.round(p * (sorted.length - 1))));
  return sorted[i];
}

// One split: its counts over all games, its pools, its figures, and a bootstrap over games.
// perGame[i] is game i's counts for this split (or undefined).
export function estimateSplit(perGame, { boot = 1000, seed = 1, min = MIN_BATONS } = {}) {
  const total = blankCounts();
  for (const c of perGame) if (c) addCounts(total, c);
  const pools = poolsOfCounts(total, min);
  const point = figures(total, pools);
  const draws = {};
  for (const k of Object.keys(point)) draws[k] = [];
  const next = rng(seed), G = perGame.length;
  for (let b = 0; b < boot && G; b++) {
    const w = new Array(G).fill(0);
    for (let i = 0; i < G; i++) w[Math.floor(next() * G)]++;
    const c = blankCounts();
    for (let i = 0; i < G; i++) if (w[i] && perGame[i]) addCounts(c, perGame[i], w[i]);
    const f = figures(c, pools);
    for (const k of Object.keys(draws)) if (f[k] !== null && f[k] !== undefined && !Number.isNaN(f[k])) draws[k].push(f[k]);
  }
  const interval = {};
  for (const [k, d] of Object.entries(draws)) {
    d.sort((x, y) => x - y);
    interval[k] = { lo: percentile(d, 0.025), hi: percentile(d, 0.975), resamples: d.length };
  }
  return { total, pools, point, interval };
}

// ---------- the report ----------

const r3 = v => (v === null || v === undefined || !Number.isFinite(v) ? null : Math.round(v * 1000) / 1000);
const fig = (point, interval, key) => {
  const v = point[key], iv = interval[key] || {};
  return { E: r3(v), lo: r3(iv.lo), hi: r3(iv.hi), unbounded: v === Infinity || iv.hi === Infinity || undefined };
};

// One split's estimate as the stable structure --json prints. Per state: the chain over every
// baton, the fresh position (first baton, then the later chain), the mean over cleared turns.
export function splitReport(est) {
  const { total, pools, point, interval } = est;
  const o = { turns: total.turns, batons: total.batons, field: {}, base: {}, pools };
  for (const s of SIDES) {
    const chain = solveField(total.field[s], pools[s].all);
    const fresh = solveFresh(total.first[s], laterRows(total, s), pools[s].first, pools[s].later);
    const top = Math.max(0, ...chain.map(r => r.n), ...fresh.map(r => r.n));
    o.field[s] = [];
    for (let n = 1; n <= top; n++) {
      const c = chain.find(r => r.n === n), f = fresh.find(r => r.n === n);
      const p = total.plain[s][n] || { turns: 0, cleared: 0, btc: 0 };
      o.field[s].push({
        n,
        chain: { ...fig(point, interval, `field.${s}.${n}`), batons: c ? c.batons : 0, pool: c ? c.pool : null,
          poolBatons: c ? poolBatons(total.field[s], c.pool) : 0, took: (total.field[s][n] || []).slice() },
        fresh: { ...fig(point, interval, `fresh.${s}.${n}`), batons: f ? f.batons : 0, pool: f ? f.pool : null,
          poolBatons: f ? poolBatons(total.first[s], f.pool) : 0, took: (total.first[s][n] || []).slice() },
        cleared: { ...fig(point, interval, `plain.${s}.${n}`), turns: p.turns, cleared: p.cleared },
        hodges: HODGES.field[s][n] ?? null,
      });
    }
    const t = total.base[s];
    o.base[s] = { ...fig(point, interval, `base.${s}`), batons: t.batons, kubbs: t.kubbs, hits: t.hits,
      perHit: fig(point, interval, `baseHit.${s}`), hodges: HODGES.base[s] };
  }
  o.king = { ...fig(point, interval, 'king'), shots: total.king.shots, hits: total.king.hits, hodges: HODGES.king };
  o.fieldToBase = { ...total.fieldToBase };
  o.illegal = total.illegal;
  o.stray = total.stray;
  o.closer = closer(o);
  return o;
}

function poolBatons(rows, [lo, hi]) {
  let t = 0;
  for (let n = lo; n <= hi; n++) t += batonsAt(rows, n);
  return t;
}

// Which figure sits closest to Hodges' field table: the mean absolute difference of the chain,
// the fresh position and the mean over cleared turns, over the states where all four exist.
export function closer(o) {
  const d = { chain: 0, fresh: 0, cleared: 0 };
  let n = 0;
  for (const s of SIDES) for (const r of o.field[s]) {
    if (r.hodges === null || r.chain.E === null || r.fresh.E === null || r.cleared.E === null) continue;
    for (const k of Object.keys(d)) d[k] += Math.abs(r[k].E - r.hodges);
    n++;
  }
  if (!n) return null;
  for (const k of Object.keys(d)) d[k] = r3(d[k] / n);
  return { states: n, ...d, nearest: Object.keys(d).sort((x, y) => d[x] - d[y])[0] };
}

export async function run(dir, { tiers = false, boot = 1000, seed = 1 } = {}) {
  const { files, games } = await loadGames(dir);
  let ranking = null, labelOf = () => () => ['all'];
  if (tiers) {
    const all = rankTeams(games);
    // held out: rank on the even-numbered files, count the odd ones, and the other way round
    const half = [0, 1].map(h => rankTeams(games.filter((_, i) => i % 2 === h), HELD_OUT_MIN));
    ranking = { ranked: all.ranked.length, ...all.count, minBatons: MIN_RANKED,
      heldOut: { minBatons: HELD_OUT_MIN, halves: half.map(h => ({ ranked: h.ranked.length, ...h.count })) } };
    labelOf = (g, i) => r => {
      const out = ['all'];
      const t = tierOfSide(all.tierOf, g, r.team);
      if (t) out.push(t);
      const h = tierOfSide(half[1 - (i % 2)].tierOf, g, r.team);
      if (h) out.push(`${h} (held out)`);
      return out;
    };
  }
  const per = games.map((g, i) => countGame(g, labelOf(g, i)));
  const splits = {};
  for (const s of tiers ? SPLITS : ['all']) splits[s] = splitReport(estimateSplit(per.map(p => p[s]), { boot, seed }));
  return {
    tool: 'batonvalue', format: 1,
    estimator: { name: ESTIMATOR, minBatonsAState: MIN_BATONS, poolWidth: POOL_WIDTH, interval: 0.95,
      bootstrap: { unit: 'game', resamples: boot, seed } },
    games: { files, read: games.length },
    tiers: ranking,
    splits,
  };
}

// ---------- printing ----------

const f2 = v => (v === null || v === undefined ? '-' : v.toFixed(2));
const thin = x => (x.poolBatons !== undefined && x.poolBatons < MIN_BATONS && x.E !== null ? '*' : '');
const iv = x => (x.E === null ? (x.unbounded ? 'never' : '-')
  : x.lo === null && x.hi === null && !x.unbounded ? f2(x.E)
    : `${f2(x.E)} (${f2(x.lo)}-${x.hi === null && x.unbounded ? 'inf' : f2(x.hi)})`);

export function render(rep) {
  const L = [];
  L.push(`${rep.games.files} files, ${rep.games.read} games read. ${rep.estimator.name}; a state under ${rep.estimator.minBatonsAState} batons is pooled with up to`);
  L.push(`${rep.estimator.poolWidth - 1} neighbours (* still under ${rep.estimator.minBatonsAState}: thin); 95% intervals from ${rep.estimator.bootstrap.resamples} resamples of whole games (seed ${rep.estimator.bootstrap.seed}).`);
  L.push('chain: every baton at n; fresh: n just thrown in (the first baton, then the later batons\' chain);');
  L.push('cleared: the mean batons of the turns that began with n and cleared (leaves out the turns that did not).');
  if (rep.tiers) {
    const t = rep.tiers;
    L.push(`tiers (tools/realtiers.mjs): ${t.ranked} teams ranked, top ${t.top}, mid ${t.mid}, low ${t.low}. Held out: ranked on half`);
    L.push(`the files, counted on the other half (${t.heldOut.halves.map(h => h.ranked).join(' and ')} teams with ${t.heldOut.minBatons} batons or more).`);
  }
  const pool = p => (!p || p[0] === p[1] ? '' : `${p[0]}-${p[1]}`);
  for (const [name, o] of Object.entries(rep.splits)) {
    L.push('', `== ${name === 'all' ? 'all teams' : name}: ${o.turns} turns, ${o.batons} batons`);
    for (const s of SIDES) {
      L.push('', `Clearing n field kubbs ${SIDE_LABEL[s]}`);
      L.push(`${'n'.padStart(3)}  ${'chain (95%)'.padEnd(18)}${'batons'.padStart(7)}${'pool'.padStart(6)}  ${'fresh (95%)'.padEnd(18)}${'first'.padStart(6)}${'pool'.padStart(6)}  ${'cleared (95%)'.padEnd(18)}${'turns'.padStart(8)}${'Hodges'.padStart(8)}`);
      for (const r of o.field[s]) {
        L.push(`${String(r.n).padStart(3)}  ${(iv(r.chain) + thin(r.chain)).padEnd(18)}${String(r.chain.batons).padStart(7)}${pool(r.chain.pool).padStart(6)}  `
          + `${(iv(r.fresh) + thin(r.fresh)).padEnd(18)}${String(r.fresh.batons).padStart(6)}${pool(r.fresh.pool).padStart(6)}  `
          + `${iv(r.cleared).padEnd(18)}${`${r.cleared.cleared}/${r.cleared.turns}`.padStart(8)}${f2(r.hodges).padStart(8)}`);
      }
    }
    L.push('', 'A base kubb and the king');
    for (const s of SIDES) {
      const b = o.base[s];
      L.push(`  base kubb ${s === 'line' ? 'from 8 m' : SIDE_LABEL[s]}: ${iv(b)}, ${b.kubbs} kubbs by ${b.batons} batons; Hodges ${f2(b.hodges)}`);
    }
    L.push(`  the king: ${iv(o.king)}, ${o.king.hits} of ${o.king.shots} shots; Hodges ${f2(o.king.hodges)}`);
    L.push(`  base kubbs taken by batons at field kubbs (FB, not in the base figure): ${o.fieldToBase.kubbs} by ${o.fieldToBase.batons} batons; illegal ${o.illegal}; stray ${o.stray}`);
    if (o.closer) L.push(`  off Hodges' field table, a state (${o.closer.states} states): chain ${f2(o.closer.chain)}, fresh ${f2(o.closer.fresh)}, cleared ${f2(o.closer.cleared)}; nearest: ${o.closer.nearest}`);
  }
  return L.join('\n');
}

async function main(argv) {
  const dirs = [], o = { tiers: false, json: false, boot: 1000, seed: 1 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') o.json = true;
    else if (a === '--tiers') o.tiers = true;
    else if (a === '--boot') o.boot = Math.max(0, parseInt(argv[++i], 10) || 0);
    else if (a === '--seed') o.seed = parseInt(argv[++i], 10) || 1;
    else if (a.startsWith('--')) { console.error(`batonvalue: unknown option ${a}`); return 2; }
    else dirs.push(a);
  }
  if (dirs.length !== 1 || !existsSync(dirs[0])) {
    console.error('usage: node tools/batonvalue.mjs <games dir> [--json] [--tiers] [--boot N] [--seed S]');
    return 2;
  }
  const rep = await run(resolve(dirs[0]), o);
  if (!rep.games.read) { console.error('batonvalue: the folder has no games'); return 2; }
  console.log(o.json ? JSON.stringify(rep, null, 1) : render(rep));
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(c => process.exit(c));
}
