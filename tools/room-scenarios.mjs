// The room's equivalence scenarios (docs/ROOM.md "Equivalence"): scripted and randomised
// lobby and match sequences, played through the web's JavaScript (src/net/lobby.js,
// seats.js, sync.js) to record what each call returns. tools/room-vectors.mjs writes them
// to tests/room/vectors/; tests/node/room.test.mjs and tests/lua/room/test_vectors.lua
// replay every step through the engine's Lua and compare.
//
// A scenario is { name, start, steps: [{ call, args, keep?, out }] }. Arguments may hold
// "$doc" (the scenario's document as the runner holds it: `start` at first, then each kept
// result) and "$match" (that document's match); a member's me.engine may be "$engine"
// (the runner's own engine version). `keep`: a non-null result becomes the document.
// `out` is the result as canonical JSON (keys sorted), or { $fnv, $bytes } of that text
// when it is long. Results are compared after `normalise`, which takes out what the Lua
// adds on purpose (match.engine, a replay's engine).

// ---------- canonical JSON, FNV-1a and the comparison ----------

export function canon(v) {
  if (v === null || typeof v !== "object") return JSON.stringify(v ?? null);
  if (Array.isArray(v)) return "[" + v.map((x) => (x === undefined ? "null" : canon(x))).join(",") + "]";
  const keys = Object.keys(v)
    .filter((k) => v[k] !== undefined)
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  return "{" + keys.map((k) => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
}

export function fnv(text) {
  let h = 0x811c9dc5;
  for (const b of Buffer.from(text, "utf8")) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, "0");
}

// A match (it has seq) or a replay (v and log) keeps an `engine` only in the Lua.
export function normalise(v, found = []) {
  if (Array.isArray(v)) return v.map((x) => normalise(x, found));
  if (v && typeof v === "object") {
    const out = {};
    const strip = "seq" in v || ("v" in v && "log" in v);
    for (const [k, x] of Object.entries(v)) {
      if (strip && k === "engine") found.push(x);
      else out[k] = normalise(x, found);
    }
    return out;
  }
  return v;
}

export const FULL_MAX = 400;
export function expected(value) {
  const text = canon(value);
  return Buffer.byteLength(text) <= FULL_MAX ? value : { $fnv: fnv(text), $bytes: Buffer.byteLength(text) };
}

// Does `got` (a result, normalised) match `want` (a step's out)?
export function matches(got, want) {
  const text = canon(got);
  if (want && typeof want === "object" && !Array.isArray(want) && "$fnv" in want)
    return fnv(text) === want.$fnv && Buffer.byteLength(text) === want.$bytes;
  return text === canon(want);
}

// ---------- the JavaScript side ----------

// The web's modules behind the vector calls: named arguments, JSON in and out (undefined
// comes back as null, as from the engine).
export function jsAdapter({ lobby, seats, sync }) {
  const calls = {
    cleanOptions: (a) => lobby.cleanOptions(a.options),
    optionLabel: (a) => lobby.optionLabel(a.key, a.value),
    cleanName: (a) => lobby.cleanName(a.name),
    lobbyOf: (a) => lobby.lobbyOf(a.doc),
    sideOf: (a) => lobby.sideOf(a.doc, a.id),
    joinTeam: (a) => lobby.joinTeam(a.doc, a.id, a.side),
    setOptions: (a) => lobby.setOptions(a.doc, a.options),
    setAccess: (a) => lobby.setAccess(a.doc, a.open),
    openListing: (a) => lobby.openListing(a.doc, a.members, { over: a.over }),
    pruneTeams: (a) => lobby.pruneTeams(a.doc, a.present),
    lineup: (a) => lobby.lineup(a.doc, a.members),
    matchOptions: (a) => lobby.matchOptions(a.doc, a.lineup, { seed: a.seed, start: a.start }),
    startMatch: (a) => lobby.startMatch(a.doc, a),
    commitAction: (a) => lobby.commitAction(a.doc, a),
    replayOf: (a) => lobby.replayOf(a.match),
    isReplay: (a) => lobby.isReplay(a.replay),
    backToLobby: (a) => lobby.backToLobby(a.doc, a.n),
    teamIds: (a) => seats.teamIds(ctxOf(a.ctx), a.side),
    actorsFor: (a) => seats.actorsFor(a.need, ctxOf(a.ctx)),
    mayAct: (a) => seats.mayAct(a.need, ctxOf(a.ctx), a.me),
    shownActor: (a) => seats.shownActor(a.need, ctxOf(a.ctx)),
    controlFor: (a) => seats.controlFor(ctxOf(a.ctx), a.me),
    sameControl: (a) => seats.sameControl(a.a, a.b),
    playingSide: (a) => seats.playingSide(ctxOf(a.ctx), a.me),
    nextHost: (a) => seats.nextHost(a.members, a.host),
    decide: (a) => sync.decide(a.local, a.doc, a.with, a.mine),
    rider: (a) => sync.rider(a.n, a.seq, a.action, a.bytes),
    asciiSize: (a) => sync.asciiSize(a.value),
  };
  return (call, args) => {
    const f = calls[call];
    if (!f) throw new Error(`no call ${call}`);
    const v = f(JSON.parse(JSON.stringify(args)));
    return v === undefined ? null : JSON.parse(JSON.stringify(v));
  };
}

