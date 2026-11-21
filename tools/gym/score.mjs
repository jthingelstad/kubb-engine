// The Kubb Gym's counting (docs/notes/gym.md "What each number is"): the score-sheet figures
// (kubb.js over game files, as tools/realgames.mjs counts them), the forensics rates and
// the anomaly rates, each kept as counts so it carries its own 95% interval, and the
// page that prints them. Pure functions over what tools/gym/match.lua writes.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
let analyzeFn = null;
export async function analyzer() {
  if (!analyzeFn) {
    const kubb = join(here, '..', '..', 'tests', 'vendor', 'pk-kubb-score', 'kubb.js');
    analyzeFn = (await import(pathToFileURL(kubb).href)).analyze;
  }
  return analyzeFn;
}

// ---------- counters ----------

export const P = () => ({ t: 'p', k: 0, n: 0 });          // a share: k of n
export const M = () => ({ t: 'm', s: 0, q: 0, n: 0 });     // a mean: sum, sum of squares, n
export const R = () => ({ t: 'r', k: 0, n: 0 });           // a rate per 1000: k of n
function hit(c, yes) { c.n++; if (yes) c.k++; }
function add(c, v) { if (v === null || v === undefined || Number.isNaN(v)) return; c.n++; c.s += v; c.q += v * v; }

// The 95% interval: Wilson for a share, the normal one for a mean.
export function interval(c) {
  if (!c || !c.n) return null;
  if (c.t === 'm') {
    const mean = c.s / c.n;
    const v = c.n > 1 ? Math.max(0, (c.q - c.s * c.s / c.n) / (c.n - 1)) : 0;
    const h = 1.96 * Math.sqrt(v / c.n);
    return { v: mean, lo: mean - h, hi: mean + h, se: Math.sqrt(v / c.n), sd: Math.sqrt(v) };
  }
  const n = c.n, p = c.k / n, z = 1.96, z2 = z * z;
  const mid = (p + z2 / (2 * n)) / (1 + z2 / n);
  const h = (z / (1 + z2 / n)) * Math.sqrt(p * (1 - p) / n + z2 / (4 * n * n));
  return { v: p, lo: Math.max(0, mid - h), hi: Math.min(1, mid + h), se: Math.sqrt(Math.max(p * (1 - p), 1 / n) / n) };
}

// ---------- the score sheets ----------

const GAME_KEYS = [
  ['Games (score sheets: tools/realgames.mjs counting)'],
  ['g.turns', 'turns a game', 'm'],
  ['g.king', 'ended on the king', 'p'],
  ['g.resigned', 'resigned at the turn limit', 'p'],
  ['g.illegal', 'illegal throws, of batons', 'p'],
  ['g.fieldMiss', 'field batons: missed', 'p'],
  ['g.field1', 'field batons: took one', 'p'],
  ['g.field2', 'field batons: took two', 'p'],
  ['g.field3', 'field batons: took three or more', 'p'],
  ['g.cleared', 'turns with field kubbs: cleared them', 'p'],
  ['g.btc', 'batons to clear, when cleared', 'm'],
  ['g.advTurns', 'turns from an advantage line', 'p'],
  ['g.baseLine', 'base kubb from the baseline (8 m)', 'p'],
  ['g.baseAdv', 'base kubb from an advantage line', 'p'],
  ['g.kingHit', 'king shots that toppled it', 'p'],
  ['g.rethrown', 'kubbs rethrown, of kubbs thrown in', 'p'],
  ['g.punish', 'punishment kubbs, of kubbs thrown in', 'p'],
];

export function blankGames() {
  const o = {};
  for (const [k, , t] of GAME_KEYS) if (t) o[k] = t === 'm' ? M() : P();
  return o;
}

