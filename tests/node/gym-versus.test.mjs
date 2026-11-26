// The Kubb Gym's versus (tools/gym/versus.mjs, tools/gym/versus.lua): the spec, the
// tally, the per-team switching of the tune tables, and a few short matches for the
// checks the note promises (same spec: even and the same game both ways round; the same
// seed: the same result; a setting nothing reads: refused).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parseSpec, tally, sideOf, teamZ, unread, probeSpecs, versusRun, versusRepro } from '../../tools/gym/versus.mjs';
import { blankGames } from '../../tools/gym/score.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const LUA = process.env.LUA || 'lua5.4';

test('a spec parses the same with commas or semicolons, and says what is wrong', () => {
  const a = parseSpec('level=pro; raise=together ; autothrow.tune.inkast.pro.row=0');
  const b = parseSpec('level=pro,raise=together,autothrow.tune.inkast.pro.row=0');
  assert.deepEqual(a, b);
  assert.equal(a.text, 'level=pro;thrower=cpu;raise=together;autothrow.tune.inkast.pro.row=0');
  assert.deepEqual(parseSpec(''), { level: 'club', thrower: 'cpu', raise: 'default', sets: [], text: 'level=club;thrower=cpu;raise=default' });
  assert.throws(() => parseSpec('level=expert'), /level/);
  assert.throws(() => parseSpec('thrower=robot'), /thrower/);
  assert.throws(() => parseSpec('level=pro;level=club'), /twice/);
  assert.throws(() => parseSpec('speed=3'), /unknown part/);
  assert.throws(() => parseSpec('world.tune.dt=fast'), /not set to a number/);
});

test('team A plays side A one way round and side B the other', () => {
  assert.equal(sideOf('A', 0), 'A');
  assert.equal(sideOf('A', 1), 'B');
  assert.equal(sideOf('B', 1), 'A');
});

test('the tally pairs a seed\'s two games and splits by who opened', () => {
  const g = (m, swap, winnerTeam, firstTeam, limit = false) => ({ m, swap, winnerTeam, firstTeam, limit });
  // seed 1: A wins both; seed 2: one each; seed 3: A wins one, the other hits the turn limit
  const t = tally([g(1, 0, 'A', 'A'), g(1, 1, 'A', 'B'), g(2, 0, 'A', 'A'), g(2, 1, 'B', 'B'),
    g(3, 0, 'A', 'B'), g(3, 1, 'B', 'A', true)]);
  assert.equal(t.A, 4);
  assert.equal(t.B, 1);
  assert.equal(t.limit, 1);
  assert.equal(t.seeds, 3);
  assert.ok(Math.abs(t.paired.v - (1 + 0.5 + 0.75) / 3) < 1e-12);
  assert.deepEqual([t.byOpener.A.games, t.byOpener.A.A, t.byOpener.A.limit], [3, 2, 1]);
  assert.deepEqual([t.byOpener.B.games, t.byOpener.B.A, t.byOpener.B.B], [3, 2, 1]);
  // every pair split one each: exactly even, with no width
  const even = tally([g(1, 0, 'A', 'A'), g(1, 1, 'B', 'B'), g(2, 0, 'B', 'B'), g(2, 1, 'A', 'A')]);
  assert.deepEqual([even.paired.v, even.paired.lo, even.paired.hi], [0.5, 0.5, 0.5]);
});

test('the same rows give no difference; a team\'s unread setting is found', () => {
  const a = blankGames();
  a['g.turns'] = { t: 'm', n: 4, s: 20, q: 110 };
  assert.ok(Object.values(teamZ(a, a)).every(z => z === 0));
  const reads = { 'x.tune.y': { base: 1, A: 0, B: undefined, reads: { A: 0, B: 7, none: 0 } } };
  assert.deepEqual(unread(reads), [{ team: 'A', path: 'x.tune.y' }]);
  reads['x.tune.y'].reads.A = 1;
  assert.deepEqual(unread(reads), []);
});

