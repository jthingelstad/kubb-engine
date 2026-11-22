-- The computer's level is a game setting (Jamie, 2026-11-20: "yes this should be a real
-- per game setting"): the match option `computer` (beginner, club or pro; absent: club,
-- as before), in newMatch, the start, checkStart and renameStart, restore, replay, the
-- game file's [Throw Levels], the pitch's options and the Playdate's option table.
import "session/session"
import "session/json"
import "session/check"
import "session/replay"
import "session/api"
import "core/autothrow"
import "core/matchopts"
import "pitch/lobby"
tw.web.session.useTune("pointer")
local session, json, check, replay, autothrow = tw.web.session, tw.web.json, tw.web.check, tw.web.replay,
	tw.autothrow
local matchopts, lobby, NULL = tw.matchopts, tw.shared.lobby, tw.web.json.null

local START = { year = 2026, month = 11, day = 20, hour = 11, min = 0 }

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

local function vsComputer(o)
	local m = { mode = "match", seed = 11, cpu = "B", start = START, raising = "auto", maxTurns = 6,
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "beginner", key = "m1" } } } } }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

-- Play the match out: the person's throws are the computer's choice at club, scripted.
local function playOut(s)
	local log = {}
	local r = autothrow.rng(42)
	for _ = 1, 2000 do
		local n = s:need()
		if n.kind == "over" then break end
		local a
		if n.kind == "raise" then
			a = { type = "raise" }
			s:apply(a)
		elseif n.kind == "punish" then
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
			s:apply(a)
		elseif n.cpu then
			for _ = 1, 2000 do
				local f = s:frame { dt = 1 / 30 }
				if f.action then a = f.action break end
			end
		else
			local ts = s.ts
			local c = autothrow.choose(s.setup, r, 1)
			tw.web.throw.showAim(ts, c)
			local L, how = tw.web.throw.cpuLaunch(ts, c)
			ts.playerX, ts.playerY = c.x, c.y
			a = json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
				stop = c.swing.releaseAngle })))
			s:apply(a)
		end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
	end
	return log
end

test("the computer takes the match's level; a person keeps their own", function()
	local s = vsComputer { computer = "pro" }
	expect.eq(s.opts.computer, "pro")
	expect.eq(s.opts.teams.B.players[1].level, "pro", "the computer's player (made by the session)")
	expect.eq(s.opts.teams.A.players[1].level, "beginner", "the person's own level")
	-- the computer's throws are chosen at pro (autothrow.choose reads the thrower's level)
	local b = vsComputer { computer = "pro", first = "B" }
	local n = b:need()
	expect.eq(n.cpu, true)
	expect.eq(n.setup.thrower.level, "pro")
	-- an entry that names its own level keeps it
	local t = vsComputer { computer = "beginner",
		teams = { A = { name = "Ada", players = { { name = "Ada" } } },
			B = { name = "Computer", players = { { name = "Computer", level = "pro" } } } } }
	expect.eq(t.opts.teams.B.players[1].level, "pro")
	expect.eq(t.opts.teams.A.players[1].level, nil, "a person is never given the computer's level")
end)

test("without the option nothing changes: no key, no level, the snapshot as before", function()
	local s = vsComputer()
	expect.eq(s.opts.computer, nil)
	expect.eq(s.opts.teams.B.players[1].level, nil, "the computer throws at club by default")
	expect.truthy(not s:snapshot():find('"computer":', 1, true), "no computer key in the snapshot")
	-- an unknown value is no option
	expect.eq(vsComputer({ computer = "legend" }).opts.computer, nil)
	expect.eq(vsComputer({ computer = "club" }):snapshot(), s:snapshot(),
		"club, the default, named or not: the same start as before")
end)

test("a different level is a different match: the computer's throws change", function()
	local club = vsComputer { cpu = "both", computer = "club", teams = {} }
	expect.eq(club.opts.computer, nil, "the default is not written")
	local pro = vsComputer { cpu = "both", computer = "pro", teams = {} }
	local differ = false
	for _ = 1, 20 do
		local a1, a2
		for _ = 1, 2000 do local f = club:frame { dt = 1 / 30 }; if f.action then a1 = f.action break end end
		for _ = 1, 2000 do local f = pro:frame { dt = 1 / 30 }; if f.action then a2 = f.action break end end
		if not (a1 and a2) then break end
		if not check.same(a1, a2) then differ = true break end
	end
	expect.truthy(differ, "pro throws otherwise than club")
	-- watch mode: both sides take it
	expect.eq(pro.opts.teams.A.players[1].level, "pro")
	expect.eq(pro.opts.teams.B.players[1].level, "pro")
end)