// The JSON ctx's connected list is a Set in the JavaScript.
function ctxOf(c) {
  return c && typeof c === "object" ? { ...c, connected: new Set(c.connected || []) } : c;
}

// ---------- the scenarios ----------

// mulberry32: a seeded generator, so the same seed gives the same scenarios.
function rng(seed) {
  let a = seed >>> 0;
  const r = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  r.int = (n) => Math.floor(r() * n);
  r.pick = (xs) => xs[r.int(xs.length)];
  r.chance = (p) => r() < p;
  return r;
}

const NAMES = [
  "Ann", "  Jo   Ann  ", "Ångström", "x".repeat(20), "Zoë", "名前テスト", "O'Brien \"Q\"", "\tTab\nName",
  "\u00a0nbsp\u3000ideo\u2003", "", null, 7, "back\\slash", "🙂🙂🙂🙂🙂🙂🙂🙂🙂", "a b c d e f g h i j", "Hanna",
];
const LEVELS = ["beginner", "club", "pro", "expert", undefined, null];
const OPTIONS = {
  surface: ["grass", "sand", "snow", "lava"],
  opening: ["2-4-6", "six", "seven"],
  raising: ["hand", "auto", "never"],
  wind: ["off", "light", "strong", "storm"],
  set: ["classic", "usa", "sweden", "minnesota", "wisconsin", "mars"],
  x: [1, "y"],
};

function randomString(r, n = 12) {
  const parts = ["a", "Z", "0", " ", '"', "\\", "/", "\n", "\t", "\u0001", "\u007f", "é", "€", "名", "🙂", "3.0", "{", "}"];
  let s = "";
  for (let i = 0; i < n; i++) s += r.pick(parts);
  return s;
}

function randomNumber(r) {
  switch (r.int(8)) {
    case 0: return r.int(1000) - 500;
    case 1: return (r() - 0.5) * 10 ** (r.int(30) - 12);
    case 2: return r.pick([0.1, 0.2, 0.1 + 0.2, 1e-7, 1e21, 123456789012345680000, 5e-324, 1.7976931348623157e308, 2 ** 53, -1e-6, 1e-6]);
    case 3: return r() * 360 - 180;
    default: return Math.round((r() - 0.5) * 2e6) / 1000;
  }
}

function randomValue(r, depth = 0) {
  const k = r.int(depth > 2 ? 5 : 8);
  if (k === 0) return randomNumber(r);
  if (k === 1) return randomString(r, r.int(10));
  if (k === 2) return r.chance(0.5);
  if (k === 3) return null;
  if (k === 4) return randomNumber(r);
  if (k === 5) return Array.from({ length: r.int(4) }, () => randomValue(r, depth + 1));
  const o = {};
  for (let i = r.int(4); i > 0; i--) o[r.pick(["x", "y", "speed", "loft", "w", "é", "k" + r.int(9)])] = randomValue(r, depth + 1);
  return o;
}

