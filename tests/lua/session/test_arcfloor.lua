-- ARC and the drive's floor (0.16; Codex on #47): a release set under the throw's floor
-- is kept at the floor, a step goes from the release as planned and never under the
-- floor, so every step and every reversal at the floor moves the throw; a kept release
-- under a floor that rose is planned at the floor and comes back when it falls again.
import "session/session"
tw.web.session.useTune("pointer")
local session, plan = tw.web.session, tw.plan
local pt = plan.tune
local START = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }

-- A person aiming from 3 m out (an advantage line) at an empty spot d metres ahead.
local function at(d)
	local s = session.new { mode = "match", seed = 7, cpu = "B", start = START, maxTurns = 4,
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	s.setup.forwardY, s.ts.forwardY = 3, 3
	s:setStance(0, 3)
	s:setTarget(0, 3 + d, false)
	return s
end
local function shown(s) return s:aimView().controls.arc.value end
local function planned(s) return s.ts.sol.release end

test("arc floor: at 5 m setArc(0) shows and plans the floor, and the first step up moves it", function()
	local s = at(5)
	local floor = s.ts.arcMin
	expect.truthy(floor > 10, "a high floor at 5 m: " .. floor)
	s:setArc(0)
	expect.near(shown(s), floor, 1e-5); expect.near(planned(s), floor, 1e-5); expect.eq(s.ts.release, floor)
	s:stepArc(1)
	expect.near(shown(s), floor + pt.arcStepDeg, 1e-5, "one step up from what was shown")
	expect.near(planned(s), floor + pt.arcStepDeg, 1e-5)
	s:stepArc(-1); s:stepArc(-1)
	expect.near(shown(s), floor, 1e-5, "down at the floor stays there")
	s:stepArc(1)
	expect.near(planned(s), floor + pt.arcStepDeg, 1e-5, "and the reversal moves the throw at once")
end)

test("arc floor: a kept release comes back when the floor falls, and is planned at a risen floor", function()
	local s = at(1.5)
	local low = s.ts.arcMin
	expect.truthy(low < 1, "a low floor close in: " .. low)
	s:setArc(5)
	expect.eq(planned(s), 5)
	s:setTarget(0, 3 + 4, false)
	local f4 = s.ts.arcMin
	expect.truthy(f4 > 5, "the floor at 4 m is over 5: " .. f4)
	expect.near(shown(s), f4, 1e-5); expect.near(planned(s), f4, 1e-5)
	expect.eq(s.ts.release, 5, "the player's release is kept")
	s:setTarget(0, 3 + 1.5, false)
	expect.eq(planned(s), 5, "back where the player set it")
	-- a step from the risen floor goes from the floor, not from the kept value
	s:setTarget(0, 3 + 4, false)
	s:stepArc(-1)
	expect.near(planned(s), f4, 1e-5, "down at a risen floor stays at it")
	s:stepArc(1)
	expect.near(planned(s), f4 + pt.arcStepDeg, 1e-5)
end)

test("arc floor: a thrown kubb's floor is the knee; tilt and spin have no floor of their own", function()
	local s = session.new { mode = "practice" }
	s:setDrill(true)
	s:setArc(0)
	expect.eq(shown(s), pt.driveKneeDeg)
	s:stepArc(1)
	expect.eq(shown(s), pt.driveKneeDeg + pt.arcStepDeg)
	s:setSpin(pt.spinSteps); s:stepSide(1)
	expect.eq(s.ts.spin, pt.spinSteps)
	s:stepSide(-1)
	expect.eq(s.ts.spin, pt.spinSteps - 1, "a reversal at the end moves the spin at once")
	s:setDrill(false)
	s:setTilt(pt.tiltMaxDeg); s:stepSide(1)
	expect.eq(s.ts.tilt, pt.tiltMaxDeg)
	s:stepSide(-1)
	expect.eq(s.ts.tilt, pt.tiltMaxDeg - pt.tiltStepDeg)
end)

test("arc floor: plan.arcFloor is plan.solve's floor and leaves the question alone", function()
	for _, d in ipairs { 1, 1.5, 2, 3, 4, 5, 8 } do
		local q = { projectile = "baton", px = 0, py = 0, tx = 0, ty = d, release = 40, meter = plan.meter(),
			aimZ = plan.aimZFor("kubb") }
		local f = plan.arcFloor(q)
		expect.eq(q.release, 40)
		q.release = 0
		expect.eq(plan.solve(q, {}).release, f)
		-- a client stepping ARC itself (the Playdate): from max(release, floor), never under it
		local r = math.max(0, f)
		local up = math.max(f, plan.clampRelease(r + pt.arcStepDeg))
		q.release = up
		expect.truthy(plan.solve(q, {}).release > f or f >= pt.releaseMaxDeg, "a step up moves the plan at " .. d)
	end
	expect.eq(plan.arcFloor { projectile = "kubb", release = 0 }, pt.driveKneeDeg)
end)
