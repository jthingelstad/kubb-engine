-- The v0.8.1 implementation of the short throw's plan, kept as the reference the
-- engine's must equal bit for bit (tests/lua/test_plan_identity.lua under desktop
-- Lua, tests/node/plan-identity.test.mjs under wasmoon). Copied verbatim from the
-- v0.8.1 tag's core/flight.lua (timeToGround, carry, speedForCarry, handAt) and
-- core/throwplan.lua (carrySpeed, solve); only the names are local. The helpers
-- solve calls that did not change (plan.level, clampRelease, loftFor, tumbleFor,
-- backForSpeed, flight.nearTurn, drill.solveAt) are the live ones. Never edit the
-- copied bodies: they are what 0.8.x computes.
import "core/tw"
import "core/flight"
import "core/drill"
import "core/throwplan"

local sqrt, sin, cos, rad = math.sqrt, math.sin, math.cos, math.rad
local atan = math.atan
local flight, drill, plan = tw.flight, tw.drill, tw.plan
local levelOf = plan.level

local ref = {}

local function timeToGround(z0, vz, g)
	return (vz + sqrt(vz * vz + 2 * g * z0)) / g
end

local function carry(speed, e, h, k)
	local t = flight.tune
	local g = t.g
	local u, w = speed * cos(e), speed * sin(e)
	if k <= 0 then
		local T = timeToGround(h, w, g)
		return u * T, T
	end
	local H = t.carryStep
	local x, z, time = 0, h, 0
	for _ = 1, 3000 do
		local s = sqrt(u * u + w * w)
		local hu = u - 0.5 * H * k * s * u
		local hw = w - 0.5 * H * (g + k * s * w)
		local sm = sqrt(hu * hu + hw * hw)
		local au, aw = -k * sm * hu, -g - k * sm * hw
		local z1 = z + H * hw
		if z1 <= 0 then
			-- this step reaches the ground: z + w s + aw s^2 / 2 = 0 (aw < 0)
			local a = -aw
			local tau = (w + sqrt(w * w + 2 * a * z)) / a
			return x + u * tau + 0.5 * au * tau * tau, time + tau
		end
		x, z = x + H * hu, z1
		u, w = u + H * au, w + H * aw
		time = time + H
	end
	return x, time
end
ref.carry = carry

local function speedForCarry(R, e, h, k)
	local g = flight.tune.g
	local c = cos(e)
	local v0 = sqrt(g * R * R / (2 * c * c * (R * sin(e) / c + h)))
	if k <= 0 then return v0, timeToGround(h, v0 * sin(e), g) end
	local r0, T0 = carry(v0, e, h, k)
	local best = r0 - R
	if best < 0 then best = -best end
	local v1 = v0 * sqrt(R / r0)
	for _ = 1, 10 do
		local r1, T = carry(v1, e, h, k)
		local err = r1 - R
		local a = err < 0 and -err or err
		if a >= best then return v0, T0 end
		local dr = r1 - r0
		if a < 1e-7 or dr == 0 then return v1, T end
		local v2 = v1 - err * (v1 - v0) / dr
		if v2 == v1 or v2 ~= v2 then return v1, T end
		v0, r0, T0, v1, best = v1, r1, T, v2, a
	end
	return v0, T0
end
ref.speedForCarry = speedForCarry

function ref.handAt(d)
	local t = flight.tune
	if not d or d >= t.nearM then return t.handHeight, 0, 1, 0, 0 end
	if d < 0 then d = 0 end
	local s = 1 - d / t.nearM
	local fwd = t.nearReach * s
	if fwd > 0.5 * d then fwd = 0.5 * d end
	local h = t.handHeight - (t.handHeight - t.nearHandHeight) * s
	local tip = t.nearTip * s
	-- the firm bowl: lower the hand until a release at nearSpeed and the flattened
	-- field loft carries just to the aim at the target, a kubb's (nearAimRef
	-- toward nearAimZ, as plan.solve; bisection; the carry
	-- grows with the height; the carry is never taken under 0.1 m, as plan.solve)
	local R, z, k = d - fwd, t.nearAimRef + (t.nearAimZ - t.nearAimRef) * s, t.dragK.baton
	if R < 0.1 then R = 0.1 end
	local e = rad(t.nearLoftDeg * (1 - t.nearFlatten * s))
	local lo = (0.5 * t.batonLength - t.batonRadius) * cos(tip) + t.batonRadius + t.nearLow
	if lo < z + 0.005 then lo = z + 0.005 end
	if h > lo and carry(t.nearSpeed, e, h - z, k) > R then
		if carry(t.nearSpeed, e, lo - z, k) >= R then
			h = lo
		else
			local a, b = lo, h
			for _ = 1, 30 do
				local m = 0.5 * (a + b)
				if carry(t.nearSpeed, e, m - z, k) > R then b = m else a = m end
			end
			h = 0.5 * (a + b)
		end
	end
	return h, fwd, 1 - t.nearFlatten * s, s, tip
