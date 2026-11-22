-- The hand at a short throw (flight.tune, flight.handAt; a player's report,
-- 2026-11-20: two batons at a field kubb 35 cm away both missed). The cases are
-- synthetic, shaped like the report's numbers: a kubb 0.353 m from the stance,
-- turned about 77 degrees, and the two swings' backswing and stop.
import "core/flight"
import "core/world"
import "core/throwplan"

local flight, world, plan = tw.flight, tw.world, tw.plan

-- A kubb's seat (world.seat, on from 1.0.0) leans a kubb set down plumb by up to its
-- surface's seat. This test replays a player's report (2026-11-20) against the kubb as
-- it stood then, plumb; with the seat the second launch lands on a top tipped toward it
-- and fells it, so it runs with the seat off (seatOn 0, as before 1.0); the seat itself
-- is tests/lua/test_seat.lua's.
local function plumb(fn)
	return function()
		local saved = tw.world.tune.seatOn
		tw.world.tune.seatOn = 0
		local ok, err = pcall(fn)
		tw.world.tune.seatOn = saved
		if not ok then error(err, 0) end
	end
end
local D = 0.353
local YAW = -1.34

local function fell(L, sol, yaw, h, fwd, d)
	local w = world.new { surface = "grass", stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0, y = d or D, yaw = yaw } } }
	world.launchBaton(w, 0, 0, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton",
		h or (sol and sol.handZ), fwd or (sol and sol.handFwd), sol and sol.handTip)
	world.run(w, 4)
	return world.result(w).toppled[1] == "k"
end

local function solveAt(d, level)
	return plan.solve({ projectile = "baton", px = 0, py = 0, tx = 0, ty = d,
		release = plan.sharedArcFor(d), level = level or "club", aimZ = plan.aimZFor("field") }, {})
end

local function swing(back, stop, flick)
	return { back = back, releaseAngle = stop, flickFrac = flick or 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
end

-- Of an n x n sample across the gauge's ON ON box (the power target moved by
-- shift degrees), how many topple a kubb d away square and turned 45 degrees.
local function sample(d, n, flick, shift)
	local sol = solveAt(d)
	local sq, diag, of = 0, 0, 0
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local fb, fs = (i + 0.5) / n, (j + 0.5) / n
			local back = sol.powerLo + (shift or 0) + fb * (sol.powerHi - sol.powerLo)
			local stop = sol.releaseLo + fs * (sol.releaseHi - sol.releaseLo)
			local L = plan.launch(sol, swing(back, stop, flick), { level = "club" }, {})
			of = of + 1
			if fell(L, sol, 0, nil, nil, d) then sq = sq + 1 end
			if fell(L, sol, math.pi / 4, nil, nil, d) then diag = diag + 1 end
		end
	end
	return sq / of, diag / of
end

test("handAt: at nearM and over, the feet at handHeight exactly", function()
	local t = flight.tune
	for _, d in ipairs { t.nearM, 2.5, 4, 8, 9.4 } do
		local h, fwd, flat, s, tip = flight.handAt(d)
		expect.eq(h, t.handHeight, "h at " .. d)
		expect.eq(fwd, 0, "fwd at " .. d)
		expect.eq(flat, 1, "loft share at " .. d)
		expect.eq(s, 0, "s at " .. d)
		expect.eq(tip, 0, "tip at " .. d)
	end
	local h, fwd = flight.handAt(nil)
	expect.eq(h, t.handHeight); expect.eq(fwd, 0)
end)

test("handAt: under nearM the hand goes down, ahead and tips the baton, its end off the grass", function()
	local t = flight.tune
	local lastH, lastTip = t.handHeight, 0
	for _, d in ipairs { 1.99, 1.5, 1.0, 0.75, 0.5, 0.35, 0.2, 0.05, 0 } do
		local h, fwd, flat, _, tip = flight.handAt(d)
		expect.truthy(h < lastH, "lower at " .. d)
		expect.truthy(tip > lastTip, "tipped further at " .. d)
		local lowEnd = h - (0.5 * t.batonLength - t.batonRadius) * math.cos(tip) - t.batonRadius
		expect.truthy(lowEnd >= t.nearLow - 1e-9, "its lower end clear of the grass at " .. d)
		expect.truthy(fwd <= 0.5 * d + 1e-12, "fwd within half the distance at " .. d)
		expect.truthy(flat >= 0 and flat < 1, "flatter at " .. d)
		lastH, lastTip = h, tip
	end
end)

test("solve: the club power target stays at 45 degrees or more under nearM", function()
	for d100 = 20, 199, 5 do
		local sol = solveAt(d100 / 100)
		expect.truthy(sol.powerLo >= 45, "power target from " .. sol.powerLo .. " at " .. d100 / 100)
	end
end)

test("solve: no step in the plan at nearM", function()
	local a, b = solveAt(flight.tune.nearM - 1e-6), solveAt(flight.tune.nearM)
	expect.near(a.tumble, b.tumble, 1e-3, "tumble")
	expect.eq(select(2, flight.nearTurn(flight.tune.nearM)), 0, "no turn of its own at nearM")
	expect.near(a.speed, b.speed, 1e-3, "speed")
	expect.near(a.loft, b.loft, 1e-3, "loft")
	expect.near(a.handZ, b.handZ, 1e-4, "hand")
	expect.near(a.aimZ, b.aimZ, 1e-4, "aim height")
	expect.near(a.back, b.back, 0.01, "backswing")
end)

