-- The hit window by range (a player's report, 2026-11-20: two batons at a
-- field kubb 35 cm away, both missed). For a standing kubb d metres from the
-- stance, every swing on a grid of backswing (degrees) and stop (degrees past
-- 6 o'clock) is turned into a launch by plan.launch at the level's gauge (the
-- field arc, 4 o'clock, aimed through the kubb as the throw scene aims; the base
-- arc from 6 m), thrown in core/world against that one kubb (grass, no stakes)
-- from the hand flight.handAt gives, and run until it rests or falls. Per range
-- and for the kubb square to the throw and turned 45 degrees:
--   plan       the clean throw's speed, loft and hand (height, ahead of the feet)
--   power      the power target on the clock (the band the gauge calls ON)
--   ON ON      the share of swings inside both targets that topple the kubb
--   area       the toppling area over the whole grid, in square degrees
-- A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/pointblank.lua [--level club] [--ranges 0.2,0.35,1,4] [--coarse]
--     [--flick 0.88] (the flick's share: 1 full)  [--over 1] (the box moved this
--     many power bands long)  [--nerves] (each swing draws its nerves, seeded)
--     [--cpu n] (also n of the computer's throws at each range, its own swing and
--     nerves, stood there regardless of autothrow.tune.minRange)
--     [--behind king --gap 0.3] (a second piece, kubb or king, that far behind
--     the target on the line of the throw: the table adds how often it fell too)
--     [--cluster 5 --layouts 40] (instead of one kubb, a cluster of that many
--     field kubbs as an inkast leaves them, the nearest d away and the rest
--     touching or 0.1 to 0.3 m apart behind and beside it, seeded; 3 x 3 swings
--     across the ON ON box on each: how many kubbs a baton takes)
--     [--sweep] (the plan from 1.6 to 2.2 m: continuity across flight.tune.nearM)
--     [--set flight.nearM=0] (a tune value for a trial; flight.nearM=0 is the
--     engine before the hand at a short throw)
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end
import "core/tw"
import "core/world"
import "core/throwplan"
import "core/autothrow"
import "core/flight"

local world, plan, autothrow, flight = tw.world, tw.plan, tw.autothrow, tw.flight
local fmt = string.format

local level, coarse, cpuN, flick, over, nerves, sweep = "club", false, 0, 1, 0, false, false
local behind, gap = nil, 0.3
local cluster, layouts = nil, 40
local ranges = { 0.2, 0.35, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0, 8.0 }
local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--level" then level = arg[i + 1]; i = i + 1
	elseif a == "--coarse" then coarse = true
	elseif a == "--nerves" then nerves = true
	elseif a == "--sweep" then sweep = true
	elseif a == "--cluster" then cluster = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--layouts" then layouts = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--behind" then behind = arg[i + 1]; i = i + 1
	elseif a == "--gap" then gap = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--flick" then flick = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--over" then over = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--cpu" then cpuN = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--set" then
		local mod, key, v = arg[i + 1]:match("^(%w+)%.([%w_]+)=(.+)$")
		tw[mod].tune[key] = tonumber(v)
		i = i + 1
	elseif a == "--ranges" then
		ranges = {}
		for v in arg[i + 1]:gmatch("[^,]+") do ranges[#ranges + 1] = tonumber(v) end
		i = i + 1
	end
	i = i + 1
end

local PY = 1 -- the stance's y: clear of the pitch's ends
local YAWS = { 0, math.pi / 4 }

-- Throw one launch L from (0, PY) at a kubb (0, PY + d) turned yaw; true if it
-- fell, and (with --behind) whether the piece behind it fell.
local function throwAt(d, yaw, L)
	local pieces = { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } }
	if behind then pieces[2] = { id = "b", kind = behind, x = 0, y = PY + d + gap, yaw = 0 } end
	local w = world.new { surface = "grass", stakes = false, pieces = pieces }
	local h, fwd, _, _, tip = flight.handAt(d)
	world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	local k, b = w.byId.k, w.byId.b
	for _ = 1, 3 * 240 do
		world.step(w)
		if k.toppled and not b then return true, false end
		if world.isAtRest(w) then break end
	end
	return k.toppled or false, b and b.toppled or false
end

local function solveFor(d, lv)
	local kind = d >= 6 and "base" or "field"
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d,
		release = plan.arcFor("baton", d), level = lv or level, aimZ = plan.aimZFor(kind) }, {})
end

