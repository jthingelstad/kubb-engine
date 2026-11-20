-- Several engines in one room (room/engines.lua, docs/ROOM.md "Engines in one match"):
-- what a member carries, the room's engine, what a client carrying several announces,
-- and that a client carrying one (every release before 0.8.1) agrees with it through its
-- own startCheck, startMatch and mayPlay, which these calls leave as they were.
import "session/api"
import "session/json"
import "room/js"
local json, js, NULL, object = tw.web.json, tw.room.js, tw.web.json.null, tw.web.json.object
local lobby = tw.room.lobby
local MM = lobby.ENGINE

local function room(name, args)
	local text = type(args) == "string" and args or json.encode(args or object {})
	local out = json.decode(kubbCall("room." .. name, text), true)
	if out.error then error("room." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end
local function same(a, b, what) expect.eq(js.text(a), js.text(b), what) end

-- A member: id, presence fields.
local function member(id, me, connected)
	local m = { id = id, connected = connected ~= false, me = { name = id:upper(), level = "club" } }
	for k, v in pairs(me or {}) do m.me[k] = v end
	return m
end
-- An old client (one engine, no `engines`): build 113 sends "0.7.4", a web tab "0.7".
local function old(id, engine) return member(id, { engine = engine }) end
-- A new client: what announce gives it for the room's engine.
local function new(id, carries, roomEngine)
	return member(id, room("announce", { carries = carries, engine = roomEngine }))
end
local function doc(a, b) return { v = 1, teams = { A = a or {}, B = b or {} } } end

-- ---------- what a member carries ----------

test("carried: an old client's lone engine, as major.minor", function()
	same(room("carried", { me = { engine = "0.7.4" } }), { "0.7" })
	same(room("carried", { me = { engine = "0.7" } }), { "0.7" })
	same(room("carried", { me = { name = "x" } }), {})
	same(room("carried", { me = NULL }), {})
	same(room("carried", { me = { engine = 7 } }), {})
end)

test("carried: `engines` is believed only beside a marked engine it includes", function()
	same(room("carried", { me = { engine = "0.7+engines", engines = { "0.7", "0.8" } } }), { "0.8", "0.7" })
	-- an older client rejoined under the same id: the room kept the stale `engines`
	same(room("carried", { me = { engine = "0.7", engines = { "0.8", "0.7" } } }), { "0.7" })
	same(room("carried", { me = { engine = "0.7.4", engines = { "0.8", "0.7" } } }), { "0.7" })
	-- marked, but not among its own list: the lone engine
	same(room("carried", { me = { engine = "0.6+engines", engines = { "0.8", "0.7" } } }), { "0.6" })
	-- junk in the list is left out, duplicates once, newest first (0.10 after 0.9)
	same(room("carried", { me = { engine = "0.9+engines", engines = { "0.9.2", 3, "x", "0.10", "0.9", object {} } } }),
		{ "0.10", "0.9" })
	-- a marked engine with no list at all
	same(room("carried", { me = { engine = "0.8+engines" } }), { "0.8" })
end)

test("announce: the room's engine marked, the list newest first", function()
	same(room("announce", { carries = { "0.7.4", "0.8.1" }, engine = "0.7" }),
		{ engine = "0.7+engines", engines = { "0.8", "0.7" } })
	-- no room engine yet, or one it does not carry: its newest
	same(room("announce", { carries = { "0.7", "0.8" } }), { engine = "0.8+engines", engines = { "0.8", "0.7" } })
	same(room("announce", { carries = { "0.7", "0.8" }, engine = "0.6" }),
		{ engine = "0.8+engines", engines = { "0.8", "0.7" } })
	expect.eq(room("announce", { carries = {} }), nil)
	-- what it announces reads back as what it carries
	same(room("carried", { me = room("announce", { carries = { "0.8", "0.7" }, engine = "0.7" }) }), { "0.8", "0.7" })
	-- and an older client reads its engine as the room's
	expect.eq(lobby.majorMinor("0.7+engines"), "0.7")
end)

test("compareEngines", function()
	expect.eq(room("compareEngines", { a = "0.8", b = "0.7.4" }), 1)
	expect.eq(room("compareEngines", { a = "0.9", b = "0.10" }), -1)
	expect.eq(room("compareEngines", { a = "0.7+engines", b = "0.7.4" }), 0)
	expect.eq(room("compareEngines", { a = "x", b = "0.7" }), nil)
end)

-- ---------- the room's engine ----------

local both = { "0.8", "0.7" }

test("engineFor: the newest that the host and every player carry", function()
	local ms = { new("h", both), new("p", both) }
	same(room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h" }),
		{ engine = "0.8", missing = {}, unknown = {} })
	-- an iPhone on build 113 takes a seat: 0.7
	ms[3] = old("i", "0.7.4")
	same(room("engineFor", { doc = doc({ "h" }, { "p", "i" }), members = ms, host = "h" }).engine, "0.7")
	-- an old web tab, the same
	ms[3] = old("w", "0.7")
	same(room("engineFor", { doc = doc({ "h", "w" }, { "p" }), members = ms, host = "h" }).engine, "0.7")
end)

test("engineFor: the limit is each member's list, not the room's engines together", function()
	-- the host carries 0.1 to 0.16 and the player 0.1 and 0.17: seventeen engines
	-- between them, and the one they share is the oldest
	local sixteen = {}
	for i = 16, 1, -1 do sixteen[#sixteen + 1] = "0." .. i end
	local ms = { new("h", sixteen, "0.1"), new("p", { "0.17", "0.1" }, "0.1") }
	local r = room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h" })
	same(r.engine, "0.1")
	same(r.missing, {})
end)

test("engineFor: a new host on its own, an old host, the computer on a side", function()
	same(room("engineFor", { doc = doc(), members = { new("h", both) }, host = "h" }).engine, "0.8")
	same(room("engineFor", { doc = doc({ "h" }), members = { new("h", both) }, host = "h" }).engine, "0.8")
	-- an old host is one of those it is worked out over
	local ms = { old("i", "0.7.4"), new("p", both) }
	same(room("engineFor", { doc = doc({ "i" }, { "p" }), members = ms, host = "i" }).engine, "0.7")
	same(room("engineFor", { doc = doc({ "p" }), members = ms, host = "i" }).engine, "0.7")
end)

test("engineFor: watchers do not count; `me` does when given", function()
	local ms = { new("h", both), new("p", both), old("i", "0.7.4") }
	-- i watches: the match is 0.8
	same(room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h" }).engine, "0.8")
	-- what i should expect if it sits
	same(room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h", me = "i" }).engine, "0.7")
	-- what a new client announces before its own presence comes back
	same(room("engineFor", { doc = doc({ "h" }), members = { new("h", both) }, host = "h", me = "z",
		carries = { "0.7" } }).engine, "0.7")
	-- `carries` overrides only `me`'s presence
	same(room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h", me = "p",
		carries = { "0.8" } }).engine, "0.8")
end)

test("engineFor: a seated member who is away still counts, one who left does not", function()
	local ms = { new("h", both), old("i", "0.7.4") }
	ms[2].connected = false
	same(room("engineFor", { doc = doc({ "h" }, { "i" }), members = ms, host = "h" }).engine, "0.7")
	-- i left the room (not in members): lineup leaves it out, as START does
	same(room("engineFor", { doc = doc({ "h" }, { "i" }), members = { ms[1] }, host = "h" }).engine, "0.8")
end)

test("engineFor: none in common names who is missing it", function()
	-- an iPhone that carries only 0.8 and one on build 113
	local ms = { member("h", { engine = "0.8.1+engines", engines = { "0.8" } }), old("i", "0.7.4"), new("p", both) }
	local e = room("engineFor", { doc = doc({ "h", "p" }, { "i" }), members = ms, host = "h" })
	same(e, { engine = NULL, missing = { "i" }, unknown = {} })
	-- a player who names no engine (a web client from before 0.3)
	ms[2] = member("i", {})
	e = room("engineFor", { doc = doc({ "h" }, { "i" }), members = ms, host = "h" })
	same(e, { engine = NULL, missing = { "i" }, unknown = { "i" } })
	-- the host not in members
	e = room("engineFor", { doc = doc({ "p" }), members = { new("p", both) }, host = "h" })
	same(e, { engine = NULL, missing = { "h" }, unknown = { "h" } })
	-- even split: the host's engine is the one the others are missing
	ms = { old("h", "0.8"), old("a", "0.7") }
	same(room("engineFor", { doc = doc({ "h" }, { "a" }), members = ms, host = "h" }).missing, { "a" })
end)

test("engineFor reads `engines`, never a new client's own engine, so it cannot swing", function()
	-- p announced 0.7 while i sat; i has gone: p's engine still says 0.7, the room's is 0.8
	local ms = { new("h", both, "0.7"), new("p", both, "0.7") }
	expect.eq(ms[2].me.engine, "0.7+engines")
	same(room("engineFor", { doc = doc({ "h" }, { "p" }), members = ms, host = "h" }).engine, "0.8")
end)

test("engineFor: a stale `engines` left by a rejoin is not believed", function()
	-- a new tab announced both, then an old tab of the same browser rejoined
	local ms = { new("h", both), member("w", { engine = "0.7", engines = both }) }
	same(room("engineFor", { doc = doc({ "h" }, { "w" }), members = ms, host = "h" }).engine, "0.7")
end)

-- ---------- speaking down: clients that carry one engine agree ----------

-- Run `fn` with this engine's room standing in for one whose major.minor is `mm`. The
-- room's code is the same in 0.7.4 and 0.8.x (`git diff v0.7.4 v0.8.0 -- room/` is
-- empty); only lobby.ENGINE, what START checks against and writes, differs.
local function as(mm, fn)
	local was = lobby.ENGINE
	lobby.ENGINE = mm
	local ok, err = pcall(fn)
	lobby.ENGINE = was
	if not ok then error(err, 0) end
end

local function startOn(d, ms, host)
	local lu = room("lineup", { doc = d, members = ms })
	return room("startMatch", { doc = d, snap = "{}", hash = "x", players = lu.players, cpu = lu.cpu,
		host = host, members = ms })
end

test("an old host (one engine, 0.7) starts with a new player who speaks down", function()
	as("0.7", function()
		local d = doc({ "i" }, { "p" })
		local ms = { old("i", "0.7.4"), new("p", both) }
		-- p works out the room's engine and announces it
		local e = room("engineFor", { doc = d, members = ms, host = "i", me = "p" }).engine
		expect.eq(e, "0.7")
		ms[2] = new("p", both, e)
		expect.truthy(room("startCheck", { players = room("lineup", { doc = d, members = ms }).players,
			members = ms, host = "i" }).ok)
		local s = startOn(d, ms, "i")
		expect.eq(s.match.engine, "0.7")
		-- p may play it on its 0.7 engine
		expect.truthy(room("mayPlay", { engine = "0.7.4", match = s.match }).ok)
		-- had p announced its newest, the old host would have refused, as it must
		ms[2] = new("p", both)
		expect.eq(startOn(d, ms, "i"), nil)
	end)
end)

test("a new host starts on its 0.7 engine with an old player", function()
	local d = doc({ "h" }, { "i" })
	local ms = { new("h", both), old("i", "0.7.4") }
	local e = room("engineFor", { doc = d, members = ms, host = "h" }).engine
	expect.eq(e, "0.7")
	-- the host's announcement, which the old player's lobby check reads
	ms[1] = new("h", both, e)
	expect.truthy(room("mayPlay", { engine = "0.7.4", match = { engine = ms[1].me.engine } }).ok)
	as("0.7", function()
		local s = startOn(d, ms, "h")
		expect.eq(s.match.engine, "0.7")
		-- the old player joins the running match
		expect.truthy(room("mayPlay", { engine = "0.7.4", match = s.match }).ok)
	end)
end)

test("a new client on its own engine's START: speakAs covers an announcement still on its way", function()
	-- i has left; p's announcement still says 0.7, the room's engine is now 0.8
	local d = doc({ "h" }, { "p" })
	local ms = { new("h", both, "0.8"), new("p", both, "0.7") }
	local e = room("engineFor", { doc = d, members = ms, host = "h" }).engine
	expect.eq(e, "0.8")
	as("0.8", function()
		expect.eq(startOn(d, ms, "h"), nil)
		local s = startOn(d, room("speakAs", { members = ms, engine = e }), "h")
		expect.eq(s.match.engine, "0.8")
	end)
end)

test("speakAs changes only members that carry the engine, and only their engine", function()
	local ms = { new("h", both), old("i", "0.7.4"), member("x", {}) }
	local out = room("speakAs", { members = ms, engine = "0.8" })
	expect.eq(out[1].me.engine, "0.8")
	same(out[1].me.engines, both)
	expect.eq(out[1].me.name, "H")
	same(out[2], ms[2])
	same(out[3], ms[3])
	-- the members it was given are not changed
	expect.eq(ms[1].me.engine, "0.8+engines")
	-- with 0.7, the old member already says it
	out = room("speakAs", { members = ms, engine = "0.7" })
	expect.eq(out[1].me.engine, "0.7")
	expect.eq(out[2].me.engine, "0.7")
end)

test("an `engines` field changes nothing for startCheck, startMatch and mayPlay", function()
	local d = doc({ "h" }, { "p", "q" })
	local plain = { old("h", MM), old("p", MM), old("q", "0.6") }
	local extra = { member("h", { engine = MM, engines = both }), member("p", { engine = MM, engines = both }),
		member("q", { engine = "0.6", engines = { MM } }) }
	local lu = room("lineup", { doc = d, members = plain })
	same(room("lineup", { doc = d, members = extra }), lu)
	same(room("startCheck", { players = lu.players, members = extra, host = "h" }),
		room("startCheck", { players = lu.players, members = plain, host = "h" }))
	expect.eq(startOn(d, extra, "h"), nil)
	plain[3], extra[3] = old("q", MM), member("q", { engine = MM, engines = { "0.1" } })
	same(startOn(d, extra, "h"), startOn(d, plain, "h"))
end)