function randomAction(r, pad = 0) {
  const t = r.pick(["throw", "throw", "throw", "raise", "punish", "resign", "thrower"]);
  if (t === "throw") {
    const a = {
      type: "throw", seq: r.int(300), how: r.pick(["baton", "lob", "drill"]),
      launch: { speed: randomNumber(r), loft: randomNumber(r), swivel: randomNumber(r), tilt: 0, tumble: r() * 10 },
      stance: { x: r() - 0.5, y: r() * 2 }, target: { x: randomNumber(r), y: 8 - r() }, scripted: r.chance(0.5),
      verdicts: r.chance(0.5) ? { power: r(), release: -r(), steady: true } : undefined,
      extra: randomValue(r),
    };
    if (r.chance(0.2)) a.empty = r.pick([{}, [], [{}], { a: [] }]);
    if (pad) a.pad = "x".repeat(pad);
    return a;
  }
  if (t === "raise") return r.chance(0.5) ? { type: "raise", choice: r.int(3) + 1 } : { type: "raise" };
  if (t === "punish") return { type: "punish", x: randomNumber(r), y: r() * 4 };
  if (t === "resign") return { type: "resign", side: r.pick(["A", "B"]), at: { year: 2026, month: 11, day: 17, hour: 9, min: 5 } };
  return { type: "thrower", id: r.pick(["a1", "a2", "b1"]) };
}

const hex = (r) => (r.int(2 ** 31) * 2 + r.int(2)).toString(16).padStart(8, "0");
const snapOf = (r, n) => `{"v":3,"opts":{"x":3.0,"s":${JSON.stringify(randomString(r, 8))}},"n":${n},"t":"${randomString(r, 6).replace(/["\\]/g, "")}"}`;

// A scenario builder over the adapter: step() runs a call through the JavaScript and
// records it; "$doc", "$match" and "$engine" are put in and taken out here.
function builder(call, name) {
  const steps = [];
  let doc = null;
  let start = null;
  const subst = (v) => {
    if (v === "$doc") return doc;
    if (v === "$match") return doc && typeof doc === "object" ? (doc.match ?? null) : null;
    if (v === "$engine") return "0.0.0-js";
    if (Array.isArray(v)) return v.map(subst);
    if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, subst(x)]));
    return v;
  };
  const step = (fn, args = {}, { keep = false } = {}) => {
    const out = call(fn, subst(args));
    steps.push({ call: fn, args, ...(keep ? { keep: true } : {}), out: expected(normalise(out)) });
    if (keep && out !== null) doc = out;
    return out;
  };
  const setDoc = (d) => {
    if (!steps.length) start = d;
    doc = d;
  };
  return { name, steps, step, doc: () => doc, setDoc, scenario: () => ({ name, start, steps }) };
}

function membersOf(pool) {
  return pool.filter((m) => !m.gone).map(({ id, connected, me }) => ({ id, connected, me }));
}

function makeMember(r, i, { engine = true } = {}) {
  const me = { name: r.pick(NAMES) };
  const level = r.pick(LEVELS);
  if (level !== undefined) me.level = level;
  if (engine) me.engine = "$engine";
  return { id: `m${String(i).padStart(2, "0")}`, connected: true, me };
}

