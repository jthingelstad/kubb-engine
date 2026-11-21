-- The Kubb Gym's human thrower (docs/notes/gym.md "The human thrower"): a person at
-- the meter. It picks its target and stance as the computer does
-- (core/autothrow), then plans the throw on the person's meter, as the session
-- does for a player (session/throw replan: plan.meter(), the bars for the
-- distance, the default arc for the target, no tilt or spin; from 0.13 a level
-- no longer changes a person's throw), makes a swing with a person's errors in
-- it, drawn from a model fitted to recorded swings (tools/gym/fit.mjs writes
-- tools/gym/human-model.json; the level only picks which fitted part), and turns
-- it into the launch exactly as throw.playerLaunch does: plan.launch against the
-- plan, the meter's forgiveness, and the nerves seeded by the swing
-- (plan.swingSeed). An engine before 0.13 (no plan.meter) plans at the level.
-- Desktop only, a measuring tool.
--
--   local human = dofile("tools/gym/human.lua")    -- after core/autothrow is imported
--   local model = human.load(path)                 -- the fitted model (JSON)
--   local a = human.choose(setup, r, level, model) -- the same table autothrow.choose makes
--
-- The model, per throw level and projectile (baton, drill), holds the
-- measured distribution of each part of a swing as 21 quantiles (0, 5%, ...,
-- 100%): back (degrees of backswing past the power target's centre), release
-- (degrees the crank stopped past the release target's centre), flick (the
-- flick's share of the power, when it was not full) beside flickFull (the
-- share of swings with a full flick), shake (0..1) and pullRight (the share
-- pulled right). Each part is drawn on its own (the parts' correlation is
-- reported by the fit, not modelled). A level with no recorded swings uses the
-- level the model's `use` names for it.
import "core/autothrow"
import "core/throwplan"
import "core/swing"
import "session/json"
local autothrow, plan, swing, json = tw.autothrow, tw.plan, tw.swing, tw.web.json

local human = {}

function human.load(path)
	local f = assert(io.open(path, "r"), "no human model at " .. tostring(path))
	local m = json.decode(f:read("a"))
	f:close()
	assert(m.levels, "human model: no levels")
	return m
end

-- The model's swing table for level and projectile ("baton" or "drill").
function human.part(model, level, projectile)
	local use = (model.use and model.use[level]) or level
	local lv = model.levels[use] or model.levels.pooled
	assert(lv, "human model: no swings for level " .. tostring(level))
	return lv[projectile] or model.levels.pooled[projectile], use
end

-- Inverse CDF of 21 quantiles at u in [0, 1).
local function draw(q, u)
	local n = #q - 1
	local x = u * n
	local i = math.floor(x)
	if i >= n then return q[n + 1] end
	local f = x - i
	return q[i + 1] + (q[i + 2] - q[i + 1]) * f
end
human.draw = draw

-- A person's swing for solution sol from model part p: core/swing's result
-- fields. Always draws seven values from r.
function human.swing(sol, p, r, out)
	out = out or {}
	local st = swing.tune
	local u1, u2, u3, u4, u5, u6, u7 = r.next(), r.next(), r.next(), r.next(), r.next(), r.next(), r.next()
	local back = sol.back + draw(p.back, u1)
	if back > st.backswingMaxDeg then back = st.backswingMaxDeg end
	if back < 0 then back = 0 end
	out.back = back
	local rel = sol.release + draw(p.release, u2)
	if rel < 1 then rel = 1 end
	out.how = rel >= st.skyDeg and "sky" or "stopped"
	out.releaseAngle = rel
	local flick = 1
	if u3 >= (p.flickFull or 1) and p.flick then flick = draw(p.flick, u4) end
	if flick > 1 then flick = 1 elseif flick < st.minFlickFrac then flick = st.minFlickFrac end
	out.flickFrac = flick
	local shake = draw(p.shake, u5)
	if shake < 0 then shake = 0 elseif shake > 1 then shake = 1 end
	out.shake, out.smoothness = shake, 1 - shake
	out.pull = (u6 < (p.pullRight or 0.5)) and 1 or -1
	local _ = u7 -- kept so a later part can be added without moving the stream
	return out
end

-- The standing kubb or king nearest a plan's aim point: the target of an engine whose
-- autothrow does not name it (before 0.8).
function human.nearest(s, P)
	if not P or not P.tx then return nil end
	local best, bd = nil, math.huge
	for _, p in ipairs(s.pieces) do
		if p.kind ~= "baton" and not p.toppled then
			local d = (p.x - P.tx) ^ 2 + (p.y - P.ty) ^ 2
			if d < bd then best, bd = p, d end
		end
	end
	return best and best.id
end

-- A throw for match setup s at throw level `level` (a name) by a person
-- whose swing is drawn from model. Returns what autothrow.choose returns
-- (autothrow.launch puts it into a world), with a.human = the model level used.
function human.choose(s, r, level, model)
	-- the computer's choice of target and stance, thrown clean (scale 0: no
	-- mistakes, no nerves; it still draws its numbers from r)
	local a0 = autothrow.choose(s, r, 0, level)
	local P = a0.plan
	local kubb = s.kind == "toss"
	-- a kubb's spin is the computer's for the level (from 0.11 the taps set the roll,
	-- and a person at the level spins as its computer does); none on an older engine
	local taps = 0
	if kubb and a0.drill and tw.drill.plannedSpin then
		taps = tw.drill.plannedSpin(a0.drill.spin) / plan.tune.spinPerStep
	end
	local q = { projectile = kubb and "kubb" or "baton", px = P.px, py = P.py, tx = P.tx, ty = P.ty,
		level = level, meter = plan.meter and plan.meter() or nil, surface = s.surface, spin = taps }
	if kubb then
		q.release = plan.arcFor("drill")
	else
		-- an engine before 0.8 does not name its target: the standing piece nearest
		-- the aim point is it (the arc depends on whether that is a field kubb)
		local on = a0.on or human.nearest(s, P)
		a0.on = on
		local role = "base"
		for _, p in ipairs(s.pieces) do
			if p.id == on then role = p.role or (p.kind == "king" and "king") or "base" end
		end
		-- (the distance: an engine whose default arc goes by it takes it; one
		-- whose arc goes by the target alone ignores it)
		local d = math.sqrt((P.tx - P.px) ^ 2 + (P.ty - P.py) ^ 2)
		if s.kingShot or role == "king" then
			q.release, q.aimZ = plan.arcFor("king", d), plan.aimZFor("king")
		else
			q.release, q.aimZ = plan.arcFor(role == "field" and "field" or "base", d), plan.aimZFor("kubb")
		end
	end
	local sol = plan.solve(q, {})
	local part, used = human.part(model, level, kubb and "drill" or "baton")
	local sw = human.swing(sol, part, r, {})
	-- the player's launch (session/throw playerLaunch): nerves seeded by the swing
	local L = plan.launch(sol, sw, { projectile = q.projectile, tilt = 0, spin = taps,
		level = not q.meter and level or nil, nerves = true }, {})
	local a = { x = P.px, y = P.py, swivel = L.swivel, loftDeg = L.loft, speed = L.speed, tumbleRate = L.tumble,
		tilt = L.tilt, legal = L.legal, plan = sol, swing = sw, launch = L, on = a0.on, human = used }
	if kubb then
		a.drill = { markerX = P.tx, markerY = P.ty - s.lineY, noseDown = L.noseDown, rollLand = L.rollLand,
			spin = L.spin, wobble = L.wobble, scatter = L.scatter }
	end
	return a
end

tw.human = human
return human
