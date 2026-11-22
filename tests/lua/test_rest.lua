-- Where a box may come to rest (world.step, phase 8; docs/notes/physics.md
-- "Rest on a face"). A box held up by the ground alone rests only on a face;
-- a box propped on another piece may rest tilted (the leaner rule decides
-- whether it is down).
import "core/world"
import "core/quat"
import "core/drill"
import "core/throwplan"
local world, quat, body, drill = tw.world, tw.quat, tw.body, tw.drill

-- a kubb lying with its long axis along x, rolled about it by `roll` degrees
-- (0 and 90 on a long face, 45 balanced on a long edge)
local function lyingRolled(roll)
	local a1, b1, c1, d1 = quat.fromAxisAngle(0, 1, 0, math.pi / 2)
	local a2, b2, c2, d2 = quat.fromAxisAngle(1, 0, 0, math.rad(roll))
	return quat.mul(a2, b2, c2, d2, a1, b1, c1, d1)
end

-- A play-test match: the second kubb of an inkast came to rest free-standing
-- on a long edge, rolled 44 degrees, its centre at the section's
-- half-diagonal (4.95 cm), nothing within 0.4 m. Set down a few degrees off
-- that balance and sliding a little, it rolled up to the edge and slept there
-- (grass at 49, sand at 47 and 48, snow at 50): the slow, held-by-the-turf
-- spin passed the sleep test with its centre over the edge.
test("a kubb set down near its long edge's balance rolls onto a face", function()
	for _, c in ipairs { { "grass", 49 }, { "grass", 44.4 }, { "sand", 47 }, { "sand", 48 }, { "snow", 50 }, { "grid", 49 }, { "grid", 44.4 } } do
		local surf, roll = c[1], c[2]
		local w = world.new { surface = surf }
		local qw, qx, qy, qz = lyingRolled(roll)
		local r = math.rad(roll)
		local z = 0.035 * (math.cos(r) + math.sin(r)) + 0.001
		local b = world.launch(w, "kubb", "k", 0.5, 6, z, qw, qx, qy, qz, 0.05, 0.1, 0, 0, 0, 0)
		world.run(w)
		local what = string.format("%s at %.1f degrees", surf, roll)
		expect.truthy(not b.awake, what .. ": it sleeps before the throw runs out")
		expect.truthy(world.boxFlat(b, world.tune.flatTol), what .. string.format(": on a face (z %.4f)", b.z))
		expect.truthy(b.z < 0.0355, what .. string.format(": centre a half width up (%.4f)", b.z))
		expect.truthy(b.toppled, what .. ": down")
	end
end)

-- Drilled kubbs into an empty half on every surface, jittered in aim, loft,
-- power, wrist and spin (the swing's own release scatter on top): none rests
-- free on an edge or a corner, and none is still moving when the throw runs
-- out. Before the fix 1 in 140 on grass, 1 in 13 on sand, 1 in 60 on snow.
test("no drilled kubb rests free on an edge or a corner", function()
	local s = 12345
	local function u() s = (s * 48271) % 2147483647; return (s - 1) / 2147483646 end
	local n = 0
	for _, surf in ipairs(world.SURFACES) do
		for i = 1, 400 do
			local mx, my = (u() - 0.5) * 3, 4.6 + u() * 3
			local sol = drill.solveAt(mx, my, 0, 30 + u() * 20, {}, nil, surf)
			local L = drill.body(0.6 + 0.4 * u(), u() < 0.5 and -1 or 1, (u() - 0.5) * 20, {})
			local w = world.new { surface = surf, stakes = false }
			local b = world.launchDrill(w, "d", sol.x, 0, sol.swivel + (u() - 0.5) * 0.02, sol.loft,
				sol.speed * (0.95 + 0.1 * u()), L.noseDown, L.rollLand, L.spin, L.wobble)
			world.run(w)
			n = n + 1
			local what = string.format("%s drill %d", surf, i)
			expect.truthy(w.time < world.tune.maxTime, what .. ": still moving at the end")
			expect.truthy(world.boxFlat(b, world.tune.flatTol),
				what .. string.format(": rests on an edge or a corner (z %.4f, r33 %.3f)", b.z, b.r33))
		end
	end
	expect.eq(n, 400 * #world.SURFACES)
end)

-- Leaners keep their rest: a kubb lying with one end up on a lying kubb, a
-- kubb leaning on a stake and a kubb leaning on a baton all sleep tilted.
test("a kubb propped on a kubb, a stake or a baton still rests tilted", function()
	-- one end on a lying kubb
	local a1, b1, c1, d1 = quat.fromAxisAngle(0, 1, 0, math.pi / 2)
	local w = world.new { texture = false, stakes = false, pieces = {
		{ id = "lo", kind = "kubb", x = 0, y = 0, qw = a1, qx = b1, qy = c1, qz = d1, z = 0.035 },
	} }
	-- across it, its near end over the lower kubb and its far end past it
	local cw, cx, cy, cz = quat.fromAxisAngle(1, 0, 0, math.pi / 2)
	local hi = world.launch(w, "kubb", "hi", 0, 0.09, 0.11, cw, cx, cy, cz, 0, 0, 0, 0, 0, 0)
	world.run(w)
	expect.truthy(not hi.awake, "on a kubb: asleep")
	expect.truthy(not world.boxFlat(hi, world.tune.flatTol), string.format("on a kubb: tilted (r33 %.3f)", hi.r33))
	expect.truthy(hi.z > 0.045, string.format("on a kubb: one end up (z %.3f)", hi.z))

	-- leaning on a stake: a standing kubb tipped onto the corner stake
	local w2 = world.new { texture = false }
	local st = w2.byId.stake1
	local lean = math.rad(35)
	local lw, lx, ly, lz = quat.fromAxisAngle(1, 0, 0, -lean)
	-- its foot 6 cm from the stake's axis, leaning toward it (+y)
	local k = world.launch(w2, "kubb", "k", st.x, st.y - 0.10, 0.0001 + 0.075 * math.cos(lean) + 0.035 * math.sin(lean),
		lw, lx, ly, lz, 0, 0, 0, 0, 0, 0)
	world.run(w2)
	expect.truthy(not k.awake, "on a stake: asleep")
	expect.truthy(not world.boxFlat(k, world.tune.flatTol), string.format("on a stake: tilted (r33 %.3f)", k.r33))
	expect.truthy(k.toppled and body.wouldFall(k), "on a stake: down by the leaner rule")

	-- leaning on a baton lying on the ground
	local bw, bx, by, bz = quat.fromAxisAngle(0, 1, 0, math.pi / 2)
	local w3 = world.new { texture = false, stakes = false }
	local bat = world.launch(w3, "baton", "b", 0, 0.12, 0.022, bw, bx, by, bz, 0, 0, 0, 0, 0, 0)
	local k3 = world.launch(w3, "kubb", "k", 0, 0, 0.0001 + 0.075 * math.cos(lean) + 0.035 * math.sin(lean),
		lw, lx, ly, lz, 0, 0, 0, 0, 0, 0)
	world.run(w3)
	expect.truthy(not k3.awake and not bat.awake, "on a baton: asleep")
	expect.truthy(not world.boxFlat(k3, world.tune.flatTol), string.format("on a baton: tilted (r33 %.3f)", k3.r33))
end)
