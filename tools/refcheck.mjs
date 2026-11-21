// The play reference's checker (docs/reference/README.md is its specification): that
// sources.json, the observations, the plays and QUESTIONS.md keep the rules between them,
// so a play cannot cite an entry that is not there and an observed source cannot lack its
// observation; and that every play the computer player carries out (core/plays.lua) is a
// play here. It reads the tree and changes nothing.
//   node tools/refcheck.mjs [--root <dir>] [--plays <file>|--no-plays]
//   default: docs/reference and core/plays.lua beside this script
// Prints one `<file>:<line>: <problem>` per problem and exits 1, or a one-line summary.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// The README's lists. They are written out here, not parsed from the README, so a wording
// change there cannot quietly loosen the check; change both together.
const PREFIXES = ['yt', 'kn', 'ko', 'pk', 'pod', 'web', 'owner', 'games'];
const KINDS = ['lesson', 'interviews', 'article', 'match', 'podcast', 'data', 'rules', 'book', 'owner'];
const NO_URL_KINDS = ['owner', 'book'];
const STATUSES = ['found', 'observed', 'set-aside'];
const PHASES = ['inkast', 'field', 'baseline', 'king', 'raise', 'punish', 'rules', 'practice', 'surface', 'levels'];
const MARKS = ['said', 'shown', 'points', 'inferred', 'unclear'];
const BASES = ['measured', 'owner', 'player', 'coach', 'estimate'];
const FRONT_KEYS = ['source', 'observed', 'method', 'schema'];
const PLAY_FIELDS = ['When', 'Play', 'Says who', 'Basis', 'Engine'];

// A YouTube video id keeps its case, so only yt- may carry capitals after the prefix.
const ID_RE = new RegExp(`^(${PREFIXES.join('|')})-[A-Za-z0-9_-]+$`);
const idOk = (id) => ID_RE.test(id) && (id.startsWith('yt-') || id === id.toLowerCase());

// A citation is `<source id>#<anchor>`. The look-behind keeps a URL's fragment
// (https://example.com/web-page#top) from reading as one.
const CITE_RE = new RegExp(`(?<![\\w/.#-])((?:${PREFIXES.join('|')})-[A-Za-z0-9_-]+)#([^\\s\`|<>\\[\\]]+)`, 'g');
// An anchor never ends in punctuation, so whatever sentence punctuation follows one is dropped.
const citationsIn = (text) => [...text.matchAll(CITE_RE)].map((m) => ({ id: m[1], anchor: m[2].replace(/[.,;:)?!]+$/, '') }));

const read = (f) => (fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : null);
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const filled = (v) => typeof v === 'string' && v.trim() !== '';

// Lines outside fenced code: a heading or table shown as an example in a fence is not one.
function bodyLines(text) {
  const out = [];
  let fence = false;
  text.split('\n').forEach((line, i) => {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; return; }
    if (!fence) out.push({ n: i + 1, line });
  });
  return out;
}

