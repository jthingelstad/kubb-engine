-- The Kubb Gym's recorded-throw worker (docs/notes/gym.md "Fitting the human thrower",
-- "The recorded-throw bank"). Reads recorded throws (tools/gym/fit.mjs and bank.mjs
-- write them to a private temporary file: they never go into this repository) and,
-- on the engine it is run with (--engine DIR, default this checkout):
--
--   invert   restores the snapshot before each throw, plans it as the player's session
--            did (stance, target, arc, tilt or spin) and recovers the swing and the
--            nerves' draws that make the recorded launch: back and stop come with the
--            record; the shake from the tilt, the pull from its sign, the side draw from
--            the swivel, the flick and the length and tumble draws from the speed and
--            the tumble. `err` is the largest relative difference between the launch
--            these rebuild and the recorded one (about 1e-12 when this is the engine
--            that planned the throw).
--   played   (--played) the recorded launch thrown on this engine's physics, with
--            forensics, and whether the snapshot after it is the recorded one (desktop
--            Lua: a hash check worth having, not the reference's, docs/DETERMINISM.md)
--   rethrow  (--rethrow FILE: lines { k, back, stop, flick, shake, pull, z }) the
--            recovered swing re-planned on this engine (the backswing and stop counted
--            from this engine's targets) and thrown with the same nerve draws, with
--            forensics
--
--   selftest (--selftest N) N seeded throws made by this engine's own session from
--            known swings (back and stop off the plan's targets, a flick, a shake and a
--            pull, the nerves seeded by the swing as a person's are), recorded as the
--            session records them and inverted: prints how many came back and the
--            largest error in each recovered part. Needs no records.
--
--   lua5.4 tools/gym/invert.lua --in FILE --out FILE [--engine DIR] [--played]
--       [--rethrow FILE]
--   lua5.4 tools/gym/invert.lua --selftest 200 [--engine DIR]
--
-- Input lines: { k, kind = "room", before = snapshot, a = action, hash } or
-- { k, kind = "browser", start = snapshot, actions = [...], hashes = [...] } (the
-- throws of a one-browser match are judged from its start while the hashes agree).
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/../.."
for k = 1, #arg - 1 do if arg[k] == "--engine" then sourceDir = arg[k + 1] end end
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end

import "session/session"
import "session/json"
import "session/throw"
import "core/throwplan"
import "core/world"
import "core/flight"
import "core/swing"
import "version"
local session, json, throw, plan, world, flight = tw.web.session, tw.web.json, tw.web.throw, tw.plan, tw.world, tw.flight
local swingTune = tw.swing.tune
local forensics = dofile(here .. "/forensics.lua")
local abs, sqrt, deg, max, min, huge = math.abs, math.sqrt, math.deg, math.max, math.min, math.huge
if session.useTune then session.useTune("pointer") end

local opt = {}
do
	local i = 1
	while i <= #arg do
		local a, v = arg[i], arg[i + 1]
		if a == "--in" then opt.input = v; i = i + 1
		elseif a == "--out" then opt.out = v; i = i + 1
		elseif a == "--engine" then i = i + 1
		elseif a == "--played" then opt.played = true
		elseif a == "--rethrow" then opt.rethrow = v; i = i + 1
		elseif a == "--selftest" then opt.selftest = tonumber(v); i = i + 1
		else error("invert: unknown option " .. a) end
		i = i + 1
	end
end
assert(opt.selftest or (opt.input and opt.out), "usage: invert.lua --in FILE --out FILE [--engine DIR] [--played] [--rethrow FILE]")

local function F(x) return (x or 0) + 0.0 end

-- ---------- the player's plan and launch ----------

-- The target's kind as the session names it: the nearest snap point (settleMarker).
local function snapOf(ts)
	local best, bd = nil, huge
	for _, it in ipairs(ts.snaps or {}) do
		local dx, dy = it.x - ts.markerX, it.y - ts.markerY
		local d = dx * dx + dy * dy
		if d < bd then best, bd = it, d end
	end
	return best
end

local function aimAt(ts, a, release, tilt, spin)
	local st, tg = a.stance or {}, a.target or {}
	ts.playerX, ts.playerY, ts.stanceSet = F(st.x), F(st.y), st.set and true or false
	ts.markerX, ts.markerY, ts.markerSet, ts.markerOnId = F(tg.x), F(tg.y), tg.set and true or false, tg.on
	if ts.projectile ~= "kubb" then
		local best = snapOf(ts)
		if best then
			ts.markerKind = best.kind == "king" and "king" or (best.role == "field" and "field" or "base")
		end
	end
	if release then ts.release, ts.arcSet = F(release), true else ts.arcSet = false end
	ts.tilt = F(tilt)
	if spin then ts.spin = spin end
	ts.planDirty = true
	throw.replan(ts)
	return ts.sol
end

local function stream(z)
	local i = 0
	return { normal = function(sd) i = i + 1; return (z[i] or 0) * sd end, next = function() return 0.5 end }
end

local function launch(ts, r, z)
	ts.nerves = stream(z or { 0, 0, 0 })
	local L = throw.playerLaunch(ts, r)
	ts.nerves = nil
	return L
end

local function swingOf(back, stop, flick, shake, pull)
	return { back = F(back), releaseAngle = F(stop), flickFrac = F(flick), shake = F(shake), smoothness = 1 - F(shake),
		pull = pull, how = stop >= swingTune.skyDeg and "sky" or "stopped" }
end

local KEYS = { baton = { "speed", "loft", "swivel", "tilt", "tumble" },
	kubb = { "speed", "loft", "swivel", "tilt", "noseDown", "rollLand", "spin", "wobble" } }

local function errOf(L, R, kubb)
	local e = 0
	for _, k in ipairs(KEYS[kubb and "kubb" or "baton"]) do
		local x, y = F(L[k]), F(R[k])
		local d = abs(x - y) / max(abs(y), 1e-6)
		if d > e then e = d end
	end
	return e
end

-- Recovers flick, shake, pull and the draws for one plan (release, tilt, spin fixed).
local function invertOn(ts, a, release, tilt, spin)
	local R, sw = a.launch, a.swing
	local kubb = ts.projectile == "kubb"
	local sol = aimAt(ts, a, release, tilt, spin)
	local back, stop = F(sw.back), F(sw.stop)
	-- the shake: the tilt it makes against a full shake
	local L0 = launch(ts, swingOf(back, stop, 1, 0, 1))
	local L1 = launch(ts, swingOf(back, stop, 1, 1, 1))
	local unit = F(L1.tilt) - F(L0.tilt)
	local dt = F(R.tilt) - F(L0.tilt)
	local pull = dt < 0 and -1 or 1
	if unit > 0 and abs(dt) > unit * (1 + 1e-9) then return nil, "shake past 1" end
	-- the tilt grows with the shake as it counts, which on a person's meter (0.13 on) is
	-- not the shake itself (plan.shakeCounts: a steady shake is forgiven), so the shake
	-- is found by bisection on the tilt it makes, not by proportion
	local shake = 0
	if unit > 0 and dt ~= 0 then
		local lo, hi, want = 0, 1, abs(dt)
		for _ = 1, 60 do
			local mid = 0.5 * (lo + hi)
			if F(launch(ts, swingOf(back, stop, 1, mid, 1)).tilt) - F(L0.tilt) < want then lo = mid else hi = mid end
		end
		shake = 0.5 * (lo + hi)
	end
	-- the side draw: the swivel past what the pull makes
	local Ls = launch(ts, swingOf(back, stop, 1, shake, pull))
	local zs = (Ls.sdSide and Ls.sdSide > 0) and deg(F(R.swivel) - F(Ls.swivel)) / Ls.sdSide or 0
	local S1 = F(Ls.speed)
	local P = F(R.speed) / S1
	local sdLen = Ls.sdLen or 0
	local zl = function(f) return sdLen > 0 and ((P / f) ^ 2 - 1) / sdLen or 0 end
	local f, zt
	if kubb then
		-- a kubb's flick and length draw make one product: the draw alone, unless it
		-- would be past 2.5 sd short, then the flick takes the rest
		f = 1
		if zl(1) < -2.5 then f = min(1, P / sqrt(max(1e-9, 1 - 2.5 * sdLen))) end
		zt = 0
	else
		local rate = F(Ls.tumble)
		local Lt = launch(ts, swingOf(back, stop, 1, shake, pull), { 0, 0, 1 })
		local kT = F(Lt.tumble) - rate
		local function cost(x)
			local a1 = zl(x)
			local a2 = kT ~= 0 and (F(R.tumble) - rate * x) / kT or 0
			return a1 * a1 + a2 * a2, a2
		end
		local bestF, bestC = 1, cost(1)
		for x = 0.2, 1, 0.0005 do
			local c = cost(x)
			if c < bestC then bestF, bestC = x, c end
		end
		local s = 0.0005
		while s > 1e-11 do
			for _, x in ipairs({ bestF - s, bestF + s }) do
				if x >= 0.2 and x <= 1 then
					local c = cost(x)
					if c < bestC then bestF, bestC = x, c end
				end
			end
			s = s / 4
		end
		f = bestF
		local _
		_, zt = cost(f)
	end
	local z = { zs, zl(f), zt }
	local Lc = launch(ts, swingOf(back, stop, f, shake, pull), z)
	return { L = Lc, sol = sol, flick = f, shake = shake, pull = pull, z = z, err = errOf(Lc, R, kubb) }
end

local TILTS = { 0, -5, 5, -10, 10, -15, 15, -20, 20 }

local function invert(ts, a)
	local R, sw = a.launch, a.swing
	local kubb = ts.projectile == "kubb"
	local P = type(a.plan) == "table" and a.plan or nil
	-- the arc: the plan's own when the record names it; else the default, unless its loft
	-- is not the recorded one (the player set the arc): then the release that makes it
	local release = P and P.release or nil
	local spins = { 0 }
	if kubb then
		if P and P.spin then spins = { P.spin }
		else
			spins = {}
			local m = plan.tune.spinSteps or 0
			local keep = ts.keptSpin or ts.spin or 0
			spins[1] = keep
			for k = -m, m do if k ~= keep then spins[#spins + 1] = k end end
		end
	end
	local tilts = kubb and { 0 } or ((P and P.tilt) and { P.tilt } or TILTS)
	if not release then
		local sol = aimAt(ts, a, nil, 0, spins[1])
		local L0 = launch(ts, swingOf(sw.back, sw.stop, 1, 0, 1))
		if abs(F(L0.loft) - F(R.loft)) > 1e-7 then
			local lo, hi = 1, 179
			local function loftAt(x)
				aimAt(ts, a, x, 0, spins[1])
				return F(launch(ts, swingOf(sw.back, sw.stop, 1, 0, 1)).loft)
			end
			for _ = 1, 200 do
				local mid = (lo + hi) / 2
				if loftAt(mid) < F(R.loft) then lo = mid else hi = mid end
			end
			release = (lo + hi) / 2
		end
		local _ = sol
	end
	local best
	local steadyRec = a.verdicts and a.verdicts.steady
	for _, sp in ipairs(spins) do
		for _, tp in ipairs(tilts) do
			local r = invertOn(ts, a, release, tp, sp)
			if r then
				r.tiltPlan, r.spinPlan = tp, sp
				-- the verdicts the player saw must come out the same
				local agree = steadyRec == nil or (r.L.steady and true or false) == (steadyRec and true or false)
				r.agree = agree
				local better = not best
					or (agree and not best.agree)
					or (agree == best.agree and r.err < best.err * 0.5)
				if better then best = r end
				if best.agree and best.err < 1e-9 and tp == 0 then break end
			end
		end
		if best and best.err < 1e-9 and best.agree then break end
	end
	if best then best.release, best.arcSet = release, release ~= nil end
	return best
end

-- ---------- throwing it with forensics ----------

local function fireWorld(ts, L, how)
	local kubb = how ~= "baton"
	local pieces = {}
	for i, it in ipairs(ts.items) do
		pieces[i] = { id = it.id, kind = it.kind, x = it.x, y = it.y, z = it.z,
			qw = it.qw, qx = it.qx, qy = it.qy, qz = it.qz, toppled = it.toppled }
	end
	local w = world.new { surface = ts.surface, pieces = pieces, windX = ts.windX, windY = ts.windY }
	local id = ts.projectileId
	if how == "drill" and not id then id = "d" .. ((ts.drillSeq or 0) + 1) end
	if kubb then
		if how == "drill" then
			world.launchDrill(w, id, ts.playerX, ts.playerY, F(L.swivel), F(L.loft), F(L.speed), F(L.noseDown),
				F(L.rollLand), F(L.spin), F(L.wobble))
		else
			world.launchKubb(w, id, ts.playerX, ts.playerY, F(L.swivel), F(L.loft), F(L.speed), 0)
		end
	else
		-- a baton's hand (since 0.8: flight.handAt); older engines launch from their own
		local hz, hf, tip
		if flight.handAt then
			local _
			hz, hf, _, _, tip = flight.handAt(sqrt((ts.markerX - ts.playerX) ^ 2 + (ts.markerY - ts.playerY) ^ 2))
		end
		world.launchBaton(w, ts.playerX, ts.playerY, F(L.swivel), F(L.loft), F(L.speed), F(L.tumble), F(L.tilt), id,
			hz, hf, tip)
	end
	local on = ts.markerOnId
	if not on and not kubb then
		local s = snapOf(ts)
		on = s and s.id
	end
	local rec = forensics.run(w, { stanceX = ts.playerX, stanceY = ts.playerY, aimX = ts.markerX, aimY = ts.markerY,
		on = on }, ts.items)
	if how == "drill" then rec.drill = { dx = rec.restX - ts.markerX, dy = rec.restY - ts.markerY } end
	return rec
end

local function kindOf(ts, a)
	if ts.projectile == "kubb" then return "drill" end
	if ts.markerKind then return ts.markerKind end
	local s = snapOf(ts)
	return s and (s.kind == "king" and "king" or (s.role == "field" and "field" or "base")) or "base"
end

-- ---------- main ----------

if opt.selftest then
	-- throws this engine makes from known swings, recorded and inverted (see the top)
	local START = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }
	local rng = plan.rng(20261122)
	local n, got, worst = 0, 0, { back = 0, stop = 0, flick = 0, shake = 0, pull = 0, err = 0 }
	local kinds = {}
	local seed = 0
	while n < opt.selftest do
		seed = seed + 1
		local s = session.new { mode = "match", seed = seed, start = START, maxTurns = 3,
			teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
				B = { name = "Bo", players = { { name = "Bo", level = "club", key = "m2" } } } } }
		for _ = 1, 40 do
			local need = s:need()
			if need.kind ~= "throw" or n >= opt.selftest then break end
			local ts = s.ts
			local sol = ts.sol
			local kubb = ts.projectile == "kubb"
			local back = sol.back + rng.normal(10)
			local stop = sol.release + rng.normal(8)
			if back < 0 then back = 0 end
			local flick = rng.uniform(0, 1) < 0.5 and 1 or rng.uniform(0.85, 1)
			local shake = rng.uniform(0, 0.6)
			local pull = rng.uniform(0, 1) < 0.5 and -1 or 1
			local r = swingOf(back, stop, flick, shake, pull)
			ts.nerves = nil
			local L, how = throw.playerLaunch(ts, r)
			local a = s:throwAction(L, how, { back = back, stop = stop, input = "pointer",
				verdicts = { powerV = L.powerV, releaseV = L.releaseV, steady = L.steady, sideV = L.sideV } })
			local before = s:snapshot()
			local s2 = session.restore(before)
			s2:need()
			local ok, rv = pcall(invert, s2.ts, a)
			n = n + 1
			kinds[how] = (kinds[how] or 0) + 1
			if ok and rv and rv.err < 1e-6 then
				got = got + 1
				local function dd(k, x, y) local d = abs(x - y); if d > worst[k] then worst[k] = d end end
				dd("flick", rv.flick, flick)
				dd("shake", rv.shake, shake)
				dd("pull", rv.pull, pull)
				dd("err", rv.err, 0)
			end
			local okA = pcall(function() s:apply(a) end)
			if not okA then break end
		end
	end
	local kk = {}
	for k, v in pairs(kinds) do kk[#kk + 1] = k .. " " .. v end
	table.sort(kk)
	print(string.format("invert selftest (engine %s): %d of %d recovered (%s); largest error: flick %.2g, shake %.2g, pull %.2g, launch %.2g",
		(tw.engine and tw.engine.version) or "?", got, n, table.concat(kk, ", "), worst.flick, worst.shake, worst.pull, worst.err))
	os.exit(got == n and 0 or 1)
end

local rethrow = {}
if opt.rethrow then
	for line in io.lines(opt.rethrow) do
		local r = json.decode(line)
		rethrow[r.k] = r
	end
end

local out = assert(io.open(opt.out, "w"))
local function emit(o) out:write(json.encode(o), "\n") end

local function one(s, a, base)
	s:need()
	local ts = s.ts
	local o = { k = base.k, i = base.i, how = a.how, level = throw.levelFor(ts), engine = VERSION }
	if type(o.level) == "table" then o.level = nil end
	if a.how ~= "baton" and a.how ~= "drill" then return end
	if a.scripted or not a.swing then return end
	local before = s:snapshot()
	local r = invert(ts, a)
	o.kind = kindOf(ts, a)
	o.dist = sqrt((ts.markerX - ts.playerX) ^ 2 + (ts.markerY - ts.playerY) ^ 2)
	o.verdicts = a.verdicts
	o.legal = not (a.launch and a.launch.legal == false)
	if r then
		local sol = r.sol
		o.err, o.agree = r.err, r.agree
		o.back, o.stop = F(a.swing.back), F(a.swing.stop)
		o.solBack, o.solRelease, o.powerLo, o.powerHi = sol.back, sol.release, sol.powerLo, sol.powerHi
		o.releaseLo, o.releaseHi = sol.releaseLo, sol.releaseHi
		o.flick, o.shake, o.pull, o.z = r.flick, r.shake, r.pull, r.z
		o.arcSet, o.release, o.tiltPlan, o.spinPlan = r.arcSet, r.release, r.tiltPlan, r.spinPlan
		o.powerV, o.releaseV, o.steady = r.L.powerV, r.L.releaseV, r.L.steady
	end
	if opt.played then
		s = session.restore(before)
		local ts2 = s.ts
		local st, tg = a.stance or {}, a.target or {}
		ts2.playerX, ts2.playerY = F(st.x), F(st.y)
		ts2.markerX, ts2.markerY, ts2.markerOnId = F(tg.x), F(tg.y), tg.on
		o.played = fireWorld(ts2, a.launch, a.how)
		if base.hash then
			local s3 = session.restore(before)
			s3:need()
			local ok = pcall(function() s3:apply(a) end)
			o.same = ok and s3:hash() == base.hash or false
		end
	end
	local rt = rethrow[base.k .. ":" .. base.i]
	if rt then
		s = session.restore(before)
		local ts3 = s.ts
		s:need()
		local sol = aimAt(ts3, a, rt.arcSet and rt.release or nil, rt.tiltPlan or 0, rt.spinPlan)
		-- the same misses counted from this engine's targets
		local back = sol.back + rt.db
		local stop = sol.release + rt.dr
		if back < 0 then back = 0 end
		if back > swingTune.backswingMaxDeg then back = swingTune.backswingMaxDeg end
		local L2 = launch(ts3, swingOf(back, stop, rt.flick, rt.shake, rt.pull), rt.z)
		o.rethrow = fireWorld(ts3, L2, a.how)
		o.rethrow.legal = L2.legal
		o.rethrow.powerV, o.rethrow.releaseV, o.rethrow.steady = L2.powerV, L2.releaseV, L2.steady and true or false
	end
	emit(o)
end

for line in io.lines(opt.input) do
	local m = json.decode(line)
	if m.kind == "room" then
		local ok, s = pcall(session.restore, m.before)
		if ok and s then
			local okN, n = pcall(function() return s:need() end)
			if okN and n.kind == "throw" then
				local ok2, e = pcall(one, s, m.a, { k = m.k, i = m.i, hash = m.hash })
				if not ok2 then emit({ k = m.k, i = m.i, error = tostring(e) }) end
			end
		else
			emit({ k = m.k, i = m.i, error = "restore: " .. tostring(s) })
		end
	elseif m.kind == "browser" then
		local ok, s = pcall(session.restore, m.start)
		if ok and s then
			for i, a in ipairs(m.actions) do
				local n = s:need()
				if n.kind == "over" then break end
				if a.type == "throw" and n.kind == "throw" then
					local before = s:snapshot()
					local ok2, e = pcall(one, session.restore(before), a, { k = m.k, i = i })
					if not ok2 then emit({ k = m.k, i = i, error = tostring(e) }) end
					s = session.restore(before)
					s:need()
				end
				local okA = pcall(function() s:apply(a) end)
				if not okA then break end
				-- judged from the start: stop at the first action this engine plays another way
				if m.hashes and m.hashes[i] and s:hash() ~= m.hashes[i] then break end
			end
		end
	end
end
out:close()
