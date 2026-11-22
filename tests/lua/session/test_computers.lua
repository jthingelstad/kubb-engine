-- Computer players in teams (0.17.0, docs/SESSION.md "Computer players"): a team may hold
-- people, computers or both, each computer at its own level. The throwing order with
-- mixed teams, each computer at its own level, the team decisions, the refusals, names,
-- the game file, a host change mid-throw, one device, and the old `cpu` option unchanged.
import "session/session"
import "session/json"
import "session/check"
import "session/api"
import "core/autothrow"
import "core/match"
import "core/namegen"
tw.web.session.useTune("pointer")
local session, json, check, autothrow = tw.web.session, tw.web.json, tw.web.check, tw.autothrow
local cmatch, namegen = tw.match, tw.namegen

local START = { year = 2026, month = 11, day = 22, hour = 10, min = 0 }

local function new(o)
	local m = { mode = "match", seed = 7, start = START, maxTurns = 6 }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

-- Tyler and Jamie each with a pro computer partner (the owner's second example).
local function twoByTwo(o)
	local m = {
		teams = {
			A = { name = "Birch Batons", players = { { name = "Mighty Maple", key = "m1" }, { cpu = true, level = "pro" } } },
			B = { name = "Wobbly Towers", players = { { name = "Quiet Juniper", key = "m2" }, { cpu = true, level = "pro" } } },
		},
	}
	for k, v in pairs(o or {}) do m[k] = v end
	return new(m)
end

-- A person's throw, scripted as the computer would make it (a stand-in for a swing).
local function personThrow(s, r)
	local ts = s.ts
	local c = autothrow.choose(s.setup, r, 1)
	tw.web.throw.showAim(ts, c)
	local L, how = tw.web.throw.cpuLaunch(ts, c)
	ts.playerX, ts.playerY = c.x, c.y
	local a = json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
		stop = c.swing.releaseAngle })))
	s:apply(a)
	return a
end

