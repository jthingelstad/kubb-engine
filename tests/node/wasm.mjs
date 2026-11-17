// The engine under wasmoon (Lua 5.4 built to wasm with musl's libm: the reference
// platform, docs/DETERMINISM.md), loaded from the bundle as a client loads it: an
// `import` shim over the module map, then the API's one door, kubbCall.
import { LuaFactory } from 'wasmoon';
import { bundleLua } from '../../tools/bundle.mjs';

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

// A fresh Lua state with the engine loaded. call(method, args) goes through kubbCall
// as JSON text and throws on {"error": ...}; text(method, argText) is the raw door.
// extra: more modules { name: source } to put beside the engine's and import (a test
// driver).
export async function createEngine({ sources = bundleLua(), extra = {} } = {}) {
  const all = { ...sources, ...extra };
  const lua = await new LuaFactory().createEngine();
  // undefined, not null, for a missing module: wasmoon turns it into nil
  lua.global.set('__kubbSource', (name) => (Object.hasOwn(all, name) ? all[name] : undefined));
  await lua.doString(BOOT);
  for (const name of Object.keys(extra)) await lua.doString(`import "${name}"`);
  const kubbCall = lua.global.get('kubbCall');
  const text = (method, argText = '') => kubbCall(method, argText);
  const call = (method, args) => {
    const out = JSON.parse(text(method, args === undefined ? '' : JSON.stringify(args)));
    if (out && typeof out === 'object' && !Array.isArray(out) && 'error' in out) throw new Error(`${method}: ${out.error}`);
    return out;
  };
  return { lua, call, text };
}
