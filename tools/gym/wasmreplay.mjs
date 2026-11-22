// The browser's recorded matches (records.mjs, `browser/<day>/`) replayed under wasmoon,
// the reference platform (docs/DETERMINISM.md), on the engine the record names (its
// tag's sources, loaded as a client loads the bundle), so every person's throw is
// paired with the snapshot its player saw. Under stock Lua (tools/gym/invert.lua) a
// browser match was judged from its start only while the hashes agreed, and desktop
// Lua's last-bit differences ended most of them within a few throws.
//
// browserToRoom(lines) turns each browser line into one `room` line a throw (the
// snapshot before it, the action, the recorded hash after it), checking every action's
// hash; a match whose hash parts from the record is cut there. A match that names no
// engine, or one with no tag here, is passed on unchanged for the inverter's fallback.
// What comes back is as
// private as what went in: it stays in memory and in the caller's temporary folder.
import { LuaFactory } from 'wasmoon';
import { mkdtempSync, rmSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';
import { extractEngine, git } from './pool.mjs';

const BOOT = `
local imported = {}
function import(name)
  name = name:gsub("%.lua$", "")
  if imported[name] then return nil end
  imported[name] = true
  local s = __kubbSource(name)
  if not s then error("import: no module " .. name, 2) end
  return assert(load(s, "@" .. name))()
end
import "session/api"
`;

// A tag's engine as a module map { "core/world": source, ... }.
function sourcesOf(tag) {
  const dir = mkdtempSync(join(tmpdir(), 'kubb-gym-eng-'));
  try {
    extractEngine(tag, dir);
    const out = {};
    const walk = (d) => {
      for (const f of readdirSync(d)) {
        const p = join(d, f);
        if (statSync(p).isDirectory()) walk(p);
        else if (f.endsWith('.lua')) out[relative(dir, p).slice(0, -4)] = readFileSync(p, 'utf8');
      }
    };
    walk(dir);
    return out;
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

async function engineFor(sources) {
  const lua = await new LuaFactory().createEngine();
  lua.global.set('__kubbSource', (name) => (Object.hasOwn(sources, name) ? sources[name] : undefined));
  await lua.doString(BOOT);
  const kubbCall = lua.global.get('kubbCall');
  const text = (m, a = '') => kubbCall(m, a);
  const call = (m, a) => {
    const out = JSON.parse(text(m, a === undefined ? '' : JSON.stringify(a)));
    if (out && typeof out === 'object' && !Array.isArray(out) && 'error' in out) throw new Error(`${m}: ${out.error}`);
    return out;
  };
  return { lua, text, call };
}

// { lines (room lines), stats: { matches, throws, cut, agreed } }
export async function browserToRoom(lines) {
  const out = [];
  const stats = { matches: 0, throws: 0, throwsSeen: 0, cut: 0, actions: 0, agreed: 0, passed: 0 };
  const cache = new Map();
  for (const l of lines) {
    if (l.kind !== 'browser') { out.push(l); continue; }
    stats.matches++;
    const tag = l.e ? `v${l.e}` : null;
    // a record that names no engine (they predate the field), or one this checkout has no
    // tag for, cannot be replayed on its own engine here: it goes on as it came, to the
    // inverter's fallback (it tries the engines it has and judges the match from its start
    // while the hashes agree, tools/gym/invert.lua)
    if (!tag || git(['rev-parse', '-q', '--verify', `${tag}^{commit}`]) === null) { stats.passed++; out.push(l); continue; }
    if (!cache.has(tag)) cache.set(tag, sourcesOf(tag));
    const e = await engineFor(cache.get(tag));
    try {
      e.call('useTune', { name: 'pointer' });
      const r = JSON.parse(e.text('restore', l.start));
      if (r && r.error) { stats.cut++; continue; }
      for (let i = 0; i < l.actions.length; i++) {
        const a = l.actions[i];
        const person = a.type === 'throw' && !a.scripted && a.swing;
        if (person) stats.throwsSeen++;
        const before = person ? e.text('snapshot') : null;
        e.call('apply', a);
        const h = e.call('hash').hash;
        stats.actions++;
        if (l.hashes && l.hashes[i] !== h) { stats.cut++; break; }
        stats.agreed++;
        if (person) {
          out.push({ k: l.k, i: i + 1, kind: 'room', before, a, hash: h, e: l.e });
          stats.throws++;
        }
      }
    } finally { e.lua.global.close(); }
  }
  return { lines: out, stats };
}
