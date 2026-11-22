-- A baton driven into a tight group of field kubbs (0.16.0: docs/notes/throw.md "The
-- drive"). For each of the two hand-written group positions in
-- tests/fixtures/drive/positions.lua, the launch is swept from a plan (the default
-- arc, as the session plans a person's throw on the standard meter) down through flat
-- to downward lofts (rows "plan (0.15)": the default arc before 0.16, which every
-- target shared; "plan (0.16)": the default from 0.16, the drive close in), each
-- at the speed that puts the baton's centre through the front
-- kubb at mid-height (or at the plan's aim height for the plan rows), from the hand
-- flight.handAt gives for the distance. Every setting is thrown --n times with a seeded
-- jitter of aim, loft, speed, tilt and tumble, in core/world with the stakes and every
-- piece of the position, and counted:
--   kubbs    field kubbs felled per baton
--   2+       the share of batons felling two or more
--   0        the share felling none
--   baton    where the baton came to rest: in the group (within 15 cm of the box
--            round its standing kubbs), past it, wide of it, or short of the front kubb;
--            and its mean rest beyond the group's back kubb (m, along the throw)
-- A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/driveprobe.lua [--n 200] [--seed 1] [--pos group1,group2]
--     [--aim 0.6] [--loftsd 1] [--speedsd 0.03] [--tiltsd 6] [--turnsd 0.06]
--     (the jitter's sds: degrees off the line, degrees of loft, a share of the speed,
--     degrees of tilt and turns over the flight)
--     [--lofts 10,5,0,-5] (the swept launch lofts) [--stand] (also from a standing
--     hand: handHeight at the feet, upright, whatever the distance)
--     [--aimz 0.075] (the height the swept lofts' centre goes through the front kubb:
--     its middle) [--turn 1] (the swept lofts' planned tumble times this: 0 a baton
--     that does not turn end over end) [--plan] (only the plan rows: today's default and the drive's, plan.solve)
--     [--set module.key=value]
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
import "core/flight"
local world, plan, flight, body = tw.world, tw.plan, tw.flight, tw.body
local fmt = string.format
local POS = dofile(sourceDir .. "/tests/fixtures/drive/positions.lua")

local n, seed = 200, 1
local aimSd, loftSd, speedSd, tiltSd, turnSd = 0.6, 1, 0.03, 6, 0.06
local names = { "group1", "group2" }
local lofts = nil
local stand, planOnly = false, false
local aimZ = nil
local turnShare = 1
local i = 1
while i <= #arg do
	local a = arg[i]
	local v = arg[i + 1]
	if a == "--n" then n = tonumber(v); i = i + 1
	elseif a == "--seed" then seed = tonumber(v); i = i + 1
	elseif a == "--aim" then aimSd = tonumber(v); i = i + 1
	elseif a == "--loftsd" then loftSd = tonumber(v); i = i + 1
	elseif a == "--speedsd" then speedSd = tonumber(v); i = i + 1
	elseif a == "--tiltsd" then tiltSd = tonumber(v); i = i + 1
	elseif a == "--turnsd" then turnSd = tonumber(v); i = i + 1
	elseif a == "--stand" then stand = true
	elseif a == "--aimz" then aimZ = tonumber(v); i = i + 1
	elseif a == "--turn" then turnShare = tonumber(v); i = i + 1
	elseif a == "--plan" then planOnly = true
	elseif a == "--pos" then
		names = {}
		for s in v:gmatch("[^,]+") do names[#names + 1] = s end
		i = i + 1
	elseif a == "--lofts" then
		lofts = {}
		for s in v:gmatch("[^,]+") do lofts[#lofts + 1] = tonumber(s) end
		i = i + 1
	elseif a == "--set" then
		local mod, key, val = v:match("^(%w+)%.([%w_]+)=(.+)$")
		assert(tw[mod] and tw[mod].tune and tw[mod].tune[key] ~= nil, "--set: no " .. tostring(v))
		tw[mod].tune[key] = tonumber(val)
		i = i + 1
	else error("unknown argument " .. a) end
	i = i + 1
end

local KUBB_MID = body.kinds.kubb.hz -- a kubb's mid-height

-- The tumble plan.solve gives a clean launch at speed and loft whose flight to the
-- target takes T, d metres away from a hand tipped by tip (rad): the level's half turn
-- in the wrist's range, and under nearM the short throw's arrival turn.
local function tumbleOf(d, speed, loft, T, tip)
	local lv = plan.meterLevel(plan.meter(), d, "baton")
	local r = plan.tumbleFor(speed, loft, T, lv)
	local ft = flight.tune
	if d < ft.nearM and T > 0 then
		local turnDeg, share = flight.nearTurn(d)
		r = r + ((math.rad(turnDeg) - tip) / T - r) * share
		if d < ft.nearTurnM then
			local arm = speed / plan.tune.armR
			local lo, hi = arm * (1 - plan.tune.wristShare), arm * (1 + plan.tune.wristShare)
			if r < lo then r = lo elseif r > hi then r = hi end
		end
		if r < plan.tune.tumbleMin then r = plan.tune.tumbleMin end
	end
	return r
end

-- The group's box: its standing field kubbs.
local function groupBox(pos)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(pos.pieces) do
		if p.field and not p.lying then
			x0, x1 = math.min(x0, p.x), math.max(x1, p.x)
			y0, y1 = math.min(y0, p.y), math.max(y1, p.y)
		end
	end
	return x0, x1, y0, y1
end

-- One throw: the launch from (stance) along swivel; returns the field kubbs felled
-- and where the baton rested.
local function throwOnce(pos, L, hand)
	local w = world.new { surface = "grass", pieces = POS.pieces(pos) }
	local st = pos.stance
	local b = world.launchBaton(w, st.x, st.y, L.swivel, L.loft, L.speed, L.tumble, L.tilt, "baton",
		hand.h, hand.fwd, hand.tip)
	world.run(w, 6)
	local r = world.result(w)
	local felled = 0
	for _, id in ipairs(r.toppled) do
		local k = tonumber(id:match("^p(%d+)$"))
		if k and pos.pieces[k].field then felled = felled + 1 end
	end
	return felled, b.x, b.y
end

local function pct(a, of) return of > 0 and fmt("%3.0f%%", 100 * a / of) or "  -" end

-- A setting thrown n times with the jitter: a clean launch (speed, loft, swivel,
-- tumble) and its hand.
local function sweep(pos, clean, hand, label)
	local x0, x1, y0, y1 = groupBox(pos)
	local r = plan.rng(seed * 7919 + math.floor(clean.loft * 100) + 13)
	local total, two, none = 0, 0, 0
	local where = { inn = 0, past = 0, wide = 0, short = 0 }
	local beyond = 0
	local L = {}
	for _ = 1, n do
		L.swivel = clean.swivel + math.rad(r.normal(aimSd))
		L.loft = clean.loft + r.normal(loftSd)
		L.speed = clean.speed * (1 + r.normal(speedSd))
		L.tilt = r.normal(tiltSd)
		L.tumble = clean.tumble + r.normal(turnSd) * 2 * math.pi / clean.T
		if L.tumble < 0 then L.tumble = 0 end
		local k, bx, by = throwOnce(pos, L, hand)
		total = total + k
		if k >= 2 then two = two + 1 end
		if k == 0 then none = none + 1 end
		local m = 0.15
		if by < y0 - 0.1 then where.short = where.short + 1
		elseif bx < x0 - m or bx > x1 + m then where.wide = where.wide + 1
		elseif by > y1 + m then where.past = where.past + 1
		else where.inn = where.inn + 1 end
		beyond = beyond + (by - y1)
	end
	print(fmt("  %-14s %6.1f %6.2f %6.1f | %4.2f %s %s | in %s past %s wide %s short %s | %+5.2f m",
		label, clean.loft, clean.speed, plan.backForSpeed(clean.speed), total / n, pct(two, n), pct(none, n),
		pct(where.inn, n), pct(where.past, n), pct(where.wide, n), pct(where.short, n), beyond / n))
end

for _, name in ipairs(names) do
	local pos = assert(POS[name], "no position " .. name)
	local st, tg = pos.stance, pos.pieces[pos.target]
	local dx, dy = tg.x - st.x, tg.y - st.y
	local d = math.sqrt(dx * dx + dy * dy)
	local swivel = math.atan(dx, dy)
	print(fmt("%s: the front kubb %.2f m from the stance, %d throws a setting (jitter: aim %.2g deg, loft %.2g deg, speed %.2g, tilt %.2g deg, turn %.2g)",
		name, d, n, aimSd, loftSd, speedSd, tiltSd, turnSd))
	print("  setting          loft  speed   back | kubbs  2+    0  | the baton at rest                      | past the back kubb")
	-- the plans: the default arc for the distance, as the session plans it
	local function planRow(label, release)
		local sol = plan.solve({ projectile = "baton", px = st.x, py = st.y, tx = tg.x, ty = tg.y,
			release = release, meter = plan.meter(), aimZ = plan.aimZFor("kubb") }, {})
		sweep(pos, { speed = sol.speed, loft = sol.loft, swivel = sol.swivel, tumble = sol.tumble, T = sol.flightT },
			{ h = sol.handZ, fwd = sol.handFwd, tip = sol.handTip }, label)
		return sol
	end
	planRow("plan (0.15)", plan.sharedArcFor(d))
	planRow("plan (0.16)", plan.arcFor("baton", d))
	if not planOnly then
		local hands = { { name = "hand", hand = { flight.handAt(d) } } }
		if stand then hands[2] = { name = "stand", hand = { flight.tune.handHeight, 0, 1, 0, 0 } } end
		local list = lofts or (d < 2 and { 10, 5, 0, -5, -10, -15, -20 } or { 10, 5, 2, 0, -2, -4, -6 })
		for _, hd in ipairs(hands) do
			local h, fwd, _, _, tip = table.unpack(hd.hand)
			for _, loft in ipairs(list) do
				local R = d - fwd
				local ok, speed, T = pcall(flight.speedForCarry, R, math.rad(loft), h - (aimZ or KUBB_MID), flight.tune.dragK.baton)
				if ok and speed == speed and speed > 0 and speed < 25 then
					local clean = { speed = speed, loft = loft, swivel = swivel, T = T,
						tumble = turnShare * tumbleOf(d, speed, loft, T, tip) }
					sweep(pos, clean, { h = h, fwd = fwd, tip = tip }, fmt("%s %+g", hd.name, loft))
				else
					print(fmt("  %-14s %6.1f  (no speed reaches the kubb's middle)", hd.name .. " " .. loft, loft))
				end
			end
		end
	end
	print()
end
