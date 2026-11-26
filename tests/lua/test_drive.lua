-- The drive (0.16, docs/notes/throw.md "The drive"): ARC under half past 5 throws a
-- baton flat or down and hard, the default arc is firm close in, a drive
-- does not flip, and the two group positions a player reported (written out by hand in
-- tests/fixtures/drive/positions.lua) fall more to the new default than to the old.
import "core/world"
import "core/throwplan"
import "core/flight"
local world, plan, flight = tw.world, tw.plan, tw.flight

-- A kubb's seat (world.seat, on from 1.0.0) leans a kubb set down plumb by up to its
-- surface's seat. The two group positions compare two default arcs as measured on plumb
-- kubbs (tools/driveprobe.lua, docs/notes/throw.md "The drive"); with the seat group2's
-- margin read 0.11 a baton against the pinned 0.15, so it runs with the seat off (seatOn
-- 0, as before 1.0); the seat itself is tests/lua/test_seat.lua's.
local function plumb(fn)
	return function()
		local saved = tw.world.tune.seatOn
		tw.world.tune.seatOn = 0
		local ok, err = pcall(fn)
		tw.world.tune.seatOn = saved
		if not ok then error(err, 0) end
	end
end
local POS = dofile("tests/fixtures/drive/positions.lua")

local function solve(d, release, extra)
	local q = { projectile = "baton", px = 0, py = 0, tx = 0, ty = d, release = release, meter = plan.meter(),
		aimZ = plan.aimZFor("kubb") }
	for k, v in pairs(extra or {}) do q[k] = v end
	return plan.solve(q, {})
end

test("drive: under the knee the loft falls to loftAt0; above it the one line, as before", function()
	local t = plan.tune
	expect.near(plan.loftFor(t.driveKneeDeg), 7, 1e-12)
	expect.near(plan.loftFor(0), t.loftAt0, 1e-12)
	expect.near(plan.loftFor(7.5), (7 + t.loftAt0) / 2, 1e-12)
	-- a swing about a plan from the knee up is the one line, bit for bit
	for _, e in ipairs { 3, 10, 14.9, 15, 40 } do
		expect.eq(plan.launchLoft(15, e), plan.loftFor(e, true))
		expect.eq(plan.launchLoft(60, e), plan.loftFor(e, true))
	end
	-- about a drive: its loft plus the error at the one line's slope (a third a degree)
	expect.near(plan.launchLoft(6, 9), plan.loftFor(6) + 1, 1e-12)
	expect.near(plan.launchLoft(6, 0), plan.loftFor(6) - 2, 1e-12)
	-- continuous across the knee
	expect.near(plan.launchLoft(15 - 1e-9, 20), plan.launchLoft(15, 20), 1e-8)
	-- a thrown kubb never drives
	expect.eq(plan.launchLoft(15, 0, true), t.lineMinDeg)
	expect.eq(plan.clampRelease(3, "kubb"), t.driveKneeDeg)
	local k = plan.solve({ projectile = "kubb", px = 1.9, py = 0, tx = 1.9, ty = 4.75, release = 0,
		meter = plan.meter() }, {})
	expect.eq(k.release, t.driveKneeDeg, "a kubb's plan starts at the knee")
end)

test("drive: the default is firm close in and as before at 8 m", function()
	expect.eq(plan.arcFor("baton", 8), plan.sharedArcFor(8))
	expect.eq(plan.arcFor("baton", 0.6), plan.sharedArcFor(0.6), "point blank: as before")
	local near = solve(1.5, plan.arcFor("baton", 1.5))
	local old = solve(1.5, plan.sharedArcFor(1.5))
	expect.truthy(near.loft < 0, "a drive at 1.5 m: down, loft " .. near.loft)
	expect.truthy(near.speed > old.speed + 1.5, "and harder: " .. near.speed .. " against " .. old.speed)
	expect.near(near.tumble, 0, 1e-12, "and it does not flip")
	local four = solve(4, plan.arcFor("baton", 4))
	expect.truthy(four.loft < 6 and four.back <= plan.tune.driveBackMaxDeg, "4 m: low and makeable")
	expect.truthy(four.tumble > 0, "4 m: still a turn, eased")
end)

test("drive: the floor is the lowest release the swing can make, never above the knee", function()
	local t = plan.tune
	local vmax = plan.speedFor(t.driveBackMaxDeg)
	for _, d in ipairs { 1, 1.5, 2, 3, 4, 5 } do
		local f = solve(d, 0)
		expect.truthy(f.release >= 0 and f.release <= t.driveKneeDeg, "floor at " .. d)
		expect.truthy(f.speed <= vmax * (1 + 1e-6), "the floor's speed at " .. d .. ": " .. f.speed)
		if f.release > 1e-6 then
			local below = solve(d, f.release - 0.05)
			expect.near(below.release, f.release, 1e-5, "a plan under the floor is raised to it at " .. d)
		end
	end
	-- 8 m: nothing under the knee can be made, so the knee is the floor and every plan
	-- from it up is as it was
	expect.eq(solve(8, 0).release, t.driveKneeDeg)
	local a, b = solve(8, 15), solve(8, 15)
	expect.eq(a.speed, b.speed)
end)