test("checkStart, renameStart, restore and replay keep the computer's level", function()
	local s = vsComputer { computer = "pro" }
	local start = s:snapshot()
	local ok, why = session.startCheck(start)
	expect.eq(ok, true, tostring(why))
	-- an entry's own level is kept, so a start whose computer names its level is a start
	local own = start:gsub('"level":"pro"', '"level":"club"')
	expect.truthy(own ~= start)
	local ok2, why2 = session.startCheck(own)
	expect.eq(ok2, true, "a level the entry names is its own: " .. tostring(why2))
	local bad = start:gsub('"computer":"pro"', '"computer":"legend"')
	expect.eq((session.startCheck(bad)), false, "an unknown level is not a start")
	local renamed = session.renameStart(start, { A = "Bea" })
	local rd = json.decode(renamed)
	expect.eq(rd.opts.computer, "pro")
	expect.eq(rd.opts.teams.B.players[1].level, "pro")
	expect.eq(session.restore(start).opts.computer, "pro")
	local log = playOut(s)
	local r = replay.new { start = start, log = log, checkCpu = true }
	local info = r:finish()
	expect.eq(info.differs, false)
	expect.eq(info.forged, false)
	-- from the setup (newMatch's options) too
	local setup = session.setupOf(start)
	local r2 = replay.new { setup = setup, log = log }
	expect.eq(r2:finish().differs, false)
	-- the pitch document of the replay names the option
	local r3 = replay.new { start = start, log = log, document = true }
	r3:finish()
	local doc, dwhy = r3:document()
	expect.truthy(doc, tostring(dwhy))
	expect.eq(doc.settings.computer, "pro")
end)

test("the game file's [Throw Levels] names the computer's level", function()
	local s = vsComputer { computer = "pro" }
	playOut(s)
	local text = s:sheet().text
	local line = text:match('%[Throw Levels "([^"]*)"%]')
	expect.truthy(line and line:find("pro", 1, true), "the computer's level: " .. tostring(line))
	expect.truthy(line:find("beginner", 1, true), "and the person's")
	local plain = vsComputer()
	playOut(plain)
	local l2 = plain:sheet().text:match('%[Throw Levels "([^"]*)"%]')
	expect.truthy(l2 and not l2:find("club", 1, true) and not l2:find("pro", 1, true),
		"without the option only the person's, as before: " .. tostring(l2))
end)

test("the pitch: the host picks the computer's level; a pitch without it is as before", function()
	local doc = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	expect.eq(doc.settings, nil, "absent until set")
	expect.eq(pitch("optionsOf", { doc = doc }).computer, "club", "absent: the default")
	doc = pitch("setOptions", { doc = doc, options = { computer = "pro" } })
	expect.eq(doc.settings.computer, "pro")
	expect.eq(doc.options.computer, nil)
	expect.eq(doc.options.surface, "grass")
	expect.eq(pitch("optionsOf", { doc = doc }).computer, "pro")
	expect.eq(pitch("setOptions", { doc = doc, options = { computer = "legend" } }), nil, "an unknown level changes nothing")
	expect.eq(pitch("lobbyOf", { doc = { settings = { computer = "legend" } } }).settings, nil, "an invalid one is dropped")
	local lu = pitch("lineup", { doc = doc, members = { { id = "m1", me = { name = "Ada", level = "club" } } } })
	local o = pitch("matchOptions", { doc = doc, lineup = lu, seed = 5, start = START })
	expect.eq(o.computer, "pro")
	o.mode = "match"
	local s = session.new(o)
	expect.eq(s.opts.teams.B.players[1].level, "pro", "the empty side's computer plays at the host's level")
	expect.eq(s.opts.teams.A.players[1].level, "club", "the member's own level")
	-- a pitch without the option starts what it always did
	local d0 = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	local o0 = pitch("matchOptions", { doc = d0, lineup = lu, seed = 5, start = START })
	expect.eq(o0.computer, nil)
	o0.mode = "match"
	expect.eq(session.new(o0).opts.teams.B.players[1].level, nil)
	-- the constants a client draws the option from
	local c = pitch("constants", {})
	expect.eq(c.OPTION_DEFAULTS.computer, "club")
	local row = c.MATCH_OPTIONS[#c.MATCH_OPTIONS]
	expect.eq(row[1], "computer")
	expect.eq(row[2], "Computer")
	expect.eq(row[3][2][2], "Club")
	expect.eq(pitch("optionLabel", { key = "computer", value = "pro" }), "Pro")
end)

test("the Playdate's option table: a COMPUTER row, club by default", function()
	local c = matchopts.defaults()
	expect.eq(matchopts.value(c, "computer"), "club")
	expect.eq(matchopts.shown(c, "computer"), "CLUB")
	matchopts.step(c, "computer", 1)
	expect.eq(matchopts.apply({}, c).computer, "pro")
	expect.eq(matchopts.valid({ computer = 7 }).computer, 2, "an odd choice falls back to club")
	expect.eq(matchopts.valid({}).computer, 2, "a choice kept before the row existed: club")
end)