-- Plays the match out (or `limit` actions); each(need) is called before every action.
local function playOut(s, each, limit)
	local r = autothrow.rng(99)
	local log = {}
	for _ = 1, limit or 3000 do
		local n = s:need()
		if n.kind == "over" then break end
		if each then each(n, s) end
		local a
		if n.kind == "raise" then
			a = { type = "raise" }; s:apply(a)
		elseif n.kind == "punish" then
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }; s:apply(a)
		elseif n.cpu then
			for _ = 1, 3000 do
				local f = s:frame { dt = 1 / 30 }
				if f.action then a = f.action break end
			end
		else
			a = personThrow(s, r)
		end
		log[#log + 1] = a
	end
	return log
end

test("a lineup with computer players: their levels, cpu, and generated names", function()
	local s = twoByTwo()
	local A, B = s.opts.teams.A.players, s.opts.teams.B.players
	expect.eq(A[1].cpu, nil, "a person carries no cpu")
	expect.eq(A[2].cpu, true)
	expect.eq(A[2].level, "pro")
	expect.truthy(namegen.valid("player", A[2].name), "a generated name: " .. tostring(A[2].name))
	expect.truthy(namegen.valid("player", B[2].name))
	expect.truthy(A[2].name ~= B[2].name, "no two players share a name")
	expect.eq(#s.opts.cpu, 0, "no side is the computer's whole")
	-- the same seed and seats make the same names on every client; another seed others
	local t = twoByTwo()
	expect.eq(t.opts.teams.A.players[2].name, A[2].name)
	expect.eq(t.opts.teams.B.players[2].name, B[2].name)
	local u = twoByTwo { seed = 8 }
	expect.truthy(u.opts.teams.A.players[2].name ~= A[2].name or u.opts.teams.B.players[2].name ~= B[2].name)
	-- a name given is kept
	local g = new { teams = { A = { players = { { name = "Mighty Maple" } } },
		B = { players = { { cpu = true, level = "club", name = "Proud Plum" } } } } }
	expect.eq(g.opts.teams.B.players[1].name, "Proud Plum")
	expect.eq(g.opts.teams.B.name, "Proud Plum", "a team of one computer, no team name: the player's")
	-- the mode: a computer partner makes it Vs Computer
	expect.eq(s.m.mode, "Vs Computer")
end)

test("the throwing order shares the batons; a computer's throw is the computer's, at its own level", function()
	local s = twoByTwo()
	local seen = { cpu = 0, person = 0 }
	local levels = {}
	playOut(s, function(n, ss)
		if n.kind ~= "throw" then return end
		local th = n.setup.thrower
		local e = cmatch.member(ss.m, n.side, th.id)
		expect.eq(n.cpu, e.cpu == true, "need.cpu is the thrower's")
		expect.eq(th.cpu, e.cpu, "the view says the thrower is a computer")
		if n.cpu then
			seen.cpu = seen.cpu + 1
			expect.eq(th.level, "pro")
			-- the computer's throw is the choice at the thrower's own level
			levels[#levels + 1] = th.level
			local r1 = autothrow.rng(session.mix(ss.seed, 1, ss.throws))
			local r2 = autothrow.rng(session.mix(ss.seed, 1, ss.throws))
			local mine = autothrow.choose(ss.setup, r1, tw.web.tune.throw.cpuScatter)
			local at = autothrow.choose(ss.setup, r2, tw.web.tune.throw.cpuScatter, "pro")
			expect.eq(mine.speed, at.speed, "chosen at pro")
			expect.eq(mine.swivel, at.swivel)
		else
			seen.person = seen.person + 1
			expect.eq(n["local"], true, "one device acts for the person")
		end
		-- the turn's batons as core/order dealt them, each to its player
		if n.setup.projectile == "baton" then
			expect.eq(th.id, ss.m.order.deal[n.setup.n], "the dealt thrower throws")
		end
	end, 400)
	expect.truthy(seen.cpu > 10 and seen.person > 10, "both throw: " .. seen.cpu .. " and " .. seen.person)
	expect.eq(#tw.order.checkSheet(s.m.game), 0, "the sheet keeps II.A.4 and II.B.5")
end)

test("a team of computers at mixed levels: each throws at its own", function()
	local s = new { first = "A", teams = {
		A = { players = { { cpu = true, level = "club" }, { cpu = true, level = "pro" } } },
		B = { players = { { name = "Mighty Maple" } } } } }
	local byLevel = {}
	playOut(s, function(n, ss)
		if n.kind ~= "throw" or not n.cpu then return end
		local th = n.setup.thrower
		byLevel[th.level] = (byLevel[th.level] or 0) + 1
		local r1 = autothrow.rng(session.mix(ss.seed, 1, ss.throws))
		local r2 = autothrow.rng(session.mix(ss.seed, 1, ss.throws))
		local mine = autothrow.choose(ss.setup, r1, tw.web.tune.throw.cpuScatter)
		local other = autothrow.choose(ss.setup, r2, tw.web.tune.throw.cpuScatter, th.level == "pro" and "club" or "pro")
		local r3 = autothrow.rng(session.mix(ss.seed, 1, ss.throws))
		local own = autothrow.choose(ss.setup, r3, tw.web.tune.throw.cpuScatter, th.level)
		expect.eq(mine.speed, own.speed, "the thrower's own level")
		expect.truthy(mine.speed ~= other.speed or mine.swivel ~= other.swivel or mine.loftDeg ~= other.loftDeg,
			"not the other level's throw")
	end, 200)
	expect.truthy((byLevel.club or 0) > 0 and (byLevel.pro or 0) > 0, "both levels threw")
	expect.eq(s.m.mode, "Vs Computer")
end)

test("team decisions: a team with a person raises by hand; a team of computers at its strongest", function()
	-- the person's team raises by hand
	local s = twoByTwo { raising = "hand" }
	local raises = {}
	playOut(s, function(n) if n.kind == "raise" then raises[n.side] = true end end, 400)
	expect.truthy(raises.A or raises.B, "a team with a person raises by hand")
	-- a team of computers never asks: the computer raises, at its strongest level
	local c = new { raising = "hand", teams = {
		A = { players = { { name = "Mighty Maple" } } },
		B = { players = { { cpu = true, level = "beginner" }, { cpu = true, level = "pro" }, { cpu = true, level = "club" } } } } }
	expect.eq(cmatch.strongestLevel(c.m, "B"), "pro")
	expect.eq(cmatch.hasPerson(c.m, "B"), false)
	expect.eq(cmatch.hasPerson(c.m, "A"), true)
	local asked = false
	playOut(c, function(n) if (n.kind == "raise" or n.kind == "punish") and n.side == "B" then asked = true end end, 400)
	expect.eq(asked, false, "no raise or punishment is asked of a team of computers")
	-- the policy it raises with is the computer's at pro (par)
	local pol = cmatch.raisePolicy(c.m, "B")
	expect.eq(type(pol), "function")
	local p2 = cmatch.raisePolicy(c.m, "A")
	expect.eq(p2, tw.cpu.advice, "a person's side: the engine's advice")
end)

test("the thrower action: between people only", function()
	local s = new { first = "A", teams = {
		A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "club" }, { name = "Quiet Juniper" } } },
		B = { players = { { cpu = true, level = "club" } } } } }
	local n = s:need()
	-- find a person's throw with candidates
	local guard = 0
	local r = autothrow.rng(3)
	while not (n.kind == "throw" and n.side == "A" and not n.cpu) and guard < 200 do
		if n.kind == "throw" and n.cpu then
			for _ = 1, 3000 do if s:frame { dt = 1 / 30 }.action then break end end
		elseif n.kind == "throw" then personThrow(s, r)
		else s:apply(n.kind == "raise" and { type = "raise" } or { type = "punish", x = n.cursor.x, y = n.cursor.y }) end
		n = s:need()
		guard = guard + 1
	end
	expect.truthy(n.candidates, "a team with two people lists who may take the throw")
	local comp
	for _, c in ipairs(n.candidates) do
		if c.cpu then comp = c end
	end
	expect.truthy(comp, "the computer is listed")
	expect.eq(comp.ok, false)
	expect.eq(comp.why, "computer")
	local r2 = s:apply { type = "thrower", id = comp.id }
	expect.eq(r2.ok, false, "a person never hands a throw to a computer partner")
	expect.eq(r2.why, "computer")
end)

test("Kid: one computer player is never Kid; the Kid computer makes every computer Kid", function()
	local ok, err = pcall(new, { teams = { A = { players = { { name = "Mighty Maple" } } },
		B = { players = { { cpu = true, level = "kid" } } } } })
	expect.eq(ok, false)
	expect.truthy(tostring(err):find("beginner, club or pro", 1, true), tostring(err))
	local bad = json.decode(kubbCall("new", json.encode { mode = "match", teams = { A = { players = { { name = "Mighty Maple" } } },
		B = { players = { { cpu = true, level = "expert" } } } } }))
	expect.truthy(bad.error and bad.error:find("computer player", 1, true), "the refusal names the reason")
	local k = new { computer = "kid", teams = { A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "pro" } } },
		B = { players = { { name = "Quiet Juniper" } } } } }
	expect.eq(k.opts.rules, "kid", "a computer partner with the Kid computer chosen: a Kid match")
	expect.eq(k.opts.teams.A.players[2].level, "kid", "every computer is the Kid computer")
	-- the old whole side, as before
	local w = new { cpu = "B", computer = "kid", teams = { A = { players = { { name = "Mighty Maple" } } } } }
	expect.eq(w.opts.rules, "kid")
	expect.eq(w.opts.teams.B.players[1].level, "kid")
	-- two teams of people with the Kid computer chosen: the standard rules, as before
	local p = new { computer = "kid", teams = { A = { players = { "Mighty Maple" } }, B = { players = { "Quiet Juniper" } } } }
	expect.eq(p.opts.rules, nil)
