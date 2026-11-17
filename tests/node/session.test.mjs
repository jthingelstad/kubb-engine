// The session under wasmoon, loaded from the bundle as a client loads it (the web's
// tests/engine/engine.test.mjs, through kubbCall here instead of the web's Engine
// class): the host's start-up calls, a practice throw, and the multiplayer proof: one
// Lua state acts through a whole match, others only apply its actions, and every
// recording and hash agrees. Then a replay of a finished match.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createEngine } from './wasm.mjs';

// What the web's src/engine Engine does, over kubbCall: the same methods, so the
// tests below read as they do there. Every engine gets the pointer tune.
class Engine {
  static async create({ tune = 'pointer' } = {}) {
    const e = new Engine();
    Object.assign(e, await createEngine());
    if (tune) e.call('useTune', { name: tune });
    return e;
  }
  newPractice(opts = {}) { return this.call('new', { ...opts, mode: 'practice' }); }
  newMatch(opts = {}) { return this.call('new', { ...opts, mode: 'match' }); }
  restore(snapshot) {
    const out = JSON.parse(this.text('restore', snapshot));
    if (out && 'error' in out) throw new Error(`restore: ${out.error}`);
    return out;
  }
  snapshot() { return this.text('snapshot'); }
  hash() { return this.call('hash'); }
  view() { return this.call('view'); }
  need() { return this.call('need'); }
  aim() { return this.call('aim'); }
  frame(input = {}) {
    const a = { dt: input.dt ?? 1 / 60 };
    if (input.arm !== undefined && input.arm !== null) a.arm = input.arm;
    return this.call('frame', a);
  }
  showAt(t) { return this.call('showAt', { t }); }
  setControl(control) { return this.call('setControl', control); }
  apply(action) { return this.call('apply', action); }
  replayLoad(data) { return this.call('replayLoad', { setup: data.setup, h0: data.h0, log: data.log }); }
  replayStep() { return this.call('replayStep'); }
  replayBack() { return this.call('replayBack'); }
  replayRewind() { return this.call('replayRewind'); }
  replayInfo() { return this.call('replayInfo'); }
  replayEnd() { return this.call('replayEnd'); }
}

const START = { year: 2026, month: 11, day: 15, hour: 10, min: 0 };

// The arm angles of a swing as a pointer gives them, a frame each: back to
// `back` degrees, a quick flick forward to `stop`, held there.
function swingArms(back, stop) {
  const arms = [0, -5];
  for (let a = -5; a > -back;) {
    a = Math.max(-back, a - 400 / 60);
    arms.push(a);
  }
  for (let a = -back; a < stop;) {
    a = Math.min(stop, a + 2400 / 60);
    arms.push(a);
  }
  for (let i = 0; i < 6; i++) arms.push(stop);
  return arms;
}

test("the host's start-up calls: version, tune, client label", async () => {
  const bare = await Engine.create({ tune: null });
  const engineJson = JSON.parse(fs.readFileSync(new URL('../../engine.json', import.meta.url), 'utf8'));
  assert.deepEqual(bare.call('engineVersion'), { version: engineJson.version });
  assert.throws(() => bare.newPractice({ surface: 'grass' }), /no tune: call useTune first/);
  assert.throws(() => bare.call('useTune', { name: 'touch' }), /no module tune\/touch/);
  assert.deepEqual(bare.call('useTune', { name: 'pointer' }), { tune: 'pointer' });
  assert.throws(() => bare.call('useTune', { name: 'crank' }), /already pointer/);
  assert.deepEqual(bare.call('setClient', { label: 'web 0.4.2' }), { client: 'web 0.4.2' });
  bare.newMatch({ seed: 3, cpu: 'both', start: START, maxTurns: 1 });
  assert.match(bare.call('sheet').text, /\[Scored by "Throwing Wood web 0\.4\.2"\]/);
  const plain = await Engine.create();
  plain.newMatch({ seed: 3, cpu: 'both', start: START, maxTurns: 1 });
  assert.match(plain.call('sheet').text, new RegExp(`\\[Scored by "Throwing Wood kubb-engine ${engineJson.version.replaceAll('.', '\\.')}"\\]`));
  assert.equal(plain.hash().hash, bare.hash().hash, 'the label is not in the hash');
});

