-- A person's throw level (1.3.0; the owner, 2026-11-26: "Easy/Standard/Hard player
-- levels as bar widths"): a player entry's `throw`, easy, standard or hard, the meter that
-- person throws on (plan.meters, throw.meterFor). In newMatch and practice, kept in the
-- start only when not standard, through snapshot, restore and replay, checked by
-- checkThrow, written in the game file's [Throw Levels], carried by the pitch (me.throw).
import "session/session"
import "session/json"
import "session/check"
import "session/replay"
import "session/namecheck"
import "session/api"
import "pitch/lobby"
tw.web.session.useTune("pointer")
local session, json, check, replay, throw = tw.web.session, tw.web.json, tw.web.check, tw.web.replay, tw.web.throw
local plan, lobby, NULL = tw.plan, tw.shared.lobby, tw.web.json.null

local START = { year = 2026, month = 11, day = 26, hour = 10, min = 0 }

local function vs(tl, o)
	local m = { mode = "match", seed = 21, cpu = "B", start = START, raising = "auto", maxTurns = 4,
		teams = { A = { name = "Ada", players = { { name = "Ada", key = "m1", throw = tl } } } } }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

-- A person's swing through the session's own launch (session/throw playerLaunch): `back`
-- and `stop` off the plan's centre by eb and er bar half widths, steady, a full flick.
local function swingAction(s, eb, er)
	local ts = s.ts
	throw.replanNow = nil
	local sol = ts.sol
	local r = {}
	for k, v in pairs(throw.CLEAN) do r[k] = v end
	r.back = sol.back + eb * sol.level.powerHalf
	r.releaseAngle = sol.release + er * sol.level.releaseHalf
	local L, how = throw.playerLaunch(ts, r)
	return json.decode(json.encode(s:throwAction(L, how, { back = r.back, stop = r.releaseAngle, verdicts = L })))
end

-- Play until it is the person's throw (the computer throws its own; raises automatic).
local function toPerson(s, kubb)
	for _ = 1, 400 do
		local n = s:need()
		if n.kind == "over" then return false end
		if n.kind == "throw" and not n.cpu and (kubb == nil or (s.ts.projectile == "kubb") == kubb) then return true end
		if n.kind == "throw" and n.cpu then
			for _ = 1, 2000 do if s:frame { dt = 1 / 30 }.action then break end end
		elseif n.kind == "throw" then
			s:apply(swingAction(s, 0, 0))
		elseif n.kind == "raise" then
			s:apply { type = "raise" }
		elseif n.kind == "punish" then
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		end
	end
	return false
end

test("throw level: newMatch keeps easy and hard on the entry, never standard, and refuses others", function()
	local plain = vs(nil):snapshot()
	expect.eq(vs("standard"):snapshot(), plain, "standard is the default: the start a match always had")
	for _, tl in ipairs { "easy", "hard" } do
		local s = vs(tl)
		expect.eq(s.opts.teams.A.players[1].throw, tl)
		expect.truthy(s:snapshot() ~= plain, tl .. " is in the start")
		expect.eq(s.m.lineup.A[1].throw, tl, "and in the lineup")
		local ok, why = session.startCheck(s:snapshot())
		expect.truthy(ok, tostring(why))
	end
	for _, bad in ipairs { "club", "kid", "EASY", 3, true } do
		expect.truthy(not pcall(vs, bad), "refused: " .. tostring(bad))
	end
	-- a computer player's entry carries no throw level
	local s = session.new { mode = "match", seed = 2, start = START,
		teams = { A = { players = { { name = "Ada", throw = "hard" }, { cpu = true, level = "pro", throw = "easy" } } },
			B = { players = { { name = "Bo" } } } } }
	expect.eq(s.opts.teams.A.players[2].throw, nil)
	expect.eq(s.m.lineup.A[2].throw, nil)
end)

