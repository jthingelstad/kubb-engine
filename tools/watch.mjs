// Has a video model watch a public YouTube video about kubb and keeps its answer, for a
// person to write an observation from (docs/reference/README.md, "Taking in a source").
// The answer is raw material: other people's video, a model's account of it. It is saved
// privately, outside the repository, and never committed; the observation is written by
// hand from it.
//   node tools/watch.mjs <youtube url or id> --kind lesson|match|talk
//                        [--model <name>] [--out <dir>] [--force] [--transcript] [--fps <n>]
//   default out: $KUBB_SOURCES/video, else ../kubb-sources/video beside the repository
// Writes, per call, <id>.<model>.<prompt version>.md (the answer) and .json (the video,
// model, prompt file, its version and sha256, the date, the usage), and the raw response
// as .response.json. --transcript makes a second call with prompts/transcript-v1.txt.
// A call already made with the same prompt version and model is skipped unless --force.
// The key is read from GEMINI_API_KEY and used only as a request header; nothing here
// prints, stores or logs it.
// Exit codes: 0 done or skipped, 1 HTTP or service error, 2 usage or setup (no key, out
// inside the repository), 3 rate limit or model busy (stopped, nothing retried), 4 a
// response with no text.
import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(here, '..');
export const PROMPTS = path.join(here, 'watch', 'prompts');
export const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions';
export const DEFAULT_MODEL = 'gemini-4-hydrogen';
export const KINDS = ['lesson', 'match', 'talk'];
// The prompt version each kind uses now. A new version is a new file; old ones stay, so
// an answer's .json always names a prompt that can still be read.
export const PROMPT_FOR = { lesson: 'lesson-v1', match: 'match-v1', talk: 'talk-v1', transcript: 'transcript-v1' };
// A nine-minute video took about three minutes; a long one may take far longer.
const TIMEOUT_MS = 30 * 60 * 1000;

export class WatchError extends Error {
  constructor(message, code) { super(message); this.code = code; }
}

const USAGE = 'usage: node tools/watch.mjs <youtube url or id> --kind lesson|match|talk [--model <name>] [--out <dir>] [--force] [--transcript] [--fps <n>]';

// A YouTube video id from a watch, short, shorts or embed link, a bare id, or our yt-<id>.
export function videoId(arg) {
  const s = String(arg || '').trim();
  const ok = (id) => (/^[A-Za-z0-9_-]{11}$/.test(id) ? id : null);
  if (/^yt-/.test(s)) return ok(s.slice(3));
  if (ok(s)) return s;
  let u;
  try { u = new URL(s); } catch { return null; }
  const host = u.hostname.replace(/^(www|m|music)\./, '');
  if (host === 'youtu.be') return ok(u.pathname.slice(1).split('/')[0]);
  if (host === 'youtube.com' || host === 'youtube-nocookie.com') {
    if (u.searchParams.get('v')) return ok(u.searchParams.get('v'));
    const m = u.pathname.match(/^\/(?:shorts|embed|live|v)\/([^/]+)/);
    if (m) return ok(m[1]);
  }
  return null;
}

export function parseArgs(argv) {
  const o = { force: false, transcript: false, model: DEFAULT_MODEL };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const val = () => {
      if (i + 1 >= argv.length) throw new WatchError(`${a} needs a value\n${USAGE}`, 2);
      return argv[++i];
    };
    if (a === '--kind') o.kind = val();
    else if (a === '--model') o.model = val();
    else if (a === '--out') o.out = val();
    else if (a === '--fps') o.fps = Number(val());
    else if (a === '--force') o.force = true;
    else if (a === '--transcript') o.transcript = true;
    else if (a.startsWith('--')) throw new WatchError(`unknown option ${a}\n${USAGE}`, 2);
    else if (o.video === undefined) o.video = a;
    else throw new WatchError(`one video at a time\n${USAGE}`, 2);
  }
  if (o.video === undefined) throw new WatchError(USAGE, 2);
  o.id = videoId(o.video);
  if (!o.id) throw new WatchError(`not a YouTube link or video id: ${o.video}`, 2);
  if (!KINDS.includes(o.kind)) throw new WatchError(`--kind must be one of ${KINDS.join(', ')}\n${USAGE}`, 2);
  if (!/^[A-Za-z0-9._-]+$/.test(o.model)) throw new WatchError(`not a model name: ${o.model}`, 2);
  if (o.fps !== undefined && !(o.fps > 0 && o.fps <= 24)) throw new WatchError('--fps must be above 0 and at most 24', 2);
  return o;
}

