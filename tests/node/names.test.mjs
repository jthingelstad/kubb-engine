// Generated names through the session's door under wasmoon (docs/SESSION.md "Names"):
// the same seed gives the same names as desktop Lua (tests/lua/session/test_names.lua
// checks the same fingerprint), locked slots, stepping, valid, and that names.words is
// enough to check a name with no Lua at all: a pitch server's check, written here from
// nothing but what names.words returns, agrees with the engine on every name and on every
// near miss below.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createEngine } from './wasm.mjs';

const { call } = await createEngine();

function fnv(text) {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 0x01000193) >>> 0;
  return h.toString(16).padStart(8, '0');
}

// The same constants as tests/lua/session/test_names.lua: seeds 1 to 300, one name a line.
const FINGERPRINT = { player: '07a20e20', team: '6a91fa87' };

test('names.roll: a seed gives the same names under wasmoon as under desktop Lua', () => {
  for (const kind of ['player', 'team']) {
    const lines = [];
    for (let seed = 1; seed <= 300; seed++) lines.push(call('names.roll', { kind, seed }).text);
    assert.equal(fnv(lines.join('\n')), FINGERPRINT[kind], kind);
  }
  assert.deepEqual(call('names.roll', { kind: 'player', seed: 42 }),
    { text: 'Midsummer Myrtle', parts: { shape: 'adj', words: ['Midsummer', 'Myrtle'] } });
  assert.equal(call('names.roll', { kind: 'team', seed: 42 }).text, 'Lively Carvers');
});

test('names.roll keeps locked slots; names.step goes round a slot', () => {
  for (let seed = 1; seed <= 50; seed++) {
    const r = call('names.roll', { kind: 'team', seed, keep: { shape: 'adj', words: [null, 'Lumberjacks'] } });
    assert.equal(r.parts.words[1], 'Lumberjacks');
    assert.equal(call('names.valid', { kind: 'team', text: r.text }).ok, true, r.text);
  }
  const start = { shape: 'adj', words: ['Mighty', 'Maple'] };
  const choices = call('names.choices', { kind: 'player', parts: start, slot: 1 }).words;
  let parts = start;
  for (let i = 0; i < choices.length; i++) parts = call('names.step', { kind: 'player', parts, slot: 1 }).parts;
  assert.deepEqual(parts, start, 'a full turn comes back');
  const only = call('names.step', { kind: 'team', parts: { shape: 'adj', words: ['Magnificent', 'Owls'] }, slot: 1 });
  assert.equal(only.moved, false);
  assert.throws(() => call('names.roll', { kind: 'coach', seed: 1 }), /names\.roll: kind/);
});

// A check outside Lua, from names.words alone (docs/NAMES.md section 6): what the pitch
// server would run.
function checker(w) {
  const sets = Object.fromEntries(Object.entries(w.lists).map(([k, v]) => [k, new Set(v)]));
  const never = new Set(w.never);
  return (kind, text) => {
    const shapes = w.shapes[kind];
    if (!shapes || typeof text !== 'string' || text.length > w.max[kind]) return false;
    const ws = text.split(' ');
    if (ws.some((x) => x === '') || never.has(text)) return false;
    // no word begins with the one before it ("Pine Pinecones")
    for (let i = 1; i < ws.length; i++) if (ws[i].toLowerCase().startsWith(ws[i - 1].toLowerCase())) return false;
    return shapes.some((s) => {
      const lead = s.prefix === null ? [] : [s.prefix];
      if (ws.length !== lead.length + s.slots.length) return false;
      if (lead.length && ws[0] !== s.prefix) return false;
      return s.slots.every((list, i) => sets[list].has(ws[lead.length + i]));
    });
  };
}

function canonical(v) {
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).sort().map((k) => `${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`;
  return JSON.stringify(v);
}

const title = (s) => s.split(' ').map((x) => x.charAt(0).toUpperCase() + x.slice(1)).join(' ');

// Words docs/NAMES.md "Words taken out" removed: their names must stay refused.
const REMOVED = ['Bamboo', 'Rowan', 'Sturdy', 'Cherry', 'Ebony', 'Prickly', 'Pecan', 'Drillas', 'Inkasters', 'Yew',
  'Knotholes', 'Sassy', 'Tiny', 'Palm', 'Banyan', 'Lanterns', 'Apple', 'Super', 'Bouncy', 'Hemlock', 'Tumblers',
  'Woodpiles', 'Picnickers', 'Farfars'];

test('names.words is enough to give valid\'s answer without Lua', () => {
  const w = call('names.words');
  const { hash, ...rest } = w;
  assert.equal(fnv(canonical(rest)), hash, 'the hash is FNV-1a of the canonical JSON of the rest');
  const valid = checker(w);
  const all = {};
  for (const kind of ['player', 'team']) {
    all[kind] = call('names.all', { kind }).names;
    const file = fs.readFileSync(new URL(`../names/${kind}.txt`, import.meta.url), 'utf8');
    assert.equal(all[kind].join('\n') + '\n', file, `${kind}: names.all is tests/names/${kind}.txt`);
    for (const s of all[kind]) assert.equal(valid(kind, s), true, `${kind}: ${s}`);
  }

  // Near misses: the blocklist's words, phrases and runs as a name would spell them, the
  // never pairs, the words taken out beside good partners, the engine's defaults, and
  // every 13th real name bent (capitals, spaces, order, the other kind, one letter more).
  const near = new Set();
  const block = fs.readFileSync(new URL('../names/blocklist.txt', import.meta.url), 'utf8');
  for (const line of block.split('\n')) {
    const m = line.match(/^(word|phrase|run) (.+)$/);
    if (!m) continue;
    near.add(title(m[2]));
    near.add(m[2]);
    near.add(`The ${title(m[2])}`);
    near.add(`Mighty ${title(m[2])}`);
    near.add(`${title(m[2])} Maple`);
  }
  for (const s of w.never) near.add(s);
  for (const x of REMOVED) for (const s of [`${x} Batons`, `Mighty ${x}`, `The ${x}`, `${x} Maple`, `Birch ${x}`]) near.add(s);
  for (const s of w.defaults) near.add(s);
  for (const kind of ['player', 'team']) {
    all[kind].forEach((s, i) => {
      if (i % 13) return;
      const ws = s.split(' ');
      for (const b of [s.toLowerCase(), s.toUpperCase(), ` ${s}`, `${s} `, s.replace(' ', '  '), s.replace(' ', ' '),
        s.replace(' ', '\t'), ws.slice().reverse().join(' '), `${s}s`, ws.join(''), `The ${s}`]) near.add(b);
    });
  }
  let refusedHere = 0;
  for (const text of near) {
    for (const kind of ['player', 'team']) {
      const lua = call('names.valid', { kind, text }).ok;
      assert.equal(valid(kind, text), lua, `${kind}: ${JSON.stringify(text)}`);
      if (!lua) refusedHere++;
    }
  }
  assert.ok(near.size > 2000 && refusedHere > 3000, `${near.size} near misses checked`);
  // across kinds: no player name is a team name, and the reverse, on both checks
  for (const s of all.player.filter((_, i) => i % 7 === 0)) {
    assert.equal(valid('team', s), false, s);
    assert.equal(call('names.valid', { kind: 'team', text: s }).ok, false, s);
  }
});
