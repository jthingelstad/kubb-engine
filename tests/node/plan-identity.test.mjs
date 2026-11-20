// The short throw's plan under wasmoon (musl's libm, the reference platform), against
// the v0.8.1 implementation kept in tests/lua/planref.lua: the same dense sweep as
// tests/lua/test_plan_identity.lua, compared bit for bit. A patch release must keep
// every number the plan returns; this is the check on the platform the hashes use.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createEngine } from './wasm.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const planref = fs.readFileSync(path.join(here, '../lua/planref.lua'), 'utf8');

test('plan.solve, handAt, carry and speedForCarry equal v0.8.1 bit for bit under wasmoon', async () => {
  const e = await createEngine({ extra: { 'tests/lua/planref': planref } });
  const out = await e.lua.doString(`
    local cases, first = tw.planRef.sweep()
    return tostring(cases) .. "|" .. tostring(first)`);
  const [cases, first] = out.split('|');
  assert.ok(Number(cases) > 100000, `cases: ${cases}`);
  assert.equal(first, 'nil', 'first difference');
});
