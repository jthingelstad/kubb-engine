// The golden hashes (docs/DETERMINISM.md): tests/golden/drive.lua's matches played
// under wasmoon, the reference platform, with the hash after every action.
//   node tests/golden/golden.mjs --check            fail unless they match hashes.json exactly
//   node tests/golden/golden.mjs --write            rewrite hashes.json (`make golden`: deliberate)
//   node tests/golden/golden.mjs --compare <file>   how many actions another run (native.lua) agrees on
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createEngine } from '../node/wasm.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpusPath = path.join(here, 'hashes.json');

export async function playAll() {
  const drive = fs.readFileSync(path.join(here, 'drive.lua'), 'utf8');
  const e = await createEngine({ extra: { 'tests/golden/drive': drive } });
  const version = e.call('engineVersion').version;
  const json = await e.lua.doString(`
    local out = {}
    for i, m in ipairs(tw.golden.matches()) do out[i] = tw.golden.play(m) end
    return tw.web.json.encode({ matches = out })`);
  return { version, tune: 'pointer', ...JSON.parse(json) };
}

// The first difference between two corpora, and how many actions agree.
export function compare(want, have) {
  let actions = 0, agree = 0, prefix = 0, first = null;
  const n = Math.max(want.matches.length, have.matches.length);
  for (let i = 0; i < n; i++) {
    const w = want.matches[i], h = have.matches[i];
    if (!w || !h) { first ??= `match ${i + 1} is in one corpus only`; continue; }
    if (w.start !== h.start) first ??= `${w.name}: the starting hash`;
    const len = Math.max(w.actions.length, h.actions.length);
    let together = w.start === h.start;
    for (let j = 0; j < len; j++) {
      actions++;
      const same = w.actions[j] && h.actions[j] && w.actions[j].hash === h.actions[j].hash && w.actions[j].type === h.actions[j].type;
      if (same) agree++;
      else first ??= `${w.name}: action ${j + 1}`;
      together = together && same;
      if (together) prefix++;
    }
  }
  return { actions, agree, prefix, first };
}

// One action a line, so a diff of the corpus shows where a change moved the hashes.
function format(corpus) {
  const { matches, ...head } = corpus;
  const lines = Object.entries(head).map(([k, v]) => `  ${JSON.stringify(k)}: ${JSON.stringify(v)},`);
  const ms = matches.map((m) => {
    const { actions, ...rest } = m;
    const acts = actions.map((a) => `      ${JSON.stringify(a)}`).join(',\n');
    return `    {\n      ${JSON.stringify(rest).slice(1, -1)},\n      "actions": [\n${acts.replace(/^      /gm, '        ')}\n      ]\n    }`;
  });
  return `{\n${lines.join('\n')}\n  "matches": [\n${ms.join(',\n')}\n  ]\n}\n`;
}

async function main() {
  const [mode, file] = process.argv.slice(2);
  if (mode === '--compare') {
    const want = JSON.parse(fs.readFileSync(corpusPath, 'utf8'));
    const r = compare(want, JSON.parse(fs.readFileSync(file, 'utf8')));
    console.log(`${r.agree} of ${r.actions} actions agree (${r.prefix} before each match first differs)${r.first ? `; first difference: ${r.first}` : ''}`);
    return;
  }
  const t0 = performance.now();
  const corpus = await playAll();
  const secs = ((performance.now() - t0) / 1000).toFixed(1);
  const total = corpus.matches.reduce((s, m) => s + m.actions.length, 0);
  if (mode === '--write') {
    fs.writeFileSync(corpusPath, format(corpus));
    console.log(`golden: wrote ${corpus.matches.length} matches, ${total} actions (${secs} s)`);
  } else if (mode === '--check') {
    const want = JSON.parse(fs.readFileSync(corpusPath, 'utf8'));
    const r = compare(want, corpus);
    if (r.first || r.actions !== r.agree) {
      console.error(`golden: ${r.agree} of ${r.actions} actions agree; first difference: ${r.first}.\n` +
        'This change is not hash-neutral: it needs a minor version bump and `make golden` (docs/VERSIONING.md).');
      process.exit(1);
    }
    console.log(`golden: ${corpus.matches.length} matches, ${total} actions, every hash as recorded (${secs} s)`);
  } else {
    console.error('usage: node tests/golden/golden.mjs --check | --write | --compare <file>');
    process.exit(2);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