test('a team\'s number is served only while that team acts', () => {
  const script = `
    local sourceDir = ${JSON.stringify(root)}
    local imported = {}
    function import(name)
      if imported[name] then return end
      imported[name] = true
      return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
    end
    import "core/match"
    import "core/autothrow"
    local versus = dofile(sourceDir .. "/tools/gym/versus.lua")
    local A = versus.parse("level=pro;autothrow.tune.inkast.pro.row=0;plan.levels.pro.nervesDeg=0.123", "A")
    local B = versus.parse("level=pro;raise=away", "B")
    versus.install({ A = A, B = B }, { nervesDeg = true })
    local ik, cpu = tw.autothrow.tune.inkast.pro, tw.autothrow.cpuLevel("pro")
    local out = {}
    for _, who in ipairs { "A", "B", "none" } do
      versus.use(who ~= "none" and who or nil)
      out[#out + 1] = who .. "=" .. ik.row .. "," .. tw.plan.levels.pro.nervesDeg .. "," .. cpu.nervesDeg
    end
    local keys = {}
    for k in pairs(ik) do keys[#keys + 1] = k end
    table.sort(keys)
    print(table.concat(out, " ") .. " pairs=" .. table.concat(keys, ","))
    print(type(versus.policy(B)), versus.policy(A))
    -- a team's raising unless its spec names one: the engine's for such a side (0.12.0)
    local d = {}
    for _, sp in ipairs { "level=beginner", "level=club", "level=pro", "level=pro;thrower=human",
      "level=beginner;thrower=human", "level=pro;raise=apart", "level=club;raise=default" } do
      d[#d + 1] = versus.parse(sp, "A").raise
    end
    print(table.concat(d, ","))`;
  const out = execFileSync(LUA, ['-e', script], { encoding: 'utf8' }).trim().split('\n');
  const m = out[0].match(/A=0,0\.123,0\.123 B=1,([\d.]+),\1 none=1,\1,\1 pairs=basketY,group,hand,row,spin/);
  assert.ok(m, out[0]);
  assert.notEqual(m[1], '0.123');
  assert.equal(out[1], 'function\tpar');
  assert.equal(out[2], 'first,apart,par,par,par,apart,apart');
});

// a few short games (the turn limit keeps them quick)
const o = { n: 2, seed: 3, maxturns: 6, jobs: 2, probe: 1, model: path.join(root, 'tools', 'gym', 'human-model.json'), sets: [] };

test('the same spec both sides: even, and the same game both ways round', async () => {
  const A = parseSpec('level=club'), B = parseSpec('level=club');
  const r = await versusRun(o, A, B, 'Grass');
  assert.equal(r.tally.games, 4);
  assert.equal(r.mirror.same, r.mirror.pairs);
  assert.equal(r.mirror.pairs, 2);
  assert.deepEqual([r.tally.paired.lo, r.tally.paired.v, r.tally.paired.hi], [0.5, 0.5, 0.5]);
  assert.equal(r.tally.A, r.tally.B);
  // the same throws, summed in another order: equal but for rounding
  assert.ok(Object.values(r.z).every(z => Math.abs(z) < 1e-9));
});

test('the same spec both sides at pro (raising par by default): even', async () => {
  const A = parseSpec('level=pro'), B = parseSpec('level=pro');
  const r = await versusRun(o, A, B, 'Grass');
  assert.equal(r.mirror.same, r.mirror.pairs);
  assert.deepEqual([r.tally.paired.lo, r.tally.paired.v, r.tally.paired.hi], [0.5, 0.5, 0.5]);
});

test('the same seed gives the same result twice; a team\'s settings are read by it alone', async () => {
  // (inkast.depth, on at pro since 0.12.0, is read at every pro toss; with it on, the
  // row's switch is never read)
  const A = parseSpec('level=pro'), B = parseSpec('level=pro;cpu.tune.depth.pro=0');
  const r1 = await versusRun(o, A, B, 'Grass');
  const r2 = await versusRun(o, A, B, 'Grass');
  assert.deepEqual(r1.tally, r2.tally);
  assert.deepEqual(r1.cards, r2.cards);
  const e = r1.reads['cpu.tune.depth.pro'];
  assert.ok(e.reads.B > 0 && e.reads.A > 0, JSON.stringify(e));
  assert.equal(e.reads.none, 0);
  assert.ok(versusRepro(o, A, B, 'Grass', 1, { m: 2, t: 5 }).includes(`--a "${A.text}" --b "${B.text}" --swap 1`));
});

test('a setting that changes nothing is refused', () => {
  // copied into locals when core/raising is imported
  assert.throws(() => probeSpecs(o, parseSpec('level=pro'), parseSpec('level=pro;pitch.kubbLong=0.2'), 'Grass'), /refused[^]*team B: pitch\.kubbLong/);
  // a pro number on a club team: that team never reads it
  assert.throws(() => probeSpecs(o, parseSpec('level=club;autothrow.tune.inkast.pro.row=0'), parseSpec('level=club'), 'Grass'), /refused[^]*team A: autothrow\.tune\.inkast\.pro\.row/);
  // the value it already has
  assert.throws(() => probeSpecs(o, parseSpec('level=pro'), parseSpec('level=pro;autothrow.tune.inkast.pro.row=1'), 'Grass'), /refused[^]*already has/);
  assert.throws(() => probeSpecs(o, parseSpec('raise=sideways'), parseSpec(''), 'Grass'), /refused[^]*no raising policy sideways/);
  assert.throws(() => probeSpecs(o, parseSpec('autothrow.tune.nothing=1'), parseSpec(''), 'Grass'), /refused[^]*not a number in the engine/);
});