test("solve: a throw of nearM or more is planned as before", function()
	for _, d in ipairs { 2.0, 4.0, 8.0 } do
		local sol = solveAt(d)
		expect.eq(sol.handZ, flight.tune.handHeight, "hand at " .. d)
		expect.eq(sol.handFwd, 0, "fwd at " .. d)
		expect.eq(sol.aimZ, plan.aimZFor("field"), "aim height at " .. d)
		expect.eq(sol.loft, plan.loftFor(plan.sharedArcFor(d)), "loft at " .. d)
	end
end)

test("batonLaunchState: no hand given is the feet at handHeight, bit for bit", function()
	local a = { world.batonLaunchState(0.3, 1.2, 0.01, 22, 6.5, 9, 3) }
	local b = { world.batonLaunchState(0.3, 1.2, 0.01, 22, 6.5, 9, 3, flight.tune.handHeight, 0) }
	for i = 1, 13 do expect.eq(b[i], a[i], "value " .. i) end
end)

test("the report's launches from the feet come down on the kubb's top and leave it standing", plumb(function()
	-- the hit model is unchanged: these are the two launches as the engine made them
	-- before the hand at a short throw (0.7.4), from the feet at handHeight
	local h = flight.tune.handHeight
	expect.eq(fell({ speed = 0.975, loft = 21.7, swivel = 0, tilt = -2.0, tumble = 2.33 }, nil, YAW, h, 0), false, "first")
	expect.eq(fell({ speed = 1.449, loft = 20.9, swivel = 0, tilt = -3.6, tumble = 2.33 }, nil, YAW, h, 0), false, "second")
end))

test("the report's two swings at a kubb 0.353 m away now topple it", function()
	-- (the firm bowl plans a harder throw, so the gauge now calls both short)
	local sol = solveAt(D)
	expect.truthy(sol.handZ < 0.2 and sol.handFwd > 0.1 and sol.handTip > 0.5, "a low hand ahead of the feet")
	for i, sw in ipairs { { 40.92, 57.10 }, { 51.39, 49.01 } } do
		-- (the stops were made at the 4 o'clock arc a field kubb had until 0.10: each
		-- is kept as far from the plan's release as it was from that one)
		local L = plan.launch(sol, swing(sw[1], sw[2] - 60 + sol.release), { level = "club" }, {})
		expect.eq(L.releaseV, 0, "swing " .. i .. ": the stop is ON")
		expect.truthy(fell(L, sol, YAW), "swing " .. i .. " toppled the kubb")
		expect.truthy(fell(L, sol, 0), "swing " .. i .. " toppled a square kubb")
	end
end)

-- The targets (2026-11-20): of the swings the gauge calls ON ON, at least 85%
-- topple a kubb square to the throw and at least 70% one turned 45 degrees, at
-- every range from 0.2 to 1.5 m. A 5 x 5 sample of the box at four ranges.
for _, d in ipairs { 0.2, 0.35, 0.75, 1.25 } do
	test("at " .. d .. " m the swings the gauge calls ON ON topple the kubb", function()
		local sol = solveAt(d)
		local n, of = { 0, 0 }, 0
		for _, fb in ipairs { 0.05, 0.275, 0.5, 0.725, 0.95 } do
			for _, fs in ipairs { 0.05, 0.275, 0.5, 0.725, 0.95 } do
				local back = sol.powerLo + fb * (sol.powerHi - sol.powerLo)
				local stop = sol.releaseLo + fs * (sol.releaseHi - sol.releaseLo)
				local L = plan.launch(sol, swing(back, stop), { level = "club" }, {})
				of = of + 1
				if fell(L, sol, 0, nil, nil, d) then n[1] = n[1] + 1 end
				if fell(L, sol, math.pi / 4, nil, nil, d) then n[2] = n[2] + 1 end
			end
		end
		expect.truthy(n[1] >= 0.85 * of, "square: toppled " .. n[1] .. " of " .. of)
		expect.truthy(n[2] >= 0.70 * of, "45 degrees: toppled " .. n[2] .. " of " .. of)
	end)
end

-- A flick at 0.85 to 0.90 of full is the ordinary player (the report's first
-- throw was 0.89 of its plan's speed). 0.7.4 toppled at flick 0.88 (fine grid,
-- square / 45 degrees): 24% / 0% at 0.35 m, 56% / 45% at 1.25 m, 77% / 38% at
-- 1.5 m. Pinned: at least 80% / 60% (a 4 x 4 sample).
for _, d in ipairs { 0.35, 1.25, 1.5 } do
	test("at " .. d .. " m a flick at 0.88 of full still topples the kubb", function()
		local sq, diag = sample(d, 4, 0.88)
		expect.truthy(sq >= 0.8, "square: " .. sq)
		expect.truthy(diag >= 0.6, "45 degrees: " .. diag)
	end)
end

-- Overpowering a short bowl misses, as players do (Jamie, 2026-11-20): on the
-- band at 0.35 m nearly every swing topples the kubb, two power bands long
-- clearly fewer.
test("at 0.35 m two power bands long topples clearly less than on the band", function()
	local sol = solveAt(0.35)
	local on = sample(0.35, 4, 1)
	local long = sample(0.35, 4, 1, 4 * sol.level.powerHalf)
	expect.truthy(on >= 0.85, "on the band: " .. on)
	expect.truthy(long <= 0.5, "two bands long: " .. long)
end)
