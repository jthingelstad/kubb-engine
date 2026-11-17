// The engine as one artifact: every engine Lua source in one JSON file, the module
// map { "core/world": "<source>", "session/api": "<source>", "tune/pointer": "<source>",
// "version": "<source>" }, keys sorted and no whitespace, so the same sources always
// give the same bytes. A client loads it behind its `import` shim (docs/SESSION.md
// "Loading") and checks it against the sha256 beside it and in engine.json.
//
//   node tools/bundle.mjs [--out build/kubb-engine-sources.json]
//
// Writes the file and <file>.sha256 ("<hex>  <name>\n", as shasum prints it).
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// The engine's Lua: these folders' *.lua files and version.lua. Module names are
// the paths without ".lua", as `import` takes them.
export const DIRS = ['core', 'session', 'tune'];
export const TOP = ['version.lua'];

// Every engine Lua file as a path from the repository root, sorted.
export function engineFiles() {
  const files = [...TOP];
  for (const dir of DIRS) {
    for (const f of fs.readdirSync(path.join(root, dir))) if (f.endsWith('.lua')) files.push(`${dir}/${f}`);
  }
  return files.sort();
}

// The module map, keys sorted.
export function bundleLua() {
  const out = {};
  for (const f of engineFiles()) out[f.slice(0, -4)] = fs.readFileSync(path.join(root, f), 'utf8');
  return out;
}

// The bundle's bytes and their sha256.
export function bundleText() {
  const text = JSON.stringify(bundleLua());
  return { text, sha256: createHash('sha256').update(text, 'utf8').digest('hex') };
}

function main() {
  let outFile = 'build/kubb-engine-sources.json';
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--out') outFile = args[++i];
    else throw new Error(`unknown argument ${args[i]}`);
  }
  const { text, sha256 } = bundleText();
  const target = path.resolve(root, outFile);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, text);
  fs.writeFileSync(`${target}.sha256`, `${sha256}  ${path.basename(target)}\n`);
  console.log(`bundle: ${Object.keys(JSON.parse(text)).length} modules, ${Buffer.byteLength(text)} bytes, sha256 ${sha256} -> ${outFile}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
