// engine.json: the engine's name, version, the playdate-kubb commit it was
// extracted from, and a sha256 for every core/*.lua file. Clients vendor
// core/ byte for byte and can check their copy against these hashes.
//   node tools/manifest.mjs write   rewrite the hashes from core/ (name, version and source kept)
//   node tools/manifest.mjs check   fail if core/ differs from engine.json
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const coreDir = path.join(root, 'core');
const manifestPath = path.join(root, 'engine.json');
const sha = (f) => createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const coreFiles = () => fs.readdirSync(coreDir).filter((f) => f.endsWith('.lua')).sort();
const hashes = () => Object.fromEntries(coreFiles().map((f) => [f, sha(path.join(coreDir, f))]));
const read = () => JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

const mode = process.argv[2];
if (mode === 'write') {
  const m = read();
  m.files = hashes();
  fs.writeFileSync(manifestPath, JSON.stringify(m, null, 2) + '\n');
  console.log(`engine.json: ${Object.keys(m.files).length} core files hashed`);
} else if (mode === 'check') {
  const m = read();
  const want = m.files || {};
  const have = hashes();
  const bad = [];
  for (const f of Object.keys(want)) if (!(f in have)) bad.push(`${f} is in engine.json but not in core/`);
  for (const f of Object.keys(have)) {
    if (!(f in want)) bad.push(`${f} is in core/ but not in engine.json`);
    else if (want[f] !== have[f]) bad.push(`${f} does not match its hash`);
  }
  if (bad.length) {
    console.error('engine.json does not match core/ (run node tools/manifest.mjs write if the change is intended):\n  ' + bad.join('\n  '));
    process.exit(1);
  }
  console.log(`engine.json matches core/ (${m.name} ${m.version}, ${Object.keys(have).length} files)`);
} else {
  console.error('usage: node tools/manifest.mjs write | check');
  process.exit(2);
}
