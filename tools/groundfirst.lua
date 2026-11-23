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
--     [--set world.tune.x=v] [--model tools/gym/human-model.json] [--flat]
--
-- Per range it also gives the share felled by a touch on the fly and by one after the
-- ground, and, for the hand's ground-first touches, the energy account of the ground
-- (the baton's translational and rotational energy, joules, and its speed): at the start
-- of the step it first meets the ground, at the first step it is off the ground again
-- (its first bounce), 0.1 s after it met it, and at the touch of the kubb. --cases FILE writes
-- those landings (the baton alone, at the start of that step) as tools/mjref cases. --set surface.grass.mu=0.3 and the
-- like change the surface; --flat takes its texture away (no bumps, drag or grip).
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

local FLAT, CASES = false, nil
local caseList = {}
local n, ranges, SURFACE, modelPath = 300, { 4, 6, 8 }, "grass", sourceDir .. "/tools/gym/human-model.json"
local i = 1
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--n" then n = tonumber(v)
	elseif a == "--ranges" then ranges = {}; for x in v:gmatch("[^,]+") do ranges[#ranges + 1] = tonumber(x) end
	elseif a == "--surface" then SURFACE = v
	elseif a == "--model" then modelPath = v
	elseif a == "--flat" then FLAT = true; i = i - 1
	elseif a == "--cases" then CASES = v
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

-- the baton's energies: translational, rotational (body frame), joules
local function energies(b)
	local vx, vy, vz, wx, wy, wz = b.vx, b.vy, b.vz, b.wx, b.wy, b.wz
	local bx = b.r11 * wx + b.r21 * wy + b.r31 * wz
	local by = b.r12 * wx + b.r22 * wy + b.r32 * wz
	local bz = b.r13 * wx + b.r23 * wy + b.r33 * wz
	local rot = 0.5 * (bx * bx / b.iIx + by * by / b.iIy + bz * bz / b.iIz)
	return 0.5 * b.m * (vx * vx + vy * vy + vz * vz), rot, sqrt(vx * vx + vy * vy + vz * vz)
end

local function throwAt(d, yaw, L, seed, alone)
	local w = world.new { surface = SURFACE, stakes = false, groundSeed = seed, texture = (not FLAT) and nil,
		pieces = alone and {} or { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	local b = world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	local k = w.byId.k or false
	local ground, at, hz = false, nil, nil
	local pre = 0
	local gnow = false
	local E = {}   -- E.g0, E.g1, E.k: { trans, rot, speed } at the ground, its first bounce, the kubb
	w.onContact = function(_, a, other)
		-- (gnow is this step's ground contact, kept up after the kubb is touched; `ground`,
		-- the ground-first verdict, and `at` are settled by the first touch of the kubb)
		if a == b and not other then
			gnow = true
			if not at then ground = true end
		end
		if not at and ((a == b and other == k) or (a == k and other == b)) then at = pre end
	end
	for _ = 1, 8 * 240 do
		local was = at
		-- (the speed the step began with: onContact comes after the step's impulses)
		pre = sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
		local t0, r0, s0 = energies(b)
		local st = CASES and not E.g0 and { b.x, b.y, b.z, b.qw, b.qx, b.qy, b.qz, b.vx, b.vy, b.vz, b.wx, b.wy, b.wz }
		gnow = false
		world.step(w)
		if gnow and not E.g0 and not at then E.g0 = { t0, r0, s0 }; E.state = st end
		-- off the ground again before the kubb: its first bounce. A baton that reaches the
		-- kubb while still on the ground has none (its account would hold the kubb's blow)
		if E.g0 and not E.g1 and not gnow and not at then E.g1 = { energies(b) } end
		if E.g0 then
			E.steps = (E.steps or 0) + 1
			if E.steps == 24 then E.t10 = { energies(b) } end
		end
		if at and not was then
			hz = b.z - b.hl * (b.r33 < 0 and -b.r33 or b.r33) - b.r
			E.k = { t0, r0, s0 }
		end
		if world.isAtRest(w) then break end
	end
	return at ~= nil, ground, at, hz, (k and k.toppled), E
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
		local fellF, fellG = 0, 0
		local acc = { g0 = { 0, 0, 0 }, g1 = { 0, 0, 0 }, t10 = { 0, 0, 0 }, k = { 0, 0, 0 } }
		local nacc = 0
		local accA, naccA = { g0 = { 0, 0, 0 }, g1 = { 0, 0, 0 }, t10 = { 0, 0, 0 } }, 0
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
			local yaw = yr.next() * 90
			local t, g, v, hz, top, E = throwAt(d, yaw, L, k)
			if t and g and who == "hand" then
				-- the same throw with no kubb: the landing alone, as tools/mjref plays it
				local _, _, _, _, _, A = throwAt(d, yaw, L, k, true)
				if A.g0 and A.g1 and A.t10 then
					naccA = naccA + 1
					for _, key in ipairs { "g0", "g1", "t10" } do
						for j = 1, 3 do accA[key][j] = accA[key][j] + A[key][j] end
					end
				end
			end
			if top then fell = fell + 1 end
			if t then
				touched = touched + 1
				zs = zs + hz
				if g then
					ground = ground + 1; vg = vg + v; ng = ng + 1
					if top then fellG = fellG + 1 end
					if CASES and who == "hand" and E.state then
						local q = E.state
						caseList[#caseList + 1] = { id = fmt("gf-%g-%d", d, k), scen = "groundfirst", group = fmt("%g m", d),
							params = { d = d }, surface = SURFACE, duration = 0.5,
							bodies = { { id = "baton", kind = "baton", pos = { q[1], q[2], q[3] }, quat = { q[4], q[5], q[6], q[7] },
								vel = { q[8], q[9], q[10] }, angvel = { q[11], q[12], q[13] }, projectile = true } } }
					end
					if E.g0 and E.g1 and E.k and E.t10 then
						nacc = nacc + 1
						for _, key in ipairs { "g0", "g1", "t10", "k" } do
							for j = 1, 3 do acc[key][j] = acc[key][j] + E[key][j] end
						end
					end
				else
					vf = vf + v; nf = nf + 1
					if top then fellF = fellF + 1 end
				end
			end
		end
		print(fmt("  %-8s %5.1f m | %5.0f%% | %20.0f%% | %8.2f / %.2f m/s %16s | %5.1f cm %13s | %3.0f%%", who, d,
			100 * touched / n, touched > 0 and 100 * ground / touched or 0, nf > 0 and vf / nf or 0, ng > 0 and vg / ng or 0, "",
			touched > 0 and 100 * zs / touched or 0, "", 100 * fell / n))
		print(fmt("  %18s   felled by a touch: on the fly %.0f%% of %d, after the ground %.0f%% of %d", "",
			nf > 0 and 100 * fellF / nf or 0, nf, ng > 0 and 100 * fellG / ng or 0, ng))
		if nacc > 0 then
			local function row(name, key)
				local a = acc[key]
				print(fmt("  %18s   %-28s trans %.3f J  rot %.3f J  sum %.3f J  speed %.2f m/s", "", name,
					a[1] / nacc, a[2] / nacc, (a[1] + a[2]) / nacc, a[3] / nacc))
			end
			print(fmt("  %18s   the ground's account, %d ground-first touches (means):", "", nacc))
			row("meeting the ground", "g0")
			row("off it again (first bounce)", "g1")
			row("0.1 s after meeting it", "t10")
			row("at the kubb", "k")
		end
		if naccA > 0 then
			print(fmt("  %18s   the same throws with no kubb, %d (means):", "", naccA))
			for _, kv in ipairs { { "meeting the ground", "g0" }, { "off it again (first bounce)", "g1" }, { "0.1 s after meeting it", "t10" } } do
				local a = accA[kv[2]]
				print(fmt("  %18s   %-28s trans %.3f J  rot %.3f J  sum %.3f J  speed %.2f m/s", "", kv[1],
					a[1] / naccA, a[2] / naccA, (a[1] + a[2]) / naccA, a[3] / naccA))
			end
		end
	end
end
if CASES then
	local json = dofile(sourceDir .. "/tools/mjref/json.lua")
	local f = assert(io.open(CASES, "w"))
	f:write(json.encode(caseList))
	f:close()
	print(fmt("  %d ground-first landings written to %s (the baton alone, at the start of the step it meets the ground)", #caseList, CASES))
end