// One game's text into the score-sheet counters (realgames.mjs addGame's rules).
export function addGameText(o, analyze, text) {
  const g = analyze(text);
  if (!g.rows.length) return;
  add(o['g.turns'], g.rows.length);
  hit(o['g.king'], g.winHow === 'king');
  hit(o['g.resigned'], g.winHow === 'resign' || g.winHow === 'resigned');
  for (const r of g.rows) {
    if (r.startField > 0) {
      const cleared = r.btc !== null && r.btc !== undefined;
      hit(o['g.cleared'], cleared);
      if (cleared) add(o['g.btc'], r.btc);
    }
    hit(o['g.advTurns'], !!r.advantage);
    if (r.ink) {
      for (let i = 0; i < (r.ink.I || 0); i++) {
        hit(o['g.rethrown'], i < (r.ink.R || 0));
        hit(o['g.punish'], i < (r.ink.P || 0));
      }
    }
    let field = r.startField, base = r.startBase;
    for (const b of r.batons) {
      if (b.void || b.kind === 'unthrown' || b.kind === 'resign' || b.kind === 'win') continue;
      hit(o['g.illegal'], b.kind === 'illegal');
      if (b.kind === 'illegal') continue;
      if (b.kind === 'king' || b.kind === 'kingmiss') { hit(o['g.kingHit'], b.kind === 'king'); continue; }
      const f = b.f || 0, k = b.b || 0, took = f + k;
      if (field > 0) {
        hit(o['g.fieldMiss'], took === 0);
        hit(o['g.field1'], took === 1);
        hit(o['g.field2'], took === 2);
        hit(o['g.field3'], took >= 3);
      } else if (base > 0) {
        if (r.advantage) hit(o['g.baseAdv'], k > 0); else hit(o['g.baseLine'], k > 0);
      }
      field = Math.max(0, field - f);
      base = Math.max(0, base - k);
    }
  }
}

export async function gamesOf(dir) {
  const analyze = await analyzer();
  const o = blankGames();
  for (const f of readdirSync(dir).sort()) if (f.endsWith('.txt')) addGameText(o, analyze, readFileSync(join(dir, f), 'utf8'));
  return o;
}

// ---------- forensics and anomalies ----------

// Thresholds of the derived figures (docs/notes/gym.md).
export const T = {
  shortM: 0.15,      // m along: landed this far short of (or past) the target's centre ...
  wideM: 0.10,       // ... or this far across: which of the two it missed by more
  hardSpeed: 3,      // m/s: a touch this fast is a hard one (forensics.tune.hardSpeed)
  deadSpeed: 4,      // m/s: a baton that lands this fast ...
  deadRun: 0.15,     // ... and goes less than this along after landing stopped dead
  energyJ: 0.02,     // J: a rise in the world's energy past this is a gain (physcheck energyCum)
  drillFar: 0.30,    // m: a drill resting this far from its mark is a loose one
};

const FKEYS = [];
const KINDS = ['field', 'base', 'king'];
const KLABEL = { field: 'at field kubbs', base: 'at base kubbs', king: 'at the king' };
FKEYS.push(['Batons, what they did (forensics)']);
for (const k of KINDS) {
  FKEYS.push([`f.${k}.hit`, `${KLABEL[k]}: target toppled`, 'p']);
  FKEYS.push([`f.${k}.ground1`, `${KLABEL[k]}: met the ground first`, 'p']);
}
FKEYS.push(['f.good', 'meter all good (power, release, steady), of batons', 'p']);
FKEYS.push(['f.goodMiss', 'meter all good, the kubb stood (field and base)', 'p']);
FKEYS.push(['Batons that missed their target: how (field and base kubbs)']);
for (const w of ['short', 'over', 'wide', 'touched']) FKEYS.push([`f.miss.${w}`, {
  short: 'landed short', over: 'landed past it', wide: 'wide of it', touched: 'touched it, it stood' }[w], 'p']);
FKEYS.push(['Batons that landed short of their target']);
FKEYS.push(['f.short.died', 'landed short and stopped before reaching it', 'p']);
FKEYS.push(['f.short.run', 'run on after landing short (m)', 'm']);
FKEYS.push(['f.landSpeed', 'speed landing on the ground first (m/s)', 'm']);
FKEYS.push(['First touch of a standing piece (kubbs)']);
FKEYS.push(['f.top', 'first contact point within 1 cm of its top (face or edge)', 'p']);
FKEYS.push(['f.topFace', 'first contact point on the top face, inside its edges', 'p']);
FKEYS.push(['f.touchH', 'height up the kubb (m)', 'm']);
FKEYS.push(['f.lean', 'baton lean from vertical, unsigned (deg)', 'm']);
FKEYS.push(['f.touchSpeed', 'baton speed (m/s)', 'm']);
FKEYS.push(['f.kept', 'baton speed kept 0.05 s later (share)', 'm']);
for (const fate of ['toppled', 'rocked', 'slid', 'nudged', 'unmoved']) FKEYS.push([`f.fate.${fate}`, `the kubb ${fate === 'toppled' ? 'toppled' : fate === 'unmoved' ? 'did not move' : fate + ' and stood'}`, 'p']);
FKEYS.push(['f.topStood', 'contact within 1 cm of the top: the kubb stood', 'p']);
// how the baton arrived (forensics' arrival): the classes a kubb player names
export const ACLASS = ['down on top', 'clipped the top', 'body, upright', 'body, flat', 'ground first', 'other'];
const ALABEL = { 'down on top': 'came down on top (its normal near vertical)', 'clipped the top': 'clipped the top going over',
  'body, upright': 'body hit, baton upright (within 45 deg)', 'body, flat': 'body hit, baton lying flat or sideways',
  'ground first': 'ground first, then the kubb', other: 'other (its bottom)' };