// The real path of p, or of its nearest existing ancestor with the rest appended, so a
// symlink cannot carry an output folder into the repository unseen.
function realish(p) {
  const abs = path.resolve(p);
  let head = abs;
  const tail = [];
  while (!fs.existsSync(head)) {
    const up = path.dirname(head);
    if (up === head) break;
    tail.unshift(path.basename(head));
    head = up;
  }
  return path.join(fs.realpathSync(head), ...tail);
}

export function isInside(child, parent) {
  const rel = path.relative(realish(parent), realish(child));
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

export function outDir(opts, env = process.env, repo = REPO) {
  const dir = opts.out ? path.resolve(opts.out)
    : env.KUBB_SOURCES ? path.join(path.resolve(env.KUBB_SOURCES), 'video')
    : path.join(path.dirname(repo), 'kubb-sources', 'video');
  if (isInside(dir, repo))
    throw new WatchError(`refusing to write inside the repository (${dir}): model answers and transcripts are kept privately, outside it. Pass --out or set KUBB_SOURCES.`, 2);
  return dir;
}

export function readPrompt(version, dir = PROMPTS) {
  const file = path.join(dir, `${version}.txt`);
  if (!fs.existsSync(file)) throw new WatchError(`no prompt ${file}`, 2);
  const text = fs.readFileSync(file, 'utf8');
  return { version, file, text, sha256: crypto.createHash('sha256').update(text).digest('hex') };
}

export const watchUrl = (id) => `https://www.youtube.com/watch?v=${id}`;

export function buildRequest({ id, model, prompt, fps }) {
  const video = { type: 'video', uri: watchUrl(id) };
  if (fps !== undefined) video.processing = { type: 'static', fps };
  return { model, input: [{ type: 'text', text: prompt }, video] };
}

// The answer's text: the text parts of the model's output steps. Thought and processing
// steps (agentic mode) are left out; a response with only those has no answer.
export function answerText(resp) {
  if (!resp || typeof resp !== 'object') return '';
  const parts = [];
  const take = (c) => {
    if (typeof c === 'string') parts.push(c);
    else if (Array.isArray(c)) c.forEach(take);
    else if (c && typeof c === 'object' && typeof c.text === 'string' && (!c.type || c.type === 'text')) parts.push(c.text);
  };
  const skip = new Set(['thought', 'thinking', 'processing_call', 'processing_result', 'function_call', 'function_result']);
  for (const s of Array.isArray(resp.steps) ? resp.steps : []) {
    if (!s || typeof s !== 'object' || skip.has(s.type)) continue;
    if (s.content !== undefined) take(s.content);
    else if (typeof s.text === 'string') parts.push(s.text);
  }
  if (!parts.length && Array.isArray(resp.outputs)) resp.outputs.forEach(take);
  return parts.join('\n').trim();
}

export const baseName = (id, model, version) => `${id}.${model}.${version}`;
export const done = (dir, id, model, version) => fs.existsSync(path.join(dir, `${baseName(id, model, version)}.md`));

// Keeps the key out of anything printed, should a service ever echo a header back.
const scrub = (s, key) => (key ? String(s).split(key).join('[key]') : String(s));

function httpsTransport(url, headers, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, { method: 'POST', headers: { ...headers, 'content-length': Buffer.byteLength(body) } }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks).toString('utf8') }));
    });
    req.setTimeout(TIMEOUT_MS, () => req.destroy(new Error(`no answer after ${TIMEOUT_MS / 60000} minutes`)));
    req.on('error', reject);
    req.end(body);
  });
}

