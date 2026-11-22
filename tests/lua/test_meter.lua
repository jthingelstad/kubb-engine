-- The person's meter (0.13; docs/notes/throw.md "The person's meter"): one meter for
-- every person, the bars by distance, and an honest meter: a swing inside both bars
-- and steady goes where it was aimed. The computer keeps the levels (plan.levels,
-- autothrow.cpuLevel). Real physics for the lone kubb; seeded, so the counts are fixed.
import "core/throwplan"
import "core/flight"
import "core/world"
import "core/autothrow"
local plan, flight, world, autothrow = tw.plan, tw.flight, tw.world, tw.autothrow

-- A kubb's seat (world.seat, on from 1.0.0) leans a kubb set down plumb by up to its
-- surface's seat. This test holds the person's meter to tools/meterprobe.lua's targets,
-- measured on a plumb lone kubb (with the seat the 6 m rate read 57% against 48, the
-- meter's tuning and not the turf), so it runs with the seat off (seatOn 0, as before
-- 1.0); the seat itself is tests/lua/test_seat.lua's.
local function plumb(fn)
	return function()
		local saved = tw.world.tune.seatOn
		tw.world.tune.seatOn = 0
		local ok, err = pcall(fn)
		tw.world.tune.seatOn = saved
		if not ok then error(err, 0) end
	end
end

local PY = 1

local function personSol(d, projectile)
	if projectile == "kubb" then
		return plan.solve({ projectile = "kubb", px = 0, py = 0, tx = 1.9, ty = d, release = plan.arcFor("drill"),
			meter = plan.meter(), surface = "grass", spin = 1 }, {})
	end
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d, release = plan.arcFor("baton", d),
		meter = plan.meter(), aimZ = plan.aimZFor(d >= 6 and "base" or "field") }, {})
end

-- does this launch fell a lone standing kubb d m out, turned yaw?
local function fells(d, yaw, L)
	local w = world.new { surface = "grass", stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	for _ = 1, 8 * 240 do
		world.step(w)
		if world.isAtRest(w) then break end
	end
	return w.byId.k.toppled
end

test("meter: a level names the computer's standard; a person's meter is plan.meter whatever the name", function()
	expect.eq(plan.meter(), plan.meters.standard)
	expect.eq(plan.meter("club"), plan.meters.standard, "a level name is not a meter")
	expect.eq(plan.meter("pro"), plan.meters.standard)
	-- a solve with a meter ignores the level it is also given
	local q = { projectile = "baton", px = 0, py = 0, tx = 0, ty = 7, release = 60, meter = plan.meter() }
	local a = plan.solve(q, {})
	for _, name in ipairs(plan.LEVELS) do
		q.level = name
		local b = plan.solve(q, {})
		expect.eq(b.powerLo, a.powerLo, name); expect.eq(b.powerHi, a.powerHi, name)
		expect.eq(b.releaseLo, a.releaseLo, name); expect.eq(b.releaseHi, a.releaseHi, name)
		expect.eq(b.level.meter, plan.meters.standard)
	end
	-- and a solve with a level alone is that level's, as the computer's is
	q.meter, q.level = nil, "beginner"
	local c = plan.solve(q, {})
	expect.near(c.powerHi - c.powerLo, 2 * plan.levels.beginner.powerHalf, 1e-9)
	expect.eq(c.level, plan.levels.beginner)
end)

test("meter: the bars are wide for a short throw and narrow for a long one", function()
	for _, projectile in ipairs { "baton", "kubb" } do
		local prevP, prevR = math.huge, math.huge
		for _, d in ipairs { 3, 4, 5, 6, 7, 8, 9 } do
			local sol = personSol(d, projectile)
			local wp, wr = sol.powerHi - sol.powerLo, sol.releaseHi - sol.releaseLo
			-- (0.18.0: a baton's power bar is also held by its speed, plan.meters powerSpeed,
			-- so it is never wider than the distance's and may be narrower than a farther one's)
			local byDist = 2 * plan.meterLevel(plan.meter(), d, projectile).powerHalf
			expect.truthy(wp <= byDist + 1e-12, string.format("%s %d m: power bar within the distance's", projectile, d))
			if projectile == "kubb" then wr = wr; expect.truthy(wp < prevP, string.format("kubb %d m narrower than nearer", d)) end
			expect.truthy(wr < prevR, string.format("%s %d m release narrower than nearer", projectile, d))
			wp = projectile == "kubb" and wp or prevP
			expect.near((sol.powerLo + sol.powerHi) / 2, sol.back, 1e-9)
			expect.near((sol.releaseLo + sol.releaseHi) / 2, sol.release, 1e-9)
			prevP, prevR = wp, wr
		end
	end
	-- held at nearM: a point-blank throw's bars are the nearM throw's
	local m = plan.meter()
	local a, b = plan.meterLevel(m, 1, "baton"), plan.meterLevel(m, m.nearM, "baton")
	expect.eq(a.powerHalf, b.powerHalf); expect.eq(a.releaseHalf, b.releaseHalf)
	-- the 8 m baton's bars are the meter's own numbers
	local e = plan.meterLevel(m, 8, "baton")
	expect.near(e.powerHalf, m.powerHalf8, 1e-12); expect.near(e.releaseHalf, m.releaseHalf8, 1e-12)
end)

test("meter: a perfect swing fells a lone kubb at 4, 6 and 8 m, nerves and all", function()
	for _, d in ipairs { 4, 6, 8 } do
		local sol = personSol(d)
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
			how = "stopped" }
		local r, yr = plan.rng(31 + d), plan.rng(57 + d)
		local fell = 0
		for _ = 1, 30 do
			local L = plan.launch(sol, sw, { nerves = r }, {})
			expect.eq(L.sideV, 0, "a perfect swing goes straight")
			if fells(d, yr.next() * math.pi / 2, L) then fell = fell + 1 end
		end
		expect.eq(fell, 30, d .. " m")
	end
end)

