// The pitch's calls under wasmoon, the reference platform (docs/PITCH.md "The vectors").
// Every committed vector (tests/pitch/vectors/, a frozen corpus recorded from the web's
// JavaScript at the commit engine.json's pitchFrom names) through kubbCall("pitch.<name>"),
// compared with what the JavaScript returned, every result's text byte stable, and the
// old spelling "room.<name>" giving the same bytes.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createEngine } from './wasm.mjs';
import { root } from '../../tools/bundle.mjs';

const DIR = path.join(root, 'tests/pitch/vectors');
const index = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8'));
const engine = await createEngine();
const constants = JSON.parse(engine.text('pitch.constants', '{}')).value;
const VERSION = JSON.parse(fs.readFileSync(path.join(root, 'engine.json'), 'utf8')).version;

// ---------- canonical JSON, FNV-1a and the comparison (as the vectors were written) ----------

function canon(v) {
  if (v === null || typeof v !== 'object') return JSON.stringify(v ?? null);
  if (Array.isArray(v)) return '[' + v.map((x) => (x === undefined ? 'null' : canon(x))).join(',') + ']';
  const keys = Object.keys(v)
    .filter((k) => v[k] !== undefined)
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
}

function fnv(text) {
  let h = 0x811c9dc5;
  for (const b of Buffer.from(text, 'utf8')) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

// A match (it has seq) or a replay (v and log) keeps an `engine` only in the Lua.
function normalise(v, found = []) {
  if (Array.isArray(v)) return v.map((x) => normalise(x, found));
  if (v && typeof v === 'object') {
    const out = {};
    const strip = 'seq' in v || ('v' in v && 'log' in v);
    for (const [k, x] of Object.entries(v)) {
      if (strip && k === 'engine') found.push(x);
      else out[k] = normalise(x, found);
    }
    return out;
  }
  return v;
}

// Does `got` (a result, normalised) match `want` (a step's out)?
function matches(got, want) {
  const text = canon(got);
  if (want && typeof want === 'object' && !Array.isArray(want) && '$fnv' in want)
    return fnv(text) === want.$fnv && Buffer.byteLength(text) === want.$bytes;
  return text === canon(want);
}

// One call through the door: the result text and its value.
function lua(call, args, prefix = 'pitch') {
  const text = engine.text(`${prefix}.${call}`, JSON.stringify(args));
  const out = JSON.parse(text);
  if ('error' in out) throw new Error(`${prefix}.${call}: ${out.error}`);
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
    // byte stable: the same call again gives the same bytes, and so does the old spelling
    if (i % 7 === 0) assert.equal(lua(step.call, args).text, text, `${sc.name} step ${i + 1}: the same bytes twice`);
    if (i % 11 === 0) assert.equal(lua(step.call, args, 'room').text, text, `${sc.name} step ${i + 1}: room. is pitch.`);
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
  assert.equal(m.pitchFrom.commit, index.web);
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

test('room. is the old spelling of pitch.; an error names the call as it was made', () => {
  assert.equal(engine.text('room.constants', '{}'), engine.text('pitch.constants', '{}'));
  assert.match(JSON.parse(engine.text('room.nope', '{}')).error, /unknown call room\.nope/);
  assert.match(JSON.parse(engine.text('pitch.nope', '{}')).error, /unknown call pitch\.nope/);
  assert.match(JSON.parse(engine.text('room.lobbyOf', '[1]')).error, /^room\.lobbyOf: /);
  assert.match(JSON.parse(engine.text('pitch.lobbyOf', '[1]')).error, /^pitch\.lobbyOf: /);
});

// Several engines in one pitch (pitch/engines.lua, since 0.8.1): the same answers under
// wasmoon as tests/lua/pitch/test_engines.lua finds under desktop Lua.
test('engineFor, carried, announce and speakAs under wasmoon', () => {
  const both = ['0.8', '0.7'];
  const fresh = (id, engine) => ({ id, connected: true, me: { name: id, ...lua('announce', { carries: both, engine }).value } });
  const doc = { v: 1, teams: { A: ['h'], B: ['p', 'i'] } };
  const members = [fresh('h'), fresh('p'), { id: 'i', connected: true, me: { name: 'i', engine: '0.7.4' } }];
  assert.equal(lua('announce', { carries: ['0.7.4', '0.8.1'], engine: '0.7' }).text,
    '{"value":{"engine":"0.7+engines","engines":["0.8","0.7"]}}');
  assert.deepEqual(lua('carried', { me: { engine: '0.7', engines: both } }).value, ['0.7']);
  assert.deepEqual(lua('carried', { me: members[0].me }).value, both);
  assert.deepEqual(lua('engineFor', { doc, members, host: 'h' }).value, { engine: '0.7', missing: [], unknown: [] });
  assert.deepEqual(lua('engineFor', { doc: { v: 1, teams: { A: ['h'], B: ['p'] } }, members, host: 'h' }).value,
    { engine: '0.8', missing: [], unknown: [] });
  members[0] = { id: 'h', connected: true, me: { name: 'h', engine: '0.8+engines', engines: ['0.8'] } };
  assert.deepEqual(lua('engineFor', { doc, members, host: 'h' }).value, { engine: null, missing: ['i'], unknown: [] });
  const spoken = lua('speakAs', { members: [fresh('p', '0.7')], engine: '0.8' }).value;
  assert.equal(spoken[0].me.engine, '0.8');
  assert.deepEqual(spoken[0].me.engines, both);
});
