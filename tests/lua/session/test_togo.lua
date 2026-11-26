-- The throw to go (1.4.0; core/togo, docs/SESSION.md "The throw to go"): before turn 1
-- each team throws one baton at the king; the closer that leaves it standing throws
-- first. Blind and simultaneous, a phase of its own, in the snapshot while undecided.
import "session/session"
import "session/json"
import "session/check"
import "session/replay"
import "core/autothrow"
import "core/togo"
tw.web.session.useTune("pointer")
local session, json, autothrow, togo = tw.web.session, tw.web.json, tw.autothrow, tw.togo

local START = { year = 2026, month = 11, day = 26, hour = 12, min = 0 }

local function newMatch(o)
	local x = { mode = "match", seed = o.seed or 11, start = START, togo = o.togo == nil and true or o.togo,
		cpu = o.cpu, teams = o.teams, rules = o.rules, computer = o.computer }
	return session.new(x)
end

-- A person's baton to go, as the engine would throw it at `level` (scripted: a test's
-- stand-in for the meter), for the side the session has set up.
local function personBaton(s, side, seedN, aimShort)
	local setup = tw.match.togoSetup(s.m, side)
	local c = togo.cpuThrow(setup, autothrow.rng(seedN), "club", 1)
	if aimShort then
		-- a straight, gentle throw that stops well short: never near the king
		c.launch.speed = c.launch.speed * aimShort
	end
	local L = c.launch
	return json.decode(json.encode {
		type = "togo", side = side, round = s.togo and s.togo.round or 1, how = "baton",
		launch = { speed = L.speed, loft = L.loft, swivel = L.swivel, tilt = L.tilt or 0, tumble = L.tumble or 0,
			legal = true },
		stance = { x = c.x, y = c.y, set = true }, target = { x = c.tx, y = c.ty, set = true }, scripted = true,
	})
end

test("off by default: a match without togo has its usual start", function()
	local a = newMatch { togo = false }
	local b = session.new { mode = "match", seed = 11, start = START }
	expect.eq(a:snapshot(), b:snapshot())
	expect.eq(a:need().kind, "throw")
	expect.eq(a.opts.togo, nil)
end)

