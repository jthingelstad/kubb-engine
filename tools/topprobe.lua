-- Where a baton first meets a standing kubb, and what follows (a play-test
-- match, 2026-11-20: "Batons bounce off the top of kubbs way too much"; of
-- its 41 first contacts with standing pieces 29 were on the top). For a lone
-- standing kubb d metres from the stance (grass, no stakes, turned 0 to 90
-- degrees, seeded), n throws at each range and level as the computer makes
-- them (autothrow.swing and plan.launch with the level's nerves, stood d
-- short of the kubb whatever autothrow.tune.minRange says, from the hand
-- flight.handAt gives; the field arc under 6 m, the base arc from 6 m):
--   hit        the share of throws that touched the kubb
--   top/side   where the first touch was on the kubb: its top (the top face
--              or the top 1 cm of a side, the edge) or lower
--   skip       the share of touches that came after the baton met the ground
--   fell       the share of touches that toppled it; then of the top
--              touches alone
--   stood: kept  after a top touch that left the kubb standing, the
--              baton's speed 0.05 s later over its speed at the touch (mean)
--   rose       of top touches, the share where the baton's centre
--              rose 5 cm or more above its height at the touch, and the mean
--              of those rises (cm)
-- A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/topprobe.lua [--n 200] [--ranges 1,2,3,4,5,6,7,8]
--     [--levels clean,pro,club,beginner] [--seed 11]
--     [--set plan.aimHeightShare=0.5] [--set world.pairE=0.35] (one tune a --set)
--     [--surface grass|sand|snow|grid]
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
import "core/collide"

local world, plan, autothrow, flight = tw.world, tw.plan, tw.autothrow, tw.flight
local fmt, sqrt, abs = string.format, math.sqrt, math.abs

local n, seed = 200, 11
local SURFACE = "grass"
local ranges = { 1, 2, 3, 4, 5, 6, 7, 8 }
local levels = { "clean", "pro", "club", "beginner" }
local i = 1
local function list(s, num)
	local out = {}
	for v in s:gmatch("[^,]+") do out[#out + 1] = num and tonumber(v) or v end
	return out
end
while i <= #arg do
	local a = arg[i]
	if a == "--n" then n = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--seed" then seed = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--ranges" then ranges = list(arg[i + 1], true); i = i + 1
	elseif a == "--levels" then levels = list(arg[i + 1]); i = i + 1
	elseif a == "--surface" then SURFACE = arg[i + 1]; i = i + 1
	elseif a == "--set" then
		local mod, key, v = arg[i + 1]:match("^(%w+)%.([%w_]+)=(.+)$")
		local t = mod == "world" and world.tune or tw[mod].tune
		assert(t[key] ~= nil, "no " .. mod .. ".tune." .. key)
		t[key] = tonumber(v)
		i = i + 1
	else error("unknown argument " .. a) end
	i = i + 1
end

local PY = 1

local function speed(b) return sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz) end

-- One throw: what its first touch of the kubb was, and what followed.
local function throwAt(d, yaw, L)
	local w = world.new { surface = SURFACE, stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	local b = world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	local k = w.byId.k
	local o = {}
	local v0, z0, hitStep, maxZ
	for step = 1, 4 * 240 do
		local v = speed(b)
		world.step(w)
		if not hitStep and k.touchT then
			hitStep, v0, z0, maxZ = step, v, b.z, b.z
			local fh = w.firstHit
			o.skip = w.firstContact ~= fh
			-- the touch in the kubb's frame (it was standing until this step)
			local dx, dy, dz = fh.x - k.x, fh.y - k.y, fh.z - k.z
			local lx = k.r11 * dx + k.r21 * dy + k.r31 * dz
			local ly = k.r12 * dx + k.r22 * dy + k.r32 * dz
			local lz = k.r13 * dx + k.r23 * dy + k.r33 * dz
			-- (the point lies between the two surfaces, up to a baton's radius
			-- above the kubb's top face: on its top face and its top edge alike)
			o.where = lz > k.hz - 0.01 and "top" or "side"
		end
		if hitStep then
			if b.z > maxZ then maxZ = b.z end
			if step == hitStep + 12 then o.kept = speed(b) / v0 end
			if step >= hitStep + 120 then break end
		end
		if world.isAtRest(w) then break end
	end
	for _ = 1, 3 * 240 do
		if world.isAtRest(w) then break end
		world.step(w)
	end
	if not hitStep then return nil end
	o.fell = k.toppled
	o.rise = maxZ - z0
	return o
end

local function solveFor(d, lv)
	local kind = d >= 6 and "base" or "field"
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d,
		release = plan.arcFor("baton", d), level = lv, aimZ = plan.aimZFor(kind) }, {})