// One room's life: a lobby, matches, commits from the right and the wrong clients, the
// host going and coming, rematches.
function roomLife(call, seed, opts = {}) {
  const r = rng(seed);
  const b = builder(call, `room ${seed}`);
  const { step } = b;
  const nMembers = opts.members ?? 2 + r.int(9);
  const pool = Array.from({ length: nMembers }, (_, i) => makeMember(r, i + 1, { engine: r.chance(0.8) }));
  let host = pool[0].id;
  const local = Object.fromEntries(pool.map((m) => [m.id, { n: null, seq: 0 }]));
  if (opts.start !== undefined) b.setDoc(opts.start);
  const ctxNow = () => {
    const m = b.doc()?.match;
    return {
      players: m?.players ?? { A: [], B: [] },
      cpu: m?.cpu ?? null,
      host,
      connected: pool.filter((x) => !x.gone && x.connected).map((x) => x.id),
    };
  };
  const someone = () => r.pick(pool.filter((m) => !m.gone));
  const deliver = (w, writer) => {
    // up to three receivers a version: enough for every path, and the vectors stay small
    for (const m of pool.filter((x) => !x.gone && x.id !== writer).slice(0, 3)) {
      if (!m.connected || r.chance(0.08)) continue; // missed this version: a gap later
      const d = step("decide", { local: local[m.id], doc: "$doc", with: w ?? undefined, mine: false });
      if (d.kind === "start" || d.kind === "adopt" || d.kind === "apply" || d.kind === "same")
        local[m.id] = { n: d.match.n, seq: d.match.seq };
      if (d.kind === "lobby") local[m.id] = { n: local[m.id].n, seq: local[m.id].seq };
    }
  };
  const ops = opts.ops ?? 40 + r.int(60);
  for (let k = 0; k < ops; k++) {
    const doc = b.doc();
    const started = !!(doc && doc.started);
    const roll = r();
    if (!started) {
      if (roll < 0.35) {
        const m = someone();
        step("joinTeam", { doc: "$doc", id: m.id, side: r.pick(["A", "B", "A", "B", null, "C"]) }, { keep: true });
        step("sideOf", { doc: "$doc", id: m.id });
      } else if (roll < 0.45) {
        const opt = {};
        for (const [key, vals] of Object.entries(OPTIONS)) if (r.chance(0.4)) opt[key] = r.pick(vals);
        step("setOptions", { doc: "$doc", options: r.chance(0.1) ? null : opt }, { keep: true });
      } else if (roll < 0.5) {
        step("setAccess", { doc: "$doc", open: r.pick([true, false, 1, 0, null, "yes"]) }, { keep: true });
        step("openListing", { doc: "$doc", members: membersOf(pool), over: r.chance(0.2) });
      } else if (roll < 0.58) {
        const m = someone();
        if (m.id !== host && r.chance(0.5)) m.gone = true;
        else m.connected = !m.connected;
        step("pruneTeams", { doc: "$doc", present: membersOf(pool).map((x) => x.id) }, { keep: true });
      } else if (roll < 0.62 && pool.length < 16) {
        const m = makeMember(r, pool.length + 1, { engine: r.chance(0.8) });
        pool.push(m);
        local[m.id] = { n: null, seq: 0 };
      } else {
        // START, by the host
        const members = membersOf(pool);
        const lu = step("lineup", { doc: "$doc", members });
        if (!lu) continue;
        const seed2 = r.int(2 ** 31);
        const start = { year: 2026, month: 1 + r.int(12), day: 1 + r.int(28), hour: r.int(24), min: r.int(60) };
        const setup = step("matchOptions", { doc: "$doc", lineup: lu, seed: seed2, start });
        const old = members.some((m) => !m.me.engine);
        const snap = snapOf(r, 0);
        const hash = hex(r);
        const withSetup = r.chance(0.85);
        const res = step(
          "startMatch",
          { doc: "$doc", snap, hash, players: lu.players, cpu: lu.cpu, host, ...(withSetup ? { setup } : {}), members, ...(old ? { lenient: true } : {}) },
          { keep: true },
        );
        local[host] = { n: res ? res.n : local[host].n, seq: 0 };
        deliver({ kind: "start" }, host);
      }
      continue;
    }
    // a match is on
    const m0 = doc.match;
    const ctx = ctxNow();
    if (roll < 0.25) {
      const side = r.pick(["A", "B"]);
      const team = ctx.players[side] || [];
      const need = r.pick([
        { kind: "throw", side, cpu: side === ctx.cpu, setup: { thrower: { key: team.length ? r.pick(team).id : "cpu" } } },
        { kind: "throw", side, setup: { thrower: { key: "gone-id" } } },
        { kind: "raise", side },
        { kind: "punish", side },
        { kind: "over" },
        { kind: "throw", practice: true },
        null,
      ]);
      const me = r.pick([...pool.map((x) => x.id), "watcher"]);
      step("actorsFor", { need, ctx });
      step("mayAct", { need, ctx, me });
      step("shownActor", { need, ctx });
      const c = step("controlFor", { ctx, me });
      step("sameControl", { a: c, b: r.pick([c, { sides: ["A"], cpu: false }, null, { sides: c.sides, cpu: !c.cpu }]) });
      step("playingSide", { ctx, me });
      step("teamIds", { ctx, side });
    } else if (roll < 0.33) {
      // the host goes (or comes back)
      const h = pool.find((x) => x.id === host);
      if (h) h.connected = !h.connected;
      const next = step("nextHost", { members: membersOf(pool), host });
      if (next) host = next;
    } else if (roll < 0.9) {
      // a commit
      const actor = r.pick(pool.filter((x) => !x.gone && x.connected)) || pool[0];
      const loc = local[actor.id];
      const n = r.chance(0.95) ? m0.n : m0.n + 1;
      const seq = r.chance(0.9) ? m0.seq + 1 : r.pick([m0.seq, m0.seq + 2, loc.seq + 1]);
      const action = randomAction(r, opts.pad ?? 0);
      const w = step("rider", { n, seq, action, bytes: r.pick([undefined, 4096, 600, 200]) });
      const over = r.chance(opts.overP ?? 0.04);
      const res = step(
        "commitAction",
        { doc: "$doc", n, seq, snap: snapOf(r, seq), hash: hex(r), ...(r.chance(0.94) ? { action } : {}), over },
        { keep: true },
      );
      if (res) {
        local[actor.id] = { n, seq };
        step("decide", { local: { n, seq: seq - 1 }, doc: "$doc", with: w ?? undefined, mine: true });
        deliver(w, actor.id);
        // a second client that acted at once loses the compare-and-set
        if (r.chance(0.2)) step("commitAction", { doc: "$doc", n, seq, snap: snapOf(r, seq), hash: hex(r), action }, { keep: true });
        if (over) {
          const rep = step("replayOf", { match: "$match" });
          step("isReplay", { replay: rep });
          step("openListing", { doc: "$doc", members: membersOf(pool), over: true });
          step("backToLobby", { doc: "$doc", n: n + 1 }, { keep: true });
          if (r.chance(0.8)) step("backToLobby", { doc: "$doc", n: r.chance(0.5) ? n : undefined }, { keep: true });
          deliver(undefined, host);
        }
      }
    } else {
      step("replayOf", { match: "$match" });
      step("lobbyOf", { doc: "$doc" });
      if (r.chance(0.3)) step("backToLobby", { doc: "$doc", n: m0.n }, { keep: true });
    }
  }
  return b.scenario();
}