// A table row's cells, with `\|` kept as a literal bar inside a cell.
function cells(line) {
  let s = line.trim();
  if (s.startsWith('|')) s = s.slice(1);
  if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1);
  return s.split(/(?<!\\)\|/).map((c) => c.replace(/\\\|/g, '|').trim());
}
const unticked = (s) => s.replace(/`/g, '').trim();

// `## <head>` sections: each with its heading line and the lines up to the next heading
// of level one or two.
function sections(text, headRe) {
  const out = [];
  let cur = null;
  for (const { n, line } of bodyLines(text)) {
    if (/^#{1,2}\s/.test(line)) {
      cur = null;
      const m = line.match(headRe);
      if (m) out.push((cur = { n, m, lines: [] }));
    } else if (cur) cur.lines.push({ n, line });
  }
  return out;
}

// `- **Name:** value` bullets, a value running on over indented lines that start no bullet.
function bullets(lines) {
  const out = {};
  let cur = null;
  for (const { n, line } of lines) {
    const m = line.match(/^\s*[-*]\s+\*\*([^*]+?):\*\*\s*(.*)$/);
    if (m) {
      cur = { n, value: m[2] };
      if (!(m[1] in out)) out[m[1]] = cur;
    } else if (cur && /^\s+\S/.test(line) && !/^\s*[-*]\s/.test(line)) cur.value += ' ' + line.trim();
    else cur = null;
  }
  return out;
}

// The line a JSON key first appears on, for pointing at a source in sources.json.
function keyLine(text, key, from = 0) {
  const lines = text.split('\n');
  const want = JSON.stringify(key);
  for (let i = from; i < lines.length; i++) {
    const at = lines[i].indexOf(want);
    if (at >= 0 && /^\s*:/.test(lines[i].slice(at + want.length))) return i + 1;
  }
  return 1;
}

// The play ids core/plays.lua holds: its `["<id>"] = {` keys, with their lines.
export function enginePlays(text) {
  const out = [];
  text.split('\n').forEach((line, i) => {
    const m = line.match(/^\s*\[\s*"([^"]+)"\s*\]\s*=\s*\{/);
    if (m) out.push({ id: m[1], line: i + 1 });
  });
  return out;
}

// opts.playsLua: core/plays.lua's path (its problems are reported against `core/plays.lua`);
// left out, the engine's plays are not checked.
export function checkReference(root, opts = {}) {
  const problems = [];
  const bad = (file, line, msg) => problems.push({ file, line, msg });
  const counts = { sources: 0, observations: 0, entries: 0, plays: 0, questions: 0 };

  // sources.json
  const SJ = 'sources.json';
  const sjText = read(path.join(root, SJ));
  let sources = {};
  if (sjText === null) bad(SJ, 1, 'missing: the reference needs its sources');
  else {
    let doc = null;
    try {
      doc = JSON.parse(sjText);
    } catch (e) {
      const pos = Number((e.message.match(/position (\d+)/) || [])[1]);
      const line = Number.isFinite(pos) ? sjText.slice(0, pos).split('\n').length : 1;
      bad(SJ, line, `does not parse: ${e.message}`);
    }
    if (doc !== null) {
      if (!isObj(doc) || !isObj(doc.sources)) bad(SJ, 1, 'must be an object with a "sources" object keyed by id');
      else sources = doc.sources;
    }
  }
  // Every other layer is checked against the sources; without them each citation and
  // observation would fail for the same one reason, so that reason is the whole report.
  if (problems.length) return { problems, counts };
  const from = Math.max(0, keyLine(sjText, 'sources') - 1);
  for (const [id, s] of Object.entries(sources)) {
    counts.sources++;
    const ln = keyLine(sjText, id, from);
    const say = (msg) => bad(SJ, ln, `${id}: ${msg}`);
    if (!idOk(id)) say(`id is not <prefix>-<name> in lower case with a prefix from the README (${PREFIXES.join(', ')})`);
    if (!isObj(s)) { say('must be an object'); continue; }
    if (!filled(s.title)) say('needs a title');
    if (!KINDS.includes(s.kind)) say(`kind ${JSON.stringify(s.kind)} is not one of ${KINDS.join(', ')}`);
    if (!STATUSES.includes(s.status)) say(`status ${JSON.stringify(s.status)} is not one of ${STATUSES.join(', ')}`);
    if (!NO_URL_KINDS.includes(s.kind) && !filled(s.url)) say('needs a url (only owner and book may go without)');
    if (s.status === 'set-aside' && !filled(s.note)) say('is set-aside and needs a note saying why');
    if (s.covers !== undefined) {
      if (!Array.isArray(s.covers)) say('covers must be an array of phases');
      else for (const c of s.covers) if (!PHASES.includes(c)) say(`covers ${JSON.stringify(c)}, which is not a phase (${PHASES.join(', ')})`);
    }
    if (s.original !== undefined) {
      const o = s.original;
      if (!isObj(o)) say('original must be { "sha256": ..., "bytes": ... }');
      else {
        if (typeof o.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(o.sha256)) say('original.sha256 must be 64 lower-case hex digits');
        if (!Number.isInteger(o.bytes) || o.bytes <= 0) say('original.bytes must be a positive integer');
      }
    }
  }

  // observations/<id>.md: front matter, then entry tables. anchors[id] is the set a citation may name.
  const anchors = {};
  const obsDir = path.join(root, 'observations');
  const obsFiles = fs.existsSync(obsDir) ? fs.readdirSync(obsDir).filter((f) => f.endsWith('.md')).sort() : [];
  for (const f of obsFiles) {
    counts.observations++;
    const rel = `observations/${f}`;
    const id = f.slice(0, -3);
    const text = fs.readFileSync(path.join(obsDir, f), 'utf8');
    const lines = text.split('\n');
    const seen = (anchors[id] = new Set());

    const front = {};
    const frontLine = {};
    let bodyStart = 0;
    if (lines[0].trim() !== '---') bad(rel, 1, 'needs front matter between --- lines');
    else {
      const end = lines.findIndex((l, i) => i > 0 && l.trim() === '---');
      if (end < 0) bad(rel, 1, 'front matter is not closed with ---');
      else {
        bodyStart = end + 1;
        for (let i = 1; i < end; i++) {
          const m = lines[i].match(/^([A-Za-z_]+):\s*(.*)$/);
          if (m) { front[m[1]] = m[2].trim(); frontLine[m[1]] = i + 1; }
        }
        for (const k of FRONT_KEYS) if (!filled(front[k])) bad(rel, 1, `front matter needs ${k}`);
        if (filled(front.observed) && !/^\d{4}-\d{2}-\d{2}$/.test(front.observed))
          bad(rel, frontLine.observed, `observed ${front.observed} is not YYYY-MM-DD`);
        if (filled(front.source) && front.source !== id)
          bad(rel, frontLine.source, `source ${front.source} does not match the file name (${id})`);
      }
    }
    if (!(id in sources)) bad(rel, frontLine.source || 1, `${id} is not in sources.json`);
    else if (isObj(sources[id]) && sources[id].status !== 'observed')
      bad(rel, frontLine.source || 1, `${id} has an observation but its status in sources.json is ${JSON.stringify(sources[id].status)}, not "observed"`);

    // An entry table is one whose header's first cell is At; its rows run to the first
    // line that is not a table row.
    let rows = 0;
    let inTable = false;
    let afterHeader = false;
    for (const { n, line } of bodyLines(lines.slice(bodyStart).join('\n')).map((x) => ({ ...x, n: x.n + bodyStart }))) {
      const isRow = line.trim().startsWith('|');
      if (!isRow) { inTable = false; continue; }
      const c = cells(line);
      if (!inTable) {
        if (unticked(c[0]) === 'At') { inTable = true; afterHeader = true; }
        continue;
      }
      if (afterHeader) { afterHeader = false; if (c.every((x) => /^:?-+:?$/.test(x))) continue; }
      rows++;
      const anchor = unticked(c[0]);
      if (!anchor) bad(rel, n, 'entry has no anchor in its At cell');
      else if (seen.has(anchor)) bad(rel, n, `anchor ${anchor} is used twice`);
      else seen.add(anchor);
      const mark = unticked(c[c.length - 1]);
      if (!MARKS.includes(mark)) bad(rel, n, `mark ${JSON.stringify(mark)} is not one of ${MARKS.join(', ')}`);
    }
    counts.entries += rows;
    if (rows === 0) bad(rel, bodyStart + 1, 'has no entries (a table whose first column is At)');
  }
  const obsIds = new Set(obsFiles.map((f) => f.slice(0, -3)));
  for (const [id, s] of Object.entries(sources))
    if (isObj(s) && s.status === 'observed' && !obsIds.has(id))
      bad(SJ, keyLine(sjText, id, from), `${id} is observed but has no observations/${id}.md`);

  // Every citation in the plays and the questions names an entry that exists.
  const checkCitations = (rel, text) => {
    text.split('\n').forEach((line, i) => {
      for (const { id, anchor } of citationsIn(line)) {
        if (!(id in sources)) bad(rel, i + 1, `cites ${id}#${anchor}, but ${id} is not in sources.json`);
        else if (!anchors[id]) bad(rel, i + 1, `cites ${id}#${anchor}, but ${id} has no observation file`);
        else if (!anchors[id].has(anchor)) bad(rel, i + 1, `cites ${id}#${anchor}, but observations/${id}.md has no entry ${anchor}`);
      }
    });
  };

  // QUESTIONS.md, read before the plays so their Against lines can be checked.
  const QF = 'QUESTIONS.md';
  const qText = read(path.join(root, QF));
  const questions = new Set();
  if (qText !== null) {
    for (const sec of sections(qText, /^##\s+Q(\d+):\s*(.*)$/)) {
      counts.questions++;
      const num = Number(sec.m[1]);
      if (questions.has(num)) bad(QF, sec.n, `Q${num} is used twice`);
      questions.add(num);
      if (!sec.m[2].trim()) bad(QF, sec.n, `Q${num} has no title`);
      const status = bullets(sec.lines).Status;
      if (!status) bad(QF, sec.n, `Q${num} needs a - **Status:** line`);
      else if (!/^(open|answered)\b/.test(status.value.trim()))
        bad(QF, status.n, `Q${num}'s status must start with open or answered`);
    }
    checkCitations(QF, qText);
  }

  // plays/<phase>.md
  const playDir = path.join(root, 'plays');
  const playFiles = fs.existsSync(playDir) ? fs.readdirSync(playDir).filter((f) => f.endsWith('.md')).sort() : [];
  const keys = new Map();
  for (const f of playFiles) {
    const rel = `plays/${f}`;
    const phase = f.slice(0, -3);
    const text = fs.readFileSync(path.join(playDir, f), 'utf8');
    if (!PHASES.includes(phase)) bad(rel, 1, `${phase} is not a phase (${PHASES.join(', ')})`);
    for (const sec of sections(text, /^##\s+([^\s:]+):\s*(.*)$/)) {
      counts.plays++;
      const key = sec.m[1];
      const say = (n, msg) => bad(rel, n, `${key}: ${msg}`);
      if (!new RegExp(`^${phase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\.[a-z0-9_-]+$`).test(key))
        say(sec.n, `key must be ${phase}.<word>, lower case, matching the file`);
      if (keys.has(key)) say(sec.n, `key is also used in ${keys.get(key)}`);
      else keys.set(key, `${rel}:${sec.n}`);
      if (!sec.m[2].trim()) say(sec.n, 'has no title');
      const b = bullets(sec.lines);
      for (const field of PLAY_FIELDS) {
        if (!b[field]) say(sec.n, `needs a - **${field}:** line`);
        else if (!b[field].value.trim()) say(b[field].n, `${field} is empty`);
      }
      const basis = b.Basis ? b.Basis.value.trim() : '';
      if (b.Basis) for (const w of basis.split(/[\s,]+/).filter(Boolean))
        if (!BASES.includes(w)) say(b.Basis.n, `basis ${JSON.stringify(w)} is not one of ${BASES.join(', ')}`);
      if (b['Says who'] && basis !== 'estimate' && citationsIn(b['Says who'].value).length === 0)
        say(b['Says who'].n, 'Says who cites no observation (<source id>#<anchor>); a claim with none has Basis estimate');
      if (b.Against) for (const m of b.Against.value.matchAll(/\bQ(\d+)\b/g))
        if (!questions.has(Number(m[1]))) say(b.Against.n, `Against names Q${m[1]}, which is not in QUESTIONS.md`);
    }
    checkCitations(rel, text);
  }

  // core/plays.lua: every play the computer carries out is a play here.
  if (opts.playsLua) {
    const PL = 'core/plays.lua';
    const plText = read(opts.playsLua);
    if (plText === null) bad(PL, 1, `missing: ${opts.playsLua}`);
    else {
      const ids = enginePlays(plText);
      if (ids.length === 0) bad(PL, 1, 'holds no plays (no ["<id>"] = { entries)');
      for (const { id, line } of ids) {
        counts.engine = (counts.engine || 0) + 1;
        if (!keys.has(id)) bad(PL, line, `${id} is not a play in plays/`);
      }
    }
  }

  problems.sort((a, b) => (a.file < b.file ? -1 : a.file > b.file ? 1 : a.line - b.line));
  return { problems, counts };
}

function main() {
  const args = process.argv.slice(2);
  let root = path.join(repo, 'docs', 'reference');
  let playsLua = path.join(repo, 'core', 'plays.lua');
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--root' && args[i + 1]) root = path.resolve(args[++i]);
    else if (args[i] === '--plays' && args[i + 1]) playsLua = path.resolve(args[++i]);
    else if (args[i] === '--no-plays') playsLua = null;
    else { console.error('usage: node tools/refcheck.mjs [--root <dir>] [--plays <file>|--no-plays]'); process.exit(2); }
  }
  const { problems, counts } = checkReference(root, { playsLua });
  // Paths relative to where it was run, so an editor can open them from the terminal; the
  // engine's plays file is reported where it is.
  const where = (f) => (f === 'core/plays.lua' ? playsLua : path.join(root, f));
  for (const p of problems) console.log(`${path.relative(process.cwd(), where(p.file))}:${p.line}: ${p.msg}`);
  if (problems.length) process.exit(1);
  const c = counts;
  const engine = playsLua ? `; ${c.engine || 0} played by the engine` : '';
  console.log(`refcheck: ${c.sources} sources, ${c.observations} observations (${c.entries} entries), ${c.plays} plays, ${c.questions} questions${engine}; no problems`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
