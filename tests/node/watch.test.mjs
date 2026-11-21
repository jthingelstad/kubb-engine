// The video watcher (tools/watch.mjs), with no network: the request it builds, reading a
// response, the skip rule, refusing to write inside the repository, and each failure.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  REPO, ENDPOINT, PROMPT_FOR, videoId, parseArgs, outDir, buildRequest, answerText, callModel, main, readPrompt,
} from '../../tools/watch.mjs';

const KEY = 'test-key-not-real';
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'watch-'));
const now = new Date('2026-11-21T12:00:00Z');

const canned = {
  id: 'int-1',
  status: 'completed',
  model: 'gemini-4-hydrogen',
  usage: { total_input_tokens: 90000, total_output_tokens: 4000, total_tokens: 94000 },
  steps: [
    { type: 'thought', content: [{ type: 'text', text: 'thinking about it' }] },
    { type: 'model_output', content: [{ type: 'text', text: '0. THE VIDEO\n[SEEN] a pitch.' }, { type: 'text', text: '9. COULD NOT SEE\n- nothing.' }] },
  ],
};

// A transport that records each call and answers with the given responses in turn.
function fake(...answers) {
  const calls = [];
  const fn = async (url, headers, body) => {
    calls.push({ url, headers, body: JSON.parse(body) });
    const a = answers[Math.min(calls.length - 1, answers.length - 1)];
    if (a instanceof Error) throw a;
    return { status: a.status ?? 200, headers: a.headers ?? {}, body: typeof a.body === 'string' ? a.body : JSON.stringify(a.body ?? canned) };
  };
  fn.calls = calls;
  return fn;
}

// main() with captured output; env holds the key unless told otherwise.
async function run(argv, { env = { GEMINI_API_KEY: KEY }, transport = fake({}) } = {}) {
  const out = [];
  const err = [];
  const code = await main(argv, { env, transport, now, out: (s) => out.push(s), err: (s) => err.push(s) });
  return { code, out: out.join('\n'), err: err.join('\n'), transport };
}

test('a video id comes from every usual link, a bare id or our yt- id', () => {
  for (const s of ['Io-rxbSB3Ns', 'yt-Io-rxbSB3Ns', 'https://www.youtube.com/watch?v=Io-rxbSB3Ns&t=30s',
    'https://youtu.be/Io-rxbSB3Ns?si=x', 'https://m.youtube.com/shorts/Io-rxbSB3Ns', 'https://www.youtube.com/embed/Io-rxbSB3Ns'])
    assert.equal(videoId(s), 'Io-rxbSB3Ns', s);
  for (const s of ['', 'short', 'https://example.com/watch?v=Io-rxbSB3Ns', 'https://www.youtube.com/watch?v=bad'])
    assert.equal(videoId(s), null, s);
});

test('the arguments: a kind is required and must be known', () => {
  const o = parseArgs(['KnLTnKVVPMg', '--kind', 'lesson', '--transcript']);
  assert.equal(o.id, 'KnLTnKVVPMg');
  assert.equal(o.model, 'gemini-4-hydrogen');
  assert.equal(o.transcript, true);
  assert.throws(() => parseArgs(['KnLTnKVVPMg']), /--kind must be one of lesson, match, talk/);
  assert.throws(() => parseArgs(['KnLTnKVVPMg', '--kind', 'podcast']), /--kind/);
  assert.throws(() => parseArgs(['--kind', 'lesson']), /usage/);
  assert.throws(() => parseArgs(['nope', '--kind', 'lesson']), /not a YouTube link/);
  assert.throws(() => parseArgs(['KnLTnKVVPMg', '--kind', 'lesson', '--fps', '30']), /--fps/);
});

test('every kind has a versioned prompt file, and each asks for marks and what could not be seen', () => {
  for (const v of Object.values(PROMPT_FOR)) {
    const p = readPrompt(v);
    assert.match(p.sha256, /^[0-9a-f]{64}$/);
    assert.match(p.text, /kubb/);
    assert.match(p.text, /inkast/);
  }
  for (const k of ['lesson', 'talk', 'match']) {
    const t = readPrompt(PROMPT_FOR[k]).text;
    assert.match(t, /\[SAID\]/, k);
    assert.match(t, /\[UNCLEAR\]/, k);
    assert.match(t, /COULD NOT (SEE|HEAR)/, k);
    assert.match(t, /Timestamps on everything/, k);
  }
  assert.match(readPrompt('lesson-v1').text, /\[POINTS\]/);
});