-- 1.0: a line whose drag-free speed is already past the swing's costs no carry. Drag only
-- adds to the speed a line needs (measured over every line the game can plan, the hand
-- over the aim: the carry speed is at least the drag-free one wherever that one is near
-- the swing's top speed), so the pre-check never refuses a line the carry would take.
test("drive: the drag-free pre-check never refuses a line the carry would take", function()
	local g, k = flight.tune.g, flight.tune.dragK.baton
	local vmax = plan.speedFor(plan.tune.driveBackMaxDeg)
	local n = 0
	for Ri = 10, 80, 5 do
		local R = Ri / 10
		for _, hz in ipairs { 0.05, 0.2, 0.36, 0.43, 0.6 } do
			for ei = -150, 100, 2 do
				local e = math.rad(ei / 10)
				local den = R * math.tan(e) + hz
				if den > 0 then
					local c = math.cos(e)
					local vdf = math.sqrt(g * R * R / (2 * c * c * den))
					if vdf > vmax and vdf < 2 * vmax then
						n = n + 1
						local sp = flight.speedForCarry(R, e, hz, k)
						expect.truthy(not (sp == sp and sp > 0 and sp <= vmax),
							string.format("R %g hz %g loft %g: carry %g under %g", R, hz, ei / 10, sp, vmax))
					end
				end
			end
		end
	end
	expect.truthy(n > 500, "lines checked: " .. n)
end)

test("drive: a kept drive raised to a new floor runs no carry that returns nan", function()
	local real = flight.speedForCarry
	local bad, calls = 0, 0
	flight.speedForCarry = function(...)
		local v, T = real(...)
		calls = calls + 1
		if v ~= v then bad = bad + 1 end
		return v, T
	end
	local ok, err = pcall(function()
		for _, d in ipairs { 1.5, 2, 2.21, 3, 4, 5 } do
			for i = 1, 5 do
				-- the circle moves a little: each solve finds a new floor
				solve(d + i * 1e-3, 0)
				plan.arcFloor({ projectile = "baton", px = 0.01 * i, py = 0, tx = 0, ty = d, release = 3,
					meter = plan.meter(), aimZ = plan.aimZFor("king") })
			end
		end
	end)
	flight.speedForCarry = real
	assert(ok, err)
	expect.eq(bad, 0, "carries that returned nan (" .. calls .. " in all)")
	-- the floors as docs/notes/throw.md gives them (a kubb's aim height, the person's meter; 3 and 4 m
	-- lower from 1.3.0, the aim by how the baton arrives)
	for d, f in pairs { [1.5] = 0.3, [2] = 5.0, [3] = 8.9, [4] = 11.6, [5] = 14.8 } do
		expect.near(solve(d, 0).release, f, 0.05, "the floor at " .. d .. " m")
	end
end)

-- The two positions: the old default (plan.sharedArcFor) against 0.16's, each thrown n times with the same seeded jitter of aim, loft, speed,
-- tilt and turn as tools/driveprobe.lua. Measured there with 300 throws (docs/notes/
-- throw.md "The drive"); pinned here at n = 60 with a margin of 0.15 kubbs a baton.
local function felled(pos, release, n)
	local st, tg = pos.stance, pos.pieces[pos.target]
	local d = math.sqrt((tg.x - st.x) ^ 2 + (tg.y - st.y) ^ 2)
	local sol = plan.solve({ projectile = "baton", px = st.x, py = st.y, tx = tg.x, ty = tg.y,
		release = release(d), meter = plan.meter(), aimZ = plan.aimZFor("kubb") }, {})
	local r = plan.rng(77)
	local total = 0
	for _ = 1, n do
		local w = world.new { surface = "grass", pieces = POS.pieces(pos) }
		local tumble = sol.tumble + r.normal(0.06) * 2 * math.pi / sol.flightT
		world.launchBaton(w, st.x, st.y, sol.swivel + math.rad(r.normal(0.6)), sol.loft + r.normal(1),
			sol.speed * (1 + r.normal(0.03)), tumble > 0 and tumble or 0, r.normal(6), "baton",
			sol.handZ, sol.handFwd, sol.handTip)
		world.run(w, 6)
		for _, id in ipairs(world.result(w).toppled) do
			local k = tonumber(id:match("^p(%d+)$"))
			if k and pos.pieces[k].field then total = total + 1 end
		end
	end
	return total / n
end

for _, name in ipairs { "group1", "group2" } do
	test("drive: the reported " .. name .. " falls more to the drive than to the old default", plumb(function()
		local old = felled(POS[name], function(d) return plan.sharedArcFor(d) end, 60)
		local new = felled(POS[name], function(d) return plan.arcFor("baton", d) end, 60)
		print(string.format("      %s: %.2f a baton against %.2f", name, new, old))
		expect.truthy(new >= old + 0.15, string.format("%s: %.2f a baton against %.2f", name, new, old))
	end))
end