FKEYS.push(['Arrival at a kubb, of batons thrown at field and base kubbs']);
for (const c of ACLASS) FKEYS.push([`a.thr.${c}`, ALABEL[c], 'p']);
FKEYS.push(['a.thr.none', 'touched no kubb', 'p']);
FKEYS.push(['Arrival at a kubb, of first touches of a kubb']);
for (const c of ACLASS) FKEYS.push([`a.tch.${c}`, ALABEL[c], 'p']);
FKEYS.push(['a.downTopple', 'came down on top: the kubb toppled', 'p']);
FKEYS.push(['a.upTopple', 'body hit, upright: the kubb toppled', 'p']);
FKEYS.push(['Arrival, batons that met a kubb before the ground']);
FKEYS.push(['a.part.lower end', 'met it with its lower end (lowest 30%)', 'p']);
FKEYS.push(['a.part.middle', 'met it with its middle', 'p']);
FKEYS.push(['a.part.upper end', 'met it with its upper end', 'p']);
FKEYS.push(['a.half', 'a half turn, within 30 deg (180 deg since release)', 'p']);
FKEYS.push(['a.turnErr', 'turn since release less 180 (deg)', 'm']);
FKEYS.push(['a.turnAbs', 'its size (deg)', 'm']);
FKEYS.push(['a.lean', 'signed lean: + upper end ahead of travel (deg)', 'm']);
FKEYS.push(['a.leanAbs', 'lean from vertical (deg)', 'm']);
FKEYS.push(['a.descent', 'descent angle (deg)', 'm']);
FKEYS.push(['a.low', 'lowest point passing the near face (m; kubb 0.15 tall)', 'm']);
FKEYS.push(['Hit window: field and base batons on line (centre within 10 cm across), by where its centre would have come down']);
for (const [b, l] of [['s4', '30-60 cm short'], ['s2', '10-30 cm short'], ['on', 'within 10 cm'], ['l2', '10-30 cm long'], ['l4', '30-60 cm long']])
  FKEYS.push([`w.${b}`, `would come down ${l}: toppled`, 'p']);