end

local function carrySpeed(R, e, h)
	return speedForCarry(R, e, h, flight.tune.dragK.baton)
end

function ref.solve(q, out)
	local lv = levelOf(q.level)
	local rel = plan.clampRelease(q.release or plan.tune.arc.base)
	local loft = plan.loftFor(rel)
	local px, py, tx, ty = q.px, q.py, q.tx, q.ty
	if q.projectile == "kubb" then
		drill.solveAt(tx, ty, py, loft, out, px, q.surface, (q.spin or 0) * plan.tune.spinPerStep)
		out.tumble, out.flightT, out.aimZ, out.handZ, out.handFwd, out.loftShare, out.handTip = nil, nil, 0, nil, nil, nil, nil
		out.nearShare = nil
	else
		local dx, dy = tx - px, ty - py
		local d = sqrt(dx * dx + dy * dy)
		local ft = flight.tune
		local z = q.aimZ or 0
		-- a short throw (flight.tune "The hand at a short throw"): the hand lower
		-- and ahead of the feet, the loft flatter, and the centre aimed through a
		-- piece's face rather than over its top
		local h, fwd, flat, near, tip = ref.handAt(d)
		out.handZ, out.handFwd, out.loftShare, out.handTip, out.nearShare = h, fwd, flat, tip, near
		if near > 0 and z > 0 then z = z + (ft.nearAimZ - z) * near end
		if flat ~= 1 then loft = loft * flat end
		local R = d - fwd
		if R < 0.1 then R = 0.1 end
		local speed, T = carrySpeed(R, rad(loft), h - z)
		if near > 0 and z > 0 and speed < ft.nearSpeed and h - z > 0.005 then
			-- the hand is as low as it goes (flight.handAt) and the bowl would still
			-- be soft: aim higher through the face until it is firm again (the
			-- carry shortens as the drop does), never within 5 mm of the hand
			local a, b = z, h - 0.005
			if carrySpeed(R, rad(loft), h - b) <= ft.nearSpeed then
				z = b
			else
				for _ = 1, 20 do
					local m = 0.5 * (a + b)
					if carrySpeed(R, rad(loft), h - m) < ft.nearSpeed then a = m else b = m end
				end
				z = b
			end
			speed, T = carrySpeed(R, rad(loft), h - z)
		end
		out.swivel, out.dist, out.loft, out.aimZ = atan(dx, dy), d, loft, z
		out.speed = speed
		out.tumble, out.flightT = plan.tumbleFor(speed, loft, T, lv), T
		if near > 0 and T > 0 then
			-- the turn it arrives with (flight.nearTurn): a share of the way from
			-- the level's own rate to the one that makes it; flat into the face is
			-- kept inside the wrist's range (plan.tumbleFor's)
			local turnDeg, share = flight.nearTurn(d)
			local r = out.tumble + ((rad(turnDeg) - tip) / T - out.tumble) * share
			if d < ft.nearTurnM then
				local arm = speed / plan.tune.armR
				local lo, hi = arm * (1 - plan.tune.wristShare), arm * (1 + plan.tune.wristShare)
				if r < lo then r = lo elseif r > hi then r = hi end
			end
			out.tumble = r > plan.tune.tumbleMin and r or plan.tune.tumbleMin
		end
	end
	local back = plan.backForSpeed(out.speed)
	out.back, out.powerLo, out.powerHi = back, back - lv.powerHalf, back + lv.powerHalf
	out.release, out.releaseLo, out.releaseHi = rel, rel - lv.releaseHalf, rel + lv.releaseHalf
	out.projectile, out.px, out.py, out.tx, out.ty, out.level = q.projectile or "baton", px, py, tx, ty, lv
	return out
end

-- The fields plan.solve fills, compared one by one.
local FIELDS = { "back", "powerLo", "powerHi", "release", "releaseLo", "releaseHi", "projectile", "px", "py",
	"tx", "ty", "level", "swivel", "dist", "loft", "aimZ", "speed", "tumble", "flightT", "handZ", "handFwd",
	"loftShare", "handTip", "nearShare", "x", "band", "T", "land" }

