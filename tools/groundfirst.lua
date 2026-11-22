-- How a baton meets a lone standing kubb: on the fly or off the ground first (0.18; the
-- owner, 2026-11-22: "Batons are thrown hard enough that kubbs aren't just tapped they are
-- banged into"). A lone kubb d metres from the stance, turned 0 to 90 degrees, planned and
-- launched as the session plans a person's throw (plan.solve on the person's meter at the
-- default arc, the field arc under 6 m and the base kubb's from 6 m), for a perfect swing
-- and for the Gym's recorded hand (fit 2, tools/gym/human-model.json, its misses x1),
-- thrown --n times a range. Per range: the share that touched the kubb, and of those the
-- share that met the ground first; the baton's speed at the first touch of the kubb (on
-- the fly and after the ground); how high on the kubb it met it; and the share that fell.
-- A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/groundfirst.lua [--n 300] [--ranges 4,6,8] [--surface grass]
--     [--set world.tune.x=v] [--model tools/gym/human-model.json]
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
local world, plan, flight = tw.world, tw.plan, tw.flight
local fmt, sqrt = string.format, math.sqrt
local human = dofile(sourceDir .. "/tools/gym/human.lua")

local n, ranges, SURFACE, modelPath = 300, { 4, 6, 8 }, "grass", sourceDir .. "/tools/gym/human-model.json"
local i = 1
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--n" then n = tonumber(v)
	elseif a == "--ranges" then ranges = {}; for x in v:gmatch("[^,]+") do ranges[#ranges + 1] = tonumber(x) end
	elseif a == "--surface" then SURFACE = v
	elseif a == "--model" then modelPath = v
	elseif a == "--set" then
		local p, val = v:match("^([%w_%.]+)=(.+)$")
		local t, keys = tw, {}
		for k in p:gmatch("[^%.]+") do keys[#keys + 1] = k end
		for k = 1, #keys - 1 do t = t[keys[k]] end
		t[keys[#keys]] = tonumber(val)
	else error("unknown option " .. a) end
	i = i + 2
end
local model = human.load(modelPath)
local part = human.part(model, "club", "baton")
local PY = 1

local function throwAt(d, yaw, L, seed)
	local w = world.new { surface = SURFACE, stakes = false, groundSeed = seed,
		pieces = { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	local b = world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	local k = w.byId.k
	local ground, at, hz = false, nil, nil
	local pre = 0
	w.onContact = function(_, a, other)
		if at then return end
		if a == b and not other then ground = true end
		if (a == b and other == k) or (a == k and other == b) then at = pre end
	end
	for _ = 1, 8 * 240 do
		local was = at
		-- (the speed the step began with: onContact comes after the step's impulses)
		pre = sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
		world.step(w)
		if at and not was then hz = b.z - b.hl * (b.r33 < 0 and -b.r33 or b.r33) - b.r end
		if world.isAtRest(w) then break end
	end
	return at ~= nil, ground, at, hz, k.toppled
end

local function solveAt(d)
	local kind = d >= 6 and "base" or "field"
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d,
		release = plan.arcFor("baton", d), meter = plan.meter(), aimZ = plan.aimZFor(kind) }, {})
end

local PERFECT = { back = 0, releaseAngle = 0, flickFrac = 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
print(fmt("groundfirst: a lone kubb, %d throws a range, %s; the person's meter at the default arc", n, SURFACE))
print("  thrower     range | touched | of those: ground first | speed at the kubb, on the fly / after the ground | lowest point at the touch | fell")
for _, who in ipairs { "perfect", "hand" } do
	for _, d in ipairs(ranges) do
		local sol = solveAt(d)
		local r, nr, yr = plan.rng(500 + d * 13), plan.rng(900 + d * 7), plan.rng(77 + d)
		local touched, ground, fell = 0, 0, 0
		local vf, nf, vg, ng, zs = 0, 0, 0, 0, 0
		for k = 1, n do
			local sw
			if who == "perfect" then
				PERFECT.back, PERFECT.releaseAngle = sol.back, sol.release
				sw = PERFECT
			else
				sw = human.swing(sol, part, r, {})
			end
			local L = plan.launch(sol, sw, { nerves = who == "hand" and nr or nil }, {})
			local t, g, v, hz, top = throwAt(d, yr.next() * 90, L, k)
			if top then fell = fell + 1 end
			if t then
				touched = touched + 1
				zs = zs + hz
				if g then ground = ground + 1; vg = vg + v; ng = ng + 1 else vf = vf + v; nf = nf + 1 end
			end
		end
		print(fmt("  %-8s %5.1f m | %5.0f%% | %20.0f%% | %8.2f / %.2f m/s %16s | %5.1f cm %13s | %3.0f%%", who, d,
			100 * touched / n, touched > 0 and 100 * ground / touched or 0, nf > 0 and vf / nf or 0, ng > 0 and vg / ng or 0, "",
			touched > 0 and 100 * zs / touched or 0, "", 100 * fell / n))
	end
end
