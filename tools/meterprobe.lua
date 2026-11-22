-- The person's meter, measured (0.13; docs/notes/throw.md "The person's meter"). Every
-- person throws on one meter (plan.meters, plan.meterLevel), whatever level the computer
-- plays at, so the bars carry the difficulty by distance. For a lone standing kubb d
-- metres from the stance (grass, no stakes, turned 0 to 90 degrees, seeded), planned and
-- launched as the session plans a person's throw (plan.solve with q.meter, plan.launch
-- with the nerves; the field arc and aim height under 6 m, the base kubb's from 6 m):
--   perfect   a perfect swing (back and stop dead on the plan, full flick, no shake):
--             the share that touched and that fell, and that came back PULLED
--   honest    swings drawn evenly across the inside of both bars, a full flick and a
--             shake even in 0..steadyBelow: the share that fell and that came back
--             PULLED; then a dead-centre swing with the same shakes
--   hand      the Gym's fitted human thrower (tools/gym/human-model.json, the --hand
--             part, club by default), its misses about the target centre scaled x2 (a
--             newcomer), x1 (the recorded people) and x0.5 (a master; human.scale): the
--             share that fell, and in brackets the share inside both bars and steady,
--             beside the reference row each should land on (TARGETS)
--   drill     a drilled kubb (the inkast) onto a spot in the far half's corner, one tap
--             of spin, into an empty half: the recorded hand (the --hand drill part)
--             on the person's meter, steady swings drawn evenly inside both bars and a
--             dead-centre steady swing on it, and the computer
--             at club and pro (autothrow's swing at its level, as it drills): the
--             median rest distance from the spot (cm), the share within 0.3 m, the
--             share that landed dead (world.tune deadLanding), and the mean scatter
-- A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/meterprobe.lua [--n 400] [--ranges 4,6,8]
--     [--parts perfect,honest,hand,drill] [--hand club] [--seed 1]
--     [--set plan.meters.standard.powerHalf8=4] (one tune a --set)
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
import "core/drill"

local world, plan, autothrow, flight, drill = tw.world, tw.plan, tw.autothrow, tw.flight, tw.drill
local fmt, sqrt, abs, min, max = string.format, math.sqrt, math.abs, math.min, math.max
local human = dofile(sourceDir .. "/tools/gym/human.lua")
local model = human.load(sourceDir .. "/tools/gym/human-model.json")

local n, seed, hand = 400, 1, "club"
local ranges = { 4, 6, 8 }
local parts = { perfect = true, honest = true, hand = true, drill = true }
local function list(s, num)
	local out = {}
	for v in s:gmatch("[^,]+") do out[#out + 1] = num and tonumber(v) or v end
	return out
end
local i = 1
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--n" then n = tonumber(v); i = i + 1
	elseif a == "--seed" then seed = tonumber(v); i = i + 1
	elseif a == "--ranges" then ranges = list(v, true); i = i + 1
	elseif a == "--hand" then hand = v; i = i + 1
	elseif a == "--parts" then
		parts = {}
		for _, p in ipairs(list(v)) do parts[p] = true end
		i = i + 1
	elseif a == "--set" then
		local path, val = v:match("^([^=]+)=(.+)$")
		assert(path, "--set path=value")
		local t, keys = tw, list(path:gsub("%.", ","))
		for k = 1, #keys - 1 do t = assert(t[keys[k]], "no " .. path) end
		assert(type(t[keys[#keys]]) == "number", path .. " is not a number")
		t[keys[#keys]] = tonumber(val)
		i = i + 1
	else error("unknown option " .. a) end
	i = i + 1
end

local PY = 1
local METER = plan.meter()
local STEADY = plan.tune.steadyBelow

local function throwAt(d, yaw, L)
	local w = world.new { surface = "grass", stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0, y = PY + d, yaw = yaw } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	world.launchBaton(w, 0, PY, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton", h, fwd, tip)
	local k = w.byId.k
	local touched = false
	for _ = 1, 8 * 240 do
		world.step(w)
		if k.touchT then touched = true end
		if world.isAtRest(w) then break end
	end
	return touched, k.toppled
end

local function solveAt(d)
	return plan.solve({ projectile = "baton", px = 0, py = PY, tx = 0, ty = PY + d,
		release = plan.arcFor("baton", d), meter = METER, aimZ = plan.aimZFor(d >= 6 and "base" or "field") }, {})
end

local function pct(a, b) return b > 0 and 100 * a / b or 0 end

print(fmt("meterprobe: the person's meter, %d throws a cell, seed %d", n, seed))
print("bars by range (half widths, degrees): power / release, and the release's pull past its bar (deg/deg)")
for _, d in ipairs(ranges) do
	local sol = solveAt(d)
	print(fmt("  %4.1f m  %5.1f / %5.1f  %.3f   (power target %.1f..%.1f, release %.1f..%.1f)", d,
		sol.level.powerHalf, sol.level.releaseHalf, sol.level.pullPerDeg or 0, sol.powerLo, sol.powerHi,
		sol.releaseLo, sol.releaseHi))
end

if parts.perfect then
	print("\nperfect swing")
	print("  range | touched | fell | pulled")
	for _, d in ipairs(ranges) do
		local sol = solveAt(d)
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, smoothness = 1, shake = 0, pull = 1, how = "stopped" }
		local r, yr = plan.rng(seed * 1000 + d * 17), plan.rng(seed * 77 + d)
		local T, F, P = 0, 0, 0
		for _ = 1, n do
			local L = plan.launch(sol, sw, { nerves = r }, {})
			local t, f = throwAt(d, yr.next() * math.pi / 2, L)
			if t then T = T + 1 end
			if f then F = F + 1 end
			if L.sideV ~= 0 then P = P + 1 end
		end
		print(fmt("  %3.0f m |  %3.0f%%   | %3.0f%% | %3.0f%%", d, pct(T, n), pct(F, n), pct(P, n)))
	end
end

if parts.honest then
	print("\nhonest bars: inside both bars, steady (shake 0..steadyBelow), full flick")
	print("  range | in the bars: fell | pulled | dead centre: fell | pulled")
	for _, d in ipairs(ranges) do
		local sol = solveAt(d)
		local lv = sol.level
		local r, nr, yr = plan.rng(seed * 500 + d * 13), plan.rng(seed * 900 + d * 7), plan.rng(seed * 77 + d)
		local F, P, C, CP = 0, 0, 0, 0
		for _ = 1, n do
			local shake = r.next() * STEADY * 0.999
			local sw = { back = sol.back + (2 * r.next() - 1) * lv.powerHalf * 0.999,
				releaseAngle = sol.release + (2 * r.next() - 1) * lv.releaseHalf * 0.999,
				flickFrac = 1, shake = shake, smoothness = 1 - shake, pull = r.next() < 0.5 and -1 or 1, how = "stopped" }
			local yaw = yr.next() * math.pi / 2
			local L = plan.launch(sol, sw, { nerves = nr }, {})
			assert(L.powerV == 0 and L.releaseV == 0 and L.steady)
			local _, f = throwAt(d, yaw, L)
			if f then F = F + 1 end
			if L.sideV ~= 0 then P = P + 1 end
			sw.back, sw.releaseAngle = sol.back, sol.release
			L = plan.launch(sol, sw, { nerves = nr }, {})
			_, f = throwAt(d, yaw, L)
			if f then C = C + 1 end
			if L.sideV ~= 0 then CP = CP + 1 end
		end
		print(fmt("  %3.0f m |        %3.0f%%      |  %3.0f%%  |        %3.0f%%        |  %3.0f%%", d,
			pct(F, n), pct(P, n), pct(C, n), pct(CP, n)))
	end
end

local scaled = function(sw, sol, k) return human.scale(sw, sol, k) end

-- What each hand should fell at 4 / 6 / 8 m: the reference's rows (docs/reference
-- PLAY.md, play-levels.json g.baseLine and g.fieldMiss), a newcomer on beginner's, the
-- recorded people on club's, a master on pro's; the recorded hand within about 4 points,
-- the other two as guides (docs/notes/throw.md "The person's meter").
local TARGETS = { [2] = { 45, 22, 10 }, [1] = { 72, 48, 27 }, [0.5] = { 88, 70, 45 } }

if parts.hand then
	local p = human.part(model, hand, "baton")
	print(fmt("\nthe recorded hand (%s baton part): fell (in both bars and steady)", hand))
	local head = "  hand        |"
	for _, d in ipairs(ranges) do head = head .. fmt("    %2.0f m    |", d) end
	print(head)
	for _, hk in ipairs { { "newcomer x2", 2 }, { "recorded x1", 1 }, { "master x0.5", 0.5 } } do
		local line = fmt("  %-11s |", hk[1])
		for _, d in ipairs(ranges) do
			local sol = solveAt(d)
			local r, nr, yr = plan.rng(seed * 500 + d * 13), plan.rng(seed * 900 + d * 7), plan.rng(seed * 77 + d)
			local F, I = 0, 0
			for _ = 1, n do
				local sw = scaled(human.swing(sol, p, r, {}), sol, hk[2])
				local L = plan.launch(sol, sw, { nerves = nr }, {})
				if L.powerV == 0 and L.releaseV == 0 and L.steady then I = I + 1 end
				local yaw = yr.next() * math.pi / 2
				if L.legal then
					local _, f = throwAt(d, yaw, L)
					if f then F = F + 1 end
				end
			end
			line = line .. fmt(" %3.0f%% (%2.0f) |", pct(F, n), pct(I, n))
		end
		local tg = TARGETS[hk[2]]
		if tg then line = line .. fmt("  target at 4 / 6 / 8 m: %d / %d / %d", tg[1], tg[2], tg[3]) end
		print(line)
	end
end

if parts.drill then
	-- the spot: the basket's corner (autothrow.tune.basketX, basketY from the baseline)
	local at = autothrow.tune
	local mx, my = at.basketX, at.basketY
	local taps = 1
	local function drillThrow(L, sol, ws)
		local w = world.new { surface = "grass", groundSeed = ws }
		local b = world.launchDrill(w, "d", sol.px, 0, L.swivel, L.loft, L.speed, L.noseDown, L.rollLand,
			L.spin, L.wobble, L.scatter)
		local dead = false
		for _ = 1, 10 * 240 do
			world.step(w)
			if b.deadAt then dead = true end
			if world.isAtRest(w) then break end
		end
		return sqrt((b.x - mx) ^ 2 + (b.y - my) ^ 2), dead
	end
	local function row(name, make)
		local ds, near, dead, sc = {}, 0, 0, 0
		local r, nr = plan.rng(seed * 4100 + 3), plan.rng(seed * 5200 + 9)
		for j = 1, n do
			local L, sol = make(r, nr)
			local dist, dd = drillThrow(L, sol, seed * 100000 + j)
			ds[#ds + 1] = dist
			if dist <= 0.3 then near = near + 1 end
			if dd then dead = dead + 1 end
			sc = sc + (L.scatter or 1)
		end
		table.sort(ds)
		print(fmt("  %-26s | %5.0f cm | %4.0f%%  | %4.0f%% | %.2f", name, 100 * ds[1 + #ds // 2],
			pct(near, n), pct(dead, n), sc / n))
	end
	local function personSol()
		local st = plan.stance(mx, my, 0, 0, at.halfWidth, {})
		return plan.solve({ projectile = "kubb", px = st.x, py = 0, tx = mx, ty = my, release = plan.arcFor("drill"),
			meter = METER, surface = "grass", spin = taps }, {})
	end
	local p = human.part(model, hand, "drill")
	print(fmt("\na drilled kubb onto the basket's spot (%.2f, %.2f m), one tap of spin", mx, my))
	print("  thrower                    | median   | <0.3 m | dead  | scatter")
	row(fmt("person, recorded (%s)", hand), function(r, nr)
		local sol = personSol()
		local sw = human.swing(sol, p, r, {})
		return plan.launch(sol, sw, { projectile = "kubb", tilt = 0, spin = taps, nerves = nr }, {}), sol
	end)
	row("person, in the bars steady", function(r, nr)
		local sol = personSol()
		local lv = sol.level
		local shake = r.next() * STEADY * 0.999
		local sw = { back = sol.back + (2 * r.next() - 1) * lv.powerHalf * 0.999,
			releaseAngle = sol.release + (2 * r.next() - 1) * lv.releaseHalf * 0.999, flickFrac = 1,
			shake = shake, smoothness = 1 - shake, pull = r.next() < 0.5 and -1 or 1, how = "stopped" }
		return plan.launch(sol, sw, { projectile = "kubb", tilt = 0, spin = taps, nerves = nr }, {}), sol
	end)
	row("person, dead centre steady", function(r, nr)
		local sol = personSol()
		local shake = r.next() * STEADY * 0.999
		local sw = { back = sol.back, releaseAngle = sol.release, flickFrac = 1, shake = shake,
			smoothness = 1 - shake, pull = 1, how = "stopped" }
		return plan.launch(sol, sw, { projectile = "kubb", tilt = 0, spin = taps, nerves = nr }, {}), sol
	end)
	for _, lname in ipairs { "club", "pro" } do
		row("computer " .. lname, function(r, nr)
			local lv = autothrow.cpuLevel(lname)
			local st = plan.stance(mx, my, 0, 0, at.halfWidth, {})
			local sol = plan.solve({ projectile = "kubb", px = st.x, py = 0, tx = mx, ty = my,
				release = plan.arcFor("drill"), level = lv, surface = "grass", spin = taps }, {})
			local sw = autothrow.swing(sol, r, at.inkast[lname].hand, {})
			return plan.launch(sol, sw, { projectile = "kubb", tilt = 0, spin = taps, level = lv, nerves = nr }, {}), sol
		end)
	end
end
