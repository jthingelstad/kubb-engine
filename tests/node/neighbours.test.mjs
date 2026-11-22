// The Tournament's neighbouring pitches under wasmoon (the reference platform), loaded
// from the bundle as a client loads it: kubbCall("neighbours.<name>"). The same proofs as
// tests/lua/session/test_neighbours.lua, and the reference playback a web client copies
// (playRecording below): a client's model built from the events alone equals view after
// every call. Also the events of one seed pinned by their hash, so a change that moves a
// neighbour's throws is seen (they are scenery, not a golden match: such a change says so
// and updates NEIGHBOURS_HASH).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { createEngine } from './wasm.mjs';

// A client's playback of a neighbour's recording (docs/CLIENTS.md "0.15.1 on top"): the
// items the pitch stood in, each moved body between its two poses around t (before its
// start where the items have it, after its last pose there), new bodies added. The same
// as the iPhone's Playback.pieces(at:) (Recording.swift).
export function playRecording(items, rec, t) {
  const out = items.map((it) => ({ ...it }));
  const at = new Map(out.map((it, i) => [it.id, i]));
  const u = t / rec.frameDt;
  const f = Math.floor(u);
  const a = u - f;
  const k = rec.poseScale;
  for (const b of rec.bodies) {
    let i = at.get(b.id);
    if (i === undefined) {
      out.push({ id: b.id, kind: b.kind, team: b.team, toppled: false });
      i = out.length - 1;
      at.set(b.id, i);
    }
    const it = out[i];
    if (f + 1 >= b.start) {
      const pose = (g) => {
        if (g < b.start) return [it.x, it.y, it.z, it.qw, it.qx, it.qy, it.qz];
        const j = Math.min(g - b.start, b.frames - 1) * 7;
        return b.poses.slice(j, j + 7).map((v) => v / k);
      };
      const p0 = pose(f);
      let p1 = a === 0 ? p0 : pose(f + 1);
      if (p0[3] * p1[3] + p0[4] * p1[4] + p0[5] * p1[5] + p0[6] * p1[6] < 0) {
        p1 = [p1[0], p1[1], p1[2], -p1[3], -p1[4], -p1[5], -p1[6]];
      }
      const m = p0.map((v, n) => v + (p1[n] - v) * a);
      [it.x, it.y, it.z, it.qw, it.qx, it.qy, it.qz] = m;
    }
    if (b.toppleT !== undefined && b.toppleT <= t) it.toppled = true;
  }
  return out;
}

function sameItems(got, want, what) {
  assert.equal(got.length, want.length, `${what}: count`);
  const by = new Map(want.map((it) => [it.id, it]));
  for (const it of got) {
    const w = by.get(it.id);
    assert.ok(w, `${what}: ${it.id}`);
    for (const key of ['x', 'y', 'z', 'qw', 'qx', 'qy', 'qz']) {
      assert.ok(Math.abs(it[key] - w[key]) < 1e-9, `${what}: ${it.id}.${key} ${it[key]} ${w[key]}`);
    }
    assert.equal(it.toppled, w.toppled, `${what}: ${it.id} toppled`);
  }
}

async function engine({ clock } = {}) {
  const e = await createEngine();
  if (clock) e.lua.global.set('__kubbClock', clock);
  return e;
}

function run(e, now0, now1, dt, budget, onEach) {
  const events = [];
  let now = now0;
  while (now < now1 - 1e-9) {
    now = Math.min(now1, now + dt);
    const r = e.call('neighbours.advance', { now, ...budget });
    events.push(...r.events);
    if (onEach && onEach(r, now)) break;
  }
  return events;
}

function fnv(text) {
  let h = 0x811c9dc5;
  const bytes = Buffer.from(text, 'utf8');
  for (const c of bytes) h = Math.imul(h ^ c, 0x01000193) >>> 0;
  return h.toString(16).padStart(8, '0');
}

// seed 9, six pitches, 3 minutes of clock in 1/20 s steps: every event, hashed
const NEIGHBOURS_HASH = '33173648'; // 1.0.0: kubbs stand in their seats, a baton resting on pieces feels their rolling resistance from the first step, and propped contacts are fixed (0.18.0 e427782a: the club and pro computers drive, and the baton's blow on a face moves the physics; 0.16.0 f3f06bfd: hits and landing; bafb735b before)