end)

test("the old cpu option means what it meant", function()
	local s = new { cpu = "B", computer = "pro", teams = { A = { players = { { name = "Mighty Maple", level = "club" } } } } }
	for _, side in ipairs { "A", "B" } do
		for _, p in ipairs(s.opts.teams[side].players) do expect.eq(p.cpu, nil, "no cpu field on a player") end
		for _, e in ipairs(s.m.lineup[side]) do expect.eq(e.cpu, nil, "nor in the lineup") end
	end
	expect.eq(s.opts.teams.B.name, "Computer")
	expect.eq(s.opts.teams.B.players[1].level, "pro")
	expect.eq(s.m.mode, "Vs Computer")
	expect.eq(s:snapshot():find('"cpu":true', 1, true), nil, "the snapshot has no computer player")
	local b = new { cpu = "both" }
	expect.eq(b.m.mode, "Computer vs Computer")
	local n = new { first = "B", cpu = "B", teams = { A = { players = { "Mighty Maple" } } } }:need()
	expect.eq(n.cpu, true)
	expect.eq(n.setup.thrower.cpu, true, "the view says so for the whole side too")
	local p = new {}
	expect.eq(p.m.mode, "Pass and Play")
end)

test("the game file names each computer player with its level; names.check allows them", function()
	local s = twoByTwo { maxTurns = 3 }
	playOut(s)
	local sheet = s:sheet()
	-- (the sheet writes short ids: [Team A Players "Mighty Maple (m), Brisk Birch (b)"])
	local lv = sheet.text:match('%[Throw Levels "([^"]*)"%]')
	expect.truthy(lv, "a [Throw Levels] line")
	local n = 0
	for id, level in lv:gmatch("(%w+) (%a+)") do
		n = n + 1
		expect.eq(level, "pro")
		expect.truthy(sheet.text:find("(" .. id .. ")", 1, true), "an id of the sheet: " .. id)
	end
	expect.eq(n, 2, "the two computer partners, and no person")
	expect.truthy(sheet.text:find('[Mode "Vs Computer"]', 1, true))
	local rep = json.decode(kubbCall("names.check", json.encode { snap = s:snapshot() }))
	expect.eq(rep.allowed, true, "names.check: " .. json.encode(rep.refused))
	-- a restore reads it back the same
	local t = session.restore(s:snapshot())
	expect.eq(t:hash(), s:hash())
	expect.eq(t.m.lineup.A[2].cpu, true)
end)