test('the request: the prompt and the video link, in the documented shape', () => {
  assert.deepEqual(buildRequest({ id: 'KnLTnKVVPMg', model: 'gemini-4-hydrogen', prompt: 'Watch.' }), {
    model: 'gemini-4-hydrogen',
    input: [{ type: 'text', text: 'Watch.' }, { type: 'video', uri: 'https://www.youtube.com/watch?v=KnLTnKVVPMg' }],
  });
  const r = buildRequest({ id: 'KnLTnKVVPMg', model: 'm', prompt: 'p', fps: 4 });
  assert.deepEqual(r.input[1].processing, { type: 'static', fps: 4 });
});

test('the call sends the key only as a header, to the endpoint', async () => {
  const t = fake({});
  await callModel({ model: 'm', input: [] }, { key: KEY, transport: t });
  assert.equal(t.calls[0].url, ENDPOINT);
  assert.equal(t.calls[0].headers['x-goog-api-key'], KEY);
  assert.ok(!t.calls[0].url.includes(KEY));
  assert.ok(!JSON.stringify(t.calls[0].body).includes(KEY));
});

test('the answer is the output steps\' text, without thoughts', () => {
  assert.equal(answerText(canned), '0. THE VIDEO\n[SEEN] a pitch.\n9. COULD NOT SEE\n- nothing.');
  assert.equal(answerText({ steps: [{ type: 'thought', content: [{ type: 'text', text: 'x' }] }] }), '');
  assert.equal(answerText({ steps: [{ type: 'processing_result', content: [{ type: 'text', text: 'x' }] }, { type: 'model_output', text: 'y' }] }), 'y');
  assert.equal(answerText({}), '');
  assert.equal(answerText(null), '');
});

test('a call saves the answer, its metadata and the raw response', async () => {
  const dir = tmp();
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', dir]);
  assert.equal(r.code, 0, r.err);
  const base = path.join(dir, 'KnLTnKVVPMg.gemini-4-hydrogen.lesson-v1');
  assert.match(fs.readFileSync(`${base}.md`, 'utf8'), /THE VIDEO/);
  const meta = JSON.parse(fs.readFileSync(`${base}.json`, 'utf8'));
  assert.equal(meta.video, 'KnLTnKVVPMg');
  assert.equal(meta.model, 'gemini-4-hydrogen');
  assert.equal(meta.prompt.version, 'lesson-v1');
  assert.equal(meta.prompt.file, 'tools/watch/prompts/lesson-v1.txt');
  assert.equal(meta.date, '2026-11-21');
  assert.equal(meta.usage.total_tokens, 94000);
  assert.ok(fs.existsSync(`${base}.response.json`));
  for (const f of fs.readdirSync(dir)) assert.ok(!fs.readFileSync(path.join(dir, f), 'utf8').includes(KEY), f);
  assert.match(r.out, /94000 tokens/);
});

test('--transcript makes a second call with the transcript prompt', async () => {
  const dir = tmp();
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--transcript', '--out', dir]);
  assert.equal(r.code, 0, r.err);
  assert.equal(r.transport.calls.length, 2);
  assert.match(r.transport.calls[1].body.input[0].text, /transcript/i);
  assert.ok(fs.existsSync(path.join(dir, 'KnLTnKVVPMg.gemini-4-hydrogen.transcript-v1.md')));
});

test('the skip rule: same prompt version and model is skipped unless --force', async () => {
  const dir = tmp();
  await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', dir]);
  const again = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', dir]);
  assert.equal(again.code, 0);
  assert.equal(again.transport.calls.length, 0);
  assert.match(again.out, /skip KnLTnKVVPMg\.gemini-4-hydrogen\.lesson-v1/);
  const other = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--model', 'gemini-other', '--out', dir]);
  assert.equal(other.transport.calls.length, 1);
  const talk = await run(['KnLTnKVVPMg', '--kind', 'talk', '--out', dir]);
  assert.equal(talk.transport.calls.length, 1);
  const forced = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--force', '--out', dir]);
  assert.equal(forced.transport.calls.length, 1);
});