test("throw level: the person throws on their level's meter, before and after a restore", function()
	for _, tl in ipairs(plan.THROW_LEVELS) do
		local s = vs(tl)
		expect.truthy(toPerson(s), "the person's throw")
		expect.eq(s.ts.sol.level.meter, plan.meters[tl], tl .. ": planned on its meter")
		expect.eq(throw.meterFor(s.ts), plan.meters[tl])
		expect.eq(s:need().setup.thrower.throw, tl ~= "standard" and tl or nil, "the thrower says so")
		local r = session.restore(s:snapshot())
		expect.eq(r.ts.sol.level.meter, plan.meters[tl], tl .. ": restored")
		-- the bars are the meter's: easy's wider, hard's narrower
		local d = s.ts.sol.dist
		expect.near(s.ts.sol.powerHi - s.ts.sol.powerLo, 2 * plan.meterLevel(plan.meters[tl], d, "baton").powerHalf, 1e-9)
	end
	-- the computer's throw is not on a person's meter
	local s = vs("hard")
	expect.eq(s:need().kind, "throw")
	-- a Kid match: every person on the Kid meter, whatever their level
	local k = vs("hard", { computer = "kid" })
	expect.eq(k.opts.rules, "kid")
	expect.truthy(toPerson(k), "the person's throw")
	expect.eq(k.ts.sol.level.meter, plan.meters.kid)
end)

test("throw level: two people on a team, each on their own meter, the thrower action switching it", function()
	local s = session.new { mode = "match", seed = 5, cpu = "B", start = START, raising = "auto",
		teams = { A = { name = "Two", players = { { name = "Ada", throw = "easy" }, { name = "Bo", throw = "hard" } } } } }
	expect.truthy(toPerson(s), "a person's throw")
	local first = s.setup.thrower
	expect.eq(s.ts.sol.level.meter, plan.meters[first.throw])
	local other
	for _, p in ipairs(s.m.game.teams.A.players) do if p.id ~= first.id then other = p.id end end
	expect.truthy(s:apply { type = "thrower", id = other }.ok)
	expect.truthy(s.setup.thrower.throw ~= first.throw, "the other person")
	expect.eq(s.ts.sol.level.meter, plan.meters[s.setup.thrower.throw], "the plan follows the thrower")
end)

test("throw level: checkThrow takes honest throws on easy and hard and catches a nudged line", function()
	for _, tl in ipairs { "easy", "standard", "hard" } do
		for _, kubb in ipairs { true, false } do
			local s = vs(tl, { maxTurns = 8 })
			expect.truthy(toPerson(s, kubb), tl .. ": a person's " .. (kubb and "kubb" or "baton"))
			for _, c in ipairs { { 0, 0 }, { 0.6, -0.8 }, { -0.95, 0.95 }, { 0.3, 1.6 }, { -1.4, -2.2 } } do
				local a = swingAction(s, c[1], c[2])
				local res = check.throw(s, a)
				expect.truthy(res.ok, string.format("%s %s %.1f %.1f: %s", tl, a.how, c[1], c[2], tostring(res.why)))
				-- no nerves, so a line a hair off what the swing gives is not a throw the dial made
				local f = json.decode(json.encode(a))
				f.launch.swivel = f.launch.swivel + 2e-4
				expect.eq(check.throw(s, f).ok, false, tl .. " " .. a.how .. ": the line nudged")
				-- nor a throw thrown on another meter's pull
				if c[2] ~= 0 then
					local g = json.decode(json.encode(a))
					g.launch.swivel = s.ts.sol.swivel
					local back = check.throw(s, g)
					expect.eq(back.ok, false, tl .. " " .. a.how .. ": the release's pull left out")
				end
			end
		end
	end
end)