test("on: the match opens with the throw to go, both sides owe", function()
	local s = newMatch {}
	local n = s:need()
	expect.eq(n.kind, "togo")
	expect.eq(#n.owe, 2)
	expect.eq(n.side, "A")
	expect.eq(n.round, 1)
	expect.truthy(n.setup and n.setup.togo)
	expect.eq(n.setup.batonId, "togoA")
	expect.eq(s.throws, 0)
end)

test("Kid matches and computer-only matches have no throw to go", function()
	local k = newMatch { rules = "kid" }
	expect.eq(k.opts.togo, nil)
	expect.eq(k:need().kind, "throw")
	local cc = newMatch { cpu = "both" }
	expect.eq(cc.opts.togo, nil)
end)

test("pass and play: A then B, then one recording and turn 1 with the winner first", function()
	local s = newMatch {}
	local r1 = s:apply(personBaton(s, "A", 3))
	expect.truthy(r1.ok)
	expect.eq(r1.recording, nil)
	local n = s:need()
	expect.eq(n.kind, "togo")
	expect.eq(n.side, "B")
	expect.eq(#n.owe, 1)
	local again = s:apply(personBaton(s, "A", 3))
	expect.eq(again.ok, false)
	local r2 = s:apply(personBaton(s, "B", 4))
	expect.truthy(r2.ok)
	expect.truthy(r2.recording)
	expect.eq(r2.recording.kind, "togo")
	local res = r2.recording.result
	expect.truthy(res.togo)
	if res.how == "again" then
		expect.eq(s:need().kind, "togo")
		expect.eq(s:need().round, 2)
	else
		local n2 = s:need()
		expect.eq(n2.kind, "throw")
		expect.eq(n2.side, res.first)
		expect.eq(s.m.game.first, res.first)
		expect.truthy(s.m.game.firstBy)
		expect.eq(s.throws, 0)
		local sh = s:sheet()
		expect.truthy(sh.text:find("[Engine:first", 1, true))
	end
	-- the show plays back
	local sa = s:showAt(0.5)
	expect.truthy(sa and sa.items and sa.camera)
	expect.truthy(s:showAt(99).done)
end)

test("snapshot mid-phase restores the batons in, and the result is the same", function()
	local s = newMatch { seed = 5 }
	s:apply(personBaton(s, "A", 8))
	local snap = s:snapshot()
	local r = session.restore(snap)
	expect.eq(r:snapshot(), snap)
	expect.eq(r:need().side, "B")
	local bb = personBaton(s, "B", 9)
	local x = s:apply(bb)
	local y = r:apply(bb)
	expect.eq(s:hash(), r:hash())
	expect.eq(x.recording.result.text, y.recording.result.text)
end)

test("against the computer: one person's baton decides it, the computer's flies with it", function()
	local s = newMatch { cpu = "B" }
	local n = s:need()
	expect.eq(n.kind, "togo")
	expect.eq(#n.owe, 1)
	expect.eq(n.owe[1], "A")
	expect.truthy(n.computer.B)
	local r = s:apply(personBaton(s, "A", 12))
	expect.truthy(r.recording)
	expect.truthy(r.recording.result.B.cpu)
	local refused = s:apply(personBaton(s, "B", 1))
	expect.eq(refused.ok, false)
end)

test("seats: each side's client throws its own baton, either order, the same verdict", function()
	local base = newMatch { seed = 21 }
	local start = base:snapshot()
	local a = session.restore(start, { sides = { "A" } })
	local b = session.restore(start, { sides = { "B" } })
	expect.eq(a:need().side, "A")
	expect.eq(b:need().side, "B")
	local ba, bb = personBaton(a, "A", 31), personBaton(b, "B", 32)
	-- A's client applies A then B; B's client B then A
	a:apply(ba); local ra = a:apply(bb)
	b:apply(bb); local rb = b:apply(ba)
	expect.eq(a:hash(), b:hash())
	expect.eq(ra.recording.result.text, rb.recording.result.text)
end)

test("a decided match replays from its start", function()
	local s = newMatch { seed = 40 }
	local start = s:snapshot()
	local log = {}
	for _, side in ipairs { "A", "B" } do
		local a = personBaton(s, side, 50 + #log)
		s:apply(a)
		log[#log + 1] = { a = a, h = s:hash() }
	end
	local r = session.restore(start)
	for _, e in ipairs(log) do
		r:apply(e.a)
		expect.eq(r:hash(), e.h)
	end
end)

-- The computer never topples the king more often than a person of its standing (the
-- brief; togo.tune). A person here is the Gym's recorded hand (tools/gym/human-model.json,
-- its club baton part) at the person's starting circle, its misses scaled as the meter
-- probe scales them: x2 a newcomer on the easy meter beside the Beginner computer, x1 on
-- standard beside Club, x0.5 a master on hard beside Pro. The same count of throws each;
-- seeded, so the counts are fixed on desktop Lua; one throw of slack for the draw.
test("the computer topples the king no more often than a person of its standing", function()
	local human = dofile("tools/gym/human.lua")
	local model = human.load("tools/gym/human-model.json")
	local plan = tw.plan
	local N = 150
	for _, row in ipairs { { "beginner", "easy", 2 }, { "club", "standard", 1 }, { "pro", "hard", 0.5 } } do
		local level, meter, k = row[1], row[2], row[3]
		local s = session.new { mode = "match", seed = 3, togo = true, start = START,
			teams = { A = { players = { { name = "Pat", throw = meter } } }, B = { players = { { name = "Sam" } } } } }
		local ts, sol = s.ts, s.ts.sol
		local r, nr = plan.rng(91), plan.rng(73)
		local person, cpu = 0, 0
		for i = 1, N do
			local sw = human.scale(human.swing(sol, human.part(model, "club", "baton"), r, {}), sol, k)
			local L = plan.launch(sol, sw, { nerves = nr, projectile = "baton", tilt = 0 }, {})
			local a = json.decode(json.encode { type = "togo", side = "A", round = 1, how = "baton",
				launch = { speed = L.speed, loft = L.loft, swivel = L.swivel, tilt = L.tilt or 0, tumble = L.tumble or 0,
					legal = true },
				stance = { x = ts.playerX, y = ts.playerY, set = true }, target = { x = ts.markerX, y = ts.markerY, set = true } })
			local _, _, _, top = s:togoFire(a)
			if top then person = person + 1 end
			-- the computer at this level, a fresh draw each round
			s.togo.round = i
			s.m.lineup.A[1].level = level
			local _, _, _, top2 = s:togoFire(s:togoCpuAction("A"))
			s.m.lineup.A[1].level = nil
			if top2 then cpu = cpu + 1 end
		end
		expect.truthy(cpu <= person + 1, level .. ": computer " .. cpu .. ", person " .. person .. " of " .. N)
	end
end)

test("a tie or both kings down: throw again, the round counts on", function()
	local s = newMatch { seed = 6 }
	-- two batons thrown straight into the king: both down
	local function hard(side)
		local a = personBaton(s, side, 1)
		a.target = { x = 0, y = 4, set = true }
		local setup = tw.match.togoSetup(s.m, side)
		local q = { level = autothrow.cpuLevel("pro"), surface = setup.surface, projectile = "baton", aimZ = tw.plan.aimZFor("king"),
			px = 0, py = 0, tx = 0, ty = 4, release = tw.plan.arcFor("baton", 4) }
		local sol = tw.plan.solve(q, {})
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
		local L = tw.plan.launch(sol, sw, { projectile = "baton", tilt = 0 }, {})
		a.launch = { speed = L.speed, loft = L.loft, swivel = L.swivel, tilt = L.tilt or 0, tumble = L.tumble or 0, legal = true }
		a.stance = { x = 0, y = 0, set = true }
		return json.decode(json.encode(a))
	end
	s:apply(hard("A"))
	local r = s:apply(hard("B"))
	expect.eq(r.recording.result.how, "again")
	expect.eq(r.recording.result.why, "both king")
	local n = s:need()
	expect.eq(n.kind, "togo")
	expect.eq(n.round, 2)
	expect.eq(n.again.why, "both king")
	-- a round-1 baton now is refused
	local old = personBaton(s, "A", 2)
	old.round = 1
	expect.eq(s:apply(old).ok, false)
	-- the snapshot keeps the round
	expect.eq(session.restore(s:snapshot()):need().round, 2)
end)

-- A person's baton made on the dial, frame by frame (as test_check's pointer swing).
local function dialBaton(s, back, stop)
	local arm, dt = 0, 1 / 60
	while arm > -back do
		arm = math.max(-back, arm - 400 * dt)
		local o = s:frame { dt = dt, arm = arm }
		if o.action then return o end
	end
	for _ = 1, 600 do
		arm = math.min(stop, arm + 900 * dt)
		local o = s:frame { dt = dt, arm = arm }
		if o.action then return o end
		if arm >= stop then
			for _ = 1, 40 do
				o = s:frame { dt = dt, arm = arm }
				if o.action then return o end
			end
			return nil
		end
	end
end

test("a baton thrown on the dial: a togo action that checkThrow passes, a forged one fails", function()
	local s = newMatch { seed = 14 }
	local before = session.restore(s:snapshot())
	local o = dialBaton(s, s.ts.sol.back, s.ts.sol.release)
	expect.truthy(o and o.action)
	expect.eq(o.action.type, "togo")
	expect.eq(o.action.side, "A")
	expect.eq(o.action.seq, nil)
	local r = tw.web.check.throw(before, o.action)
	expect.truthy(r.ok, r.why)
	local forged = json.decode(json.encode(o.action))
	forged.launch.speed = forged.launch.speed * 1.3
	expect.eq(tw.web.check.throw(before, forged).ok, false)
	local cpuSide = newMatch { seed = 14, cpu = "B" }
	local fb = json.decode(json.encode(o.action))
	fb.side = "B"
	expect.eq(tw.web.check.throw(cpuSide, fb).ok, false)
	-- the session's next baton is B's
	expect.eq(s:need().side, "B")
end)

test("the computer's speed: x1, x2 and x4 make the same throw in fewer frames", function()
	local frames = {}
	local acts = {}
	for _, sp in ipairs { 1, 2, 4 } do
		local s = session.new { mode = "match", seed = 4, start = START, cpu = "both" }
		local n = 0
		for _ = 1, 5000 do
			n = n + 1
			local o = s:frame { dt = 1 / 60, speed = sp }
			if o.action then acts[sp] = json.encode(o.action); break end
		end
		frames[sp] = n
	end
	expect.eq(acts[1], acts[2])
	expect.eq(acts[1], acts[4])
	expect.truthy(frames[2] < frames[1] and frames[4] < frames[2])
end)

test("checkStart: a togo match's first snapshot is a start; one with a baton to go in is not", function()
	local s = newMatch { seed = 21 }
	local snap = s:snapshot()
	local ok, why = session.startCheck(snap)
	expect.truthy(ok, why)
	local r = s:apply(personBaton(s, "A", 3))
	expect.truthy(r.ok, r.why)
	expect.eq(s:need().kind, "togo", "B still owes")
	expect.eq((session.startCheck(s:snapshot())), false)
	-- renamed, the start still has its throw to go
	local renamed = session.renameStart(snap, { A = "Riverside" })
	local o = session.setupOf(renamed)
	o.mode = "match"
	expect.eq(session.new(o):need().kind, "togo")
end)

-- (Codex on #61) the names check knows the throw to go's strings; a match whose first
-- players are both computers has none; the aiming calls work on a baton to go.
test("names check: a decided and a half-thrown throw to go pass a strict restore", function()
	import "session/namecheck"
	local nc = tw.web.namecheck
	-- half thrown: A's baton in, B owed (pass and play)
	local s = newMatch { seed = 21 }
	local r = s:apply(personBaton(s, "A", 3))
	expect.truthy(r.ok, r.why)
	local rep = nc.snapshot(json.decode(s:snapshot()))
	expect.eq(#rep.refused, 0, rep.refused[1] and (rep.refused[1].from .. ": " .. rep.refused[1].why))
	expect.truthy(s.togo.acts.A.launch and s.togo.acts.A.type == "togo")
	-- decided
	local d = newMatch { seed = 21, cpu = "B" }
	expect.truthy(d:apply(personBaton(d, "A", 3)).ok)
	expect.truthy(d.m.game.firstBy or d:need().kind == "togo")
	rep = nc.snapshot(json.decode(d:snapshot()))
	expect.eq(#rep.refused, 0, rep.refused[1] and (rep.refused[1].from .. ": " .. rep.refused[1].why))
	expect.truthy(nc.isTogoText("throw to go: Team A 0.42 m, Team B king down; 3 rounds"))
	expect.truthy(nc.isTogoText("throw to go: Team A king down, Team B 1.00 m"))
	expect.eq(nc.isTogoText("throw to go: Team A Anything Typed, Team B 1.00 m"), false)
	expect.eq(nc.isTogoText("throw to go: Team B 1.00 m, Team A 1.00 m"), false)
	-- a field a client added does not ride into the snapshot
	local e = newMatch { seed = 22 }
	local a = personBaton(e, "A", 3)
	a.note = "Anything Typed"
	expect.truthy(e:apply(a).ok)
	expect.eq(e.togo.acts.A.note, nil)
end)

test("both teams' first players computers: no throw to go", function()
	local function teams(firstCpu)
		return {
			A = { name = "Team A", players = { firstCpu and { cpu = true, level = "club" } or { name = "Player 1" }, { name = "Player 2" } } },
			B = { name = "Team B", players = { { cpu = true, level = "club" }, { name = "Player 3" } } },
		}
	end
	local s = newMatch { teams = teams(true) }
	expect.eq(s.opts.togo, nil)
	expect.eq(s:need().kind, "throw")
	local t = newMatch { teams = teams(false) }
	expect.eq(t.opts.togo, true)
	expect.eq(t:need().kind, "togo")
	expect.eq(#t:need().owe, 1)
end)

test("the aiming calls move a baton to go's circle and arc", function()
	local s = newMatch { seed = 23 }
	local before = s:aimView()
	local out = s:setTarget(0.3, 2.0, false)
	expect.near(out.aim.marker.x, 0.3, 1e-9)
	expect.near(out.aim.marker.y, 2.0, 1e-9)
	local arc = s:setArc(30)
	expect.truthy(arc.aim.plan.release ~= before.plan.release or before.plan.release == 30, "the arc moved")
end)

test("the other side's baton arriving leaves this client's aim as it is", function()
	local s = newMatch { seed = 24 }
	s:setControl { sides = { "B" } }
	expect.eq(s:need().side, "B")
	s:setTarget(-0.5, 3.0, false)
	s:setArc(28)
	local before = s:aimView()
	local a = personBaton(s, "A", 5)
	expect.truthy(s:apply(a).ok)
	local n = s:need()
	expect.eq(n.kind, "togo")
	expect.eq(table.concat(n.owe, ","), "B")
	local after = s:aimView()
	expect.near(after.marker.x, -0.5, 1e-9)
	expect.near(after.marker.y, 3.0, 1e-9)
	expect.eq(after.plan.release, before.plan.release, "the arc kept")
end)