FKEYS.push(['More than one kubb']);
FKEYS.push(['f.multi', 'batons that toppled two or more', 'p']);
FKEYS.push(['f.chainKubb', 'of those, one fell by kubb on kubb', 'p']);
FKEYS.push(['f.triple', 'batons that toppled three or more', 'p']);
FKEYS.push(['f.quad', 'batons that toppled four or more', 'p']);
FKEYS.push(['Drills and groups']);
FKEYS.push(['d.dist', 'drill rests from its mark (m)', 'm']);
FKEYS.push(['d.far', `drill rests over ${T.drillFar} m from its mark`, 'p']);
FKEYS.push(['d.along', 'drill rest along the throw, past the mark (m)', 'm']);
FKEYS.push(['d.landShort', 'drill met the ground before its mark', 'p']);
FKEYS.push(['d.spread', 'field group, mean distance to its centre (m)', 'm']);
FKEYS.push(['d.far2', 'field group, farthest two kubbs apart (m)', 'm']);
FKEYS.push(['d.need', 'field group of 3 or more: batons it takes at best (chains of kubbs within 20 cm)', 'm']);
FKEYS.push(['d.needShare', '... as a share of its kubbs (1: every kubb its own baton)', 'm']);
FKEYS.push(['d.one', '... one baton could take it all', 'p']);
FKEYS.push(['d.touching', '... share of its kubbs touching another', 'm']);
FKEYS.push(['d.touchMost', '... most kubbs touching in one chain', 'm']);
FKEYS.push(['l.n', 'kubbs lying after an inkast of 3 or more, before raising', 'm']);
FKEYS.push(['l.touching', '... share of them touching another', 'm']);
FKEYS.push(['l.most', '... most kubbs touching in one chain', 'm']);
FKEYS.push(['l.three', '... three or more touching in one chain', 'p']);
FKEYS.push(['l.five', '... five or more touching in one chain', 'p']);
FKEYS.push(['f.rest', 'time to rest, every throw (s)', 'm']);
FKEYS.push(['Anomalies, per 1000 throws (tools/gym.mjs lists each)']);
const ANOM = {
  hardUnmoved: `a touch at ${T.hardSpeed} m/s or more left the kubb unmoved`,
  topVault: `a touch within 1 cm of the top at ${T.hardSpeed} m/s or more, the kubb stood`,
  propped: 'a kubb moved and rests standing, tilted past 10 deg',
  deadStop: `a baton landed at ${T.deadSpeed} m/s or more and stopped dead`,
  energy: `the world gained energy (over ${T.energyJ} J)`,
  unsettled: 'still moving when the throw ran out of time',
  broken: 'a body not a number or under the ground',
};
export const ANOM_KINDS = Object.keys(ANOM);
for (const k of ANOM_KINDS) FKEYS.push([`a.${k}`, ANOM[k], 'r']);

export function blankThrows() {
  const o = {};
  for (const [k, , t] of FKEYS) if (t) o[k] = t === 'm' ? M() : t === 'r' ? R() : P();
  return o;
}

// The anomalies one throw record shows: [{ kind, detail, key }] (key: the cluster).
export function anomaliesOf(o) {
  const f = o.f, out = [];
  const band = o.dist == null ? '-' : o.dist < 2 ? '<2m' : o.dist < 4 ? '2-4m' : o.dist < 6 ? '4-6m' : '6m+';
  for (const h of f.hard || []) {
    if (h.fate === 'unmoved') out.push({ kind: 'hardUnmoved', key: `${h.role} ${h.where || '?'} ${band}`,
      detail: `${h.id} (${h.role}) struck at ${h.speed.toFixed(1)} m/s on the ${h.where || '?'}, moved ${(h.moved * 100).toFixed(1)} cm, tilted ${h.tilt.toFixed(1)} deg` });
  }
  const fi = f.first;
  if (fi && fi.kind === 'kubb' && /^top/.test(fi.where || '') && fi.fate !== 'toppled' && fi.speed >= T.hardSpeed) {
    out.push({ kind: 'topVault', key: `${fi.role} ${fi.where} ${fi.fate} ${band}`,
      detail: `${fi.id} met on the ${fi.where} at ${fi.speed.toFixed(1)} m/s, ${(fi.h * 100).toFixed(1)} cm up, lean ${fi.lean.toFixed(0)} deg; ${fi.fate}` });
  }
  for (const p of f.propped || []) out.push({ kind: 'propped', key: `${p.role} ${o.k === 'drill' ? 'drill' : 'baton'}`,
    detail: `${p.id} (${p.role}) rests standing at ${p.tilt.toFixed(1)} deg` });
  if (o.k !== 'drill' && f.ground1 && f.landSpeed >= T.deadSpeed && f.runOn != null && f.runOn < T.deadRun && !f.touched) {
    out.push({ kind: 'deadStop', key: `${o.k} ${band}`, detail: `landed at ${f.landSpeed.toFixed(1)} m/s, went ${(f.runOn * 100).toFixed(0)} cm on` });
  }
  if (f.eRise > T.energyJ) out.push({ kind: 'energy', key: `${o.k}`, detail: `energy rose ${(f.eRise * 1000).toFixed(0)} mJ above its low` });
  for (const b of f.broken || []) out.push({ kind: 'broken', key: `${o.k} ${b.why}`, detail: `${b.id}: ${b.why}` });
  if (f.timedOut) out.push({ kind: 'unsettled', key: `${o.k}`, detail: `still moving at ${f.rest.toFixed(1)} s` });
  return out;
}

