// The play reference's checker (tools/refcheck.mjs): a correct small tree passes, and each
// rule in docs/reference/README.md fires on a tree that breaks only that rule.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { checkReference, enginePlays } from '../../tools/refcheck.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const sources = () => ({
  about: 'fixture',
  sources: {
    'kn-drill-2012': { title: 'Drill', url: 'https://example.com/drill', kind: 'article', status: 'observed', covers: ['inkast'] },
    'yt-Io-rxbSB3Ns': { title: 'Lesson', url: 'https://example.com/v', kind: 'lesson', status: 'found' },
    'owner-2026-11-21': { title: 'Jamie', kind: 'owner', status: 'found' },
    'web-old': { title: 'Old', url: 'https://example.com/old', kind: 'article', status: 'set-aside', note: 'thin',
      original: { sha256: 'a'.repeat(64), bytes: 120 } },
  },
});

const observation = (body = `| At | Who | Topic | What is said or shown | Mark |
| --- | --- | --- | --- | --- |
| \`p2.3\` | Joakim | inkast | throw deep | said |
| \`p2.9\` | Joakim | inkast | a picture of it \\| twice | shown |
`) => `---
source: kn-drill-2012
observed: 2026-11-21
method: read as laid out, all six pages
schema: 1
---

What it is.

${body}`;

const play = (fields = {}) => {
  const f = { When: 'a kubb stands deep.', Play: 'throw deep.', Why: 'it says so.',
    'Says who': 'kn-drill-2012#p2.3 (Joakim); kn-drill-2012#p2.9.', Basis: 'player, coach',
    Against: 'Q1', Engine: 'not modelled (0.11.0)', ...fields };
  return Object.entries(f).filter(([, v]) => v !== null).map(([k, v]) => `- **${k}:** ${v}`).join('\n');
};

const questions = `# Questions

## Q1: How deep is deep?

- **Status:** open. Ask Jamie.
- **Sides:** kn-drill-2012#p2.3 against nobody yet.
`;

// A fixture tree from a { relative path: content } map; objects are written as JSON.
function tree(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'refcheck-'));
  for (const [rel, content] of Object.entries(files)) {
    if (content === null) continue;
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), typeof content === 'string' ? content : JSON.stringify(content, null, 2) + '\n');
  }
  return dir;
}

const good = (over = {}) => ({
  'sources.json': sources(),
  'observations/kn-drill-2012.md': observation(),
  'plays/inkast.md': `# Inkast\n\nIntro.\n\n## inkast.deep: Throw deep what you cannot clear\n\n${play()}\n`,
  'QUESTIONS.md': questions,
  ...over,
});

// The problems of a tree, as "file:line: message" strings.
const run = (files) => checkReference(tree(files)).problems.map((p) => `${p.file}:${p.line}: ${p.msg}`);

// Exactly one problem, in `file`, whose message matches `re`.
function onlyProblem(files, file, re) {
  const got = run(files);
  assert.equal(got.length, 1, got.join('\n'));
  assert.ok(got[0].startsWith(file + ':'), got[0]);
  assert.match(got[0], re);
}

const withSource = (id, s) => { const j = sources(); j.sources[id] = s; return j; };
const changeSource = (id, change) => { const j = sources(); change(j.sources[id]); return j; };

test('a correct tree passes and is counted', () => {
  const { problems, counts } = checkReference(tree(good()));
  assert.deepEqual(problems, []);
  assert.deepEqual(counts, { sources: 4, observations: 1, entries: 2, plays: 1, questions: 1 });
});

// Without sources.json nothing else can be checked, so that one problem is the whole report.
test('the tree may not yet have plays or questions, but must have sources', () => {
  assert.deepEqual(run(good({ 'plays/inkast.md': null, 'QUESTIONS.md': null })), []);
  onlyProblem(good({ 'sources.json': null }), 'sources.json', /missing/);
});

test('sources.json must parse and hold a sources object', () => {
  onlyProblem(good({ 'sources.json': '{\n  "sources": {\n    oops\n  }\n}\n' }), 'sources.json', /does not parse/);
  onlyProblem({ 'sources.json': { sources: [] } }, 'sources.json', /"sources" object/);
});

