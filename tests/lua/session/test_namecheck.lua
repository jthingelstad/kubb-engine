-- The names in a match from outside (session/namecheck, docs/SESSION.md "Names",
-- docs/NAMES.md section 6): names.check on a snapshot, a replay and a pitch's document,
-- and the strict restore and replayLoad (names = "check"). tests/node/session.test.mjs
-- runs the same calls under wasmoon.
import "session/api"
import "session/json"
import "session/session"
import "core/autothrow"
tw.web.session.useTune("pointer")
local session, json, autothrow, throw = tw.web.session, tw.web.json, tw.autothrow, tw.web.throw

local START = { year = 2026, month = 11, day = 21, hour = 10, min = 0 }

local function call(method, a)
	local text = _G.kubbCall(method, type(a) == "string" and a or (a and json.encode(a) or ""))
	local out = json.decode(text)
	if type(out) == "table" and out.error then error(method .. ": " .. out.error, 2) end
	return out
end
local function refused(method, a)
	local out = json.decode(_G.kubbCall(method, type(a) == "string" and a or json.encode(a)))
	return type(out) == "table" and out.error
end
local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

local function cpuThrow(s)
	for _ = 1, 600 do
		local o = s:frame { dt = 1 / 60 }
		if o.action then return o end
	end
	error("the computer did not throw")
end
local function scripted(s, r)
	local ts = s.ts
	local a = autothrow.choose(s.setup, r, (s.setup.kind == "toss") and 4 / autothrow.tune.drillScale or 1)
	throw.showAim(ts, a)
	local L, how = throw.cpuLaunch(ts, a)
	ts.playerX, ts.playerY = a.x, a.y
	return json.decode(json.encode(s:throwAction(L, how, { back = a.swing.back, stop = a.swing.releaseAngle,
		verdicts = L })))
end