test('it refuses to write inside the repository, however it is pointed there', async () => {
  // (`..private-video` is a folder in the repository whose name begins with two dots)
  for (const out of [REPO, path.join(REPO, 'docs', 'reference'), path.join(REPO, 'not-yet', 'made'),
    path.join(REPO, '..private-video'), path.join(REPO, '..')+ path.sep + path.basename(REPO) + path.sep + 'x']) {
    const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', out]);
    assert.equal(r.code, 2, out);
    assert.match(r.err, /refusing to write inside the repository/);
    assert.equal(r.transport.calls.length, 0);
  }
  // and a sibling of the repository, or its parent, is outside
  assert.equal(outDir({ out: path.join(path.dirname(REPO), 'kubb-sources', 'video') }), path.join(path.dirname(REPO), 'kubb-sources', 'video'));
  assert.equal(outDir({ out: path.dirname(REPO) }), path.dirname(REPO));
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson'], { env: { GEMINI_API_KEY: KEY, KUBB_SOURCES: path.join(REPO, 'build') } });
  assert.equal(r.code, 2);
  // A symlink outside that leads in is followed, and refused.
  const link = path.join(tmp(), 'sneaky');
  fs.symlinkSync(REPO, link);
  const s = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', path.join(link, 'video')]);
  assert.equal(s.code, 2);
  assert.match(s.err, /refusing/);
});

test('the default output is $KUBB_SOURCES/video, else the sibling kubb-sources/video', () => {
  assert.equal(outDir({}, { KUBB_SOURCES: '/somewhere/sources' }), path.join('/somewhere/sources', 'video'));
  assert.equal(outDir({}, {}), path.join(path.dirname(REPO), 'kubb-sources', 'video'));
});

test('a missing key: a plain message, no call', async () => {
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', tmp()], { env: {} });
  assert.equal(r.code, 2);
  assert.match(r.err, /GEMINI_API_KEY is not set/);
  assert.equal(r.transport.calls.length, 0);
});

test('an HTTP error: its status and message, nothing written', async () => {
  const dir = tmp();
  const t = fake({ status: 400, body: { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'Video is private.' } } });
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', dir], { transport: t });
  assert.equal(r.code, 1);
  assert.match(r.err, /HTTP 400 INVALID_ARGUMENT: Video is private/);
  assert.deepEqual(fs.existsSync(dir) ? fs.readdirSync(dir) : [], []);
});

test('a rate limit: says so and stops after one call, with no retry', async () => {
  const dir = tmp();
  const t = fake({ status: 429, headers: { 'retry-after': '60' }, body: { error: { code: 429, status: 'RESOURCE_EXHAUSTED', message: 'Quota exceeded.' } } });
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--transcript', '--out', dir], { transport: t });
  assert.equal(r.code, 3);
  assert.match(r.err, /rate limit reached \(HTTP 429\): Quota exceeded\. The service asks to wait 60 s\. Stopped without retrying/);
  assert.equal(t.calls.length, 1);
});

test('a busy model (HTTP 503): says so and stops, with no retry', async () => {
  const t = fake({ status: 503, body: { error: { code: 503, status: 'UNAVAILABLE', message: 'The model is experiencing high demand.' } } });
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', tmp()], { transport: t });
  assert.equal(r.code, 3);
  assert.match(r.err, /the model is busy \(HTTP 503\): The model is experiencing high demand\. Stopped without retrying/);
  assert.equal(t.calls.length, 1);
});

test('a response with no text: says so, saves nothing', async () => {
  const dir = tmp();
  const t = fake({ body: { status: 'completed', steps: [{ type: 'thought', content: [{ type: 'text', text: 'hmm' }] }] } });
  const r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', dir], { transport: t });
  assert.equal(r.code, 4);
  assert.match(r.err, /no answer text \(status completed; steps: thought\)/);
  assert.deepEqual(fs.existsSync(dir) ? fs.readdirSync(dir) : [], []);
});

test('a failed interaction, a body that is not JSON, and a dropped connection', async () => {
  let r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', tmp()], { transport: fake({ body: { status: 'failed', error: { message: 'boom' } } }) });
  assert.equal(r.code, 1);
  assert.match(r.err, /ended failed: boom/);
  r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', tmp()], { transport: fake({ status: 502, body: '<html>bad gateway</html>' }) });
  assert.equal(r.code, 1);
  assert.match(r.err, /HTTP 502/);
  r = await run(['KnLTnKVVPMg', '--kind', 'lesson', '--out', tmp()], { transport: fake(new Error(`socket hang up near ${KEY}`)) });
  assert.equal(r.code, 1);
  assert.match(r.err, /failed before an answer came back: socket hang up/);
  assert.ok(!r.err.includes(KEY), 'the key never reaches a message');
});
