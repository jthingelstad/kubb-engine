-- The person's meter (0.13; docs/notes/throw.md "The person's meter"): the bars by
-- distance, and an honest meter: a swing inside both bars and steady goes where it was
-- aimed. Since 1.3.0 no nerves, the release sets the line inside its bar too, and three
-- player levels (easy, standard, hard) that differ in their bars. The computer keeps the levels (plan.levels,
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

local function personSol(d, projectile, meter)
	meter = plan.meter(meter)
	if projectile == "kubb" then
		return plan.solve({ projectile = "kubb", px = 0, py = 0, tx = 1.9, ty = d, release = plan.arcFor("drill"),
			meter = meter, surface = "grass", spin = 1 }, {})
	end
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d, release = plan.arcFor("baton", d),
		meter = meter, aimZ = plan.aimZFor(d >= 6 and "base" or "field") }, {})
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

-- The honest meter (1.3.0; the owner, 2026-11-26): no hidden draw on a person's throw, a
-- perfect throw always lands, and an easier player level makes a good throw easier to
-- make, never makes one fail. At every player level and range.
test("meter: a perfect swing fells a lone kubb at every player level, 3 to 8 m", function()
	for _, name in ipairs(plan.THROW_LEVELS) do
		for _, d in ipairs { 3, 4, 6, 8 } do
			local sol = personSol(d, nil, name)
			local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
				how = "stopped" }
			local yr = plan.rng(57 + d)
			local fell = 0
			for _ = 1, 12 do
				local L = plan.launch(sol, sw, { nerves = true }, {})
				expect.eq(L.sideDeg, 0, "a perfect swing goes straight")
				expect.eq(L.sideV, 0)
				if fells(d, yr.next() * math.pi / 2, L) then fell = fell + 1 end
			end
			expect.eq(fell, 12, name .. " " .. d .. " m")
		end
	end
end)

test("meter: the meter is honest: a steady swing inside both bars fells the kubb and is not PULLED, at every level", function()
	for _, name in ipairs(plan.THROW_LEVELS) do
		for _, d in ipairs { 4, 6, 8 } do
			local sol = personSol(d, nil, name)
			local lv = sol.level
			local r, yr = plan.rng(101 + d), plan.rng(307 + d)
			local fell, n = 0, 40
			for _ = 1, n do
				local shake = r.next() * plan.tune.steadyBelow * 0.999
				local eb, er = 2 * r.next() - 1, 2 * r.next() - 1
				local sw = { back = sol.back + eb * lv.powerHalf * 0.999,
					releaseAngle = sol.release + er * lv.releaseHalf * 0.999, flickFrac = 1,
					shake = shake, smoothness = 1 - shake, pull = r.next() < 0.5 and -1 or 1, how = "stopped" }
				local L = plan.launch(sol, sw, { nerves = true }, {})
				expect.truthy(L.powerV == 0 and L.releaseV == 0 and L.steady, "inside both bars and steady")
				expect.eq(L.sideV, 0, string.format("%s %d m: a steady swing is not PULLED", name, d))
				if fells(d, yr.next() * math.pi / 2, L) then fell = fell + 1 end
			end
			expect.eq(fell, n, string.format("%s %d m: %d of %d fell", name, d, fell, n))
		end
	end
end)

test("meter: no hidden draw: the same swing gives the same throw, nerves asked or not", function()
	for _, name in ipairs(plan.THROW_LEVELS) do
		local m = plan.meter(name)
		expect.eq(m.nervesDeg, 0, name); expect.eq(m.nervesLen, 0, name); expect.eq(m.tumbleSd, 0, name)
		for _, projectile in ipairs { "baton", "kubb" } do
			local sol = personSol(projectile == "kubb" and 4.75 or 7, projectile, name)
			local sw = { back = sol.back + 7, releaseAngle = sol.release - 9, flickFrac = 0.93, smoothness = 0.8,
				shake = 0.2, pull = -1, how = "stopped" }
			local o = { projectile = projectile, spin = projectile == "kubb" and 1 or nil }
			local a = plan.launch(sol, sw, { projectile = projectile, spin = o.spin, nerves = true }, {})
			local b = plan.launch(sol, sw, { projectile = projectile, spin = o.spin, nerves = plan.rng(99) }, {})
			local c = plan.launch(sol, sw, { projectile = projectile, spin = o.spin }, {})
			for _, k in ipairs { "speed", "loft", "swivel", "tilt", "tumble", "sideDeg", "lenShare" } do
				expect.eq(a[k], c[k], name .. " " .. projectile .. " " .. k)
				expect.eq(b[k], c[k], name .. " " .. projectile .. " " .. k)
			end
			expect.eq(a.sdSide, 0); expect.eq(a.sdLen, 0)
		end
	end
	-- the Kid meter keeps its nerves (0.15.0), and the computer its levels'
	expect.truthy(plan.meters.kid.nervesDeg > 0)
	for _, name in ipairs(plan.LEVELS) do expect.truthy(plan.levels[name].nervesDeg > 0, name) end
end)

