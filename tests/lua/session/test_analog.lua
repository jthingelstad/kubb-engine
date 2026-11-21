-- The plan's controls take any value in their range (Jamie, 2026-11-20: "more analog
-- allow the slider to select any value in a range"): setTilt, setSpin and setArc clamp
-- without rounding, the step calls step as before, the view gives each control's
-- numbers, and a throw at any value carries through the action, checkThrow and a replay
-- to the same hash.
import "session/session"
import "session/json"
import "session/check"
import "session/replay"
import "core/autothrow"
tw.web.session.useTune("pointer")
local session, json, check, replay, autothrow, plan = tw.web.session, tw.web.json, tw.web.check, tw.web.replay,
	tw.autothrow, tw.plan
local pt = plan.tune

local START = { year = 2026, month = 11, day = 20, hour = 9, min = 0 }

test("setTilt, setSpin and setArc take any value and clamp to the range", function()
	local s = session.new { mode = "practice" }
	s:setTilt(7.3)
	expect.eq(s.ts.tilt, 7.3)
	s:setTilt(33)
	expect.eq(s.ts.tilt, pt.tiltMaxDeg)
	s:setTilt(-1e9)
	expect.eq(s.ts.tilt, -pt.tiltMaxDeg)
	s:setSpin(1)
	expect.eq(s.ts.spin, 0, "no spin for a baton")
	s:setArc(97.3)
	expect.eq(s.ts.release, 97.3, "not rounded to a step")
	s:setArc(500)
	expect.eq(s.ts.release, pt.releaseMaxDeg)
	s:setArc(-4)
	expect.eq(s.ts.release, pt.releaseMinDeg)
	s:setDrill(true)
	s:setSpin(1.37)
	expect.eq(s.ts.spin, 1.37)
	s:setSpin(-9)
	expect.eq(s.ts.spin, -pt.spinSteps)
	s:setTilt(4)
	expect.eq(s.ts.tilt, 0, "no tilt for a kubb")
	-- through the one door, as a client calls it
	local d = s:setSpin(0.6)
	expect.eq(d.aim.plan.spin, 0.6)
end)

test("the step calls step as before, from any value", function()
	local s = session.new { mode = "practice" }
	s:stepSide(1)
	expect.eq(s.ts.tilt, pt.tiltStepDeg)
	s:setTilt(2.5)
	s:stepSide(1)
	expect.eq(s.ts.tilt, 7.5)
	s:stepSide(10)
	expect.eq(s.ts.tilt, pt.tiltMaxDeg)
	s:stepArc(1)
	expect.eq(s.ts.release, plan.arcFor("base") + pt.arcStepDeg)
	s:setDrill(true)
	s:stepSide(1)
	expect.eq(s.ts.spin, 1)
	s:setSpin(0.25)
	s:stepSide(1)
	expect.eq(s.ts.spin, 1.25)
	s:stepSide(5)
	expect.eq(s.ts.spin, pt.spinSteps)
end)

test("the view gives each control's range, default, value, tick and step", function()
	local s = session.new { mode = "practice" }
	s:setTilt(-3.5)
	local c = s:view().aim.controls
	expect.eq(c.arc.min, 15)
	expect.eq(c.arc.max, 165)
	expect.eq(c.arc.default, plan.arcFor("base"))
	expect.eq(c.arc.value, s.ts.release)
	expect.eq(c.arc.tick, pt.arcTickDeg)
	expect.eq(c.arc.step, pt.arcStepDeg)
	expect.eq(c.arc.scope, "throw")
	expect.eq(c.tilt.min, -20)
	expect.eq(c.tilt.max, 20)
	expect.eq(c.tilt.default, 0)
	expect.eq(c.tilt.value, -3.5)
	expect.eq(c.tilt.tick, 1)
	expect.eq(c.spin, nil)
	s:setDrill(true)
	c = s:view().aim.controls
	expect.eq(c.tilt, nil)
	expect.eq(c.spin.min, -3)
	expect.eq(c.spin.max, 3)
	expect.eq(c.spin.tick, 0.25)
	expect.eq(c.spin.radPerTap, pt.spinPerStep)
	expect.eq(c.spin.baseRad, tw.drill.tune.spiral)
	expect.eq(c.spin.scope, "turn")
	expect.eq(c.arc.default, plan.arcFor("drill"))
	-- a tick crosses each range in about a second at 30 frames a second
	for _, k in ipairs { "arc" } do
		local n = (c[k].max - c[k].min) / c[k].tick
		expect.truthy(n >= 20 and n <= 45, k .. " ticks: " .. n)
	end
	expect.truthy((2 * pt.tiltMaxDeg) / pt.tiltTickDeg <= 45)
	expect.truthy((2 * pt.spinSteps) / pt.spinTick <= 45)
end)