test("meter: the meter is honest: a steady swing inside both bars fells the kubb and is not PULLED", function()
	for _, d in ipairs { 4, 6, 8 } do
		local sol = personSol(d)
		local lv = sol.level
		local r, nr, yr = plan.rng(101 + d), plan.rng(203 + d), plan.rng(307 + d)
		local fell, n = 0, 40
		for _ = 1, n do
			local shake = r.next() * plan.tune.steadyBelow * 0.999
			local sw = { back = sol.back + (2 * r.next() - 1) * lv.powerHalf * 0.999,
				releaseAngle = sol.release + (2 * r.next() - 1) * lv.releaseHalf * 0.999, flickFrac = 1,
				shake = shake, smoothness = 1 - shake, pull = r.next() < 0.5 and -1 or 1, how = "stopped" }
			local L = plan.launch(sol, sw, { nerves = nr }, {})
			expect.truthy(L.powerV == 0 and L.releaseV == 0 and L.steady, "inside both bars and steady")
			expect.eq(L.sideV, 0, string.format("%d m: a steady swing is not PULLED", d))
			if fells(d, yr.next() * math.pi / 2, L) then fell = fell + 1 end
		end
		expect.truthy(fell >= 0.95 * n, string.format("%d m: %d of %d fell", d, fell, n))
	end
end)

test("meter: outside a bar the error counts in full, so every miss has a readable cause", function()
	local sol = personSol(8)
	local lv = sol.level
	local function at(over)
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
			how = "stopped" }
		for k, v in pairs(over) do sw[k] = v end
		return plan.launch(sol, sw, nil, {})
	end
	local inside, past = at { back = sol.back + lv.powerHalf * 0.99 }, at { back = sol.powerHi + 5 }
	expect.eq(inside.powerV, 0); expect.eq(past.powerV, 1)
	expect.truthy(past.speed - inside.speed > 5 * (inside.speed - sol.speed), "LONG costs, inside barely")
	expect.eq(at { releaseAngle = sol.releaseLo - 5 }.releaseV, -1)
	-- a steady shake is forgiven (shakeIn), a shaky one counts in full past steadyBelow
	local steady = at { shake = plan.tune.steadyBelow * 0.99 }
	local shaky = at { shake = 0.6 }
	expect.truthy(steady.steady and not shaky.steady)
	expect.truthy(math.abs(steady.tilt) < 2, "a steady swing hardly tilts")
	expect.truthy(math.abs(shaky.tilt) > 10 * math.abs(steady.tilt), "a shaky one does")
	expect.near(plan.unshake(plan.shakeCounts(0.1, lv), lv), 0.1, 1e-12)
	expect.near(plan.unshake(plan.shakeCounts(0.7, lv), lv), 0.7, 1e-12)
end)

test("meter: a person's kubb keeps the clean hand inside the bars and scatters outside them", function()
	local sol = personSol(4.75, "kubb")
	local lv = sol.level
	local function scatter(over)
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
			how = "stopped" }
		for k, v in pairs(over) do sw[k] = v end
		return plan.launch(sol, sw, { projectile = "kubb", spin = 1 }, {}).scatter
	end
	local m = plan.meter()
	expect.eq(scatter {}, m.drillScatter, "a clean swing: pro's hand")
	expect.eq(scatter { back = sol.back + lv.powerHalf * 0.99 }, m.drillScatter, "inside the bar: the same")
	expect.truthy(scatter { back = sol.powerHi + lv.powerHalf } > 2 * m.drillScatter, "past the bar: it scatters")
	expect.truthy(scatter { shake = 0.6, smoothness = 0.4 } > 1.5 * m.drillScatter, "shaky: it scatters")
	-- the computer's kubb keeps its level's hand
	for _, name in ipairs(plan.LEVELS) do
		local lvc = autothrow.cpuLevel(name)
		local s = plan.solve({ projectile = "kubb", px = 0, py = 0, tx = 1.9, ty = 4.75, release = plan.arcFor("drill"),
			level = lvc, surface = "grass", spin = 1 }, {})
		local sw = { back = s.back + 30, releaseAngle = s.release, flickFrac = 1, smoothness = 0.4, shake = 0.6,
			pull = 1, how = "stopped" }
		expect.eq(plan.launch(s, sw, { projectile = "kubb", spin = 1, level = lvc }, {}).scatter,
			plan.levels[name].drillScatter, name)
	end