local function swingOf(back, stop)
	return { back = back, releaseAngle = stop, flickFrac = flick, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
end

local function pct(n, of) return of > 0 and fmt("%3.0f%%", 100 * n / of) or "  - " end

-- A cluster of n field kubbs whose nearest is (0, PY + d): each new kubb
-- beside a kubb already placed, its centre 0.1 m (touching, as near as two
-- kubbs turned any way can stand) plus 0 to 0.3 m away, never nearer the
-- thrower than d, never within 0.1 m of another. Seeded.
local function clusterAt(d, n, seed)
	local r = plan.rng(seed)
	local ps = { { id = "k1", kind = "kubb", x = 0, y = PY + d, yaw = r.uniform(0, math.pi / 2) } }
	local tries = 0
	while #ps < n and tries < 5000 do
		tries = tries + 1
		local from = ps[1 + math.floor(r.next() * #ps)]
		local gapM = r.next() < 0.3 and 0 or r.uniform(0, 0.3)
		local ang = r.uniform(-math.pi * 0.5, math.pi * 1.5)
		local x, y = from.x + (0.1 + gapM) * math.cos(ang), from.y + (0.1 + gapM) * math.sin(ang)
		local ok = (x * x + (y - PY) ^ 2) >= (d + 0.02) ^ 2
		for _, q in ipairs(ps) do
			if ok and (q.x - x) ^ 2 + (q.y - y) ^ 2 < 0.1 ^ 2 then ok = false end
		end
		if ok then ps[#ps + 1] = { id = "k" .. (#ps + 1), kind = "kubb", x = x, y = y, yaw = r.uniform(0, math.pi / 2) } end
	end
	return ps
end

if cluster then
	print(fmt("cluster of %d field kubbs, %d layouts, 3 x 3 swings across ON ON (%s, flick %.2f): kubbs a baton took", cluster, layouts, level, flick))
	print(" range | mean | none    1    2    3   4+")
	for _, d in ipairs(ranges) do
		local sol = solveFor(d)
		local hist, total, nT = { [0] = 0, 0, 0, 0, 0 }, 0, 0
		local L = {}
		for lay = 1, layouts do
			local ps = clusterAt(d, cluster, 9000 + lay)
			for _, fb in ipairs { 0.15, 0.5, 0.85 } do
				for _, fs in ipairs { 0.15, 0.5, 0.85 } do
					local back = sol.powerLo + fb * (sol.powerHi - sol.powerLo)
					local stop = sol.releaseLo + fs * (sol.releaseHi - sol.releaseLo)
					plan.launch(sol, swingOf(back, stop), { level = level }, L)
					local w = world.new { surface = "grass", stakes = false, pieces = ps }
					local h, fwd, _, _, tip = flight.handAt(d)
					world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
					world.run(w, 4)
					local k = #world.result(w).toppled
					hist[k >= 4 and 4 or k] = hist[k >= 4 and 4 or k] + 1
					total, nT = total + k, nT + 1
				end
			end
		end
		print(fmt(" %5.2f | %4.2f | %s %s %s %s %s", d, total / nT, pct(hist[0], nT), pct(hist[1], nT),
			pct(hist[2], nT), pct(hist[3], nT), pct(hist[4], nT)))
	end
	return
end

if sweep then
	print("the plan across nearM (field arc, " .. level .. "):")
	print("    d  | speed  loft | hand z  ahead  tip | aim z | power target")
	for d10 = 2, 30 do
		local d = d10 / 10
		if d >= 1.6 and d <= 2.2 + 1e-9 or d10 <= 10 and d10 % 2 == 0 then
			local sol = solveFor(d)
			print(fmt("  %4.2f | %5.2f %5.1f | %5.3f %6.3f %4.2f | %5.3f | %5.1f..%-5.1f",
				d, sol.speed, sol.loft, sol.handZ, sol.handFwd, sol.handTip or 0, sol.aimZ, sol.powerLo, sol.powerHi))
		end
	end
	return
end

print(fmt("level %s; flick %.2f; %s; box %s; kubb square | turned 45 degrees", level, flick,
	nerves and "nerves on" or "no nerves", over ~= 0 and fmt("%+g power band(s)", over) or "the gauge's ON ON"))
print(" range | clean speed loft  hand z/ahead | power target  | ON ON sq  45 | area sq   45")
for _, d in ipairs(ranges) do
	local sol = solveFor(d)
	local bStep, sStep = coarse and 2 or 1, coarse and 6 or 3
	local shift = over * 2 * sol.level.powerHalf
	local b0, b1 = math.max(31, math.floor(sol.back - 40)), math.ceil(sol.back + 40 + shift)
	local box, boxN, area, also = { 0, 0 }, 0, { 0, 0 }, { 0, 0 }
	local L = {}
	for back = b0, b1, bStep do
		for stop = 0, 180, sStep do
			local sw = swingOf(back, stop)
			local o = { level = level }
			if nerves then o.nerves = plan.rng(back * 1000 + stop + 7) end
			plan.launch(sol, sw, o, L)
			local inBox = back >= sol.powerLo + shift and back <= sol.powerHi + shift
				and stop >= sol.releaseLo and stop <= sol.releaseHi
			if inBox then boxN = boxN + 1 end
			for y = 1, 2 do
				if inBox or not coarse then
					local fell, other = throwAt(d, YAWS[y], L)
					if fell then
						area[y] = area[y] + bStep * sStep
						if inBox then box[y] = box[y] + 1 end
					end
					if other and inBox then also[y] = also[y] + 1 end
				end
			end
		end
	end
	print(fmt(" %5.2f | %5.2f m/s %4.1f  %5.3f/%5.3f | %5.1f..%-5.1f | %s %s | %6.0f %6.0f",
		d, sol.speed, sol.loft, sol.handZ, sol.handFwd, sol.powerLo, sol.powerHi,
		pct(box[1], boxN), pct(box[2], boxN), area[1], area[2])
		.. (behind and fmt(" | %s behind fell %s %s", behind, pct(also[1], boxN), pct(also[2], boxN)) or ""))
end

-- The computer at each range: its own swing, mistakes and nerves (autothrow),
-- stood d short of the kubb whatever its minRange says.
if cpuN > 0 then
	print(fmt("the computer (%s), %d throws a range:", level, cpuN))
	local lv = autothrow.cpuLevel(level)
	for _, d in ipairs(ranges) do
		local sol = solveFor(d, lv)
		local scale = autothrow.tune.swingScale[level] or 1
		local r = autothrow.rng(11)
		local n = 0
		for t = 1, cpuN do
			local sw = autothrow.swing(sol, r, scale, {})
			local L = plan.launch(sol, sw, { level = lv, nerves = r }, {})
			if L.legal and throwAt(d, YAWS[t % 2 + 1], L) then n = n + 1 end
		end
		print(fmt(" %5.2f m: %s toppled", d, pct(n, cpuN)))
	end
end
