import "session/session"
import "session/json"
local session, json = tw.web.session, tw.web.json
session.useTune("pointer")
local function shot(exercise, points, separate)
	local game = session.new { mode = "practice", exercise = exercise }
	if not separate then return game:frame { stroke = points }, game end
	local result
	for _, p in ipairs(points) do
		result = game:frame { stroke = { p }, dt = 1/120 }
		if result.event then break end
		game:frame { dt = 0.1 }
	end
	return result, game
end

local down = { phase = "down", x = 0, y = 0 }
local back = { x = 0, y = 2/3 }
test("straight throw takes power from the draw, line at crossing, loft from plan", function()
	local center = shot("base", { down, back, { x = 0, y = 0 } })
	local far = shot("base", { down, back, { x = 0, y = -3 } }, true)
	expect.eq(json.encode(center.action), json.encode(far.action))
	expect.eq(center.action.swing.back, 120)
	expect.eq(center.action.launch.loft, 32)
	expect.eq(center.action.input, "straight")
	local left = shot("base", { down, back, { x = -0.4, y = -2/3 } })
	local right = shot("base", { down, back, { x = 0.4, y = -2/3 } })
	expect.truthy(left.action.launch.swivel < center.action.launch.swivel)
	expect.truthy(right.action.launch.swivel > center.action.launch.swivel)
	expect.eq(left.action.launch.speed, right.action.launch.speed)
end)
test("early lift, cancellation and a forward-only gesture spend no throw", function()
	for _, points in ipairs {
		{ down, back, { phase = "up", x = 0, y = 0.2 } },
		{ down, back, { phase = "cancel" } },
		{ down, { phase = "up", x = 0, y = -2 } },
	} do
		local out, game = shot("base", points)
		expect.eq(out.event, "letdown")
		expect.eq(game.throws, 0)
	end
end)
test("all three exercises produce replayable physical throws", function()
	for _, kind in ipairs { "base", "pair", "pile" } do
		local s = session.new {mode = "practice", exercise = kind}
		local ts = s.ts
		expect.eq(#ts.items, kind == "pair" and 2 or 1)
		local out = s:frame {stroke = {down, {x = 0, y = ts.sol.back / 180}, {x = 0, y = -1}}}
		expect.eq(out.action.how, kind == "pile" and "drill" or "baton")
		local restored = session.restorePractice(s.practiceBefore)
		local replicated = restored:apply(out.action)
		expect.eq(json.encode(replicated.recording.bodies), json.encode(out.recording.bodies))
	end
end)