test("one device: a person with a computer partner against two computers, to the end", function()
	local s = new { maxTurns = 40, teams = {
		A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "club" } } },
		B = { players = { { cpu = true, level = "club" }, { cpu = true, level = "pro" } } } } }
	local log = playOut(s)
	expect.eq(s:need().kind, "over")
	expect.truthy(#log > 20)
	-- replayed from the start, action by action, every client gets the same match
	local r = new { maxTurns = 40, teams = {
		A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "club" } } },
		B = { players = { { cpu = true, level = "club" }, { cpu = true, level = "pro" } } } } }
	for _, a in ipairs(log) do r:apply(a) end
	expect.eq(r:hash(), s:hash())
end)

test("the host changes mid-throw: the new host throws for the computer, the same throw", function()
	local o = { first = "A", teams = { A = { players = { { cpu = true, level = "pro" } } }, B = { players = { "Mighty Maple" } } } }
	local a, b = new(o), new(o)
	b:setControl { sides = { "B" }, cpu = false }
	local fa
	for _ = 1, 3000 do
		fa = a:frame { dt = 1 / 30 }
		if fa.action then break end
	end
	expect.truthy(fa.action, "the host threw")
	-- b held at the release
	for _ = 1, 3000 do b:frame { dt = 1 / 30 } end
	expect.eq(b.ts.mode, "cpuhold")
	-- the host goes; b is the host now (pitch.controlFor gives it cpu)
	b:setControl { sides = { "B" }, cpu = true }
	local fb = b:frame { dt = 1 / 30 }
	expect.truthy(fb.action, "it releases on the next frame")
	expect.eq(json.encode(fb.action), json.encode(fa.action), "the throw the host would have made")
	expect.eq(b:hash(), a:hash())
	expect.eq(check.throw(new(o), fa.action).ok, true)
end)