end)

test("meter: a degree is a degree: past the power bar the backswing counts the same at every range", function()
	local m = plan.meter()
	for _, d in ipairs { 3, 4, 5, 6, 7, 8, 9 } do
		local sol = personSol(d)
		local h = sol.level.powerHalf
		for _, x in ipairs { 1, 5, 10, 20 } do
			for _, sgn in ipairs { -1, 1 } do
				local back = sol.back + sgn * (h + x)
				local sw = { back = back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
					how = "stopped" }
				local L = plan.launch(sol, sw, nil, {})
				-- what counts is the swing less the bar's own forgiveness, h (1 - inGain), at any range
				expect.near(L.back, back - sgn * h * (1 - m.inGain), 1e-9, string.format("%d m, %d past", d, sgn * x))
				expect.near(L.speed, plan.speedFor(L.back), 1e-12)
				expect.eq(L.sideV, 0, "power alone pulls nothing")
			end
		end
	end
end)

test("meter: the release past its bar pulls the baton, late left and early right, pullPerDeg a degree", function()
	local m = plan.meter()
	for _, d in ipairs { 4, 6, 8 } do
		local sol = personSol(d)
		local h = sol.level.releaseHalf
		local function side(dRel)
			local sw = { back = sol.back, releaseAngle = sol.release + dRel, flickFrac = 1, smoothness = 1, shake = 0,
				pull = 1, how = "stopped" }
			return plan.launch(sol, sw, nil, {})
		end
		expect.eq(side(h * 0.99).sideDeg, 0, "inside the bar: no pull")
		expect.eq(side(-h * 0.99).sideDeg, 0)
		for _, x in ipairs { 2, 5, 10 } do
			local late, early = side(h + x), side(-h - x)
			expect.near(late.sideDeg, -m.pullPerDeg * x, 1e-9, "late pulls left")
			-- (a stop is never under 0: the pull counts from the stop as it is)
			local ex = math.max(0, math.min(x, sol.release - h)) -- (0.16: a drive's bar reaches under 6 o'clock)
			expect.near(early.sideDeg, m.pullPerDeg * ex, 1e-9, "early pulls right")
			expect.eq(late.releaseV, 1); expect.eq(early.releaseV, -1)
		end
		-- an angle: the miss in metres grows with the range by itself
		local L = side(h + 10)
		expect.near(L.sideM, math.tan(math.rad(-m.pullPerDeg * 10)) * sol.dist, 1e-9)
	end
	-- a kubb is not pulled by its release (its scatter does that job), nor the computer
	local k = personSol(4.75, "kubb")
	local sw = { back = k.back, releaseAngle = k.releaseHi + 10, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
		how = "stopped" }
	expect.eq(plan.launch(k, sw, { projectile = "kubb", spin = 1 }, {}).sideDeg, 0)
	local lvc = autothrow.cpuLevel("club")
	local c = plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + 8, release = 60, level = lvc }, {})
	sw = { back = c.back, releaseAngle = c.releaseHi + 10, flickFrac = 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
	expect.eq(plan.launch(c, sw, { level = lvc }, {}).sideDeg, 0)
end)

test("meter: the recorded hand fells a lone kubb about as the reference's club rows say", plumb(function()
	local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
	local human = dofile(here .. "/../../tools/gym/human.lua")
	-- fit 1, the hand the meter's bars were tuned with (0.13). Fit 2 (2026-11-22, the
	-- default model) is people at the meter itself and fells 76 / 60 / 44%: whether the
	-- bars narrow to bring it back to the reference rows is a decision for the game, not
	-- this test (docs/notes/gym.md "Fitting the human thrower")
	local model = human.load(here .. "/../../tools/gym/human-model-0.7.json")
	local p = human.part(model, "club", "baton")
	-- tools/meterprobe.lua's TARGETS for the recorded hand (x1), at 200 throws a range:
	-- within 8 points (twice the 4 the meter is tuned to, for the smaller sample)
	for _, c in ipairs { { 4, 72 }, { 6, 48 }, { 8, 27 } } do
		local d = c[1]
		local sol = personSol(d)
		local r, nr, yr = plan.rng(500 + d * 13), plan.rng(900 + d * 7), plan.rng(77 + d)
		local fell, n = 0, 200
		for _ = 1, n do
			local L = plan.launch(sol, human.swing(sol, p, r, {}), { nerves = nr }, {})
			local yaw = yr.next() * math.pi / 2
			if L.legal and fells(d, yaw, L) then fell = fell + 1 end
		end
		local pc = 100 * fell / n
		expect.truthy(math.abs(pc - c[2]) <= 8, string.format("%d m: %.0f%% against %d", d, pc, c[2]))
	end
end))