test('a source id needs a known prefix and lower case, except a YouTube id', () => {
  const s = { title: 'x', url: 'https://example.com', kind: 'article', status: 'found' };
  onlyProblem(good({ 'sources.json': withSource('xx-thing', s) }), 'sources.json', /xx-thing: id/);
  onlyProblem(good({ 'sources.json': withSource('web-Thing', s) }), 'sources.json', /web-Thing: id/);
  onlyProblem(good({ 'sources.json': withSource('web-a b', s) }), 'sources.json', /id/);
});

test('a source needs a title, a known kind and a known status', () => {
  onlyProblem(good({ 'sources.json': changeSource('yt-Io-rxbSB3Ns', (s) => delete s.title) }), 'sources.json', /needs a title/);
  onlyProblem(good({ 'sources.json': changeSource('yt-Io-rxbSB3Ns', (s) => { s.kind = 'video'; }) }), 'sources.json', /kind "video"/);
  onlyProblem(good({ 'sources.json': changeSource('yt-Io-rxbSB3Ns', (s) => { s.status = 'read'; }) }), 'sources.json', /status "read"/);
});

test('a url is needed except for owner and book, and set-aside needs a note', () => {
  onlyProblem(good({ 'sources.json': changeSource('yt-Io-rxbSB3Ns', (s) => delete s.url) }), 'sources.json', /needs a url/);
  assert.deepEqual(run(good({ 'sources.json': withSource('web-book', { title: 'B', kind: 'book', status: 'found' }) })), []);
  onlyProblem(good({ 'sources.json': changeSource('web-old', (s) => delete s.note) }), 'sources.json', /set-aside and needs a note/);
});

test('covers names phases, and original has a sha256 and a size', () => {
  onlyProblem(good({ 'sources.json': changeSource('kn-drill-2012', (s) => { s.covers = ['inkast', 'tactics']; }) }), 'sources.json', /"tactics"/);
  onlyProblem(good({ 'sources.json': changeSource('kn-drill-2012', (s) => { s.covers = 'inkast'; }) }), 'sources.json', /covers must be an array/);
  onlyProblem(good({ 'sources.json': changeSource('web-old', (s) => { s.original.sha256 = 'abc'; }) }), 'sources.json', /sha256/);
  onlyProblem(good({ 'sources.json': changeSource('web-old', (s) => { s.original.bytes = 0; }) }), 'sources.json', /bytes/);
});

test('a source problem points at the line of its id', () => {
  const got = run(good({ 'sources.json': changeSource('web-old', (s) => delete s.note) }));
  const text = JSON.stringify(sources(), null, 2).split('\n');
  assert.equal(got[0], `sources.json:${text.findIndex((l) => l.includes('"web-old":')) + 1}: web-old: is set-aside and needs a note saying why`);
});

test('an observation needs its front matter, with a date and its own source', () => {
  const obs = observation();
  onlyProblem(good({ 'observations/kn-drill-2012.md': obs.replace('method: read as laid out, all six pages\n', '') }), 'observations/kn-drill-2012.md', /needs method/);
  onlyProblem(good({ 'observations/kn-drill-2012.md': obs.replace('2026-11-21', '21 Nov 2026') }), 'observations/kn-drill-2012.md', /YYYY-MM-DD/);
  onlyProblem(good({ 'observations/kn-drill-2012.md': obs.replace('source: kn-drill-2012', 'source: kn-other') }), 'observations/kn-drill-2012.md', /does not match the file name/);
  onlyProblem(good({ 'observations/kn-drill-2012.md': obs.replace(/^---\n/, '') }), 'observations/kn-drill-2012.md', /front matter/);
});