test("a kubb's spin is continuous in the physics: no step at a former tap", function()
	-- drill.body adds the planned spin to the spiral linearly; the plan's solve aims a spun
	-- kubb by how far it runs on (drill.slideFor, from 0.10), between its spins' tables,
	-- so the speed moves a little at a time and the same either way
	local q = { projectile = "kubb", px = 0, py = 0, tx = 0.3, ty = 6, release = 135, level = "club", surface = "grass" }
	local prev
	for i = -12, 12 do
		q.spin = i * 0.25
		local sol = plan.solve(q, {})
		local L = plan.launch(sol, tw.web.throw.CLEAN, { projectile = "kubb", spin = q.spin, level = "club" }, {})
		-- (from 0.11 the spiral goes the spin's way, so the launch's spin steps by twice
		-- the spiral, 6 rad/s, across no spin: under what a dead landing needs either side)
		expect.near(L.spin, (q.spin < 0 and -1 or 1) * tw.drill.tune.spiral + q.spin * pt.spinPerStep, 1e-9)
		if prev then
			expect.near(sol.speed, prev.speed, 0.15, "no step in the solve from one spin to the next")
		end
		local q2 = { projectile = "kubb", px = 0, py = 0, tx = 0.3, ty = 6, release = 135, level = "club",
			surface = "grass", spin = -q.spin }
		expect.near(plan.solve(q2, {}).speed, sol.speed, 1e-12, "the same aim for a spin either way")
		prev = { speed = sol.speed }
	end
end)

-- ---------- a match at any value: action, check, replay ----------

local function pointerThrow(s, r)
	local sol = s.ts.sol
	local back = sol.back + (r.next() - 0.5) * 30
	local stop = sol.release + (r.next() - 0.5) * 30
	local arm, dt = 0, 1 / 60
	while arm > -back do
		arm = math.max(-back, arm - 400 * dt)
		local o = s:frame { dt = dt, arm = arm }
		if o.action then return o end
	end
	for _ = 1, 600 do
		arm = math.min(stop, arm + 1500 * dt)
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

local function play(seed)
	local s = session.new { mode = "match", seed = seed, cpu = "B", start = START, raising = "hand", maxTurns = 8,
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	local start = s:snapshot()
	local log, r = {}, autothrow.rng(7100 + seed)
	local tilts, spins, guard = 0, 0, 0
	while s:need().kind ~= "over" do
		guard = guard + 1
		assert(guard < 4000, "the match ends")
		local n = s:need()
		local a
		if n.kind == "throw" and n.cpu then
			for _ = 1, 2000 do
				local f = s:frame { dt = 1 / 60 }
				if f.action then a = f.action break end
			end
		elseif n.kind == "throw" then
			-- values no step reaches
			if s.ts.projectile == "kubb" then
				s:setSpin((r.next() * 2 - 1) * 3.3)
				spins = spins + 1
			else
				s:setTilt((r.next() * 2 - 1) * 21)
				tilts = tilts + 1
			end
			s:setArc(s.ts.release + (r.next() - 0.5) * 17.3)
			local f
			for _ = 1, 20 do
				f = pointerThrow(s, r)
				if f and f.action then break end
			end
			assert(f and f.action, "a throw leaves")
			a = f.action
			expect.truthy(type(a.plan) == "table", "a person's throw names its plan")
		elseif n.kind == "raise" then
			a = { type = "raise", choice = #n.choices }
			s:apply(a)
		else
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
			s:apply(a)
		end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
	end
	return { start = start, log = log, tilts = tilts, spins = spins }
end

test("throws at any value check and replay to the same hashes", function()
	local tilts, spins, nonStep = 0, 0, 0
	for seed = 1, 3 do
		local m = play(seed)
		tilts, spins = tilts + m.tilts, spins + m.spins
		for _, e in ipairs(m.log) do
			local p = e.a.plan
			if p and ((p.tilt and p.tilt % pt.tiltStepDeg ~= 0) or (p.spin and p.spin % 1 ~= 0)) then
				nonStep = nonStep + 1
			end
		end
		local r = replay.new { start = m.start, log = m.log, checkCpu = true, checkThrows = true }
		local info = r:finish()
		expect.eq(info.differs, false, "seed " .. seed .. ": every hash the same")
		expect.eq(info.forged, false)
		expect.eq(info.outOfBounds, false, "seed " .. seed .. ": " .. tostring(info.outOfBoundsWhy))
		expect.truthy(info.throwsChecked > 5)
	end
	expect.truthy(tilts > 5 and spins > 2 and nonStep > 5, "tilts " .. tilts .. ", spins " .. spins)
end)

test("a kubb's plan.spin must be its launch's; a fractional spin out of range is refused", function()
	local m
	for seed = 1, 6 do
		m = play(seed)
		if m.spins > 0 then break end
	end
	local s = session.restore(m.start, replay.NOBODY)
	for _, e in ipairs(m.log) do
		local a = e.a
		if a.type == "throw" and a.how == "drill" and not a.scripted then
			expect.eq(check.throw(s, a).ok, true, "honest")
			local lie = json.decode(json.encode(a))
			lie.plan.spin = a.plan.spin + 0.5
			local c = check.throw(s, lie)
			expect.eq(c.ok, false)
			expect.eq(c.why, "the plan's spin is not the launch's")
			local far = json.decode(json.encode(a))
			far.plan = nil
			far.launch.spin = tw.drill.tune.spiral + 3.2 * pt.spinPerStep
			expect.eq(check.throw(s, far).ok, false, "past spinSteps")
			-- without its plan (as an older client sends) a fractional spin still checks
			local bare = json.decode(json.encode(a))
			bare.plan = nil
			expect.eq(check.throw(s, bare).ok, true, "no plan: " .. tostring(check.throw(s, bare).why))
			return
		end
		s:apply(a)
	end
	error("no person's kubb in the match")
end)