test('neighbours.open under wasmoon: the field, generated teams, any scene', async () => {
  const e = await engine();
  const o = e.call('neighbours.open', { seed: 3 });
  assert.equal(o.scene, 'tournament');
  assert.equal(o.surface, 'grass');
  assert.equal(o.set, 'usa');
  assert.equal(o.pitches.length, 8);
  for (const p of o.pitches) {
    assert.equal(p.items.length, 11);
    for (const side of ['A', 'B']) {
      const t = p.teams[side];
      assert.ok(e.call('names.valid', { kind: 'team', text: t.name }).ok, t.name);
      assert.ok(['beginner', 'club', 'pro'].includes(t.level));
    }
  }
  assert.deepEqual(e.call('neighbours.open', { seed: 3 }), o);
  assert.equal(e.call('neighbours.open', { scene: 'minnesota' }).set, 'minnesota');
  assert.throws(() => e.call('neighbours.open', { level: 'kid' }), /level/);
});

test('a client model from the events alone matches view, and recordings play to it', async () => {
  const e = await engine();
  const o = e.call('neighbours.open', { seed: 11, count: 4 });
  const model = new Map(o.pitches.map((p) => [p.id, { items: p.items }]));
  let checks = 0, throws = 0;
  run(e, 0, 150, 1 / 4, { steps: 600 }, (r, now) => {
    for (const ev of r.events) {
      const m = model.get(ev.id);
      if (m.rec) { m.items = playRecording(m.items, m.rec, m.rec.duration); m.rec = null; }
      if (ev.phase === 'throw') { m.rec = ev.recording; m.at = ev.at; throws++; }
      else if (ev.items) m.items = ev.items;
    }
    for (const [id, m] of model) {
      if (m.rec && now >= m.at + m.rec.duration) { m.items = playRecording(m.items, m.rec, m.rec.duration); m.rec = null; }
      const v = e.call('neighbours.view', { id });
      sameItems(m.items, v.items, `pitch ${id} at ${now}`);
      checks++;
    }
  });
  assert.ok(throws >= 20, `throws ${throws}`);
  assert.ok(checks > 500);
});

test('deterministic under wasmoon: two engines, slices of any size, a clock budget', async () => {
  const runOnce = async (budget, clock) => {
    const e = await engine({ clock });
    e.call('neighbours.open', { seed: 9, count: 6, now: 50 });
    return JSON.stringify(run(e, 50, 230, 1 / 20, budget));
  };
  const a = await runOnce({ steps: 300 });
  assert.equal(await runOnce({ steps: 300 }), a);
  assert.equal(await runOnce({ steps: 60 }), a);
  assert.equal(await runOnce({ steps: 100000 }), a);
  assert.equal(await runOnce({ budgetMs: 2 }, () => performance.now()), a);
  assert.equal(fnv(a), NEIGHBOURS_HASH, 'the neighbours of seed 9');
});

test('the budget under wasmoon: steps are never passed; a fake clock is never overrun', async () => {
  const e = await engine();
  e.call('neighbours.open', { seed: 5 });
  run(e, 0, 120, 1 / 30, { steps: 40 }, (r) => { assert.ok(r.used.steps <= 40); });
  let t = 0;
  const f = await engine({ clock: () => (t += 0.004) });
  f.call('neighbours.open', { seed: 5 });
  let worst = 0;
  run(f, 0, 120, 1 / 30, { budgetMs: 0.5 }, (r) => { worst = Math.max(worst, r.used.ms); });
  assert.ok(worst <= 0.5, `worst ${worst}`);
});

test("the player's session is untouched by neighbours in the same wasmoon state", async () => {
  const START = { year: 2026, month: 11, day: 15, hour: 10, min: 0 };
  const play = async (withNeighbours) => {
    const e = await engine();
    e.call('useTune', { name: 'pointer' });
    e.call('new', { mode: 'match', cpu: 'both', seed: 21, start: START, maxTurns: 6, scene: 'tournament' });
    const hashes = [e.call('hash').hash];
    if (withNeighbours) e.call('neighbours.open', { seed: 21, count: 8 });
    let now = 0;
    for (let i = 0; i < 12 && e.call('need').kind !== 'over'; i++) {
      for (let f = 0; f < 600; f++) {
        if (withNeighbours && f % 20 === 0) e.call('neighbours.advance', { now: (now += 0.5), steps: 200 });
        const out = e.call('frame', { dt: 1 / 60 });
        if (out.action) { hashes.push(`${e.call('hash').hash}:${fnv(JSON.stringify(e.call('recording')))}`); break; }
      }
    }
    return hashes.join(' ');
  };
  assert.equal(await play(true), await play(false));
});
