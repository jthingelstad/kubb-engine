// Record mode (docs/RECORD.md) under wasmoon, from the bundle as a client loads it: each
// game of tests/fixtures/record/games.lua, built through kubbCall("record.build"), writes
// the same file byte for byte as under desktop Lua (tools/recordgames.lua), so the door is
// in the bundle and the iPhone's Lua writes what the tests check.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createEngine } from './wasm.mjs';

const root = path.resolve(import.meta.dirname, '../..');
const fixture = fs.readFileSync(path.join(root, 'tests/fixtures/record/games.lua'), 'utf8');

// The fixture as a module beside the engine's: it leaves the files on a global.
const driver = `
import "session/json"
local json = tw.web.json
local games = (function()
${fixture}
end)()
local out = {}
for name, g in pairs(games) do
  local r = json.decode(kubbCall("record.build", json.encode { game = g.setup, events = g.events, want = { notation = true } }))
  out[name] = r.notation and r.notation.text or ("error: " .. tostring(r.error))
end
__recordFiles = json.encode(out)
`;

test('record mode writes the same files under wasmoon as under desktop Lua', async () => {
  const { lua } = await createEngine({ extra: { 'tests/recorddriver': driver } });
  const wasm = JSON.parse(lua.global.get('__recordFiles'));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'recordgames-'));
  try {
    const run = spawnSync(process.env.LUA || 'lua5.4', ['tools/recordgames.lua', '--out', dir], { cwd: root, encoding: 'utf8' });
    assert.equal(run.status, 0, run.stderr);
    const names = Object.keys(wasm).sort();
    assert.ok(names.length >= 10, `${names.length} games`);
    for (const name of names) {
      const desktop = fs.readFileSync(path.join(dir, `record-${name}.txt`), 'utf8');
      assert.equal(wasm[name], desktop, name);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
