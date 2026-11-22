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

test("the game file's [Throw Levels] names the computer's level, and only the computer's", function()
	local s = vsComputer { computer = "pro" }
	-- a restored session (m.cpu set again from its options) writes the same header
	expect.eq(session.restore(s:snapshot()):sheet().text:match('%[Throw Levels "([^"]*)"%]'), "computer pro")
	local start = s:snapshot()
	local log = playOut(s)
	local text = s:sheet().text
	-- and a replay of the match ends on the same file
	local r = replay.new { start = start, log = log }
	expect.eq(r:finish().differs, false)
	expect.eq(r.s:sheet().text:match('%[Throw Levels "([^"]*)"%]'), "computer pro")
	local line = text:match('%[Throw Levels "([^"]*)"%]')
	expect.eq(line, "computer pro", "the computer's level alone (0.13.2)")
	expect.truthy(not text:find("beginner", 1, true), "not the person's")
	local plain = vsComputer()
	playOut(plain)
	local l2 = plain:sheet().text:match('%[Throw Levels "([^"]*)"%]')
	expect.eq(l2, "computer " .. autothrow.tune.level, "without the option: the level it throws at")
	-- pass and play: no computer, no header, the people's levels notwithstanding
	local pp = session.new { mode = "match", seed = 11, start = START, raising = "auto", maxTurns = 2,
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "beginner" } } },
			B = { name = "Bo", players = { { name = "Bo", level = "pro" } } } } }
	expect.eq(pp:sheet().text:match('%[Throw Levels'), nil)
	-- computer against computer: both
	local cc = session.new { mode = "match", seed = 11, cpu = "both", computer = "pro", start = START,
		raising = "auto", maxTurns = 2 }
	expect.eq(cc:sheet().text:match('%[Throw Levels "([^"]*)"%]'), "team_a pro, team_b pro")
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
	expect.eq(row[3][1][1], "kid", "Kid first (0.15.0)")
	expect.eq(row[3][3][2], "Club")
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
	-- Kid (0.15.0): kept as the fourth value, so a choice kept before keeps its level, and
	-- stepped to first: left of Beginner, and right of Pro round to it
	c = matchopts.defaults()
	matchopts.step(c, "computer", -1)
	expect.eq(matchopts.value(c, "computer"), "beginner")
	matchopts.step(c, "computer", -1)
	expect.eq(matchopts.value(c, "computer"), "kid")
	expect.eq(matchopts.shown(c, "computer"), "KID")
	local o = matchopts.apply({}, c)
	expect.eq(o.computer, "kid")
	expect.eq(o.rules, "kid", "the Kid computer makes a Kid match")
	matchopts.step(c, "computer", -1)
	expect.eq(matchopts.value(c, "computer"), "pro", "round from Kid to Pro")
	expect.eq(matchopts.apply({}, c).rules, nil)
	expect.eq(matchopts.valid({ computer = 4 }).computer, 4, "Kid kept")
end)