// One call. Returns the parsed response, or throws a WatchError with a plain message.
export async function callModel(request, { key, transport = httpsTransport }) {
  if (!key) throw new WatchError('GEMINI_API_KEY is not set. Set it in the environment; it is sent only as the request header.', 2);
  let res;
  try {
    res = await transport(ENDPOINT, { 'content-type': 'application/json', 'x-goog-api-key': key }, JSON.stringify(request));
  } catch (e) {
    throw new WatchError(`the request failed before an answer came back: ${scrub(e.message, key)}`, 1);
  }
  let json = null;
  try { json = JSON.parse(res.body); } catch { /* not JSON; reported below */ }
  const err = json && json.error ? json.error : null;
  const said = err && err.message ? `: ${scrub(err.message, key).slice(0, 400).replace(/[.\s]+$/, '')}` : '';
  if (res.status === 429 || (err && err.status === 'RESOURCE_EXHAUSTED')) {
    const after = res.headers && res.headers['retry-after'] ? ` The service asks to wait ${res.headers['retry-after']} s.` : '';
    throw new WatchError(`rate limit reached (HTTP ${res.status})${said}.${after} Stopped without retrying; run it again later.`, 3);
  }
  if (res.status === 503 || (err && err.status === 'UNAVAILABLE'))
    throw new WatchError(`the model is busy (HTTP ${res.status})${said}. Stopped without retrying; run it again later.`, 3);
  if (res.status < 200 || res.status >= 300)
    throw new WatchError(`the service answered HTTP ${res.status}${err && err.status ? ` ${err.status}` : ''}${said}`, 1);
  if (!json) throw new WatchError(`the service answered HTTP ${res.status} with something that is not JSON`, 1);
  if (json.status && /fail|cancel|error/i.test(json.status)) throw new WatchError(`the interaction ended ${json.status}${said}`, 1);
  return json;
}

// One prompt on one video: skip, or call and save. Returns what happened, for the log.
export async function watchOne({ id, model, version, fps, dir, force, key, transport, now = new Date(), promptDir }) {
  const base = baseName(id, model, version);
  if (!force && done(dir, id, model, version))
    return { skipped: true, base, msg: `skip ${base}: already answered with this prompt version and model (--force to ask again)` };
  const prompt = readPrompt(version, promptDir);
  const request = buildRequest({ id, model, prompt: prompt.text, fps });
  const t0 = Date.now();
  const resp = await callModel(request, { key, transport });
  const seconds = Math.round((Date.now() - t0) / 1000);
  const text = answerText(resp);
  if (!text) {
    const types = (Array.isArray(resp.steps) ? resp.steps : []).map((s) => s && s.type).filter(Boolean);
    throw new WatchError(`the response has no answer text (status ${resp.status || 'missing'}; steps: ${types.join(', ') || 'none'}). Nothing was saved.`, 4);
  }
  fs.mkdirSync(dir, { recursive: true });
  const meta = {
    video: id,
    url: watchUrl(id),
    model,
    modelReported: resp.model || null,
    prompt: { file: path.relative(REPO, prompt.file), version, sha256: prompt.sha256 },
    request: { fps: fps ?? null },
    date: now.toISOString().slice(0, 10),
    at: now.toISOString(),
    seconds,
    status: resp.status || null,
    usage: resp.usage || null,
    interaction: resp.id || null,
  };
  fs.writeFileSync(path.join(dir, `${base}.md`), text + '\n');
  fs.writeFileSync(path.join(dir, `${base}.json`), JSON.stringify(meta, null, 2) + '\n');
  fs.writeFileSync(path.join(dir, `${base}.response.json`), JSON.stringify(resp, null, 2) + '\n');
  const tokens = resp.usage && (resp.usage.total_tokens ?? resp.usage.totalTokens);
  return { skipped: false, base, meta, msg: `wrote ${path.join(dir, base)}.md (${seconds} s${tokens !== undefined ? `, ${tokens} tokens` : ''})` };
}

export async function main(argv, { env = process.env, transport, now, out = console.log, err = console.error, promptDir } = {}) {
  try {
    const o = parseArgs(argv);
    const dir = outDir(o, env);
    const key = env.GEMINI_API_KEY;
    if (!key) throw new WatchError('GEMINI_API_KEY is not set. Set it in the environment; it is sent only as the request header.', 2);
    const versions = [PROMPT_FOR[o.kind], ...(o.transcript ? [PROMPT_FOR.transcript] : [])];
    for (const version of versions) {
      out(`${o.id}: ${version} with ${o.model}...`);
      const r = await watchOne({ id: o.id, model: o.model, version, fps: o.fps, dir, force: o.force, key, transport, now, promptDir });
      out(r.msg);
    }
    return 0;
  } catch (e) {
    if (e instanceof WatchError) { err(`watch: ${e.message}`); return e.code; }
    throw e;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main(process.argv.slice(2)).then((code) => { process.exitCode = code; });
