// The real games by how strong the team is (docs/reference/PLAY.md).
//
//   node tools/realtiers.mjs <real games dir> [--json]
//
// tools/realgames.mjs gives one figure for all 150 scored games. This reads the same
// folder (a pk-kubb-score checkout's games/, read only) with the same kubb.js and the
// same counting, and splits every figure by the team that threw: three tiers of
// teams, and the winning and the losing side of each game. docs/reference/
// play-levels.json's "real" block is this tool's --json output.
//
// The tiers: every team with 60 batons or more is ranked by kubbs toppled a baton
// over all its games, and the ranking is cut where a third and two thirds of the
// batons have been counted. A team with fewer batons is in "all" and in winners or
// losers only. Every team here entered a tournament: the low tier is not beginners.
//
// A score sheet records what each baton took, not where anything stood, so this
// says what play looks like at each strength, never why.

import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadGames, thrown, teamKey as norm } from './sheets.mjs';

export const MIN_BATONS = 60;
const BANDS = ['1', '2-3', '4-5', '6-7', '8+'];
const band = n => (n <= 1 ? '1' : n <= 3 ? '2-3' : n <= 5 ? '4-5' : n <= 7 ? '6-7' : '8+');

function blank() {
  const s = {
    teamGames: 0, wins: 0, turns: 0, advTurns: 0, batons: 0,
    field: { batons: 0, took: [0, 0, 0, 0], kubbs: 0 },
    base8: { batons: 0, hits: 0 }, baseAdv: { batons: 0, hits: 0 }, king: { shots: 0, hits: 0 },
    clear: { turns: 0, cleared: 0, btc: 0, leftTurns: 0, leftKubbs: 0 },
    ink: { turns: 0, I: 0, R: 0, P: 0, Q: 0, turnsR: 0, turnsP: 0 },
    opener: [0, 0, 0, 0, 0, 0],
    clearBy: {}, firstBy: {}, inkBy: {},
  };
  for (const b of BANDS) {
    s.clearBy[b] = { turns: 0, cleared: 0, btc: 0 };
    s.firstBy[b] = { batons: 0, took: [0, 0, 0, 0], kubbs: 0 };
    s.inkBy[b] = { turns: 0, I: 0, R: 0, P: 0 };
  }
  return s;
}

// Adds one turn (a kubb.js row) to a split's totals. Counting as tools/realgames.mjs.
function addRow(s, r) {
  s.turns++;
  if (r.advantage) s.advTurns++;
  if (r.inkast > 0) {
    const k = s.inkBy[band(r.inkast)];
    k.turns++; k.I += r.ink.I; k.R += r.ink.R; k.P += r.ink.P;
    s.ink.turns++;
    for (const c of ['I', 'R', 'P', 'Q']) s.ink[c] += r.ink[c] || 0;
    if (r.ink.R) s.ink.turnsR++;
    if (r.ink.P) s.ink.turnsP++;
  }
  // the opening turns: six batons at five base kubbs from 8 m, nothing in the field
  if (r.turn <= 2 && r.startField === 0 && r.startBase === 5) {
    let n = 0, k = 0;
    for (const b of r.batons) if (b.kind === 'hit' || b.kind === 'miss') { n++; k += b.b || 0; }
    if (n === 6) s.opener[Math.min(k, 5)]++;
  }
  if (r.startField > 0) {
    const c = s.clearBy[band(r.startField)];
    c.turns++; s.clear.turns++;
    if (r.btc !== null && r.btc !== undefined) {
      c.cleared++; c.btc += r.btc; s.clear.cleared++; s.clear.btc += r.btc;
    } else {
      s.clear.leftTurns++; s.clear.leftKubbs += r.fieldLeft || 0;
    }
  }
  let field = r.startField, base = r.startBase, first = true;
  for (const b of r.batons) {
    if (!thrown(b)) continue;
    s.batons++;
    if (b.kind === 'illegal') continue;
    if (b.kind === 'king' || b.kind === 'kingmiss') {
      s.king.shots++;
      if (b.kind === 'king') s.king.hits++;
      continue;
    }
    const f = b.f || 0, k = b.b || 0;
    if (field > 0) {
      s.field.batons++; s.field.took[Math.min(f + k, 3)]++; s.field.kubbs += f;
      if (first) {
        // the turn's first baton at the field kubbs: what the group gave it
        const fb = s.firstBy[band(r.startField)];
        fb.batons++; fb.took[Math.min(f, 3)]++; fb.kubbs += f;
      }
      first = false;
    } else if (base > 0) {
      const t = r.advantage ? s.baseAdv : s.base8;
      t.batons++;
      if (k > 0) t.hits++;
    }
    field = Math.max(0, field - f); base = Math.max(0, base - k);
  }
}