-- Kid (0.15.0, docs/notes/kid-mode.md): the Kid computer makes the match a Kid match, the
-- Kid rules for both sides and the Kid meter for a person; the view says so and where the
-- Kid line is; the snapshot keeps it; a match without it is as before.
test("the Kid computer makes a Kid match: the rules, the meter, the view", function()
	local s = vsComputer { computer = "kid", first = "A" }
	expect.eq(s.opts.computer, "kid")
	expect.eq(s.opts.rules, "kid")
	expect.eq(s.m.game.rules, "kid")
	expect.eq(s.ts.meter, "kid")
	expect.eq(s.opts.teams.B.players[1].level, "kid")
	local n = s:need()
	expect.eq(n.kid, true)
	expect.eq(n.setup.kid, true)
	expect.eq(n.setup.kidY, 2)
	expect.eq(n.setup.forwardY, 2, "the person stands up to the Kid line")
	local v = s:view()
	expect.eq(v.aim.kidY, 2)
	expect.eq(v.minimap.kidY, 2)
	expect.eq(v.aim.thrower.y, 2, "the stance starts on the Kid line")
	expect.eq(v.aim.advText, "KID LINE  2.0 M")
	-- the person's bars are the Kid meter's: wider than the standard's at the same distance
	local plan = tw.plan
	local d = v.aim.plan.dist
	local kid = plan.meterLevel(plan.meter("kid"), d, "baton")
	local std = plan.meterLevel(plan.meter(), d, "baton")
	expect.near(v.aim.plan.powerHi - v.aim.plan.powerLo, 2 * kid.powerHalf, 1e-9)
	expect.truthy(kid.powerHalf > 3 * std.powerHalf, "much wider")
	-- the snapshot keeps it, restore brings it back, names.check allows it
	local snap = s:snapshot()
	expect.truthy(snap:find('"rules":"kid"', 1, true))
	local r = session.restore(snap)
	expect.eq(r.m.game.rules, "kid"); expect.eq(r.ts.meter, "kid")
	local nc = json.decode(kubbCall("names.check", json.encode({ snap = snap })))
	-- (Ada is a typed name, refused as one; nothing else may be)
	for _, x in ipairs(nc.refused) do
		expect.truthy(x.kind == "team" or x.kind == "player", "only the typed name: " .. json.encode(x))
	end
	-- the Kid rules' notes and ruling words are the engine's own
	local d = json.decode(snap)
	local t1 = d.save.game.sheet.turns[1]
	t1.notes = { "b1 knocked the king down early; stood back up (kid rules)", "b2 helicopter; counted (kid rules)",
		"a kubb thrown in knocked the king down; stood back up (kid rules)",
		"a kubb out twice was stood at the fair spot, no punishment kubb (kid rules)" }
	d.save.text = "field kubb down; king down early: stood back up; helicopter: counted"
	local nc2 = json.decode(kubbCall("names.check", json.encode({ snap = d })))
	for _, x in ipairs(nc2.refused) do
		expect.truthy(x.kind == "team" or x.kind == "player", "the Kid words are allowed: " .. json.encode(x))
	end
	d.save.text = "out twice: stood at the fair spot; king down: stood back up; 2 out twice: stood at the fair spot"
	nc2 = json.decode(kubbCall("names.check", json.encode({ snap = d })))
	for _, x in ipairs(nc2.refused) do
		expect.truthy(x.kind == "team" or x.kind == "player", "the Kid words are allowed: " .. json.encode(x))
	end
	-- a helicopter counts in a Kid match, so its recording's flag says what it did, never
	-- HELICOPTER (0.15.1; the standard game's flag is unchanged)
	for _, kidMatch in ipairs { true, false } do
		local h = vsComputer { computer = kidMatch and "kid" or "club", first = "A" }
		local c = autothrow.choose(h.setup, autothrow.rng(42), 1)
		tw.web.throw.showAim(h.ts, c)
		local L, how = tw.web.throw.cpuLaunch(h.ts, c)
		h.ts.playerX, h.ts.playerY = c.x, c.y
		L.tilt, L.legal = 80, false
		local out = h:apply(json.decode(json.encode(h:throwAction(L, how, { scripted = true, back = c.swing.back,
			stop = c.swing.releaseAngle }))))
		local flag = out.recording.result.flag
		if kidMatch then
			expect.truthy(flag == "MISS" or flag:find(" DOWN$"), "a Kid helicopter's flag: " .. tostring(flag))
			expect.truthy(h.m.text:find("helicopter: counted", 1, true), h.m.text)
		else
			expect.eq(flag, "HELICOPTER")
		end
	end
	-- the Kid computer with nobody to play (pass and play): no Kid rules; asked outright: yes
	local pp = session.new { mode = "match", seed = 3, start = START, computer = "kid" }
	expect.eq(pp.opts.rules, nil)
	local pk = session.new { mode = "match", seed = 3, start = START, rules = "kid" }
	expect.eq(pk.opts.rules, "kid"); expect.eq(pk.m.game.rules, "kid")
	-- every other level: as before, no rules key
	expect.truthy(not vsComputer { computer = "pro" }:snapshot():find('"rules":', 1, true))
end)

test("a Kid match plays to its end, and its file passes as Kid rules with three base kubbs", function()
	local s = vsComputer { computer = "kid", maxTurns = 30 }
	playOut(s)
	expect.eq(s:need().kind, "over")
	local sh = s:sheet()
	expect.truthy(sh.text:find('[Base kubbs "3"]', 1, true))
	expect.truthy(sh.text:find("[Rules \"Kid rules", 1, true))
	expect.truthy(sh.text:find("kid", 1, true), "Throw Levels names the Kid computer")
	local nc = json.decode(kubbCall("names.check", json.encode({ snap = s:snapshot() })))
	-- (Ada is a typed name, refused as one; nothing else may be)
	for _, x in ipairs(nc.refused) do
		expect.truthy(x.kind == "team" or x.kind == "player", "only the typed name: " .. json.encode(x))
	end
end)

test("the pitch: the Computer row has Kid first, and a pitch with the Kid computer starts a Kid match", function()
	local row = pitch("optionRows", { scene = "day" }).rows
	local comp = row[#row]
	expect.eq(comp[1], "computer"); expect.eq(comp[3][1][1], "kid"); expect.eq(comp[3][1][2], "Kid")
	expect.eq(pitch("optionLabel", { key = "computer", value = "kid" }), "Kid")
	local d = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	d = pitch("setOptions", { doc = d, options = { computer = "kid" } })
	local lu = pitch("lineup", { doc = d, members = { { id = "m1", me = { name = "Ada" } } } })
	local o = pitch("matchOptions", { doc = d, lineup = lu, seed = 5, start = START })
	expect.eq(o.computer, "kid")
	o.mode = "match"
	local s = session.new(o)
	expect.eq(s.opts.rules, "kid")
	expect.eq(pitch("constants", {}).LEVELS[1], "kid")
end)
