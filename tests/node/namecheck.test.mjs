// The names in a match from outside under wasmoon, the reference platform
// (session/namecheck, docs/SESSION.md "Names"): names.check on a snapshot, a replay and a
// pitch's document, and the strict restore and replayLoad. tests/lua/session/
// test_namecheck.lua covers every place one at a time under desktop Lua.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createEngine } from './wasm.mjs';

const { call, text } = await createEngine();
call('useTune', { name: 'pointer' });

const START = { year: 2026, month: 11, day: 21, hour: 10, min: 0 };
const SETUP = {
  seed: 3, cpu: 'both', start: START, maxTurns: 6, wind: 'light',
  teams: {
    A: { name: 'Wobbly Towers', players: [{ name: 'Mighty Maple' }, { name: 'Lucky Larch' }] },
    B: { name: 'Jolly Juniper', players: [{ name: 'Jolly Juniper' }] },
  },
};

// The computer against itself: every snapshot, and the log a replay keeps.
function play(setup) {
  call('new', { ...setup, mode: 'match' });
  const snaps = [text('snapshot')];
  const h0 = call('hash').hash;
  const log = [];
  for (let guard = 0; call('need').kind !== 'over' && guard < 400; guard++) {
    let out;
    for (let i = 0; i < 600 && !out?.action; i++) out = call('frame', { dt: 1 / 60 });
    log.push({ a: out.action, h: call('hash').hash });
    snaps.push(text('snapshot'));
  }
  return { snaps, h0, log };
}

const run = play(SETUP);
const restoreRaw = (arg) => JSON.parse(text('restore', typeof arg === 'string' ? arg : JSON.stringify(arg)));

test('names.check: an honest match is allowed at every snapshot, as text or as the object', () => {
  for (const snap of run.snaps) {
    const rep = call('names.check', { snap });
    assert.equal(rep.allowed, true, JSON.stringify(rep.refused));
  }
  const rep = call('names.check', { snap: JSON.parse(run.snaps.at(-1)) });
  assert.equal(rep.allowed, true);
  const solo = rep.names.find((n) => n.from === 'save.game.teams.B.name');
  assert.deepEqual(solo, { text: 'Jolly Juniper', from: 'save.game.teams.B.name', kind: 'team', as: 'player', ok: true, default: false });
});

test("names.check: the reviewer's forgery is caught, and the strict restore refuses it", () => {
  const before = call('hash').hash;
  const d = JSON.parse(run.snaps[10]);
  d.save.game.teams.A.name = 'Anything Typed';
  d.save.game.teams.A.players[0].name = 'Typed Too';
  const forged = JSON.stringify(d);
  const rep = call('names.check', { snap: forged });
  assert.equal(rep.allowed, false);
  assert.ok(rep.refused.some((r) => r.from === 'save.game.teams.A.name'));
  assert.ok(rep.refused.some((r) => r.from === 'save.game.teams.A.players[0].name'));
  assert.ok(rep.mismatches.some((m) => m.from === 'save.game.teams.A.name' && m.other === 'opts.teams.A.name'));
  // checking changed nothing
  assert.equal(call('hash').hash, before);
  const out = restoreRaw({ snap: forged, names: 'check' });
  assert.match(out.error, /^restore: names not allowed: save\.game\.teams\.A\.name/);
  assert.ok(!out.error.includes('Anything Typed'), 'the error names places, not text');
  assert.equal(call('hash').hash, before, 'a refused restore changes nothing');
  // the honest one restores through the strict door to the same hash
  restoreRaw(run.snaps[10]);
  const plain = call('hash').hash;
  restoreRaw(run.snaps[11]);
  restoreRaw({ snap: run.snaps[10], names: 'check' });
  assert.equal(call('hash').hash, plain);
});

test('an old match with typed names is not allowed, and still restores without the check', () => {
  const old = play({ ...SETUP, maxTurns: 2, teams: { A: { name: 'Riverside', players: [{ name: 'Ann' }] }, B: { name: 'Oak', players: [{ name: 'Cy' }] } } });
  const snap = old.snaps.at(-1);
  assert.equal(call('names.check', { snap }).allowed, false);
  assert.ok(restoreRaw({ snap, names: 'check' }).error);
  assert.ok(restoreRaw(snap).need, 'the plain restore');
});

test('names.check on a replay and a document; replayLoad with names = "check"', () => {
  const replay = { setup: SETUP, h0: run.h0, log: run.log, snap: run.snaps.at(-1) };
  assert.equal(call('names.check', { replay }).allowed, true);
  const v = call('replayLoad', { setup: SETUP, h0: run.h0, log: run.log, names: 'check' });
  assert.equal(v.replay.differs, false);
  const bad = structuredClone(SETUP);
  bad.teams.B.players[0].name = 'Typed';
  const rep = call('names.check', { replay: { ...replay, setup: bad } });
  assert.ok(rep.refused.some((r) => r.from === 'setup.teams.B.players[0].name'));
  assert.throws(() => call('replayLoad', { setup: bad, log: run.log, names: 'check' }), /names not allowed/);
  call('replayEnd');
  const doc = {
    v: 1, teams: { A: ['m1', 'm2'], B: ['m3'] }, started: true, n: 1,
    teamNames: { A: 'Wobbly Towers' },
    match: { n: 1, seq: run.log.length, snap: run.snaps.at(-1), setup: SETUP, h0: run.h0, log: run.log, over: true,
      players: { A: [{ id: 'm1', name: 'Mighty Maple' }, { id: 'm2', name: 'Lucky Larch' }], B: [] } },
  };
  assert.equal(call('names.check', { document: doc, members: [{ id: 'm1', me: { name: 'Mighty Maple' } }] }).allowed, true);
  const out = call('names.check', { document: { ...doc, teamNames: { A: 'Typed' } } });
  assert.deepEqual(out.refused.map((r) => r.from), ['teamNames.A']);
});