end

local function pct(a, b) return b > 0 and fmt("%3.0f%%", 100 * a / b) or "  - " end

print(fmt("topprobe: a lone standing kubb, %d throws a cell (%s); aimHeightShare %.2f, baton on a piece: friction %.2f, bounce %.2f",
	n, SURFACE, plan.tune.aimHeightShare, world.tune.batonMu or world.tune.pairMu, world.tune.batonE or world.tune.pairE))
print(" level     range |  hit | top side | skip | fell | top fell | stood: kept | rose 5cm+ (mean)")
local tot = {}
for _, lname in ipairs(levels) do
	local T = { hit = 0, n = 0, top = 0, side = 0, skip = 0, fell = 0, teFell = 0, kept = 0, keptN = 0,
		rose = 0, riseSum = 0 }
	for _, d in ipairs(ranges) do
		local clean = lname == "clean"
		local lv = autothrow.cpuLevel(clean and "pro" or lname)
		local sol = solveFor(d, lv)
		local scale = clean and 0 or (autothrow.tune.swingScale[lname] or 1)
		local r = autothrow.rng(seed + math.floor(d * 100))
		local yr = plan.rng(seed * 7 + math.floor(d * 100))
		local C = { hit = 0, top = 0, side = 0, skip = 0, fell = 0, teFell = 0, kept = 0, keptN = 0,
			rose = 0, riseSum = 0 }
		local nn = clean and math.max(1, math.floor(n / 10)) or n
		for _ = 1, nn do
			local sw = autothrow.swing(sol, r, scale, {})
			local L = plan.launch(sol, sw, { level = lv, nerves = (not clean) and r or nil }, {})
			local yaw = yr.next() * math.pi / 2
			local o = L.legal and throwAt(d, yaw, L)
			if o then
				C.hit = C.hit + 1
				C[o.where] = C[o.where] + 1
				if o.skip then C.skip = C.skip + 1 end
				if o.fell then C.fell = C.fell + 1 end
				if o.where ~= "side" then
					if o.fell then C.teFell = C.teFell + 1
					elseif o.kept then C.kept, C.keptN = C.kept + o.kept, C.keptN + 1 end
					if o.rise >= 0.05 then C.rose, C.riseSum = C.rose + 1, C.riseSum + o.rise end
				end
			end
		end
		local te = C.top
		print(fmt(" %-8s %4.1f m | %s | %s %s | %s | %s | %s | %s | %s (%2.0f)",
			lname, d, pct(C.hit, nn), pct(C.top, C.hit), pct(C.side, C.hit),
			pct(C.skip, C.hit), pct(C.fell, C.hit), pct(C.teFell, te),
			C.keptN > 0 and fmt("%4.0f%% of %3d", 100 * C.kept / C.keptN, C.keptN) or "     -     ",
			pct(C.rose, te), C.rose > 0 and 100 * C.riseSum / C.rose or 0))
		T.n = T.n + nn
		for key, v in pairs(C) do T[key] = T[key] + v end
	end
	local te = T.top
	print(fmt(" %-8s  all  | %s | %s %s | %s | %s | %s | %s | %s (%2.0f)",
		lname, pct(T.hit, T.n), pct(T.top, T.hit), pct(T.side, T.hit),
		pct(T.skip, T.hit), pct(T.fell, T.hit), pct(T.teFell, te),
		T.keptN > 0 and fmt("%4.0f%% of %3d", 100 * T.kept / T.keptN, T.keptN) or "     -     ",
		pct(T.rose, te), T.rose > 0 and 100 * T.riseSum / T.rose or 0))
	tot[lname] = T
end