test('an observation and its source status agree both ways', () => {
  onlyProblem(good({ 'sources.json': changeSource('kn-drill-2012', (s) => { s.status = 'found'; }) }), 'observations/kn-drill-2012.md', /status .* is "found"/);
  onlyProblem(good({ 'sources.json': changeSource('yt-Io-rxbSB3Ns', (s) => { s.status = 'observed'; }) }), 'sources.json', /no observations\/yt-Io-rxbSB3Ns\.md/);
  const stray = observation().replace('source: kn-drill-2012', 'source: web-nobody');
  const got = run(good({ 'observations/web-nobody.md': stray }));
  assert.equal(got.length, 1, got.join('\n'));
  assert.match(got[0], /^observations\/web-nobody\.md:\d+: web-nobody is not in sources\.json/);
});

test('entries have unique, non-empty anchors and a known mark', () => {
  // the plays and questions cite p2.3 and p2.9; these trees leave them out
  const row = (r) => ({ 'plays/inkast.md': null, 'QUESTIONS.md': null,
    'observations/kn-drill-2012.md': observation(`| At | Who | Topic | What | Mark |\n| --- | --- | --- | --- | --- |\n| \`p1.1\` | a | b | c | said |\n${r}\n`) });
  onlyProblem(good(row('| `p1.1` | a | b | c | said |')), 'observations/kn-drill-2012.md', /p1\.1 is used twice/);
  onlyProblem(good(row('| `` | a | b | c | said |')), 'observations/kn-drill-2012.md', /no anchor/);
  onlyProblem(good(row('| `p1.2` | a | b | c | heard |')), 'observations/kn-drill-2012.md', /mark "heard"/);
});

test('an observation with no entries fails, and only At tables are entries', () => {
  const none = observation('| Who | What |\n| --- | --- |\n| a | b |\n');
  const got = run(good({ 'observations/kn-drill-2012.md': none, 'plays/inkast.md': null, 'QUESTIONS.md': null }));
  assert.equal(got.length, 1, got.join('\n'));
  assert.match(got[0], /has no entries/);
});

test('a citation must name a source, its observation and an entry in it', () => {
  const cite = (c) => good({ 'QUESTIONS.md': questions + `- **Also:** ${c}\n` });
  onlyProblem(cite('kn-missing#p1.'), 'QUESTIONS.md', /kn-missing is not in sources\.json/);
  onlyProblem(cite('yt-Io-rxbSB3Ns#1:30'), 'QUESTIONS.md', /has no observation file/);
  onlyProblem(cite('(kn-drill-2012#p9.9)'), 'QUESTIONS.md', /no entry p9\.9$/);
  // a URL's fragment is not a citation
  assert.deepEqual(run(cite('https://example.com/web-old#top')), []);
  // the punctuation of the sentence around a citation is not part of its anchor
  assert.deepEqual(run(cite('Is it so (kn-drill-2012#p2.3)? Or kn-drill-2012#p2.9: no!')), []);
});

test('a play key is <phase>.<word> for its file, and unique across files', () => {
  const p = `## inkast.deep: Throw deep\n\n${play()}\n`;
  onlyProblem(good({ 'plays/inkast.md': p.replace('inkast.deep', 'field.deep') }), 'plays/inkast.md', /key must be inkast\.<word>/);
  onlyProblem(good({ 'plays/field.md': p.replace('inkast.deep', 'field.deep'), 'plays/inkast.md': p + '\n' + p }), 'plays/inkast.md', /also used/);
  onlyProblem(good({ 'plays/tactics.md': p.replace('inkast.deep', 'tactics.deep') }), 'plays/tactics.md', /not a phase/);
});

test('a play needs every required field, each filled', () => {
  for (const field of ['When', 'Play', 'Says who', 'Basis', 'Engine'])
    onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ [field]: null })}\n` }), 'plays/inkast.md', new RegExp(`needs a - \\*\\*${field}:`));
  onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ Engine: '' })}\n` }), 'plays/inkast.md', /Engine is empty/);
});

test('Says who cites unless the basis is only estimate, and the basis words are known', () => {
  onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ 'Says who': 'nobody' })}\n` }), 'plays/inkast.md', /cites no observation/);
  assert.deepEqual(run(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ 'Says who': 'nobody', Basis: 'estimate' })}\n` })), []);
  onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ 'Says who': 'nobody', Basis: 'estimate, coach' })}\n` }), 'plays/inkast.md', /cites no observation/);
  onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ Basis: 'player hearsay' })}\n` }), 'plays/inkast.md', /basis "hearsay"/);
});