test("a practice throw gives a sane recording", async () => {
  const e = await Engine.create();
  const v = e.newPractice({ surface: "grass" });
  assert.equal(v.need.kind, "throw");
  assert.equal(v.items.length, 17);
  const plan = v.aim.plan;
  let out;
  for (const arm of swingArms(
    (plan.powerLo + plan.powerHi) / 2,
    plan.release,
  )) {
    out = e.frame({ dt: 1 / 60, arm });
    if (out.event) break;
  }
  assert.equal(out.event, "release");
  const rec = out.recording;
  assert.ok(rec.frames > 30 && rec.frames < 12 * 60);
  assert.equal(rec.frameDt, 1 / 60);
  assert.equal(rec.projectile.how, "baton");
  assert.ok(
    ["MISS", "HELICOPTER"].includes(rec.result.flag) ||
      /DOWN$/.test(rec.result.flag),
  );
  for (const b of rec.bodies) {
    assert.equal(b.poses.length, b.frames * 7);
    assert.ok(b.start >= 0 && b.start + b.frames - 1 <= rec.frames);
  }
  const p = e.showAt(rec.duration / 2);
  assert.ok(p.camera.f > 0);
  assert.equal(p.items.length, 18, "the pitch, the baton and the stakes");
  const after = e.view();
  assert.equal(after.need.kind, "throw");
  assert.ok(after.aim.verdicts && after.aim.verdicts.power);
});

test("two browsers play a whole match in step; a third joins mid-match", async () => {
  const actor = await Engine.create();
  const watcher = await Engine.create();
  actor.newMatch({
    seed: 5, // 42 ended on turn 3 once drills ran on (playdate-kubb #121)
    cpu: "B",
    start: START,
    wind: "light",
    raising: "hand",
    maxTurns: 30,
    teams: {
      A: { name: "Home", players: [{ name: "Ann" }, { name: "Bo" }] },
      B: { name: "Away", players: [{ name: "Cy" }] },
    },
  });
  watcher.restore(actor.snapshot());
  watcher.setControl({ sides: [], cpu: false });
  assert.equal(watcher.hash().hash, actor.hash().hash);

  let late = null;
  let actions = 0;
  let humanThrows = 0;
  let guard = 0;
  const check = (action, rec) => {
    const w = watcher.apply(action);
    if (rec) assert.equal(JSON.stringify(w.recording), JSON.stringify(rec));
    assert.equal(
      watcher.hash().hash,
      actor.hash().hash,
      `hash after action ${actions}`,
    );
    if (late) {
      const l = late.apply(action);
      if (rec) assert.equal(JSON.stringify(l.recording), JSON.stringify(rec));
      assert.equal(late.hash().hash, actor.hash().hash);
    }
    actions++;
  };

  while (guard++ < 2000) {
    const n = actor.need();
    if (n.kind === "over") break;
    if (actions === 25 && !(late instanceof Engine)) {
      late = await Engine.create();
      late.restore(actor.snapshot());
      late.setControl({ sides: [], cpu: false });
      assert.equal(late.hash().hash, actor.hash().hash);
    }
    if (n.kind === "raise") {
      const action = { type: "raise", choice: n.default };
      actor.apply(action);
      check(action);
    } else if (n.kind === "punish") {
      const action = { type: "punish", x: n.cursor.x, y: n.cursor.y };
      assert.equal(actor.apply(action).ok, true);
      check(action);
    } else if (n.cpu) {
      let out;
      for (let i = 0; i < 600 && !out?.action; i++)
        out = actor.frame({ dt: 1 / 60 });
      assert.ok(out.action, "the computer threw");
      check(out.action, out.recording);
    } else {
      // a human swing on the dial at the plan's power and release
      const plan = actor.aim().aim.plan;
      const stop = plan.release + ((humanThrows % 3) - 1) * 8;
      let out;
      for (const arm of swingArms(plan.back, stop)) {
        out = actor.frame({ dt: 1 / 60, arm });
        if (out.event) break;
      }
      if (!out.action) out = actor.frame({ dt: 1 / 60 }); // let go: the release
      assert.ok(out.action, `the human threw (${out.event})`);
      assert.equal(out.action.scripted, false);
      humanThrows++;
      check(out.action, out.recording);
    }
  }
  const n = actor.need();
  assert.equal(n.kind, "over");
  assert.equal(watcher.need().kind, "over");
  assert.equal(watcher.need().file.text, n.file.text);
  assert.ok(late instanceof Engine, "the late browser joined");
  assert.ok(humanThrows > 5);
  console.log(
    `      ${actions} actions (${humanThrows} by hand), ${n.turn} turns, ${n.how}; snapshot ${actor.hash().bytes} bytes`,
  );
});

