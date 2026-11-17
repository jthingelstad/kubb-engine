// The room's calls under wasmoon, the reference platform (docs/ROOM.md "Equivalence").
// 1. Every committed vector (tests/room/vectors/, recorded from the web's JavaScript by
//    tools/room-vectors.mjs) through kubbCall("room.<name>"), compared with what the
//    JavaScript returned, and every result's text byte stable.
// 2. When the web's modules are here, the same scenarios and more seeds run live through
//    both, the JavaScript and the engine side by side: $KUBB_WEB always (a failure there
//    with the committed vectors passing means the web has moved on since the commit
//    engine.json names), the sibling ../kubb.thingelstad.xyz checkout only while it is at
//    that commit.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createEngine } from './wasm.mjs';
import { root } from '../../tools/bundle.mjs';
import { canon, generate, jsAdapter, matches, normalise } from '../../tools/room-scenarios.mjs';
import { headOf, loadWeb, webDir } from '../../tools/room-vectors.mjs';

const DIR = path.join(root, 'tests/room/vectors');
const index = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8'));
const engine = await createEngine();
const constants = JSON.parse(engine.text('room.constants', '{}')).value;
const VERSION = JSON.parse(fs.readFileSync(path.join(root, 'engine.json'), 'utf8')).version;

// One call through the door: the result text and its value.
function lua(call, args) {
  const text = engine.text(`room.${call}`, JSON.stringify(args));
  const out = JSON.parse(text);
  if ('error' in out) throw new Error(`room.${call}: ${out.error}`);
  return { text, value: out.value };
}

// The runner's side of a scenario's placeholders.
function subst(v, doc) {
  if (v === '$doc') return doc;
  if (v === '$match') return doc && typeof doc === 'object' ? (doc.match ?? null) : null;
  if (v === '$engine') return VERSION;
  if (Array.isArray(v)) return v.map((x) => subst(x, doc));
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, subst(x, doc)]));
  return v;
}

function run(sc) {
  let doc = sc.start ?? null;
  sc.steps.forEach((step, i) => {
    const args = subst(step.args, doc);
    const { text, value } = lua(step.call, args);
    // byte stable: the same call again gives the same bytes
    if (i % 7 === 0) assert.equal(lua(step.call, args).text, text, `${sc.name} step ${i + 1}: the same bytes twice`);
    const found = [];
    const got = normalise(value, found);
    if (!matches(got, step.out))
      assert.fail(`${sc.name} step ${i + 1} ${step.call}(${JSON.stringify(args).slice(0, 300)})\n  lua: ${canon(got).slice(0, 600)}\n  js:  ${canon(step.out).slice(0, 600)}`);
    for (const e of found) assert.equal(e, constants.ENGINE, `${sc.name} step ${i + 1}: match.engine`);
    if (step.keep && value !== null) doc = value;
  });
  return sc.steps.length;
}

test('the vectors name the web commit engine.json records', () => {
  const m = JSON.parse(fs.readFileSync(path.join(root, 'engine.json'), 'utf8'));
  assert.equal(m.roomFrom.commit, index.web);
});

test('every committed vector matches under wasmoon', () => {
  let n = 0;
  for (const file of index.scenarios) n += run(JSON.parse(fs.readFileSync(path.join(DIR, file), 'utf8')));
  assert.equal(n, index.steps);
});

test('the constants are the JavaScript\'s, plus the engine\'s', () => {
  assert.equal(constants.ENGINE, VERSION.split('.').slice(0, 2).join('.'));
  assert.equal(constants.TEAM_MAX, 6);
  assert.equal(constants.LOG_BUDGET, 248 * 1024);
  assert.deepEqual(constants.SIDES, ['A', 'B']);
});

const wdir = webDir();
let web = await loadWeb(wdir);
let skip = !web && 'no web checkout here';
if (web && !process.env.KUBB_WEB && headOf(wdir) !== index.web) {
  skip = `the sibling web checkout is at ${String(headOf(wdir)).slice(0, 7)}, the vectors are from ${index.web.slice(0, 7)} (KUBB_WEB=<dir> compares anyway)`;
  web = null;
}
test('live: the web\'s JavaScript and the engine agree, step by step', { skip }, () => {
  const seeds = Array.from({ length: 60 }, (_, i) => 5001 + i);
  let n = 0;
  for (const sc of generate(jsAdapter(web), seeds)) n += run(sc);
  assert.ok(n > 1000, `${n} steps`);
});

test('live: the web\'s constants are the engine\'s', { skip }, () => {
  for (const [k, v] of Object.entries(web.lobby)) {
    if (k !== k.toUpperCase()) continue;
    assert.deepEqual(constants[k], JSON.parse(JSON.stringify(v)), k);
  }
  assert.equal(constants.CLIENT, web.sync.CLIENT);
});