const pct = (n, d) => (d ? +(100 * n / d).toFixed(1) : null);
const mean = (n, d, p = 2) => (d ? +(n / d).toFixed(p) : null);
const quantile = (a, p) => { const b = [...a].sort((x, y) => x - y); return b[Math.min(b.length - 1, Math.floor(p * b.length))]; };

// A split's totals as the figures the reference keeps. Shares are percentages; `n` beside a
// figure is what it was counted over.
function figures(s) {
  const tookOf = t => ({ n: t.batons, missed: pct(t.took[0], t.batons), one: pct(t.took[1], t.batons),
    two: pct(t.took[2], t.batons), threePlus: pct(t.took[3], t.batons), kubbs: mean(t.kubbs, t.batons) });
  const openers = s.opener.reduce((a, b) => a + b, 0);
  const o = {
    teamGames: s.teamGames, won: pct(s.wins, s.teamGames), turns: s.turns, batons: s.batons,
    'g.fieldMiss': pct(s.field.took[0], s.field.batons),
    'g.field1': pct(s.field.took[1], s.field.batons),
    'g.field2': pct(s.field.took[2], s.field.batons),
    'g.field3': pct(s.field.took[3], s.field.batons),
    fieldKubbsABaton: mean(s.field.kubbs, s.field.batons), fieldBatons: s.field.batons,
    'g.cleared': pct(s.clear.cleared, s.clear.turns),
    'g.btc': mean(s.clear.btc, s.clear.cleared),
    batonsLeftWhenCleared: mean(6 * s.clear.cleared - s.clear.btc, s.clear.cleared),
    kubbsLeftWhenNotCleared: mean(s.clear.leftKubbs, s.clear.leftTurns),
    'g.advTurns': pct(s.advTurns, s.turns),
    'g.baseLine': pct(s.base8.hits, s.base8.batons), baseLineBatons: s.base8.batons,
    'g.baseAdv': pct(s.baseAdv.hits, s.baseAdv.batons), baseAdvBatons: s.baseAdv.batons,
    'g.kingHit': pct(s.king.hits, s.king.shots), kingShots: s.king.shots,
    'g.rethrown': pct(s.ink.R, s.ink.I), 'g.punish': pct(s.ink.P, s.ink.I),
    rescues: s.ink.Q, kubbsThrownIn: s.ink.I,
    inkastsWithARethrow: pct(s.ink.turnsR, s.ink.turns), inkastsWithAPunishment: pct(s.ink.turnsP, s.ink.turns),
    opener: { n: openers, took: s.opener.slice(), mean: mean(s.opener.reduce((a, n, i) => a + n * i, 0), openers) },
    clearBy: {}, firstBatonBy: {}, inkastBy: {},
  };
  for (const b of BANDS) {
    const c = s.clearBy[b], k = s.inkBy[b];
    o.clearBy[b] = { n: c.turns, cleared: pct(c.cleared, c.turns), batons: mean(c.btc, c.cleared, 1) };
    o.firstBatonBy[b] = tookOf(s.firstBy[b]);
    o.inkastBy[b] = { n: k.turns, rethrown: pct(k.R, k.I), punish: pct(k.P, k.I) };
  }
  return o;
}

