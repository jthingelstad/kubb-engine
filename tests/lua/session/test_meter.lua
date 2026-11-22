-- The person's meter in the session (0.13; docs/SESSION.md "Levels"): a person's throw
-- is planned and launched on one meter whatever level the session, the player or
-- setLevel names, and the bars the session draws (the plan's powerLo..powerHi and
-- releaseLo..releaseHi) change with the throw's distance when the aim moves.
import "session/session"
import "session/json"
tw.web.session.useTune("pointer")
local session, throw, plan = tw.web.session, tw.web.throw, tw.plan

local SWINGS = {
	{ dBack = 0, dRel = 0, flickFrac = 1, shake = 0, pull = 1 },
	{ dBack = 3, dRel = -9, flickFrac = 0.93, shake = 0.12, pull = -1 },
	{ dBack = -14, dRel = 25, flickFrac = 1, shake = 0.5, pull = 1 },
}

local function launches(s)
	local ts, out = s.ts, {}
	ts.nerves = true
	for i, w in ipairs(SWINGS) do
		local r = { back = ts.sol.back + w.dBack, releaseAngle = ts.sol.release + w.dRel, flickFrac = w.flickFrac,
			shake = w.shake, smoothness = 1 - w.shake, pull = w.pull, how = "stopped" }
		out[i] = throw.playerLaunch(ts, r)
	end
	return out
end

test("a person's launch is the same whatever level is set", function()
	for _, projectile in ipairs { "baton", "kubb" } do
		local base
		for _, level in ipairs { "beginner", "club", "pro", "nonsense" } do
			local s = session.new { mode = "practice", level = level }
			if projectile == "kubb" then s:setDrill(true) end
			s:setTarget(0.6, 7.2, false)
			s:setLevel(level)
			expect.eq(s.ts.projectile, projectile)
			local got = launches(s)
			if not base then base = got else
				for i, L in ipairs(got) do
					for _, k in ipairs { "speed", "loft", "swivel", "tilt", "tumble", "scatter", "powerV", "releaseV", "sideV" } do
						expect.eq(L[k], base[i][k], projectile .. " " .. level .. " swing " .. i .. " " .. k)
					end
				end
			end
			expect.eq(s.ts.sol.level.meter, plan.meter(), "planned on the person's meter")
		end
	end
end)

test("the bars narrow as the aim moves out, and the view carries them", function()
	local s = session.new { mode = "practice" }
	local last
	for _, y in ipairs { 4, 5.5, 7, 8.5 } do
		local p = s:setTarget(0, y, false).aim.plan
		local w = p.powerHi - p.powerLo
		expect.eq(p.powerLo, s.ts.sol.powerLo); expect.eq(p.releaseHi, s.ts.sol.releaseHi)
		if last then
			-- (0.17.0: the power bar is also held by the throw's speed, plan.meters powerSpeed,
			-- so only the release bar narrows with the distance alone; the power bar is never
			-- wider than the distance's)
			expect.truthy(p.releaseHi - p.releaseLo < last.r, "narrower at " .. y .. " m")
			expect.truthy(w <= 2 * plan.meterLevel(plan.meter(), s.ts.sol.dist, "baton").powerHalf + 1e-12, "power within the distance's")
		end
		last = { w = w, r = p.releaseHi - p.releaseLo }
	end
end)
