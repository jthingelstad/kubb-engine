// Baton value (tools/batonvalue.mjs; docs/notes/real-games.md "Baton value"): the recursion on
// hand-made counts, empty and unreachable states, two hand-scored fixture games, and that the
// tool prints the same thing twice.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { solveField, solveFresh, poolsOf, figures, run, MIN_BATONS } from '../../tools/batonvalue.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const fixtures = path.join(root, 'tests', 'fixtures', 'batonvalue');
const near = (a, b, msg) => assert.ok(Math.abs(a - b) < 1e-3, `${msg}: ${a} against ${b}`);
const byN = rows => Object.fromEntries(rows.map(r => [r.n, r.E]));

test('the recursion on hand-made counts', () => {
  // n = 1: half hit -> 2. n = 2: miss 1/2, one 1/4, both 1/4 -> (1 + 1/4 * 2) / (1/2) = 3.
  // n = 3: always two -> 1 + E[1] = 3.
  const rows = [, [5, 5], [2, 1, 1], [0, 0, 4, 0]];
  const pools = [[1, 1], [2, 2], [3, 3]];
  const E = byN(solveField(rows, pools));
  near(E[1], 2, 'E1'); near(E[2], 3, 'E2'); near(E[3], 3, 'E3');
  // on its own counts with min 1 the pools are the single states
  assert.deepEqual(poolsOf(rows, 1), pools);
});

test('a pool shares its outcomes, capped at n', () => {
  // states 1 and 2 pooled: miss 2, one 1, two 1 of 4 batons. At n = 1 a two takes the last one.
  const rows = [, [1, 1], [1, 0, 1]];
  const E = byN(solveField(rows, [[1, 2]]));
  near(E[1], 2, 'E1 = 1 / (2/4)');
  near(E[2], (1 + 0.25 * 2) / 0.5, 'E2');
});

test('pooling joins thin neighbours, at most three, and a short top joins the one below', () => {
  const rows = [, [40], [10], [10], [10], [5]];
  assert.deepEqual(poolsOf(rows, 30), [[1, 1], [2, 4], [5, 5]]);
  assert.deepEqual(poolsOf([, [40], [40], [10]], 30), [[1, 1], [2, 3]]);
  assert.deepEqual(poolsOf([], 30), []);
});

test('empty and unreachable states', () => {
  assert.deepEqual(solveField([]), []);
  // nothing ever toppled from n = 1: unbounded, and n = 2 that needs it is too
  const never = byN(solveField([, [3, 0], [0, 1, 0]], [[1, 1], [2, 2]]));
  assert.equal(never[1], Infinity); assert.equal(never[2], Infinity);
  // a pool with no batons (a resample can drop them): null, and so is a state that needs it
  const empty = byN(solveField([, , [0, 1, 0]], [[1, 1], [2, 2]]));
  assert.equal(empty[1], null); assert.equal(empty[2], null);
  // ... but a state that never passes through it is still known
  const skip = byN(solveField([, , [0, 0, 2]], [[1, 1], [2, 2]]));
  assert.equal(skip[1], null); near(skip[2], 1, 'E2 when every baton takes both');
  // figures of an empty counts object: every figure null
  const f = figures({ field: { line: [], adv: [] }, first: { line: [], adv: [] }, plain: { line: [], adv: [] },
    base: { line: { batons: 0, kubbs: 0, hits: 0 }, adv: { batons: 0, kubbs: 0, hits: 0 } }, king: { shots: 0, hits: 0 } },
  { line: { all: [], first: [], later: [] }, adv: { all: [], first: [], later: [] } });
  assert.ok(Object.values(f).every(v => v === null));
});