function missKind(f) {
  if (f.targetTouched) return 'touched';
  if (f.landAlong == null) return 'wide';
  const a = f.landAlong / T.shortM, c = Math.abs(f.landAcross || 0) / T.wideM;
  if (Math.abs(a) >= c && Math.abs(a) >= 1) return a < 0 ? 'short' : 'over';
  return 'wide';
}

// One throw line into the counters; returns its anomalies.
export function addThrow(o, t) {
  const f = t.f;
  add(o['f.rest'], f.rest);
  if (t.k === 'drill') {
    if (t.drill) {
      const d = Math.hypot(t.drill.dx, t.drill.dy);
      add(o['d.dist'], d);
      hit(o['d.far'], d > T.drillFar);
      // along the throw: the stance is behind the mark, so +y past it
      add(o['d.along'], t.drill.dy);
    }
    if (f.landAlong != null) hit(o['d.landShort'], f.landAlong < 0);
  } else if (t.legal) {
    const k = t.k;
    hit(o[`f.${k}.hit`], !!f.targetDown);
    hit(o[`f.${k}.ground1`], !!f.ground1);
    const good = !!(t.v && t.v[0] === 0 && t.v[1] === 0 && t.v[2]);
    if (t.v) hit(o['f.good'], good);
    if (t.v && good && k !== 'king') hit(o['f.goodMiss'], !f.targetDown);
    if (k !== 'king' && !f.targetDown) {
      const mk = missKind(f);
      for (const w of ['short', 'over', 'wide', 'touched']) hit(o[`f.miss.${w}`], mk === w);
      if (mk === 'short' && f.runOn != null) {
        hit(o['f.short.died'], (f.restAlong != null ? f.restAlong : f.landAlong + f.runOn) < -T.shortM);
        add(o['f.short.run'], f.runOn);
      }
    }
    if (f.ground1) add(o['f.landSpeed'], f.landSpeed);
    const fi = f.first;
    if (fi && fi.kind === 'kubb') {
      const top = /^top/.test(fi.where || '');
      hit(o['f.top'], top);
      hit(o['f.topFace'], fi.where === 'top-face');
      add(o['f.touchH'], fi.h);
      add(o['f.lean'], fi.lean);
      add(o['f.touchSpeed'], fi.speed);
      if (fi.kept != null) add(o['f.kept'], fi.kept);
      for (const fate of ['toppled', 'rocked', 'slid', 'nudged', 'unmoved']) hit(o[`f.fate.${fate}`], fi.fate === fate);
      if (top) hit(o['f.topStood'], fi.fate !== 'toppled');
    }
    if (k === 'field' || k === 'base') {
      const ar = fi && fi.kind === 'kubb' ? fi.arrival : null;
      const cls = ar ? ar.class : (fi && fi.kind === 'kubb' ? 'other' : 'none');
      for (const c of [...ACLASS, 'none']) hit(o[`a.thr.${c}`], cls === c);
      if (ar) {
        for (const c of ACLASS) hit(o[`a.tch.${c}`], ar.class === c);
        if (ar.class === 'down on top') hit(o['a.downTopple'], fi.fate === 'toppled');
        if (ar.class === 'body, upright') hit(o['a.upTopple'], fi.fate === 'toppled');
        if (!fi.afterGround) {
          for (const p of ['lower end', 'middle', 'upper end']) hit(o[`a.part.${p}`], ar.part === p);
          if (ar.turn != null) {
            const e = Math.abs(ar.turn) - 180; // either way round: a tumble the other way reads negative
            hit(o['a.half'], Math.abs(e) <= 30);
            add(o['a.turnErr'], e);
            add(o['a.turnAbs'], Math.abs(e));
          }
          add(o['a.lean'], ar.lean);
          add(o['a.leanAbs'], Math.abs(ar.lean));
          add(o['a.descent'], fi.descent);
        }
      }
      if (f.lowAtFace != null && !f.faceAfterGround) add(o['a.low'], f.lowAtFace);
      // the hit window: where the centre first came down (landing, or the touch) against toppling
      const along = f.freeAlong;
      if (along != null && Math.abs(f.freeAcross || 0) < 0.1 && Math.abs(along) < 0.6) {
        const a = Math.abs(along), b = a < 0.1 ? 'on' : (along < 0 ? 's' : 'l') + (a < 0.3 ? '2' : '4');
        hit(o[`w.${b}`], !!f.targetDown);
      }
      hit(o['f.multi'], f.toppled >= 2);
      hit(o['f.triple'], f.toppled >= 3);
      hit(o['f.quad'], f.toppled >= 4);
      if (f.toppled >= 2) hit(o['f.chainKubb'], f.byKubb > 0);
    }
  }
  if (t.group && t.group.n >= 2) { add(o['d.spread'], t.group.mean); add(o['d.far2'], t.group.far); }
  if (t.lying && t.lying.n >= 3) {
    const g = t.lying;
    add(o['l.n'], g.n); add(o['l.touching'], g.touching / g.n); add(o['l.most'], g.most);
    hit(o['l.three'], g.most >= 3); hit(o['l.five'], g.most >= 5);
  }
  if (t.group && t.group.n >= 3 && t.group.need != null) {
    const g = t.group;
    add(o['d.need'], g.need); add(o['d.needShare'], g.need / g.n); hit(o['d.one'], g.need === 1);
    add(o['d.touching'], g.touching / g.n); add(o['d.touchMost'], g.touch);
  }
  const an = anomaliesOf(t);
  const kinds = new Set(an.map(a => a.kind));
  for (const k of ANOM_KINDS) hit(o[`a.${k}`], kinds.has(k));
  return an;
}