// Scripted: odd documents, the full room, options and names, rider limits, decide's table.
function scripted(call) {
  const out = [];
  const junk = [null, {}, "junk", [], 0, true,
    { teams: { A: ["a", 5, null, "b", "a"], B: "x", C: ["c"] }, n: 2.5, started: "yes", open: 1, options: { surface: "lava", wind: "light" }, match: [] },
    { teams: { A: [], B: [] }, n: 3, started: 0, open: true, match: { n: 3, seq: 1, snap: "s" } },
    { v: 9, teams: { A: ["a"] }, n: -1, started: true, match: { n: 1, seq: 0, snap: "s", log: [], players: { A: [{ id: "a", name: "A" }], B: [] }, cpu: "B" } },
  ];
  junk.forEach((d, i) => {
    const b = builder(call, `odd document ${i}`);
    b.setDoc(d);
    const { step } = b;
    step("lobbyOf", { doc: "$doc" });
    step("sideOf", { doc: "$doc", id: "a" });
    step("setOptions", { doc: "$doc", options: { surface: "snow" } });
    step("setOptions", { doc: "$doc", options: {} });
    step("setAccess", { doc: "$doc", open: false });
    step("setAccess", { doc: "$doc", open: true });
    step("openListing", { doc: "$doc", members: [{ id: "a" }, { id: "b", connected: false }, { id: "c", connected: true }] });
    step("pruneTeams", { doc: "$doc", present: ["a"] });
    step("lineup", { doc: "$doc", members: [{ id: "a", me: { name: " A " } }, { id: "b" }, { id: "a", me: null }] });
    step("joinTeam", { doc: "$doc", id: "z", side: null });
    step("joinTeam", { doc: "$doc", id: "a", side: null });
    step("joinTeam", { doc: "$doc", id: "z" });
    step("backToLobby", { doc: "$doc" });
    step("backToLobby", { doc: "$doc", n: null });
    step("commitAction", { doc: "$doc", n: 1, seq: 1, snap: "s1", hash: "h1", action: { type: "raise" } });
    step("commitAction", { doc: "$doc", n: 3, seq: 2, snap: "s2", hash: "h2", action: { type: "raise" }, over: 1 });
    step("decide", { local: { n: 1, seq: 0 }, doc: "$doc", with: { n: 1, seq: 1, a: { type: "raise" } } });
    step("decide", { local: { n: 3, seq: 1 }, doc: "$doc" });
    out.push(b.scenario());
  });
  {
    // a full room: sixteen members, six a side
    const b = builder(call, "a full room");
    const { step } = b;
    for (let i = 1; i <= 16; i++) step("joinTeam", { doc: "$doc", id: `m${i}`, side: i % 2 ? "A" : "B" }, { keep: true });
    step("joinTeam", { doc: "$doc", id: "m1", side: "B" }, { keep: true });
    step("joinTeam", { doc: "$doc", id: "m3", side: null }, { keep: true });
    step("joinTeam", { doc: "$doc", id: "m1", side: "B" }, { keep: true });
    step("setAccess", { doc: "$doc", open: true }, { keep: true });
    const members = Array.from({ length: 16 }, (_, i) => ({ id: `m${i + 1}`, connected: i < 14, me: { name: `P${i}`, level: "pro", engine: "$engine" } }));
    step("openListing", { doc: "$doc", members });
    const lu = step("lineup", { doc: "$doc", members });
    const setup = step("matchOptions", { doc: "$doc", lineup: lu, seed: 2 ** 31 - 1, start: { year: 2026, month: 11, day: 17, hour: 9, min: 0 } });
    step("startMatch", { doc: "$doc", snap: '{"x":3.0}', hash: "00000000", players: lu.players, cpu: lu.cpu, host: "m1", setup, members }, { keep: true });
    step("openListing", { doc: "$doc", members });
    const ctx = { players: b.doc().match.players, cpu: null, host: "m1", connected: members.filter((m) => m.connected).map((m) => m.id) };
    // the throws of members who are not connected fall to a team-mate in order, then the host
    for (const p of [...ctx.players.A, ...ctx.players.B]) {
      const side = ctx.players.A.includes(p) ? "A" : "B";
      step("actorsFor", { need: { kind: "throw", side, setup: { thrower: { key: p.id } } }, ctx });
      step("actorsFor", { need: { kind: "throw", side, setup: { thrower: { key: p.id } } }, ctx: { ...ctx, connected: ["m1"] } });
      step("actorsFor", { need: { kind: "raise", side }, ctx: { ...ctx, connected: [] } });
    }
    out.push(b.scenario());
  }
  {
    const b = builder(call, "options, names, labels and sizes");
    const { step } = b;
    for (const o of [undefined, null, {}, { surface: "lava", wind: "light", x: 1 }, { surface: "sand", opening: "six", raising: "auto", wind: "strong", set: "usa" }, "junk", [1]])
      step("cleanOptions", { options: o });
    for (const [k, v] of [["surface", "sand"], ["set", "usa"], ["wind", "gale"], ["nope", 3], ["wind", null], ["wind", 2.5], ["wind", true]])
      step("optionLabel", { key: k, value: v });
    for (const n of NAMES) step("cleanName", { name: n });
    for (const n of ["x".repeat(40), " \u2028\u2029\ufeff a \u205f b \u1680", "12345678901234567890", "a🙂b"]) step("cleanName", { name: n });
    for (const v of [{ a: "é" }, { a: "\u007f\u0001\n" }, [1.5, 3, 1e21, 1e-7, -0.000001, 0.1 + 0.2], "名🙂", null, { k: { j: [] } }, 123456789012345680000])
      step("asciiSize", { value: v });
    for (const bytes of [undefined, 4096, 200, 100, 64, 0, null]) step("rider", { n: 1, seq: 2, action: { type: "throw", s: "é".repeat(20) }, bytes });
    step("rider", { n: 1, seq: 2, action: { a: "x".repeat(5000) } });
    out.push(b.scenario());
  }
  {
    const b = builder(call, "decide");
    const { step } = b;
    const doc = (n, seq, started = true, snap = "s") => ({ started, match: started ? { n, seq, snap, hash: "h" } : null });
    const w = (n, seq, a = { type: "throw" }) => ({ n, seq, a });
    const cases = [
      [{ n: null, seq: 0 }, null], [{ n: 1, seq: 3 }, doc(1, 3, false)], [{ n: null, seq: 0 }, doc(1, 0)],
      [{ n: 1, seq: 9 }, doc(2, 4)], [{ n: 1, seq: 3 }, doc(1, 4), w(1, 4)], [{ n: 1, seq: 3 }, doc(1, 3)],
      [{ n: 1, seq: 3 }, doc(1, 2)], [{ n: 1, seq: 3 }, doc(1, 5), w(1, 5)], [{ n: 1, seq: 3 }, doc(1, 4)],
      [{ n: 1, seq: 3 }, doc(1, 4), w(1, 5)], [{ n: 1, seq: 3 }, doc(1, 4), w(1, 4), true],
      [{ n: 1, seq: 3 }, doc(1, 4), w(1, 4, null)], [{ n: 1, seq: 3 }, doc(1, 4), w(2, 4)],
      [{ n: 1, seq: 3 }, doc(1, 4, true, 5)], [{ n: 1, seq: 3 }, { started: 1, match: { n: 1, seq: 4, snap: "" } }, w(1, 4)],
      [{ n: 1, seq: "3" }, doc(1, 4), w(1, 4)], [{ n: 1, seq: null }, doc(1, 1), w(1, 1)], [{ n: 1 }, doc(1, 0)],
      [{ n: 1, seq: 3 }, { started: true, match: "s" }], [{ n: 1, seq: 3 }, doc(1, 4), w(1, 4, 0)],
    ];
    for (const [local, d, ww, mine] of cases) step("decide", { local, doc: d, with: ww, mine });
    const ms = [{ id: "h", connected: false }, { id: "x", connected: false }, { id: "y", connected: true }, { id: "z", connected: true }];
    for (const host of ["h", "gone", "y", null]) step("nextHost", { members: ms, host });
    step("nextHost", { members: [{ id: "h", connected: true }], host: "h" });
    step("nextHost", { members: [], host: "h" });
    out.push(b.scenario());
  }
  {
    // a match whose log outgrows the document: the log is dropped, the match goes on
    const b = builder(call, "a log past the budget");
    const { step } = b;
    step("joinTeam", { doc: "$doc", id: "a", side: "A" }, { keep: true });
    const members = [{ id: "a", connected: true, me: { name: "Ann", engine: "$engine" } }];
    const lu = step("lineup", { doc: "$doc", members });
    const setup = step("matchOptions", { doc: "$doc", lineup: lu, seed: 7, start: { year: 2026 } });
    step("startMatch", { doc: "$doc", snap: "s0", hash: "h0", players: lu.players, cpu: lu.cpu, host: "a", setup, members }, { keep: true });
    for (let seq = 1; seq <= 12; seq++)
      step("commitAction", { doc: "$doc", n: 1, seq, snap: `s${seq}`, hash: `h${seq}`, action: { type: "throw", pad: "é".repeat(4000 + seq * 7) }, over: seq === 12 }, { keep: true });
    step("replayOf", { match: "$match" });
    out.push(b.scenario());
  }
  return out;
}

export const RANDOM_SEEDS = Array.from({ length: 30 }, (_, i) => 1001 + i);

// Every scenario for these seeds: the scripted ones, then one room's life a seed (a few
// with a full room, an old document to start from, or matches that end often).
export function generate(call, seeds = RANDOM_SEEDS) {
  const out = scripted(call);
  for (const s of seeds) {
    const k = s % 6;
    const opts = k === 0 ? { members: 16, ops: 120 } : k === 1 ? { overP: 0.25 } : k === 2 ? { start: { teams: { A: ["m01"] }, n: 4, open: true, options: { wind: "light" } } } : {};
    out.push(roomLife(call, s, opts));
  }
  return out;
}
