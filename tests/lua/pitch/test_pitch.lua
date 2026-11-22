-- The pitch's calls (docs/PITCH.md): the web's own unit tests for src/net/lobby.js, seats.js
-- and sync.js ported to Lua and run through kubbCall("pitch.<name>"), then the engine's
-- deliberate differences and the JSON rules the pitch depends on.
import "session/api"
import "session/json"
import "pitch/js"
local json, js, NULL, object = tw.web.json, tw.shared.js, tw.web.json.null, tw.web.json.object
local ENGINE = tw.engine.version
local MM = tw.shared.lobby.ENGINE

-- One call through the door: args a Lua table (or JSON text); returns the value.
local function pitch(name, args)
	local text = type(args) == "string" and args or json.encode(args or object {})
	local out = json.decode(kubbCall("pitch." .. name, text), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end
-- The same value? (as JSON, keys sorted)
local function same(a, b, what)
	expect.eq(js.text(a), js.text(b), what)
end

local function members(...)
	local out = {}
	for i, id in ipairs { ... } do
		out[i] = { id = id, connected = true, me = { name = id:upper(), level = "pro", engine = ENGINE } }
	end
	return out
end
local DEFAULTS = { surface = "grass", opening = "2-4-6", raising = "hand", wind = "off", set = "classic" }

-- ---------- lobby.test.mjs ----------

test("a fresh or expired pitch reads as an empty lobby", function()
	for _, doc in ipairs { 'null', '{}', '"junk"' } do
		local l = pitch("lobbyOf", '{"doc":' .. doc .. '}')
		same(l.teams, { A = {}, B = {} })
		same(l.options, DEFAULTS)
		expect.eq(l.started, false)
		expect.eq(l.n, 0)
		expect.eq(l.match, NULL)
	end
	same(pitch("lobbyOf", '{}').teams, { A = {}, B = {} }, "doc absent (undefined)")
end)

test("joining, switching and sitting out", function()
	local d = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	same(d.teams, { A = { "m1" }, B = {} })
	expect.eq(pitch("joinTeam", { doc = d, id = "m1", side = "A" }), nil, "no change, no write")
	d = pitch("joinTeam", { doc = d, id = "m2", side = "A" })
	d = pitch("joinTeam", { doc = d, id = "m1", side = "B" })
	same(d.teams, { A = { "m2" }, B = { "m1" } })
	expect.eq(pitch("sideOf", { doc = d, id = "m1" }), "B")
	d = pitch("joinTeam", { doc = d, id = "m1", side = NULL })
	same(d.teams, { A = { "m2" }, B = {} })
	expect.eq(pitch("sideOf", { doc = d, id = "m1" }), nil)
	expect.eq(pitch("joinTeam", { doc = d, id = "m1", side = NULL }), nil)
	expect.eq(pitch("joinTeam", { doc = d, id = "m1", side = "C" }), nil)
end)

test("a side holds six", function()
	local d = NULL
	for i = 0, 5 do d = pitch("joinTeam", { doc = d, id = "m" .. i, side = "A" }) end
	expect.eq(#d.teams.A, 6)
	expect.eq(pitch("joinTeam", { doc = d, id = "m9", side = "A" }), nil)
	expect.truthy(pitch("joinTeam", { doc = d, id = "m9", side = "B" }))
end)

test("teams and options are fixed while a match runs", function()
	local d = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	d = pitch("startMatch", { doc = d, snap = "s", hash = "h", players = { A = { { id = "m1", name = "M1" } }, B = {} },
		cpu = "B", host = "m1" })
	expect.eq(pitch("joinTeam", { doc = d, id = "m2", side = "B" }), nil)
	expect.eq(pitch("setOptions", { doc = d, options = { wind = "strong" } }), nil)
	expect.eq(pitch("pruneTeams", { doc = d, present = {} }), nil)
end)

test("options are cleaned and merged", function()
	local want = {}
	for k, v in pairs(DEFAULTS) do want[k] = v end
	want.wind = "light"
	same(pitch("cleanOptions", { options = { surface = "lava", wind = "light", x = 1 } }), want)
	local d = pitch("setOptions", { doc = NULL, options = { surface = "snow" } })
	expect.eq(d.options.surface, "snow")
	expect.eq(pitch("setOptions", { doc = d, options = { surface = "snow" } }), nil)
	expect.eq(pitch("setOptions", { doc = d, options = { surface = "lava" } }), nil)
end)

test("pruning forgets members who left", function()
	local d = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	d = pitch("joinTeam", { doc = d, id = "m2", side = "B" })
	same(pitch("pruneTeams", { doc = d, present = { "m1" } }).teams, { A = { "m1" }, B = {} })
	expect.eq(pitch("pruneTeams", { doc = d, present = { "m1", "m2" } }), nil)
end)

test("the lineup puts the computer on an empty side", function()
	expect.eq(pitch("lineup", { doc = NULL, members = {} }), nil)
	local d = pitch("joinTeam", { doc = NULL, id = "a", side = "A" })
	d = pitch("joinTeam", { doc = d, id = "gone", side = "A" })
	local lu = pitch("lineup", { doc = d, members = members("a") })
	same(lu.players.A, { { id = "a", name = "A", level = "pro" } })
	expect.eq(lu.cpu, "B")
	d = pitch("joinTeam", { doc = d, id = "b", side = "B" })
	lu = pitch("lineup", { doc = d, members = members("a", "b") })
	expect.eq(lu.cpu, NULL)
	local o = pitch("matchOptions", { doc = d, lineup = lu, seed = 7, start = { year = 2026 } })
	expect.eq(o.seed, 7)
	same(o.cpu, {})
	expect.truthy(json.isArray(o.cpu) and not rawequal(o.cpu, NULL), "cpu is an empty array, not null")
	expect.eq(o.first, "A")
	same(o.teams.A.players, { { name = "A", key = "a", level = "pro" } })
	expect.eq(o.surface, "grass")
	local solo = pitch("matchOptions", { doc = d, lineup = { players = { A = {}, B = lu.players.B }, cpu = "A" }, seed = 1 })
	expect.eq(solo.cpu, "A")
	expect.eq(solo.teams.A.name, "Computer")
end)

test("names are trimmed and capped", function()
	expect.eq(pitch("cleanName", { name = "  Jo   Ann  " }), "Jo Ann")
	expect.eq(#pitch("cleanName", { name = ("x"):rep(40) }), 16)
	expect.eq(pitch("cleanName", { name = 7 }), "")
end)

test("actions commit in order; a stale one is refused", function()
	local d = pitch("joinTeam", { doc = NULL, id = "a", side = "A" })
	local players = { A = { { id = "a", name = "A", level = "pro" } }, B = {} }
	d = pitch("startMatch", { doc = d, snap = "s0", hash = "h0", players = players, cpu = "B", host = "a" })
	expect.eq(d.started, true)
	expect.eq(d.n, 1)
	same(d.match.players.A, { { id = "a", name = "A" } }, "level left out")
	expect.eq(pitch("startMatch", { doc = d, snap = "x", hash = "x", players = players, cpu = "B", host = "a" }), nil)
	d = pitch("commitAction", { doc = d, n = 1, seq = 1, snap = "s1", hash = "h1" })
	expect.eq(d.match.seq, 1)
	expect.eq(d.match.snap, "s1")
	expect.eq(pitch("commitAction", { doc = d, n = 1, seq = 1, snap = "s1b", hash = "h" }), nil, "the loser")
	expect.eq(pitch("commitAction", { doc = d, n = 1, seq = 3, snap = "s3", hash = "h" }), nil, "a gap")
	expect.eq(pitch("commitAction", { doc = d, n = 2, seq = 2, snap = "s", hash = "h" }), nil, "another match")
	expect.eq(pitch("backToLobby", { doc = d, n = 2 }), nil)
	d = pitch("backToLobby", { doc = d, n = 1 })
	expect.eq(d.started, false)
	expect.eq(d.match, NULL)
	same(d.teams.A, { "a" }, "same teams for the rematch")
	expect.eq(d.n, 1)
end)

test("the snapshot text is kept as text", function()
	local snap = '{"x":3.0}'
	local text = kubbCall("pitch.startMatch", json.encode { doc = NULL, snap = snap, hash = "h",
		players = { A = json.object {}, B = {} }, cpu = NULL, host = "a" })
	expect.eq(json.decode(text, true).value.match.snap, snap)
	expect.truthy(text:find('"snap":"{\\"x\\":3.0}"', 1, true), "the text, escaped, byte for byte")
end)

local P1 = { A = { { id = "a", name = "Ann", level = "pro" } }, B = {} }
local SETUP = { seed = 7, teams = { A = { name = "A" } }, cpu = "B" }
local function throwOf(i) return { type = "throw", arm = i } end

local function played(actions, over)
	if over == nil then over = true end
	local d = pitch("startMatch", { doc = pitch("joinTeam", { doc = NULL, id = "a", side = "A" }), snap = "s0",
		hash = "h0", players = P1, cpu = "B", host = "a", setup = SETUP })
	for i, a in ipairs(actions) do
		d = pitch("commitAction", { doc = d, n = 1, seq = i, snap = "s" .. i, hash = "h" .. i, action = a,
			over = over and i == #actions })
	end
	return d
end

test("each action is logged with its hash; the last marks the match over", function()
	local d = played { throwOf(1), { type = "raise", choice = 1 }, throwOf(2) }
	same(d.match.setup, SETUP)
	expect.eq(d.match.h0, "h0")
	same(d.match.log, { { a = throwOf(1), h = "h1" }, { a = { type = "raise", choice = 1 }, h = "h2" },
		{ a = throwOf(2), h = "h3" } })
	expect.eq(d.match.over, true)
	local r = pitch("replayOf", { match = d.match })
	same(r, { v = 1, n = 1, setup = SETUP, h0 = "h0", log = d.match.log, snap = "s3", hash = "h3",
		players = d.match.players, cpu = "B", engine = MM })
	expect.eq(pitch("isReplay", { replay = r }), true)
	expect.eq(pitch("replayOf", { match = played({ throwOf(1) }, false).match }), nil, "not over")
end)

test("a match with no whole log has no replay", function()
	local d = pitch("startMatch", { doc = NULL, snap = "s0", hash = "h0", players = P1, cpu = "B", host = "a" })
	d = pitch("commitAction", { doc = d, n = 1, seq = 1, snap = "s1", hash = "h1", action = throwOf(1), over = true })
	expect.eq(d.match.log, nil)
	expect.eq(pitch("replayOf", { match = d.match }), nil)
	d = played({ throwOf(1) }, false)
	d = pitch("commitAction", { doc = d, n = 1, seq = 2, snap = "s2", hash = "h2" })
	expect.eq(d.match.log, NULL)
	d = pitch("commitAction", { doc = d, n = 1, seq = 3, snap = "s3", hash = "h3", action = throwOf(3), over = true })
	expect.eq(d.match.log, NULL)
	expect.eq(pitch("replayOf", { match = d.match }), nil)
	for _, x in ipairs { 'null', '{}', '{"v":2,"setup":{},"log":[],"snap":""}', '{"v":1,"setup":{},"log":[null],"snap":""}' } do
		expect.eq(pitch("isReplay", '{"replay":' .. x .. '}'), false, x)
	end
end)

test("a log that would outgrow the document is dropped: no replay for that match", function()
	local big = { type = "throw", pad = ("x"):rep(4000) }
	local n = math.ceil(tw.shared.lobby.LOG_BUDGET / 4000) + 2
	local list = {}
	for i = 1, n do list[i] = big end
	local d = played(list)
	expect.eq(d.match.log, NULL)
	expect.eq(d.match.seq, n)
	expect.eq(pitch("replayOf", { match = d.match }), nil)
end)

test("a rematch drops the match; its replay was the pitch's to keep", function()
	expect.eq(pitch("backToLobby", { doc = played { throwOf(1) }, n = 1 }).match, NULL)
end)

-- ---------- seats.test.mjs ----------

local function ctx(connected, extra)
	local c = { players = { A = { { id = "a1" }, { id = "a2" } }, B = { { id = "b1" } } }, cpu = NULL, host = "a1",
		connected = connected }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end
local function throwBy(side, key) return { kind = "throw", side = side, setup = { thrower = { key = key } } } end

test("a throw is its owner's", function()
	local c = ctx { "a1", "a2", "b1" }
	same(pitch("actorsFor", { need = throwBy("A", "a2"), ctx = c }), { "a2" })
	expect.eq(pitch("mayAct", { need = throwBy("A", "a2"), ctx = c, me = "a2" }), true)
	expect.eq(pitch("mayAct", { need = throwBy("A", "a2"), ctx = c, me = "a1" }), false)
	expect.eq(pitch("mayAct", { need = throwBy("A", "a2"), ctx = c, me = "b1" }), false)
end)

test("an absent owner's throw falls to a teammate, then the host", function()
	same(pitch("actorsFor", { need = throwBy("A", "a2"), ctx = ctx { "a1", "b1" } }), { "a1" })
	same(pitch("actorsFor", { need = throwBy("B", "b1"), ctx = ctx { "a1", "a2" } }), { "a1" })
	same(pitch("actorsFor", { need = throwBy("B", "b1"), ctx = ctx({ "a2" }, { host = "a2" }) }), { "a2" })
	same(pitch("actorsFor", { need = throwBy("B", "b1"), ctx = ctx({}, { host = NULL }) }), {})
end)

test("raises and punishment kubbs are any connected defender's", function()
	local raise = { kind = "raise", side = "A" }
	same(pitch("actorsFor", { need = raise, ctx = ctx { "a1", "a2", "b1" } }), { "a1", "a2" })
	same(pitch("actorsFor", { need = { kind = "punish", side = "B" }, ctx = ctx { "a1" } }), { "a1" })
	expect.eq(pitch("mayAct", { need = raise, ctx = ctx { "a2", "b1" }, me = "b1" }), false)
end)

test("the computer is the host's client's, never a human input", function()
	local c = ctx({ "a1" }, { players = { A = { { id = "a1" } }, B = {} }, cpu = "B" })
	local t = { kind = "throw", side = "B", cpu = true }
	same(pitch("actorsFor", { need = t, ctx = c }), { "a1" })
	expect.eq(pitch("mayAct", { need = t, ctx = c, me = "a1" }), false)
	expect.eq(pitch("shownActor", { need = t, ctx = c }), "cpu")
	same(pitch("controlFor", { ctx = c, me = "a1" }), { sides = { "A" }, cpu = true })
end)

test("control: own side, and every human side for the host", function()
	local c = ctx { "a1", "a2", "b1" }
	same(pitch("controlFor", { ctx = c, me = "a1" }), { sides = { "A", "B" }, cpu = true })
	same(pitch("controlFor", { ctx = c, me = "a2" }), { sides = { "A" }, cpu = false })
	same(pitch("controlFor", { ctx = c, me = "b1" }), { sides = { "B" }, cpu = false })
	same(pitch("controlFor", { ctx = c, me = "watcher" }), { sides = {}, cpu = false })
	expect.eq(pitch("sameControl", { a = pitch("controlFor", { ctx = c, me = "a2" }), b = { sides = { "A" }, cpu = false } }), true)
	expect.eq(pitch("sameControl", { a = pitch("controlFor", { ctx = c, me = "a2" }), b = NULL }), false)
	expect.eq(pitch("playingSide", { ctx = c, me = "b1" }), "B")
	expect.eq(pitch("playingSide", { ctx = c, me = "watcher" }), nil)
end)

test("practice and the end need nobody", function()
	same(pitch("actorsFor", { need = { kind = "over" }, ctx = ctx { "a1" } }), {})
	same(pitch("actorsFor", { need = { kind = "throw", practice = true }, ctx = ctx { "a1" } }), {})
	expect.eq(pitch("mayAct", { need = NULL, ctx = ctx {}, me = "a1" }), false)
end)

test("the next host is the earliest-joined connected member", function()
	local ms = { { id = "h", connected = false }, { id = "x", connected = false }, { id = "y", connected = true },
		{ id = "z", connected = true } }
	expect.eq(pitch("nextHost", { members = ms, host = "h" }), "y")
	expect.eq(pitch("nextHost", { members = ms, host = "gone" }), "y")
	expect.eq(pitch("nextHost", { members = { { id = "h", connected = true } }, host = "h" }), nil)
end)

-- ---------- sync.test.mjs (aimKey is the web's own: not ported) ----------

local function doc(n, seq, started)
	if started == nil then started = true end
	return { started = started, match = started and { n = n, seq = seq, snap = "s", hash = "h" } or NULL }
end
local function w(n, seq) return { n = n, seq = seq, a = { type = "throw" } } end
local function decide(l, d, ww, mine) return pitch("decide", { ["local"] = l, doc = d, with = ww, mine = mine }) end

test("no match: the lobby", function()
	expect.eq(decide({ n = NULL, seq = 0 }, NULL).kind, "lobby")
	expect.eq(decide({ n = 1, seq = 3 }, doc(1, 3, false)).kind, "lobby")
end)

test("another match: take it", function()
	expect.eq(decide({ n = NULL, seq = 0 }, doc(1, 0)).kind, "start")
	expect.eq(decide({ n = 1, seq = 9 }, doc(2, 4)).kind, "start")
end)

test("the next action is applied; anything else adopts", function()
	local l = { n = 1, seq = 3 }
	local d = decide(l, doc(1, 4), w(1, 4))
	expect.eq(d.kind, "apply")
	same(d.action, { type = "throw" })
	expect.eq(decide(l, doc(1, 3)).kind, "same")
	expect.eq(decide(l, doc(1, 2)).kind, "old")
	expect.eq(decide(l, doc(1, 5), w(1, 5)).why, "gap")
	expect.eq(decide(l, doc(1, 4)).why, "no-action")
	expect.eq(decide(l, doc(1, 4), w(1, 5)).why, "no-action")
	expect.eq(decide(l, doc(1, 4), w(1, 4), true).why, "own")
end)

test("an action too big to ride along is left off", function()
	same(pitch("rider", { n = 1, seq = 2, action = { a = 1 } }), { n = 1, seq = 2, a = { a = 1 }, c = "web" })
	expect.eq(pitch("rider", { n = 1, seq = 2, action = { a = ("x"):rep(5000) } }), nil)
	expect.eq(pitch("asciiSize", { value = { a = "é" } }), #'{"a":"x"}' + 5)
end)

-- ---------- the engine's own: deliberate differences ----------

test("lobbyOf keeps top-level keys it does not know (the JavaScript drops them)", function()
	local text = kubbCall("pitch.lobbyOf",
		'{"doc":{"teams":{"A":["a"],"B":[]},"n":3.0,"later":{"x":[],"y":{},"z":null},"flag":false}}')
	expect.eq(text, '{"value":{"flag":false,"later":{"x":[],"y":{},"z":null},"match":null,"n":3,"open":false,'
		.. '"options":{"opening":"2-4-6","raising":"hand","set":"classic","surface":"grass","wind":"off"},'
		.. '"started":false,"teams":{"A":["a"],"B":[]},"v":1}}')
	-- and they ride through every reducer
	local d = pitch("joinTeam", '{"doc":{"later":{"k":1}},"id":"m","side":"B"}')
	same(d.later, { k = 1 })
	d = pitch("startMatch", { doc = d, snap = "s", hash = "h", players = { A = {}, B = { { id = "m", name = "M" } } },
		cpu = "A", host = "m" })
	d = pitch("commitAction", { doc = d, n = 1, seq = 1, snap = "s1", hash = "h1" })
	d = pitch("backToLobby", { doc = d, n = 1 })
	same(d.later, { k = 1 })
end)

test("START writes the engine's major.minor and the replay carries it", function()
	expect.eq(MM, ENGINE:match("^(%d+%.%d+)"))
	local d = played { throwOf(1) }
	expect.eq(d.match.engine, MM)
	expect.eq(pitch("replayOf", { match = d.match }).engine, MM)
	expect.truthy(pitch("isReplay", { replay = pitch("replayOf", { match = d.match }) }))
	expect.eq(pitch("constants").ENGINE, MM)
end)

test("START is refused while a player's engine differs or is unknown (strict by default)", function()
	local function startWith(ms, lenient)
		local d = pitch("joinTeam", { doc = NULL, id = "h", side = "A" })
		d = pitch("joinTeam", { doc = d, id = "p", side = "B" })
		local lu = pitch("lineup", { doc = d, members = ms })
		return pitch("startMatch", { doc = d, snap = "s", hash = "h", players = lu.players, cpu = lu.cpu, host = "h",
			members = ms, lenient = lenient })
	end
	local host = { id = "h", connected = true, me = { name = "H" } } -- the host runs this engine
	local function p(engine) return { id = "p", connected = true, me = { name = "P", engine = engine } } end
	expect.truthy(startWith { host, p(ENGINE) }, "same engine")
	expect.truthy(startWith { host, p(MM .. ".99") }, "a patch apart")
	expect.eq(startWith { host, p("0.0.1") }, nil, "another minor")
	expect.eq(startWith({ host, p("0.0.1") }, true), nil, "lenient does not let a different engine in")
	expect.eq(startWith { host, p(NULL) }, nil, "no engine named: strict")
	expect.truthy(startWith({ host, p(NULL) }, true), "no engine named: lenient")
	local c = pitch("startCheck", { players = { A = { { id = "h" } }, B = { { id = "p" }, { id = "q" } } },
		members = { host, p("9.9.0") }, host = "h" })
	same(c, { ok = false, engine = MM, differ = { "p" }, unknown = { "q" } })
end)

test("mayPlay: major.minor equal; unknown only when lenient", function()
	local function may(e, m, lenient) return pitch("mayPlay", { engine = e, match = m, lenient = lenient }) end
	same(may(ENGINE, { engine = MM }), { ok = true, why = NULL, engine = MM, match = MM })
	expect.eq(may("0.0.7", { engine = MM }).why, "differs")
	expect.eq(may(MM .. ".5", { engine = MM }).ok, true)
	expect.eq(may(NULL, { engine = MM }).why, "unknown")
	expect.eq(may(ENGINE, { n = 1 }).why, "unknown")
	expect.eq(may(ENGINE, { n = 1 }, true).ok, true)
	expect.eq(may(NULL, { n = 1 }, true).ok, true)
	expect.eq(may("junk", { engine = MM }, true).why, "differs")
end)

test("cleanName never leaves half a character beyond U+FFFF", function()
	-- 15 ASCII then an emoji: the JavaScript's 16-unit cut splits the pair
	expect.eq(pitch("cleanName", { name = ("a"):rep(15) .. "🙂" }), ("a"):rep(15))
	expect.eq(pitch("cleanName", { name = ("a"):rep(14) .. "🙂" }), ("a"):rep(14) .. "🙂")
	expect.eq(pitch("cleanName", { name = "名前テスト" }), "名前テスト")
end)

test("rider names the client and, when given, the engine", function()
	same(pitch("rider", { n = 1, seq = 2, action = { a = 1 }, client = "ios", engine = ENGINE }),
		{ n = 1, seq = 2, a = { a = 1 }, c = "ios", e = ENGINE })
end)

-- ---------- JSON the pitch depends on ----------

test("empty array, empty object, null and absent each survive a reducer", function()
	local lu = '{"players":{"A":[{"id":"a","name":"A"}],"B":[]},"cpu":"B"}'
	local text = kubbCall("pitch.startMatch", '{"doc":null,"snap":"s","hash":"h","players":{"A":[{"id":"a","name":"A"}],"B":[]},'
		.. '"cpu":"B","host":"a","setup":{"cpu":[],"teams":{},"wind":null,"x":3.5}}')
	local m = json.decode(text, true).value.match
	expect.truthy(text:find('"setup":{"cpu":[],"teams":{},"wind":null,"x":3.5}', 1, true), "setup kept as sent")
	expect.truthy(text:find('"log":[]', 1, true), "the empty log is an array")
	expect.eq(m.over, nil, "absent stays absent")
	local o = pitch("matchOptions", '{"doc":null,"lineup":' .. lu .. ',"seed":1}')
	expect.eq(o.cpu, "B")
	local both = pitch("matchOptions", '{"doc":null,"lineup":{"players":{"A":[{"id":"a"}],"B":[{"id":"b"}]},"cpu":null},"seed":1}')
	expect.truthy(json.isArray(both.cpu) and #both.cpu == 0, "setup.cpu: []")
	local d = pitch("startMatch", '{"doc":null,"snap":"s","hash":"h","players":{"A":[{"id":"a","name":"A"}],"B":[{"id":"a","name":"A"}]},"cpu":null,"host":"a"}')
	expect.eq(d.match.cpu, NULL, "match.cpu: null")
end)

test("integers stay integers and floats floats; output is byte stable", function()
	local text = kubbCall("pitch.commitAction", json.encode {
		doc = pitch("startMatch", { doc = NULL, snap = "s", hash = "h", players = { A = {}, B = {} }, cpu = NULL,
			host = "a", setup = { seed = 1 } }),
		n = 1, seq = 1, snap = "s1", hash = "h1", action = { speed = 2.5, n = 3, big = 1e21, small = 1e-7, z = -0.0 } })
	expect.truthy(text:find('"n":3,', 1, true), "an integer")
	expect.truthy(text:find('"speed":2.5', 1, true), "a float")
	expect.eq(json.encode(json.decode(text, true)), text, "decode and encode give the same bytes")
	expect.eq(kubbCall("pitch.commitAction", json.encode {
		doc = json.decode(text, true).value, n = 1, seq = 2, snap = "s2", hash = "h2" }):find('"seq":1,', 1, true), nil)
end)

test("a member id is a string and an unknown call or a bad argument is an error", function()
	expect.eq(pitch("joinTeam", { doc = NULL, id = "1", side = "A" }).teams.A[1], "1")
	local out = json.decode(kubbCall("pitch.nope", "{}"))
	expect.truthy(out.error and out.error:find("unknown call pitch.nope", 1, true), "unknown call")
	out = json.decode(kubbCall("pitch.lobbyOf", "[1]"))
	expect.truthy(out.error and out.error:find("pitch.lobbyOf: ", 1, true) == 1, "an array argument")
end)

test("room. is the old spelling of pitch.: the same calls, errors named as called", function()
	for _, name in ipairs { "constants", "lobbyOf", "optionsOf" } do
		expect.eq(kubbCall("room." .. name, "{}"), kubbCall("pitch." .. name, "{}"), name)
	end
	local d = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	expect.eq(kubbCall("room.sideOf", json.encode { doc = d, id = "m1" }), '{"value":"A"}')
	local out = json.decode(kubbCall("room.nope", "{}"))
	expect.truthy(out.error and out.error:find("unknown call room.nope", 1, true), "unknown call, old spelling")
	out = json.decode(kubbCall("room.lobbyOf", "[1]"))
	expect.truthy(out.error and out.error:find("room.lobbyOf: ", 1, true) == 1, "named as called")
	expect.truthy(rawequal(tw.room, tw.shared), "tw.room is tw.shared")
end)

test("the plain decoder is unchanged: nulls are dropped, {} and [] both read as a table", function()
	local t = json.decode('{"a":null,"b":{},"c":[]}')
	expect.eq(t.a, nil)
	expect.eq(json.encode(t), '{"b":[],"c":[]}')
	local k = json.decode('{"a":null,"b":{},"c":[]}', true)
	expect.eq(json.encode(k), '{"a":null,"b":{},"c":[]}')
end)

-- tw.pitch is the playing field's geometry (core/pitch). The shared pitch's modules live
-- in a table of their own, tw.shared, so neither load order lets one replace the other.
test("the shared pitch's tables are not the field's geometry", function()
	expect.truthy(tw.pitch and tw.pitch.halfWidth, "core/pitch's geometry is tw.pitch")
	expect.truthy(not rawequal(tw.pitch, tw.shared), "tw.shared is its own table")
	expect.eq(tw.pitch.lobby, nil)
	expect.truthy(tw.shared.lobby and tw.shared.api and tw.shared.js, "the modules are on tw.shared")
end)