export function throwsOf(dir, onAnomaly) {
  const o = blankThrows();
  let matches = 0;
  for (const f of readdirSync(dir).sort()) {
    if (!f.startsWith('throws-')) continue;
    for (const line of readFileSync(join(dir, f), 'utf8').split('\n')) {
      if (!line) continue;
      const t = JSON.parse(line);
      if (t.over) { matches++; continue; }
      const an = addThrow(o, t);
      if (onAnomaly) for (const a of an) onAnomaly(a, t);
    }
  }
  return { o, matches };
}

// The owner's estimates from play (an experienced player, 2026-11-20): a reference
// column beside the real games, his words, not measured.
export const OWNER = {
  'a.thr.down on top': 'at most 3-5',
  'a.half': 'the aim',
  'a.part.lower end': 'the hand end',
  'a.downTopple': 'some of the time',
};

// ---------- the page ----------

export const KEYS = [...GAME_KEYS, ...FKEYS];

export function cell(c, wide) {
  const iv = interval(c);
  if (!iv) return '-';
  if (c.t === 'p') return `${(iv.v * 100).toFixed(1)}±${((iv.hi - iv.lo) * 50).toFixed(1)}`;
  if (c.t === 'r') return `${(iv.v * 1000).toFixed(1)}±${((iv.hi - iv.lo) * 500).toFixed(1)}`;
  const d = Math.abs(iv.v) >= 10 ? 1 : 2;
  return `${iv.v.toFixed(d)}±${(iv.hi - iv.v).toFixed(d)}`;
}

// Rows of [label, ...cells] for the metrics of each column; a one-cell row is a heading.
export function page(columns, names, opts = {}) {
  const out = [];
  for (const [k, label, t] of KEYS) {
    if (!t) { if (k) out.push([k]); continue; }
    if (opts.skip && opts.skip(k)) continue;
    const cells = columns.map(c => (c && c[k] != null) ? (typeof c[k] === 'string' ? c[k] : cell(c[k])) : '');
    if (cells.every(x => x === '' || x === '-')) continue;
    out.push([label, ...cells]);
  }
  // a heading with no rows under it goes
  const kept = out.filter((r, i) => r.length > 1 || (out[i + 1] && out[i + 1].length > 1));
  return render(kept, names);
}

export function render(rows, names) {
  const nc = names.length;
  const w = [0, ...names.map(n => n.length)];
  for (const r of rows) if (r.length > 1) for (let i = 0; i <= nc; i++) w[i] = Math.max(w[i], (r[i] || '').length);
  const lines = [`${''.padEnd(w[0] + 2)}${names.map((n, i) => n.padStart(w[i + 1] + 2)).join('')}`];
  for (const r of rows) {
    if (r.length === 1) lines.push(r[0]);
    else lines.push(`  ${r[0].padEnd(w[0])}${r.slice(1).map((x, i) => (x || '').padStart(w[i + 1] + 2)).join('')}`);
  }
  return lines.join('\n');
}

export function labelOf(k) {
  for (const [key, label] of KEYS) if (key === k) return label;
  return k;
}

export { existsSync };