local function same(a, b)
	if a ~= a and b ~= b then return true end -- NaN
	return a == b
end

-- A dense sweep of the plan, the live engine against the reference: returns the
-- number of cases and the first difference (nil when none). Distances 0.2 to 2.5 m
-- every 2.5 mm and 2.5 to 10 m every 5 cm; several aim heights, releases, levels,
-- stances and directions; drills on both surfaces; and handAt, carry and
-- speedForCarry on their own. (flight.nearTurn is unchanged since v0.8.1, so the
-- reference calls the live one; its share reaches solve's nearShare, compared here.)
function ref.sweep(opts)
	opts = opts or {}
	local cases, first = 0, nil
	local function note(what) if not first then first = what end end
	local ds = {}
	for i = 0, 920 do ds[#ds + 1] = 0.2 + i * 0.0025 end
	for i = 1, 150 do ds[#ds + 1] = 2.5 + i * 0.05 end
	for _, d in ipairs { 0, 0.01, 0.05, 0.1, 0.15, 0.1999, 1.9999, 2.0, 2.0001 } do ds[#ds + 1] = d end
	local zs = { 0, plan.aimZFor("kubb"), plan.aimZFor("king"), 0.05, 0.12, 0.25 }
	local rels = { plan.arcFor("field"), plan.arcFor("base"), plan.arcFor("king"), plan.tune.releaseMinDeg,
		plan.tune.releaseMaxDeg, 40, 75 }
	local levels = { "beginner", "club", "pro" }
	local dirs = { { 0, 0, 0, 1 }, { 0.4, -0.3, 0.6, 0.8 }, { -1.1, 2.0, -0.28, 0.96 } }
	local stride = opts.stride or 1
	local a, b = {}, {}
	for di = 1, #ds, stride do
		local d = ds[di]
		local h1 = { flight.handAt(d) }
		local h2 = { ref.handAt(d) }
		for i = 1, 5 do cases = cases + 1; if not same(h1[i], h2[i]) then note("handAt(" .. d .. ") value " .. i) end end
		for _, dir in ipairs(dirs) do
			local px, py, ux, uy = dir[1], dir[2], dir[3], dir[4]
			for _, z in ipairs(zs) do
				for _, rel in ipairs(rels) do
					for _, lv in ipairs(levels) do
						local q = { projectile = "baton", px = px, py = py, tx = px + ux * d, ty = py + uy * d,
							release = rel, level = lv, aimZ = z, surface = "grass" }
						plan.solve(q, a); ref.solve(q, b)
						cases = cases + 1
						for _, f in ipairs(FIELDS) do
							if not same(a[f], b[f]) then
								note(string.format("solve d=%.4f z=%.3f rel=%s %s px=%.1f: %s %.17g vs %.17g", d, z,
									tostring(rel), lv, px, f, tonumber(a[f]) or 0, tonumber(b[f]) or 0))
							end
						end
					end
				end
			end
		end
	end
	-- drills (the kubb branch) on both surfaces
	for _, surface in ipairs { "grass", "sand" } do
		for i = 0, 40 do
			local ty = 4 + i * 0.1
			local q = { projectile = "kubb", px = 0.3, py = 0, tx = -0.5 + i * 0.02, ty = ty, release = plan.arcFor("drill"),
				level = "club", surface = surface, spin = (i % 3) - 1 }
			plan.solve(q, a); ref.solve(q, b)
			cases = cases + 1
			for _, f in ipairs(FIELDS) do
				if not same(a[f], b[f]) then note("drill " .. surface .. " " .. i .. ": " .. f) end
			end
		end
	end
	-- carry and its inverse on their own, over the short throw's range
	local k = flight.tune.dragK.baton
	for si = 0, 40, stride do
		for hi = 0, 30, stride do
			for ei = 0, 6 do
				local v, h, e = 1 + si * 0.3, 0.001 + hi * 0.03, rad(2 + ei * 8)
				local r1, t1 = flight.carry(v, e, h, k)
				local r2, t2 = ref.carry(v, e, h, k)
				cases = cases + 1
				if not (same(r1, r2) and same(t1, t2)) then note(string.format("carry v=%g h=%g", v, h)) end
				local w1, u1 = flight.speedForCarry(r2, e, h, k)
				local w2, u2 = ref.speedForCarry(r2, e, h, k)
				cases = cases + 1
				if not (same(w1, w2) and same(u1, u2)) then note(string.format("speedForCarry R=%g h=%g", r2, h)) end
			end
		end
	end
	return cases, first
end

tw.planRef = ref