test("meter: easy's bars are wider than standard's and hard's narrower, at every range and for both", function()
	for _, projectile in ipairs { "baton", "kubb" } do
		for _, d in ipairs { 2, 3, 4, 6, 8, 10 } do
			local e = plan.meterLevel(plan.meter("easy"), d, projectile)
			local st = plan.meterLevel(plan.meter("standard"), d, projectile)
			local h = plan.meterLevel(plan.meter("hard"), d, projectile)
			local at = projectile .. " " .. d .. " m"
			expect.truthy(e.powerHalf > st.powerHalf and st.powerHalf > h.powerHalf, at .. ": power")
			expect.truthy(e.releaseHalf > st.releaseHalf and st.releaseHalf > h.releaseHalf, at .. ": release")
			-- an easier level never lets more of an error inside a bar through
			expect.truthy(e.inGain <= st.inGain and st.inGain <= h.inGain, at .. ": inGain")
		end
	end
	expect.eq(plan.meter("easy"), plan.meters.easy)
	expect.eq(plan.meter("hard"), plan.meters.hard)
	expect.eq(plan.meter("standard"), plan.meters.standard)
	for _, v in ipairs(plan.THROW_LEVELS) do expect.truthy(plan.isThrowLevel(v), v) end
	expect.eq(plan.isThrowLevel("club"), false, "a computer's level is not a person's")
	expect.eq(plan.isThrowLevel("kid"), false, "the Kid meter is the match's")
	expect.eq(plan.THROW_DEFAULT, "standard")
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

test("meter: the release sets the line: edgeM off at the bar's edge, then pullPerDeg a degree past it", function()
	for _, name in ipairs(plan.THROW_LEVELS) do
		local m = plan.meter(name)
		for _, d in ipairs { 4, 6, 8 } do
			local sol = personSol(d, nil, name)
			local h = sol.level.releaseHalf
			local e = math.deg(math.atan(m.edgeM / sol.dist))
			local function side(dRel)
				local sw = { back = sol.back, releaseAngle = sol.release + dRel, flickFrac = 1, smoothness = 1, shake = 0,
					pull = 1, how = "stopped" }
				return plan.launch(sol, sw, nil, {})
			end
			-- inside the bar: in proportion, a late release left and an early one right
			expect.eq(side(0).sideDeg, 0, "dead centre: on the line")
			expect.near(side(h * 0.5).sideDeg, -e * 0.5, 1e-9, "inside the bar, late: left")
			-- (a stop is never under 0: at 4 m the bar reaches under 6 o'clock)
			expect.near(side(-h * 0.5).sideDeg, e * math.min(h * 0.5, sol.release) / h, 1e-9, "inside the bar, early: right")
			local edge = side(h * 0.999)
			expect.near(edge.sideM, -math.tan(math.rad(e * 0.999)) * sol.dist, 1e-9)
			expect.truthy(math.abs(edge.sideM) < m.edgeM, "at the edge: edgeM off at the target")
			expect.eq(edge.sideV, 0, "STRAIGHT inside the bar")
			for _, x in ipairs { 2, 5, 10 } do
				local late, early = side(h + x), side(-h - x)
				expect.near(late.sideDeg, -e - m.pullPerDeg * x, 1e-9, "late pulls left")
				-- (a stop is never under 0: the pull counts from the stop as it is)
				local ex = math.max(0, math.min(x, sol.release - h)) -- (0.16: a drive's bar reaches under 6 o'clock)
				if ex > 0 then expect.near(early.sideDeg, e + m.pullPerDeg * ex, 1e-9, "early pulls right") end
				expect.eq(late.releaseV, 1); expect.eq(early.releaseV, -1)
			end
			-- continuous at the edge
			expect.near(side(h + 1e-9).sideDeg, side(h - 1e-9).sideDeg, 1e-6)
		end
		-- a thrown kubb is pulled too (1.3.0), at kubbPull past its bar
		local k = personSol(4.75, "kubb", name)
		local hk = k.level.releaseHalf
		local ek = math.deg(math.atan(m.edgeM / k.dist))
		local function kside(dRel)
			local sw = { back = k.back, releaseAngle = k.release + dRel, flickFrac = 1, smoothness = 1, shake = 0,
				pull = 1, how = "stopped" }
			return plan.launch(k, sw, { projectile = "kubb", spin = 1 }, {})
		end
		expect.eq(kside(0).sideDeg, 0)
		expect.near(kside(hk * 0.5).sideDeg, -ek * 0.5, 1e-9, "a kubb inside its bar")
		expect.near(kside(hk + 10).sideDeg, -ek - m.kubbPull * 10, 1e-9, "a kubb past its bar")
		expect.eq(k.level.inGain, m.kubbInGain, "a kubb's share of an error inside a bar")
	end
	-- the Kid meter's kubb is not pulled (0.15.0, as it was), nor the computer's throw
	local kk = personSol(4.75, "kubb", "kid")
	local sw = { back = kk.back, releaseAngle = kk.releaseHi + 10, flickFrac = 1, smoothness = 1, shake = 0, pull = 1,
		how = "stopped" }
	expect.eq(plan.launch(kk, sw, { projectile = "kubb", spin = 1 }, {}).sideDeg, 0)
	local kb = personSol(6, nil, "kid")
	sw = { back = kb.back, releaseAngle = kb.release + kb.level.releaseHalf * 0.9, flickFrac = 1, smoothness = 1,
		shake = 0, pull = 1, how = "stopped" }
	expect.eq(plan.launch(kb, sw, nil, {}).sideDeg, 0, "the Kid meter's baton: none inside its bar")
	local lvc = autothrow.cpuLevel("club")
	local c = plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + 8, release = 60, level = lvc }, {})
	sw = { back = c.back, releaseAngle = c.releaseHi + 10, flickFrac = 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
	expect.eq(plan.launch(c, sw, { level = lvc }, {}).sideDeg, 0)
end)

test("meter: the recorded hand fells a lone kubb about as the reference's club rows say", plumb(function()
	local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
	local human = dofile(here .. "/../../tools/gym/human.lua")
	-- fit 2 (2026-11-22, the default model: people at the 0.13 meter), the hand the 1.3.0
	-- meter was set with (docs/notes/throw.md "The honest meter"); until 1.3.0 this test
	-- held fit 1 (tools/gym/human-model-0.7.json) to the 0.13 meter
	local model = human.load(here .. "/../../tools/gym/human-model.json")
	local p = human.part(model, "club", "baton")
	-- tools/meterprobe.lua's TARGETS for the recorded hand (x1), at 200 throws a range:
	-- within 8 points (twice the 4 the meter is tuned to, for the smaller sample)
	for _, c in ipairs { { 4, 72 }, { 6, 48 }, { 8, 27 } } do
		local d = c[1]
		local sol = personSol(d)
		local r, yr = plan.rng(500 + d * 13), plan.rng(77 + d)
		local fell, n = 0, 200
		for _ = 1, n do
			local L = plan.launch(sol, human.swing(sol, p, r, {}), { nerves = true }, {})
			local yaw = yr.next() * math.pi / 2
			if L.legal and fells(d, yaw, L) then fell = fell + 1 end
		end
		local pc = 100 * fell / n
		expect.truthy(math.abs(pc - c[2]) <= 8, string.format("%d m: %.0f%% against %d", d, pc, c[2]))
	end
end))
