-- A baton resting on other pieces feels their rolling resistance (world.tune.pairRoll;
-- docs/notes/physics.md, "A baton rocking in a groove"): from the first step since 1.0
-- (0.18.0 applied it only from 4 s into a throw, pairRollAfter). A baton set across the
-- groove of two lying batons, rolling along it, stops in a fraction of a second; without
-- the term it rolls for seconds (and on 0.18.0, held by nothing until 4 s, it rested at
-- 3.4 s and 4.2 s for these two).
import "core/world"
import "core/quat"
local world, quat, body = tw.world, tw.quat, tw.body

local function across(spin, pairRoll)
	local saved = world.tune.pairRoll
	world.tune.pairRoll = pairRoll or saved
	local w = world.new { surface = "grass", stakes = false }
	local r = body.kinds.baton.r
	local qw, qx, qy, qz = quat.fromAxisAngle(0, 1, 0, math.pi / 2)
	for i, sy in ipairs { -1, 1 } do
		local b = world.addBody(w, "baton", "l" .. i)
		body.setPose(b, 0, 5 + sy * r, r, qw, qx, qy, qz)
		body.setVelocity(b, 0, 0, 0, 0, 0, 0)
	end
	local a, b, c, d = quat.fromAxisAngle(1, 0, 0, math.pi / 2)
	local z = r + math.sqrt(3) * r + 0.0005
	world.launch(w, "baton", "t", 0, 5, z, a, b, c, d, 0, 0, 0, 0, spin, 0)
	world.run(w)
	world.tune.pairRoll = saved
	return w.time, world.isAtRest(w)
end

test("a baton rolling in the groove of two lying batons stops from the first step", function()
	expect.eq(world.tune.pairRollAfter, nil, "no late start (0.18.0's 4 s)")
	for _, spin in ipairs { 3, 6 } do
		local t, rest = across(spin)
		expect.truthy(rest and t < 1, string.format("spin %d: at rest at %.2f s", spin, t))
		local t0 = across(spin, 0)
		expect.truthy(t0 > 3, string.format("spin %d: without pairRoll it rolls to %.2f s", spin, t0))
	end
end)