test("a replay's document seats the computer players", function()
	import "session/replay"
	local o = { mode = "match", seed = 7, start = START, maxTurns = 3, teams = {
		A = { players = { { name = "Mighty Maple", key = "jamie001" }, { cpu = true, level = "pro" } } },
		B = { players = { { cpu = true, level = "club" } } } } }
	local s = session.new(o)
	local log = {}
	for _, a in ipairs(playOut(s)) do log[#log + 1] = { a = a } end
	local r = tw.web.replay.new { setup = o, log = log, document = true }
	r:finish()
	local doc = assert(r:document())
	local d = json.decode(json.encode(doc), true)
	expect.eq(d.teams.A[1], "jamie001")
	expect.eq(d.teams.A[2], "cpu:1")
	expect.eq(d.teams.B[1], "cpu:2")
	expect.eq(d.computers["cpu:1"].level, "pro")
	expect.eq(d.computers["cpu:1"].name, s.opts.teams.A.players[2].name)
	expect.eq(d.match.players.A[2].cpu, true)
	expect.eq(d.match.over, true)
end)

test("the kubbs go round a team with a computer player; a team of people keeps its opener", function()
	local function inkasters(teams)
		local s = new { maxTurns = 12, teams = teams }
		playOut(s)
		local by = {}
		for _, t in ipairs(s.m.game.sheet.turns) do
			if t.side == "A" then
				for _, pid in ipairs(t.inkastOrder) do by[pid] = (by[pid] or 0) + 1 end
			end
		end
		return by, s
	end
	local by, s = inkasters { A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "pro" } } },
		B = { players = { { cpu = true, level = "club" }, { cpu = true, level = "club" } } } }
	local a1, a2 = s.m.game.teams.A.players[1].id, s.m.game.teams.A.players[2].id
	expect.truthy((by[a1] or 0) > 0 and (by[a2] or 0) > 0, "both throw kubbs in: " .. tostring(by[a1]) .. ", " .. tostring(by[a2]))
	expect.truthy(math.abs((by[a1] or 0) - (by[a2] or 0)) <= 1, "turn and turn about")
	-- two people: the turn's first baton thrower, as before 0.17 (the deal opens with the same one)
	local pb, p = inkasters { A = { players = { "Mighty Maple", "Quiet Juniper" } }, B = { players = { "Proud Plum" } } }
	expect.eq(p.m.order.A.rotateInk, nil, "no rotation for a team of people")
	local q2 = p.m.game.teams.A.players[2].id
	expect.eq(pb[q2], nil, "the second player never opens a turn of six")
end)

test("setup.settled with mixed teams: a team of computers' raises are handed out; a person's team raises by hand", function()
	local s = new { raising = "hand", maxTurns = 12, teams = {
		A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "pro" } } },
		B = { players = { { cpu = true, level = "beginner" }, { cpu = true, level = "pro" } } } } }
	local bySide = { A = 0, B = 0 }
	local byHand = { A = 0, B = 0 }
	playOut(s, function(n)
		if n.kind == "raise" then byHand[n.side] = byHand[n.side] + 1 end
		if n.kind == "throw" and n.setup.settled then
			for _, e in ipairs(n.setup.settled.list) do
				if e.kind == "raise" then bySide[e.side] = bySide[e.side] + 1 end
			end
		end
	end)
	expect.eq(bySide.A, 0, "the person's team is never raised for")
	expect.eq(byHand.B, 0, "the computers are never asked")
	expect.truthy(bySide.B > 0 or byHand.A > 0, "kubbs were raised")
	-- a team of computers raises as the computer at its strongest level (pro: par)
	local pol = tw.match.raisePolicy(s.m, "B")
	expect.eq(type(pol), "function")
end)

