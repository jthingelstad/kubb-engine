// engine.json: the engine's name and version, where its parts came from, a sha256 for
// every engine Lua file (core/, pitch/, session/, tune/ and version.lua, keyed by their path
// from the repository root) and the sha256 of the bundle tools/bundle.mjs writes.
// Clients vendor a tagged release byte for byte and check their copy against these.
//   node tools/manifest.mjs write   rewrite the hashes (name, version and sources kept)
//   node tools/manifest.mjs check   fail if a file, the bundle or version.lua disagrees
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { root, engineFiles, bundleText } from './bundle.mjs';

const manifestPath = path.join(root, 'engine.json');
const sha = (f) => createHash('sha256').update(fs.readFileSync(path.join(root, f))).digest('hex');
const hashes = () => Object.fromEntries(engineFiles().map((f) => [f, sha(f)]));
const read = () => JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const luaVersion = () => {
  const m = fs.readFileSync(path.join(root, 'version.lua'), 'utf8').match(/local VERSION <const> = "([^"]+)"/);
  return m && m[1];
};

const mode = process.argv[2];
if (mode === 'write') {
  const m = read();
  m.files = hashes();
  m.bundle = { sha256: bundleText().sha256 };
  fs.writeFileSync(manifestPath, JSON.stringify(m, null, 2) + '\n');
  console.log(`engine.json: ${Object.keys(m.files).length} files hashed, bundle ${m.bundle.sha256}`);
} else if (mode === 'check') {
  const m = read();
  const want = m.files || {};
  const have = hashes();
  const bad = [];
  for (const f of Object.keys(want)) if (!(f in have)) bad.push(`${f} is in engine.json but not in the engine`);
  for (const f of Object.keys(have)) {
    if (!(f in want)) bad.push(`${f} is in the engine but not in engine.json`);
    else if (want[f] !== have[f]) bad.push(`${f} does not match its hash`);
  }
  if (!m.bundle || m.bundle.sha256 !== bundleText().sha256) bad.push('the bundle does not match its hash');
  if (luaVersion() !== m.version) bad.push(`version.lua says ${luaVersion()}, engine.json ${m.version}`);
  if (!/^\d+\.\d+\.\d+$/.test(m.version || '')) bad.push(`version ${m.version} is not major.minor.patch`);
  if (bad.length) {
    console.error('engine.json does not match the engine (run node tools/manifest.mjs write if the change is intended):\n  ' + bad.join('\n  '));
    process.exit(1);
  }
  console.log(`engine.json matches the engine (${m.name} ${m.version}, ${Object.keys(have).length} files and the bundle)`);
} else {
  console.error('usage: node tools/manifest.mjs write | check');
  process.exit(2);
}