test('a fresh position: the first baton, then the later chain', () => {
  // later: n = 1 hit half the time (2), n = 2 always one (1 + 2 = 3).
  // first at n = 2: both 1/2, one 1/2 -> 1 + 1/2 * E[1] = 2. At n = 3 a miss leaves n = 3 to
  // the later chain, which has no batons there: unknown.
  const later = [, [1, 1], [0, 2, 0]];
  const first = [, , [0, 1, 1]];
  const E = byN(solveFresh(first, later, [[2, 2]], [[1, 1], [2, 2]]));
  near(E[2], 2, 'fresh 2');
  const miss = byN(solveFresh([, , , [1, 0, 0, 1]], later, [[3, 3]], [[1, 1], [2, 2]]));
  assert.equal(miss[3], null);
});

// Two games scored by hand (tests/fixtures/batonvalue). From the baseline the field batons are
// n = 1: missed 2, took one 3; n = 2: 1, 2, 1 (none, one, two); n = 3: one took two;
// n = 4: missed 5, one took two; n = 5: one took one. Under 30 batons a state, the pools are
// 1-3 (10 batons: missed 3, one 5, two 2) and 4-5 (7: missed 5, one 1, two 1), so
//   E1 = 1 / 0.7 = 1.4286
//   E2 = (1 + 0.5 E1) / 0.7 = 2.4490
//   E3 = (1 + 0.5 E2 + 0.2 E1) / 0.7 = 3.5860
//   E4 = (1 + E3 / 7 + E2 / 7) / (2 / 7) = 6.5175
//   E5 = (1 + E4 / 7 + E3 / 7) / (2 / 7) = 8.5517
// Base kubbs from 8 m: 10 by 23 batons (the Z is one of them; the FB's base kubb is not);
// from an advantage line 2 by 2; the king 2 of 3 shots. Cleared turns from the baseline: two
// from 2 in 3 and 1 batons, one from 3 in 2, one from 4 in 5, the one from 5 did not clear.
// Fresh from 4: the first batons from 4 and 5 took one and two; the later chain gives
// E1 = 7/4, E2 = 3.5, E3 = 5.25, so 1 + E3 / 2 + E2 / 2 = 5.375.
test('two hand-scored games', async () => {
  const rep = await run(fixtures, { boot: 0 });
  assert.equal(rep.games.files, 2);
  assert.equal(rep.games.read, 2);
  assert.equal(rep.estimator.minBatonsAState, MIN_BATONS);
  const o = rep.splits.all;
  const line = Object.fromEntries(o.field.line.map(r => [r.n, r]));
  for (const [n, e] of [[1, 1.4286], [2, 2.4490], [3, 3.5860], [4, 6.5175], [5, 8.5517]]) near(line[n].chain.E, e, `E${n}`);
  assert.deepEqual(line[4].chain.took, [5, 0, 1, 0, 0]);
  assert.deepEqual(line[4].chain.pool, [4, 5]);
  assert.equal(line[4].chain.poolBatons, 7);
  near(line[4].fresh.E, 5.375, 'fresh 4');
  near(line[2].cleared.E, 2, 'cleared from 2');
  near(line[4].cleared.E, 5, 'cleared from 4');
  assert.equal(line[5].cleared.E, null);
  assert.equal(line[5].cleared.turns, 1);
  near(o.field.adv[0].chain.E, 1, 'one kubb from an advantage line, hit');
  assert.deepEqual([o.base.line.kubbs, o.base.line.batons], [10, 23]);
  near(o.base.line.E, 2.3, 'base from 8 m');
  near(o.base.adv.E, 1, 'base from an advantage line');
  near(o.king.E, 1.5, 'king');
  assert.deepEqual(o.fieldToBase, { batons: 1, kubbs: 1 });
  assert.equal(o.illegal, 1);
});

test('the same output on two runs', () => {
  const once = args => execFileSync(process.execPath, [path.join(root, 'tools', 'batonvalue.mjs'), ...args], { encoding: 'utf8' });
  for (const args of [[fixtures, '--json', '--tiers', '--boot', '200'], [path.join(root, 'tests', 'fixtures', 'games'), '--boot', '200']]) {
    const a = once(args), b = once(args);
    assert.equal(a, b);
    assert.ok(!a.includes(root), 'no absolute paths in the output');
  }
});