// A finished match played again from its options and its log (session/replay.lua, the
// pitch's replay): every recording and hash the same, read only, BACK in step.
test("a replay plays the match again: the same recordings and hashes, read only", async () => {
  const actor = await Engine.create();
  const setup = {
    seed: 5,
    cpu: "B",
    start: START,
    wind: "light",
    raising: "hand",
    maxTurns: 8,
    teams: {
      A: { name: "Home", players: [{ name: "Ann", key: "m1" }] },
      B: { name: "Away", players: [{ name: "Cy" }] },
    },
  };
  actor.newMatch(setup);
  const h0 = actor.hash().hash;
  const log = [];
  const recs = [];
  let guard = 0;
  while (actor.need().kind !== "over" && guard++ < 2000) {
    const n = actor.need();
    let action;
    let rec = null;
    if (n.kind === "raise") {
      action = { type: "raise", choice: n.default };
      actor.apply(action);
    } else if (n.kind === "punish") {
      action = { type: "punish", x: n.cursor.x, y: n.cursor.y };
      actor.apply(action);
    } else {
      let out;
      if (n.cpu) {
        for (let i = 0; i < 600 && !out?.action; i++)
          out = actor.frame({ dt: 1 / 60 });
      } else {
        const plan = actor.aim().aim.plan;
        for (const arm of swingArms(plan.back, plan.release)) {
          out = actor.frame({ dt: 1 / 60, arm });
          if (out.event) break;
        }
        if (!out.action) out = actor.frame({ dt: 1 / 60 });
      }
      action = out.action;
      rec = out.recording;
    }
    // through JSON, as the document carries it
    log.push({ a: JSON.parse(JSON.stringify(action)), h: actor.hash().hash });
    recs.push(rec && JSON.stringify(rec));
  }
  assert.equal(actor.need().kind, "over");

  const viewer = await Engine.create();
  const v = viewer.replayLoad({ setup, h0, log });
  assert.equal(v.replay.i, 0);
  assert.equal(v.replay.total, log.length);
  assert.equal(v.need.local, false, "nobody acts in a replay");
  assert.throws(() => viewer.apply(log[0].a), /read only/);
  assert.throws(
    () => viewer.setControl({ sides: ["A"], cpu: true }),
    /read only/,
  );
  const turnAt = [];
  for (let i = 0; i < log.length; i++) {
    const r = viewer.replayStep();
    assert.equal(r.ok, true, `action ${i + 1}`);
    assert.equal(viewer.hash().hash, log[i].h, `hash after action ${i + 1}`);
    if (recs[i]) assert.equal(JSON.stringify(r.recording), recs[i]);
    turnAt.push(r.replay.turn);
  }
  const end = viewer.replayInfo();
  assert.equal(end.done, true);
  assert.equal(end.differs, false);
  assert.equal(viewer.need().file.text, actor.need().file.text);
  // BACK from the end: the start of the turn before the last
  const back = viewer.replayBack();
  const last = turnAt.at(-1);
  assert.equal(back.replay.turn, last - 1);
  assert.equal(
    viewer.hash().hash,
    back.replay.i ? log[back.replay.i - 1].h : h0,
  );
  viewer.replayRewind();
  assert.equal(viewer.hash().hash, h0);
  viewer.replayEnd();
  console.log(`      replayed ${log.length} actions, ${last} turns`);
});
