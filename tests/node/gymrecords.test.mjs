// The Gym's records reader leaves test play out: the known QA pitches and dev/.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readRecords, TEST_PITCHES } from '../../tools/gym/records.mjs';
import { browserToRoom } from '../../tools/gym/wasmreplay.mjs';

function pitch(root, code) {
  const dir = join(root, code, '1763700000000');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, '0001-000000.json'), JSON.stringify({ topic: 'start', body: { n: 1, snap: '{}', meta: { version: '0.18.0' } } }));
  writeFileSync(join(dir, '0001-000001.json'), JSON.stringify({ topic: 'act', body: { n: 1, seq: 1, a: { type: 'throw', swing: { back: 60 } }, h: 'abcd1234', snap: '{}' } }));
}

test('readRecords: a person\'s pitch is read; the QA pitches and dev/ are skipped', () => {
  const dir = mkdtempSync(join(tmpdir(), 'gymrecords-'));
  try {
    pitch(join(dir, 'pitch'), 'abcdefgh');
    for (const code of TEST_PITCHES) pitch(join(dir, 'pitch'), code);
    pitch(join(dir, 'dev', 'pitch'), 'bcdefghj');
    const r = readRecords(dir);
    assert.equal(r.lines.length, 1);
    assert.equal(r.info.skipped, TEST_PITCHES.size + 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('browserToRoom: a browser match that names no engine goes on to the inverter as it came', async () => {
  const unversioned = { k: 'm1', kind: 'browser', start: '{}', actions: [], hashes: [], e: null };
  const untagged = { k: 'm2', kind: 'browser', start: '{}', actions: [], hashes: [], e: '0.0.0-none' };
  const room = { k: 'm3', i: 1, kind: 'room', before: '{}', a: { type: 'throw' }, hash: 'abcd1234', e: null };
  const r = await browserToRoom([unversioned, untagged, room]);
  assert.deepEqual(r.lines, [unversioned, untagged, room]);
  assert.equal(r.stats.passed, 2);
  assert.equal(r.stats.cut, 0);
});