// The tiers: every team with minBatons or more ranked by kubbs toppled a baton, cut where a
// third and two thirds of the ranked batons have been counted. tierOf is keyed by teamKey.
export function rankTeams(games, minBatons = MIN_BATONS) {
  const teams = {};
  for (const g of games) for (const side of ['A', 'B']) {
    const st = g.stats[side], key = norm(g.teamName[side]);
    const t = teams[key] || (teams[key] = { batons: 0, kubbs: 0 });
    // kubbs toppled, field and base: kubb.js's `hits` counts a baton once whatever it took
    t.batons += st.batons; t.kubbs += st.field + st.base;
  }
  const ranked = Object.entries(teams).filter(([, t]) => t.batons >= minBatons)
    .sort((a, b) => b[1].kubbs / b[1].batons - a[1].kubbs / a[1].batons);
  const total = ranked.reduce((n, [, t]) => n + t.batons, 0);
  const tierOf = {}, count = { top: 0, mid: 0, low: 0 };
  let acc = 0;
  for (const [key, t] of ranked) {
    const tier = acc < total / 3 ? 'top' : acc < 2 * total / 3 ? 'mid' : 'low';
    tierOf[key] = tier; count[tier]++; acc += t.batons;
  }
  return { ranked, tierOf, count };
}

export const tierOfSide = (tierOf, g, side) => tierOf[norm(g.teamName[side])];

export function tiers(games) {
  const { ranked, tierOf, count } = rankTeams(games);
  const S = { all: blank(), top: blank(), mid: blank(), low: blank(), winners: blank(), losers: blank() };
  const lengths = [], mostField = [];
  // a game's length by its weaker team's tier (both teams ranked)
  const byWeaker = { top: [], mid: [], low: [] }, order = ['top', 'mid', 'low'];
  let left = 0, leftLost = 0, adv = 0, advWon = 0;
  for (const g of games) {
    lengths.push(g.rows.length);
    const ta = tierOf[norm(g.teamName.A)], tb = tierOf[norm(g.teamName.B)];
    if (ta && tb) byWeaker[order[Math.max(order.indexOf(ta), order.indexOf(tb))]].push(g.rows.length);
    mostField.push(Math.max(...g.rows.map(r => r.startField)));
    const splits = side => ['all', tierOf[norm(g.teamName[side])],
      g.winner ? (g.winner === side ? 'winners' : 'losers') : null].filter(Boolean);
    for (const side of ['A', 'B']) for (const k of splits(side)) {
      S[k].teamGames++;
      if (g.winner === side) S[k].wins++;
    }
    for (const r of g.rows) {
      for (const k of splits(r.team)) addRow(S[k], r);
      if (!g.winner) continue;
      // a turn that left field kubbs standing, the game not over: did that team lose?
      if (r.startField > 0 && (r.btc === null || r.btc === undefined) && r.turn < g.rows.length) {
        left++;
        if (g.winner !== r.team) leftLost++;
      }
      if (r.advantage) { adv++; if (g.winner === r.team) advWon++; }
    }
  }
  const out = {
    games: games.length,
    teams: { ranked: ranked.length, minBatons: MIN_BATONS, ...count },
    turnsAGame: { mean: mean(lengths.reduce((a, b) => a + b, 0), lengths.length, 1), p10: quantile(lengths, 0.1),
      p25: quantile(lengths, 0.25), p50: quantile(lengths, 0.5), p75: quantile(lengths, 0.75),
      p90: quantile(lengths, 0.9), most: Math.max(...lengths) },
    turnsByWeakerTeam: Object.fromEntries(order.map(k => [k, { games: byWeaker[k].length,
      mean: mean(byWeaker[k].reduce((a, b) => a + b, 0), byWeaker[k].length, 1), p50: byWeaker[k].length ? quantile(byWeaker[k], 0.5) : null }])),
    mostFieldKubbsInAGame: { p25: quantile(mostField, 0.25), p50: quantile(mostField, 0.5),
      p75: quantile(mostField, 0.75), p90: quantile(mostField, 0.9) },
    leftFieldKubbsStanding: { turns: left, thatTeamLost: pct(leftLost, left) },
    threwFromAnAdvantageLine: { turns: adv, thatTeamWon: pct(advWon, adv) },
    split: {},
  };
  for (const [k, s] of Object.entries(S)) out.split[k] = figures(s);
  return out;
}

