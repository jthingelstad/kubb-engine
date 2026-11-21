-- The person's meter (0.13; docs/notes/throw.md "The person's meter"): one meter for
-- every person, the bars by distance, and an honest meter: a swing inside both bars
-- and steady goes where it was aimed. The computer keeps the levels (plan.levels,
-- autothrow.cpuLevel). Real physics for the lone kubb; seeded, so the counts are fixed.
import "core/throwplan"
import "core/flight"
import "core/world"
import "core/autothrow"
local plan, flight, world, autothrow = tw.plan, tw.flight, tw.world, tw.autothrow

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
			expect.truthy(wp < prevP and wr < prevR, string.format("%s %d m narrower than nearer", projectile, d))
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

test("meter: a degree past the power bar costs more on a long throw, one for one up to outFromM", function()
	local m = plan.meter()
	-- what one more degree past the edge does to the backswing as it counts
	local function past(d)
		local sol = personSol(d)
		local h = sol.level.powerHalf
		local function eff(e)
			local sw = { back = sol.back + e, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0,
				pull = 1, how = "stopped" }
			return plan.launch(sol, sw, nil, {}).back
		end
		return eff(h + 2) - eff(h + 1), eff(h + m.outCapDeg + 2) - eff(h + m.outCapDeg + 1), eff(h * 0.5) - sol.back
	end
	local a4, b4, in4 = past(4)
	local a8, b8, in8 = past(8)
	expect.near(a4, 1, 1e-9, "4 m: one for one")
	expect.near(a8, m.outGain8, 1e-9, "8 m: outGain8")
	expect.near(b8, 1, 1e-9, "past outCapDeg: one for one again")
	expect.near(b4, 1, 1e-9)
	-- inside the bar nothing changes: inGain at every range
	expect.near(in4, plan.meterLevel(m, 4, "baton").powerHalf * 0.5 * m.inGain, 1e-9)
	expect.near(in8, m.powerHalf8 * 0.5 * m.inGain, 1e-9)
	-- the release past its bar counts one for one at every range (the loft stays pinned by
	-- the stop, so checkThrow can hold it)
	local sol = personSol(8)
	expect.eq(sol.level.outGain > 1, true)
	local sw = { back = sol.back, releaseAngle = sol.releaseHi + 5, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
		how = "stopped" }
	local L = plan.launch(sol, sw, nil, {})
	expect.near(L.release, sol.release + sol.level.releaseHalf * m.inGain + 5, 1e-9)
end)