-- A seat's level and the level it throws at are two things: in a Kid match every computer
-- is the Kid computer, but the seat keeps the level the host gave it.
test("a Kid pitch with a club and a pro seat: START, play, the replay document strictly, a rematch at club", function()
	local lobby = tw.shared.lobby
	local function deep(v)
		return json.decode(json.encode(v), true)
	end
	local members = {
		{ id = "jamie001", connected = true, me = { name = "Mighty Maple", engine = tw.engine.version } },
		{ id = "tyler001", connected = true, me = { name = "Quiet Juniper", engine = tw.engine.version } },
	}
	local doc = lobby.joinTeam(nil, "jamie001", "A")
	doc = lobby.addComputer(doc, "A", "club", 11)
	doc = lobby.addComputer(doc, "B", "pro", 12)
	doc = lobby.joinTeam(doc, "tyler001", "B")
	doc = lobby.setOptions(doc, { computer = "kid" })
	expect.eq(doc.settings.computer, "kid")
	local lu = lobby.lineup(doc, members)
	expect.eq(lu.players.A[2].level, "club", "the lobby shows the seat's own level (a client shows Kid)")
	expect.eq(lobby.startCheck(lu.players, members, "jamie001").ok, true)
	local setup = deep(lobby.matchOptions(doc, lu, 21, START))
	expect.eq(setup.teams.A[2] == nil and setup.teams.A.players[2].level, "club", "the setup keeps the seat's level")
	local o = deep(setup)
	o.mode = "match"
	local s = session.new(o)
	expect.eq(s.opts.rules, "kid", "a Kid match")
	expect.eq(s.opts.teams.A.players[2].level, "kid", "the seat throws as the Kid computer")
	expect.eq(s.opts.teams.B.players[1].level, "kid")
	doc = lobby.startMatch(doc, { snap = s:snapshot(), hash = s:hash(), players = lu.players, cpu = lu.cpu,
		host = "jamie001", setup = setup, members = members })
	expect.truthy(doc, "START")
	expect.eq(doc.match.players.A[2].level, "club", "the match header records the seat")
	local seq = 0
	local r = autothrow.rng(5)
	while s:need().kind ~= "over" do
		local n = s:need()
		local a
		if n.kind == "raise" then
			a = { type = "raise" }; s:apply(a)
		elseif n.kind == "punish" then
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }; s:apply(a)
		elseif n.cpu then
			for _ = 1, 3000 do
				local f = s:frame { dt = 1 / 30 }
				if f.action then a = f.action break end
			end
		else
			a = personThrow(s, r)
		end
		seq = seq + 1
		doc = lobby.commitAction(doc, { n = doc.n, seq = seq, snap = s:snapshot(), hash = s:hash(),
			action = deep(a), over = s:need().kind == "over" })
		assert(doc, "committed")
	end
	doc = deep(doc)
	-- the game file names the level thrown
	expect.truthy(s:sheet().text:find('[Throw Levels "', 1, true))
	local lv = s:sheet().text:match('%[Throw Levels "([^"]*)"%]')
	for level in lv:gmatch("%w+ (%a+)") do expect.eq(level, "kid") end
	-- the replay: its document built from the setup is the pitch's, byte for byte, and loads strictly
	local m = doc.match
	local function call(name, a)
		local out = json.decode(kubbCall(name, json.encode(a)), true) -- (nulls kept, as a pitch holds them)
		if type(out) == "table" and out.error then error(name .. ": " .. out.error, 2) end
		return out
	end
	local rp = call("replayLoad", { setup = m.setup, h0 = m.h0, log = m.log, names = "check",
		document = { host = "jamie001" } })
	expect.eq(rp.replay.differs, false)
	call("replayFinish")
	local out = call("replayDocument")
	call("replayEnd")
	expect.truthy(out.document, "the replay's document is made (START is not refused)")
	expect.eq(json.encode(out.document), json.encode(doc), "the same document as the pitch wrote")
	local rep = call("names.check", { document = doc, members = members })
	expect.eq(rep.allowed, true, json.encode(rep.refused))
	expect.truthy(lobby.replayOf(deep(out.document).match), "the pitch keeps its replay")
	-- a rematch with the Computer back at club: the seats throw at their own levels again
	local again = lobby.backToLobby(doc, doc.n)
	again = lobby.setOptions(again, { computer = "club" })
	local lu2 = lobby.lineup(again, members)
	local o2 = deep(lobby.matchOptions(again, lu2, 22, START))
	o2.mode = "match"
	local s2 = session.new(o2)
	expect.eq(s2.opts.rules, nil, "the standard rules")
	expect.eq(s2.opts.teams.A.players[2].level, "club")
	expect.eq(s2.opts.teams.B.players[1].level, "pro")
	expect.eq(s2.opts.teams.A.players[2].name, s.opts.teams.A.players[2].name, "the seat keeps its name")
end)
