-- The seat (world.tune.seatOn, 2026-11-22; the owner: kubbs stand too firmly): what a
-- standing kubb's lean in its seat does to the blow that tips it. A lone kubb set down at
-- --n places (each its own seeded lean, up to the surface's `seat`), struck level in +y at
-- height h with an impulse J as tools/mjref's tip cases are (a velocity and a spin at its
-- centre); per place the smallest J that topples it, by bisection. Prints, per surface
-- and height, the threshold plumb (seatOn 0) and its spread over the places with the
-- seat on (min, quartiles, max), and the share of places tipped by the plumb threshold's
-- 0.9 and 0.95. A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/seatprobe.lua [--n 200] [--surfaces grass,sand,snow] [--heights 0.04,0.1,0.14]
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
local world, body = tw.world, tw.body
local fmt = string.format

local n, surfaces, heights = 200, { "grass", "sand", "snow" }, { 0.04, 0.10, 0.14 }
local i = 1
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--n" then n = tonumber(v)
	elseif a == "--surfaces" then surfaces = {}; for x in v:gmatch("[^,]+") do surfaces[#surfaces + 1] = x end
	elseif a == "--heights" then heights = {}; for x in v:gmatch("[^,]+") do heights[#heights + 1] = tonumber(x) end
	else error("unknown option " .. a) end
	i = i + 2
end

local kk = body.kinds.kubb
local Ix = body.inertia(kk)

local function falls(surf, x, y, h, J)
	local w = world.new { surface = surf, stakes = false, groundSeed = 1, texture = false,
		pieces = { { id = "k", kind = "kubb", x = x, y = y } } }
	local b = w.byId.k
	local rz = h - b.z
	body.setVelocity(b, 0, J / kk.mass, 0, -rz * J / Ix, 0, 0)
	world.wake(b)
	for _ = 1, 3 * 240 do
		world.step(w)
		if b.toppled or not b.awake then break end
	end
	return b.toppled
end

local function threshold(surf, x, y, h)
	local lo, hi = 0.02, 2
	for _ = 1, 14 do
		local mid = (lo + hi) / 2
		if falls(surf, x, y, h, mid) then hi = mid else lo = mid end
	end
	return (lo + hi) / 2
end

print(fmt("seatprobe: a lone kubb at %d places, struck level, the smallest J (N s) that tips it (flat ground)", n))
print("  surface  seat  height | plumb | with the seat: min   q1    median  q3    max  | tipped by 0.95 / 0.9 of plumb")
for _, surf in ipairs(surfaces) do
	for _, h in ipairs(heights) do
		world.tune.seatOn = 0
		local plumb = threshold(surf, 0, 4, h)
		world.tune.seatOn = 1
		local t, c95, c90 = {}, 0, 0
		for k = 1, n do
			local x, y = -2 + 4 * ((k * 0.618034) % 1), 1 + 6 * ((k * 0.414214) % 1)
			local j = threshold(surf, x, y, h)
			t[#t + 1] = j
			if j <= 0.95 * plumb then c95 = c95 + 1 end
			if j <= 0.9 * plumb then c90 = c90 + 1 end
		end
		world.tune.seatOn = 0
		table.sort(t)
		local function q(p) return t[math.max(1, math.min(#t, math.floor(p * (#t - 1) + 1.5)))] end
		print(fmt("  %-7s %4.1f  %5.2f m | %.3f | %13.3f %.3f %.3f %.3f %.3f | %3.0f%% / %.0f%%", surf,
			world.surfaces[surf].seat, h, plumb, t[1], q(0.25), q(0.5), q(0.75), t[#t], 100 * c95 / n, 100 * c90 / n))
	end
end