-- A match played to its end (or `steps` actions), the snapshot after every action kept,
-- and the log of actions with the hash after each (a replay's).
local function play(o, steps)
	o = copy(o)
	o.start = o.start or START
	-- a resignation by the side not throwing, at that action: it waits (resignPending)
	local resignAt = o.resignAt
	o.resignAt = nil
	local c = copy(o)
	c.mode = "match"
	local s = session.new(c)
	local snaps, log = { s:snapshot() }, {}
	local h0 = s:hash()
	local r = autothrow.rng(77 + (o.seed or 1))
	local n = 0
	while s:need().kind ~= "over" and n < (steps or 800) do
		n = n + 1
		local need = s:need()
		local a
		if n == resignAt and need.side then
			a = { type = "resign", side = need.side == "A" and "B" or "A" }
			s:apply(a)
			log[#log + 1] = { a = a, h = s:hash() }
			snaps[#snaps + 1] = s:snapshot()
			n = n + 1
			need = s:need()
		end
		if need.kind == "throw" then
			if need.cpu then a = cpuThrow(s).action
			else a = scripted(s, r); s:apply(a) end
		elseif need.kind == "raise" then
			a = { type = "raise" }; s:apply(a)
		elseif need.kind == "punish" then
			a = { type = "punish", x = need.cursor.x, y = need.cursor.y }; s:apply(a)
		end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
		snaps[#snaps + 1] = s:snapshot()
	end
	return { s = s, snaps = snaps, log = log, h0 = h0, setup = o }
end

local function team(name, players)
	local t = { name = name, players = {} }
	for i, p in ipairs(players) do t.players[i] = { name = p } end
	return t
end

local HONEST = {
	-- several a side, the computer at pro, six batons, a scene and wind, by hand
	{ seed = 3, cpu = "both", raising = "hand", opening = "six", wind = "strong", scene = "night", computer = "pro",
		maxTurns = 12, set = "sweden",
		teams = { A = team("Wobbly Towers", { "Mighty Maple", "Lucky Larch", "Wonky Willow" }),
			B = team("The Lumberjacks", { "Jolly Juniper", "Brave Birch" }) } },
	-- a person against the computer: a side of one named after its player
	{ seed = 11, cpu = "B", raising = "hand", maxTurns = 10,
		teams = { A = team("Mighty Maple", { "Mighty Maple" }), B = { name = "Computer", players = { { name = "Computer" } } } } },
	-- pass and play, raising automatically, on sand, with keys and levels as a pitch gives them
	{ seed = 21, cpu = {}, raising = "auto", maxTurns = 8, surface = "sand",
		teams = { A = { name = "Team A", players = { { name = "Lucky Larch", key = "m1", level = "club" },
			{ name = "Player 2", key = "m2", level = "club" } } },
			B = team("Birch Batons", { "Jolly Juniper", "Brave Birch" }) } },
	-- the engine's defaults: no names at all, to a king (or the turn limit)
	{ seed = 5, cpu = "both", maxTurns = 30, surface = "snow" },
	-- two people by hand, through punishment kubbs (the punish queue, the settle state),
	-- and a resignation waiting for its side's turn
	{ seed = 11, cpu = {}, raising = "hand", maxTurns = 14, resignAt = 60,
		teams = { A = team("Mighty Maple", { "Mighty Maple" }), B = team("Lucky Larch", { "Lucky Larch" }) } },
}

local RUNS = {}
local function runs()
	if #RUNS == 0 then for i, o in ipairs(HONEST) do RUNS[i] = play(o) end end
	return RUNS
end

local function refusedAt(rep, from)
	for _, r in ipairs(rep.refused) do if r.from == from then return r end end
	return nil
end
local function mismatchAt(rep, from)
	for _, m in ipairs(rep.mismatches) do if m.from == from then return m end end
	return nil
end
local function why(rep)
	local out = {}
	for _, r in ipairs(rep.refused) do out[#out + 1] = r.from .. " " .. tostring(r.text) .. ": " .. r.why end
	for _, m in ipairs(rep.mismatches) do out[#out + 1] = m.from .. " differs" end
	return table.concat(out, "; ")
end

-- A snapshot of a match of several a side part way, with names everywhere: the one the
-- forgeries below are made from.
local function base()
	local r = runs()[1]
	return json.decode(r.snaps[math.min(#r.snaps, 40)])
end
local function check(d) return call("names.check", { snap = type(d) == "string" and d or json.encode(d) }) end
local function forged(d, from, what)
	local rep = check(d)
	expect.eq(rep.allowed, false, what .. ": not allowed")
	expect.truthy(refusedAt(rep, from) or mismatchAt(rep, from), what .. ": refused at " .. from .. " (" .. why(rep) .. ")")
	return rep
end

test("names.check: every snapshot of honest matches is allowed, every place looked at", function()
	local total, punished, pending, over = 0, false, false, 0
	for i, r in ipairs(runs()) do
		for k, snap in ipairs(r.snaps) do
			local d = json.decode(snap)
			punished = punished or (d.save.game.punishQueue and #d.save.game.punishQueue > 0) or false
			pending = pending or d.resignPending ~= nil
			if d.save.game.phase == "over" then over = over + 1 end
			local rep = check(snap)
			expect.eq(rep.what, "snapshot")
			expect.truthy(rep.allowed, "match " .. i .. " snapshot " .. k .. ": " .. why(rep))
			total = total + 1
		end
		-- the decoded object as well as the text
		expect.truthy(call("names.check", { snap = json.decode(r.snaps[#r.snaps]) }).allowed, "the object")
	end
	-- the names come back with where they are, both copies of each
	local rep = check(runs()[1].snaps[1])
	local seen = {}
	for _, n in ipairs(rep.names) do seen[n.from] = n end
	expect.eq(seen["opts.teams.A.name"].text, "Wobbly Towers")
	expect.eq(seen["save.game.teams.A.name"].kind, "team")
	expect.eq(seen["save.game.teams.B.players[1].name"].text, "Brave Birch")
	expect.eq(seen["save.game.teams.B.players[1].name"].ok, true)
	expect.eq(#rep.ids, 5)
	expect.eq(rep.ids[1].text, "mighty_maple")
	expect.eq(rep.ids[1].name, "Mighty Maple")
	expect.truthy(total > 100, total .. " snapshots")
	-- the matches reach the places a short match does not
	expect.truthy(punished, "a punishment kubb waiting")
	expect.truthy(pending, "a resignation waiting")
	expect.truthy(over >= #runs(), "every match to its end")
end)

test("names.check: a side of one named after its player, and the engine's defaults, are allowed", function()
	local rep = check(runs()[2].snaps[1])
	expect.truthy(rep.allowed, why(rep))
	for _, n in ipairs(rep.names) do
		if n.from == "save.game.teams.A.name" then
			expect.eq(n.text, "Mighty Maple")
			expect.eq(n.as, "player")
			expect.eq(n.ok, true)
		end
		if n.text == "Computer" then expect.eq(n.default, true) end
	end
	local d = check(runs()[4].snaps[#runs()[4].snaps])
	expect.truthy(d.allowed, why(d))
	local defaults = 0
	for _, n in ipairs(d.names) do if n.default then defaults = defaults + 1 end end
	expect.eq(defaults, #d.names, "every name a default")
	-- a team name on a side of several is not a player's
	local x = base()
	x.opts.teams.A.name, x.save.game.teams.A.name = "Mighty Maple", "Mighty Maple"
	forged(x, "save.game.teams.A.name", "a player's name for a team of three")
end)

test("names.check: the reviewer's forgery (generated opts, typed save) is caught", function()
	local d = base()
	d.save.game.teams.A.name = "Rude Words Here"
	for i, p in ipairs(d.save.game.teams.A.players) do p.name = "Typed " .. i end
	local rep = forged(d, "save.game.teams.A.name", "typed save names")
	expect.truthy(refusedAt(rep, "save.game.teams.A.players[0].name"), "a typed player")
	expect.truthy(mismatchAt(rep, "save.game.teams.A.name"), "opts and save disagree")
	expect.truthy(refusedAt(rep, "save.game.teams.A.players[0].id"), "the id no longer comes from the name")
	-- every name in opts is still a generated one: a check of opts alone would pass it
	for _, n in ipairs(rep.names) do
		if n.from:match("^opts") then expect.truthy(n.ok or n.default, n.from) end
	end
	-- and with the ids made to match the typed names, still caught
	local e = base()
	e.save.game.teams.A.players[1].name = "Typed Name"
	e.save.game.teams.A.players[1].id = "typed_name"
	forged(e, "save.game.teams.A.players[0].name", "a typed name with its id")
end)

test("two sides with one name: an honest resignation is allowed (Player 1 resigned: Player 1 wins)", function()
	-- as a pitch makes it: one unnamed player a side, each "Player 1", each side named after its player
	local one = { name = "Player 1", players = { { name = "Player 1" } } }
	local run = play({ seed = 3, cpu = {}, raising = "auto", maxTurns = 12, resignAt = 6,
		teams = { A = copy(one), B = copy(one) } })
	local sawRuling = false
	for i, snap in ipairs(run.snaps) do
		local rep = call("names.check", { snap = snap })
		expect.truthy(rep.allowed, "snapshot " .. i .. ": " .. json.encode(rep.refused))
		for _, l in ipairs(rep.lines) do
			if l.text == "Player 1 resigned: Player 1 wins" then sawRuling = true end
		end
	end
	expect.truthy(sawRuling, "the match ended on the resignation ruling")
	local last = run.snaps[#run.snaps]
	expect.truthy(call("restore", { snap = last, names = "check" }), "and the strict restore takes it")
end)

test("a name that is not a text is refused, even when both copies agree", function()
	for _, bad in ipairs { 12345, true, { "x" } } do
		local d = base()
		d.opts.teams.A.name = bad
		d.save.game.teams.A.name = copy(bad)
		local rep = call("names.check", { snap = d })
		expect.eq(rep.allowed, false)
		expect.truthy(refusedAt(rep, "save.game.teams.A.name"), "the save's, as " .. type(bad))
		expect.truthy(refusedAt(rep, "opts.teams.A.name"), "the options', as " .. type(bad))
		expect.truthy(refused("restore", { snap = d, names = "check" }), "and the strict restore refuses it")
	end
	local e = base()
	e.save.game.teams.A.players[1].name = 7
	expect.truthy(refusedAt(call("names.check", { snap = e }), "save.game.teams.A.players[0].name"), "a player's")
	local f = base()
	f.save.text = 99
	expect.eq(call("names.check", { snap = f }).allowed, false)
	-- and an id: the sheet writes it as it is
	local g = base()
	g.save.game.teams.A.players[1].id = 4242
	expect.eq(call("names.check", { snap = g }).allowed, false)
end)

test("a place is safe to show: a forged key never reaches the report's place or the strict error", function()
	local d = base()
	d["Anything Typed"] = "x"
	d.save.game["Rude Key Here"] = { deep = "y" }
	d.save.game.teams.A.name = "Typed Team"
	local rep = call("names.check", { snap = d })
	expect.eq(rep.allowed, false)
	local sawForged = false
	for _, r in ipairs(rep.refused) do
		expect.truthy(not r.place:find("Typed", 1, true) and not r.place:find("Rude", 1, true), r.place)
		if r.from:find("Anything Typed", 1, true) then
			sawForged = true
			expect.eq(r.place, "?")
		end
	end
	expect.truthy(sawForged, "the forged key is reported, under its raw path")
	for _, m in ipairs(rep.mismatches) do
		expect.truthy(not m.place:find("Typed", 1, true) and not m.otherPlace:find("Typed", 1, true), m.place)
	end
	expect.eq(tw.web.namecheck.place("save.game.teams.A.players[0].name"), "save.game.teams.A.players[0].name")
	expect.eq(tw.web.namecheck.place("save.game.Rude Key Here.deep"), "save.game.?.?")
	local why = refused("restore", { snap = d, names = "check" })
	expect.truthy(why and why:find("names not allowed", 1, true), tostring(why))
	expect.truthy(not why:find("Typed", 1, true) and not why:find("Rude", 1, true) and not why:find("Anything", 1, true), why)
end)

test("names.check: a forged name or text in each place is refused", function()
	local cases = {
		{ "save.game.teams.B.players[0].name", "a player's name (the thrower, the rail)",
			function(d) d.save.game.teams.B.players[1].name = "Hello There" end },
		{ "save.game.teams.A.name", "the rail's team name, valid in opts",
			function(d) d.save.game.teams.A.name = "Big Fan" end },
		{ "opts.teams.B.name", "the options' team name (a replay's, a rename's)",
			function(d) d.opts.teams.B.name = "Big Fan" end },
		{ "opts.teams.A.players[2].name", "an options' player name",
			function(d) d.opts.teams.A.players[3].name = "Big Fan" end },
		{ "save.game.teams.A.players[1].id", "a player's id (the sheet writes it)",
			function(d) d.save.game.teams.A.players[2].id = "rude" end },
		{ "save.game.sheet.turns[0].batons[0].player", "a turn line's player id",
			function(d) d.save.game.sheet.turns[1].batons[1].player = "rude" end },
		{ "save.text", "the ruling line",
			function(d) d.save.text = "anything at all" end },
		{ "save.game.sheet.turns[0].notes[0]", "a turn line's note",
			function(d) d.save.game.sheet.turns[1].notes = { "a rude note" } end },
		{ "save.game.sheet.turns[0].batons[0].token", "a baton token",
			function(d) d.save.game.sheet.turns[1].batons[1].token = "RUDE" end },
		{ "save.mode", "the sheet's mode",
			function(d) d.save.mode = "Rude Mode" end },
		{ "opts.mode", "the options' mode",
			function(d) d.opts.mode = "Rude Mode"; d.save.mode = "Rude Mode" end },
		{ "save.game.how", "how it ended (the winner card)",
			function(d) d.save.game.how = "rude" end },
		{ "save.game.surface", "the sheet's surface",
			function(d) d.save.game.surface = "Rude" end },
		{ "save.game.first", "the sheet's first team",
			function(d) d.save.game.first = "A rude" end },
		{ "save.lineup.A[0].level", "a throw level ([Throw Levels])",
			function(d) d.save.lineup.A[1].level = "rude" end },
		{ "opts.set", "a kubb set",
			function(d) d.opts.set = "rude words" end },
		{ "save.game.kubbs.a1.inkBy", "a kubb's thrower",
			function(d) d.save.game.kubbs.a1.inkBy = "rude" end },
		{ "save.game.sheet.turns[0].n", "a number made text (a turn line writes it)",
			function(d) d.save.game.sheet.turns[1].n = "rude" end },
		{ "save.game.extra", "a text where the engine writes none",
			function(d) d.save.game.extra = "rude" end },
		{ "save.game.sheet.turns[0].inkast.rude", "a map's key",
			function(d) d.save.game.sheet.turns[1].inkast.rude = { I = 1 } end },
	}
	for _, c in ipairs(cases) do
		local d = base()
		c[3](d)
		forged(d, c[1], c[2])
	end
	-- nested past any honest snapshot
	local d = base()
	local t = d.save.game
	for _ = 1, 30 do t.deep = {}; t = t.deep end
	expect.eq(check(d).allowed, false, "nested too deep")
	-- not a snapshot at all: refused, not an error
	expect.eq(check("{}").allowed, false)
	expect.eq(check("not json").allowed, false)
end)

test("names.check: an old match with typed names is not allowed, and still restores without the check", function()
	local r = play({ seed = 9, cpu = "B", maxTurns = 4,
		teams = { A = team("Riverside", { "Ann" }), B = team("Computer", { "Computer" }) } }, 6)
	local snap = r.snaps[#r.snaps]
	local rep = check(snap)
	expect.eq(rep.allowed, false)
	expect.truthy(refusedAt(rep, "save.game.teams.A.name"))
	expect.truthy(refusedAt(rep, "save.game.teams.A.players[0].name"))
	-- the strict door refuses it, naming places, never the text
	local err = refused("restore", { snap = snap, names = "check" })
	expect.truthy(err and err:find("names not allowed: ", 1, true), tostring(err))
	expect.truthy(not err:find("Riverside", 1, true), "the error does not repeat the name")
	-- the plain door restores it, as before
	local v = call("restore", snap)
	expect.truthy(v.need, "restored")
	expect.eq(call("hash").hash, session.fnv(snap))
	-- and the wrapper without names is the plain door too
	expect.truthy(call("restore", { snap = snap }).need)
	expect.truthy(refused("restore", { snap = snap, names = "yes" }), "names is \"check\" or absent")
end)

test("strict restore: an honest snapshot restores to the same hash; a refused one changes nothing", function()
	local honest = runs()[1].snaps[30]
	call("restore", { snap = honest, names = "check" })
	expect.eq(call("hash").hash, session.fnv(honest))
	local d = json.decode(honest)
	d.save.game.teams.A.name = "Big Fan"
	expect.truthy(refused("restore", { snap = json.encode(d), names = "check" }))
	expect.eq(call("hash").hash, session.fnv(honest), "the session is the one before")
	-- Lua callers: session.restore(text, control, { names = "check" })
	local ok = pcall(session.restore, json.encode(d), nil, { names = "check" })
	expect.eq(ok, false)
	expect.truthy(session.restore(json.encode(d)), "without it, restored")
end)

test("names.check changes no state: the session, the snapshot, the setup", function()
	local honest = runs()[3].snaps[12]
	call("restore", honest)
	local h = call("hash").hash
	local view = _G.kubbCall("view", "")
	local obj = json.decode(honest)
	local before = json.encode(obj)
	call("names.check", { snap = honest })
	local d = json.decode(honest)
	d.save.game.teams.A.name = "Big Fan"
	call("names.check", { snap = json.encode(d) })
	local r = runs()[3]
	local setup = copy(r.setup)
	call("names.check", { replay = { setup = setup, h0 = r.h0, log = r.log } })
	expect.eq(call("hash").hash, h, "the live session's hash")
	expect.eq(_G.kubbCall("view", ""), view, "the live session's view")
	expect.eq(json.encode(setup), json.encode(r.setup), "the setup as given")
	-- the Lua call leaves an object it is given as it was
	tw.web.namecheck.snapshot(obj)
	expect.eq(json.encode(obj), before)
end)

test("names.check: a replay (setup or start, snap, players, log) and replayLoad's names = \"check\"", function()
	local r = runs()[1]
	local rep = call("names.check", { replay = { setup = r.setup, h0 = r.h0, log = r.log, snap = r.snaps[#r.snaps],
		players = { A = { { id = "m1", name = "Mighty Maple" } }, B = {} } } })
	expect.eq(rep.what, "replay")
	expect.truthy(rep.allowed, why(rep))
	local fromStart = call("names.check", { replay = { start = r.snaps[1], log = r.log } })
	expect.truthy(fromStart.allowed, why(fromStart))
	local cases = {
		{ "setup.teams.A.name", function(x) x.setup = copy(x.setup); x.setup.teams.A.name = "Big Fan" end },
		{ "setup.teams.B.players[0].name", function(x) x.setup = copy(x.setup); x.setup.teams.B.players[1] = "Big Fan" end },
		{ "setup.mode", function(x) x.setup = copy(x.setup); x.setup.modeName = "Rude Mode" end },
		{ "players.A[0].name", function(x) x.players = { A = { { id = "m1", name = "Big Fan" } } } end },
		{ "snap.save.game.teams.A.name", function(x)
			local d = json.decode(x.snap); d.save.game.teams.A.name = "Big Fan"; x.snap = json.encode(d) end },
		{ "start.save.game.teams.B.name", function(x)
			local d = json.decode(r.snaps[1]); d.save.game.teams.B.name = "Big Fan"
			x.setup = nil; x.start = json.encode(d) end },
	}
	for _, c in ipairs(cases) do
		local x = { setup = r.setup, h0 = r.h0, log = r.log, snap = r.snaps[#r.snaps] }
		c[2](x)
		local out = call("names.check", { replay = x })
		expect.eq(out.allowed, false, c[1])
		expect.truthy(refusedAt(out, c[1]) or mismatchAt(out, c[1]), c[1] .. ": " .. why(out))
	end
	-- a thrower action naming nobody of the match
	local log = copy(r.log)
	table.insert(log, 1, { a = { type = "thrower", id = "rude" } })
	local t = call("names.check", { replay = { setup = r.setup, log = log } })
	expect.truthy(refusedAt(t, "log[0].a.id"), why(t))
	-- replayLoad refuses a forged one with names = "check", and loads an honest one
	local v = call("replayLoad", { setup = r.setup, h0 = r.h0, log = r.log, names = "check" })
	expect.eq(v.replay.differs, false)
	local bad = copy(r.setup)
	bad.teams.A.name = "Big Fan"
	expect.truthy(refused("replayLoad", { setup = bad, h0 = r.h0, log = r.log, names = "check" }))
	-- and the refusal left the replay already loaded where it was: it still steps
	expect.truthy(call("replayStep").replay, "the honest replay is still loaded after a refused one")
	expect.truthy(call("replayLoad", { setup = bad, log = r.log }).replay, "without it, loaded")
	call("replayEnd")
end)

test("names.check: a pitch's document, its team names, its match and its members", function()
	local r = runs()[1]
	local doc = {
		v = 1, teams = { A = { "m1", "m2", "m3" }, B = { "m4" } }, open = false, started = true, n = 1,
		teamNames = { A = "Wobbly Towers", B = "Jolly Juniper" },
		match = { n = 1, seq = #r.log, snap = r.snaps[#r.snaps], hash = "x", setup = r.setup, h0 = r.h0, log = r.log,
			players = { A = { { id = "m1", name = "Mighty Maple" } }, B = { { id = "m4", name = "Jolly Juniper" } } },
			over = true },
	}
	local members = { { id = "m1", me = { name = "Mighty Maple" } }, { id = "m4", me = { name = "Jolly Juniper" } },
		{ id = "m5", me = { name = "" } } }
	local rep = call("names.check", { document = doc, members = members })
	expect.eq(rep.what, "document")
	expect.truthy(rep.allowed, why(rep))
	local cases = {
		{ "teamNames.A", function(d) d.teamNames.A = "Big Fan" end },
		{ "match.players.B[0].name", function(d) d.match.players.B[1].name = "Big Fan" end },
		{ "match.snap.save.game.teams.A.players[0].name", function(d)
			local s = json.decode(d.match.snap); s.save.game.teams.A.players[1].name = "Big Fan"; d.match.snap = json.encode(s) end },
		{ "members[1].me.name", function(_, m) m[2].me.name = "Big Fan" end },
	}
	for _, c in ipairs(cases) do
		local d, m = copy(doc), copy(members)
		c[2](d, m)
		local out = call("names.check", { document = d, members = m })
		expect.eq(out.allowed, false, c[1])
		expect.truthy(refusedAt(out, c[1]), c[1] .. ": " .. why(out))
	end
	expect.truthy(refused("names.check", { snap = r.snaps[1], replay = {} }), "one thing at a time")
	expect.truthy(refused("names.check", {}), "something to check")
end)