test('Against may name only questions that exist', () => {
  onlyProblem(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ Against: 'Q1, Q7' })}\n` }), 'plays/inkast.md', /Q7, which is not in QUESTIONS\.md/);
  assert.deepEqual(run(good({ 'plays/inkast.md': `## inkast.deep: T\n\n${play({ Against: 'nothing found' })}\n` })), []);
});

test('questions are numbered once and each has an open or answered status', () => {
  onlyProblem(good({ 'QUESTIONS.md': questions + '\n## Q1: Again\n\n- **Status:** answered\n' }), 'QUESTIONS.md', /Q1 is used twice/);
  onlyProblem(good({ 'QUESTIONS.md': questions.replace('- **Status:** open. Ask Jamie.\n', '') }), 'QUESTIONS.md', /needs a - \*\*Status:\*\*/);
  onlyProblem(good({ 'QUESTIONS.md': questions.replace('open. Ask', 'pending. Ask') }), 'QUESTIONS.md', /open or answered/);
});

test('the command prints problems and exits 1, or a summary and exits 0', () => {
  const tool = path.join(root, 'tools', 'refcheck.mjs');
  const ok = execFileSync(process.execPath, [tool, '--root', tree(good()), '--no-plays'], { encoding: 'utf8' });
  assert.match(ok, /^refcheck: 4 sources, 1 observations \(2 entries\), 1 plays, 1 questions; no problems/);
  // the real path, since the printed path is relative to the working directory
  const dir = fs.realpathSync(tree(good({ 'QUESTIONS.md': questions.replace('open. Ask', 'pending. Ask') })));
  try {
    execFileSync(process.execPath, [tool, '--root', dir, '--no-plays'], { encoding: 'utf8', cwd: dir });
    assert.fail('expected exit 1');
  } catch (e) {
    assert.equal(e.status, 1);
    assert.match(e.stdout, /^QUESTIONS\.md:5: Q1's status must start with open or answered\n$/);
  }
});

// core/plays.lua as the engine writes it, with these ids.
const playsLua = (...ids) => `local plays = {\n${ids.map((id) => `\t["${id}"] = {\n\t\tphase = "x",\n\t},`).join('\n')}\n}\n`;

test('every play core/plays.lua holds is a play in plays/', () => {
  const dir = tree(good());
  const file = path.join(dir, 'plays.lua');
  fs.writeFileSync(file, playsLua('inkast.deep'));
  assert.deepEqual(checkReference(dir, { playsLua: file }).problems, []);
  assert.equal(checkReference(dir, { playsLua: file }).counts.engine, 1);
  fs.writeFileSync(file, playsLua('inkast.deep', 'inkast.nowhere'));
  const got = checkReference(dir, { playsLua: file }).problems.map((p) => `${p.file}:${p.line}: ${p.msg}`);
  assert.deepEqual(got, ['core/plays.lua:5: inkast.nowhere is not a play in plays/']);
  fs.writeFileSync(file, 'local plays = {}\n');
  assert.match(checkReference(dir, { playsLua: file }).problems[0].msg, /holds no plays/);
  assert.match(checkReference(dir, { playsLua: path.join(dir, 'none.lua') }).problems[0].msg, /^missing/);
  // left out, the engine's plays are not read
  assert.deepEqual(checkReference(dir).problems, []);
});

test("the engine's own core/plays.lua names only plays that exist", () => {
  const ids = enginePlays(fs.readFileSync(path.join(root, 'core', 'plays.lua'), 'utf8')).map((p) => p.id);
  assert.ok(ids.length > 0);
  const { problems } = checkReference(path.join(root, 'docs', 'reference'), { playsLua: path.join(root, 'core', 'plays.lua') });
  assert.deepEqual(problems, []);
  const out = execFileSync(process.execPath, [path.join(root, 'tools', 'refcheck.mjs')], { encoding: 'utf8' });
  assert.match(out, new RegExp(`; ${ids.length} played by the engine; no problems`));
});
