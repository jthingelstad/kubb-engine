// The Kubb Gym's compare and replay commands (tools/gym.mjs): pure functions, no matches played.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { compareCards, reproOf } from '../../tools/gym.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

// a scorecard with one configuration whose every game lasted `turns` turns
function card(turns, n = 40) {
  return {
    configs: [{ name: 'cpu club' }],
    results: { 'cpu club': { 'g.turns': { t: 'm', n, s: turns * n, q: turns * turns * n } } },
  };
}

test('compare reports a change with no noise on either side', () => {
  const rows = compareCards(card(2), card(3));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].key, 'g.turns');
  assert.equal(rows[0].z, Infinity);
  assert.equal(compareCards(card(3), card(2))[0].z, -Infinity);
});

test('compare keeps the same constant as no change', () => {
  assert.equal(compareCards(card(2), card(2)).length, 0);
});

test('a replay command carries every option that shapes the simulation', () => {
  const o = { seed: 7, maxturns: 12, sets: ['plan.levels.pro.nervesDeg=0.3', 'world.tune.x=1'],
    model: path.join(root, 'build', 'my-model.json'), engine: '/elsewhere/engine' };
  const cmd = reproOf(o, { thrower: 'human', level: 'club', surface: 'Sand' }, { m: 3, t: 9 });
  for (const part of ['--thrower human', '--level club', '--surface Sand', '--seed 7', '--maxturns 12',
    '--model build/my-model.json', '--set plan.levels.pro.nervesDeg=0.3', '--set world.tune.x=1',
    '--engine /elsewhere/engine', '--repro 3:9'])
    assert.ok(cmd.includes(part), `${part} in ${cmd}`);
  // the computer has no model
  assert.ok(!reproOf(o, { thrower: 'cpu', level: 'pro', surface: 'Grass' }, { m: 1, t: 1 }).includes('--model'));
});