function render(t) {
  const cols = ['all', 'top', 'mid', 'low', 'winners', 'losers'];
  const lines = [];
  const row = (label, fn) => lines.push(label.padEnd(44) + cols.map(c => String(fn(t.split[c]) ?? '-').padStart(9)).join(''));
  lines.push(`${t.games} games; ${t.teams.ranked} teams ranked (top ${t.teams.top}, mid ${t.teams.mid}, low ${t.teams.low})`);
  lines.push(`turns a game: mean ${t.turnsAGame.mean}, a tenth under ${t.turnsAGame.p10 + 1}, half by ${t.turnsAGame.p50}, nine tenths by ${t.turnsAGame.p90}, most ${t.turnsAGame.most}`);
  lines.push('turns a game by the weaker team: ' + ['top', 'mid', 'low'].map(k => `${k} ${t.turnsByWeakerTeam[k].mean} (${t.turnsByWeakerTeam[k].games} games)`).join(', '));
  lines.push(`left field kubbs standing (${t.leftFieldKubbsStanding.turns} turns): that team lost ${t.leftFieldKubbsStanding.thatTeamLost}%`);
  lines.push(`threw from an advantage line (${t.threwFromAnAdvantageLine.turns} turns): that team won ${t.threwFromAnAdvantageLine.thatTeamWon}%`);
  lines.push('', ''.padEnd(44) + cols.map(c => c.padStart(9)).join(''));
  row('team games', s => s.teamGames);
  row('won', s => s.won);
  row('field batons: missed', s => s['g.fieldMiss']);
  row('  took two', s => s['g.field2']);
  row('  took three or more', s => s['g.field3']);
  row('field kubbs a baton', s => s.fieldKubbsABaton);
  row('cleared the field', s => s['g.cleared']);
  row('  batons left when cleared', s => s.batonsLeftWhenCleared);
  row('turns from an advantage line', s => s['g.advTurns']);
  row('base kubb from 8 m', s => s['g.baseLine']);
  row('base kubb from an advantage line', s => s['g.baseAdv']);
  row('king shots that toppled it', s => s['g.kingHit']);
  row('opening six batons: base kubbs (mean)', s => s.opener.mean);
  row('kubbs rethrown', s => s['g.rethrown']);
  row('  inkasts with a rethrow', s => s.inkastsWithARethrow);
  row('punishment kubbs', s => s['g.punish']);
  for (const b of BANDS) row(`${b} field kubbs: cleared`, s => s.clearBy[b].cleared);
  for (const b of BANDS.slice(1)) row(`${b}: first baton took two or more`, s => {
    const f = s.firstBatonBy[b];
    return f.n ? +(f.two + f.threePlus).toFixed(1) : null;
  });
  for (const b of BANDS.slice(1)) row(`${b}: first baton, kubbs (mean)`, s => s.firstBatonBy[b].kubbs);
  return lines.join('\n');
}

async function main(argv) {
  const dirs = argv.filter(a => !a.startsWith('--'));
  if (dirs.length !== 1 || !existsSync(dirs[0])) {
    console.error('usage: node tools/realtiers.mjs <real games dir> [--json]');
    return 2;
  }
  const { games } = await loadGames(resolve(dirs[0]));
  if (!games.length) { console.error('realtiers: the folder has no games'); return 2; }
  const t = tiers(games);
  console.log(argv.includes('--json') ? JSON.stringify(t, null, 1) : render(t));
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(c => process.exit(c));
}