test("throw level: a replay plays the level, and the game file names easy and hard people", function()
	local s = vs("hard", { maxTurns = 3 })
	local start = s:snapshot()
	local log = {}
	for _ = 1, 400 do
		local n = s:need()
		if n.kind == "over" then break end
		local a
		if n.kind == "throw" and n.cpu then
			for _ = 1, 2000 do local f = s:frame { dt = 1 / 30 }; if f.action then a = f.action break end end
		elseif n.kind == "throw" then
			a = swingAction(s, 0.4, -0.7)
			s:apply(a)
		elseif n.kind == "raise" then
			a = { type = "raise" }; s:apply(a)
		elseif n.kind == "punish" then
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }; s:apply(a)
		end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
	end
	local info = replay.new { start = start, log = log, checkCpu = true, checkThrows = true }:finish()
	expect.eq(info.differs, false, "the replay keeps step")
	expect.eq(info.forged, false, tostring(info.forgedWhy))
	expect.eq(info.outOfBounds, false, tostring(info.outOfBoundsWhy))
	local levels = s:sheet().text:match('%[Throw Levels "([^"]*)"%]')
	expect.eq(levels, "ada hard, computer club")
	-- standard is not written, nor any person in a Kid match
	expect.eq(vs(nil):sheet().text:match('%[Throw Levels "([^"]*)"%]'), "computer club")
	expect.eq(vs("easy", { computer = "kid" }):sheet().text:match('%[Throw Levels "([^"]*)"%]'), "computer kid")
	-- pass and play with one easy person
	local pp = session.new { mode = "match", seed = 4, start = START,
		teams = { A = { players = { { name = "Ada", throw = "easy" } } }, B = { players = { { name = "Bo" } } } } }
	expect.eq(pp:sheet().text:match('%[Throw Levels "([^"]*)"%]'), "ada easy")
end)

test("throw level: namecheck allows a person's throw level and refuses another word there", function()
	local function refusedAt(d, field)
		for _, r in ipairs(tw.web.namecheck.snapshot(d).refused) do
			if r.place:find(field, 1, true) then return true end
		end
		return false
	end
	local s = vs("hard")
	expect.eq(refusedAt(json.decode(s:snapshot()), ".throw"), false, "hard is allowed")
	local d = json.decode(s:snapshot())
	d.opts.teams.A.players[1].throw = "superb"
	expect.eq(refusedAt(d, ".throw"), true, "not a throw level")
end)

test("throw level: practice takes it and keeps it through a throw's checkpoint", function()
	for _, tl in ipairs(plan.THROW_LEVELS) do
		local s = session.new { mode = "practice", throw = tl }
		expect.eq(s.ts.sol.level.meter, plan.meters[tl], tl)
		expect.eq(s:need().throw, tl ~= "standard" and tl or nil)
		local a = swingAction(s, 0.2, 0.3)
		s:apply(a)
		local back = session.restorePractice(s.practiceBefore)
		expect.eq(back.ts.sol.level.meter, plan.meters[tl], tl .. ": the checkpoint keeps it")
	end
	expect.eq(session.new { mode = "practice", throw = "club" }.ts.sol.level.meter, plan.meters.standard,
		"an unknown word is the standard meter")
end)

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

test("throw level: the pitch carries each person's me.throw into lineup and matchOptions", function()
	local doc = pitch("joinTeam", { doc = pitch("lobbyOf", {}), id = "m1", side = "A" })
	doc = pitch("joinTeam", { doc = doc, id = "m2", side = "B" })
	local members = {
		{ id = "m1", connected = true, me = { name = "Ada", engine = lobby.ENGINE, throw = "hard" } },
		{ id = "m2", connected = true, me = { name = "Bo", engine = lobby.ENGINE, throw = "standard" } },
	}
	local lu = pitch("lineup", { doc = doc, members = members })
	expect.eq(lu.players.A[1].throw, "hard")
	expect.eq(lu.players.B[1].throw, nil, "standard is not carried")
	local o = pitch("matchOptions", { doc = doc, lineup = lu, seed = 7, start = START })
	expect.eq(o.teams.A.players[1].throw, "hard")
	expect.eq(o.teams.B.players[1].throw, nil)
	o.mode = "match"
	local s = session.new(o)
	expect.eq(s.m.lineup.A[1].throw, "hard")
	-- a word that is not a level is not carried
	members[1].me.throw = "superb"
	expect.eq(pitch("lineup", { doc = doc, members = members }).players.A[1].throw, nil)
	expect.eq(pitch("constants", {}).THROW_LEVELS[3], "hard")
end)
