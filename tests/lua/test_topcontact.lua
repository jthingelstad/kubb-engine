-- A baton on a standing kubb's top (docs/notes/physics.md, "A baton on a kubb's
-- top"). A play-test match: a clean throw at 6.89 m/s set its lower end on a
-- kubb's top face, the kubb stood and the baton went on at 4.55 m/s, rising.
-- Upright, tumbling and planted on the top, a baton presses the kubb down
-- through its own footprint, which no friction or bounce can tip; it vaults
-- over its planted end. The same baton 6 cm lower meets the face and fells it.
import "core/world"
local world = tw.world

-- A kubb's seat (world.seat, on from 1.0.0) leans a kubb set down plumb by up to its
-- surface's seat. This test pins a baton planted on a level top (a play-test throw, the
-- kubb plumb); on a top tipped by the seat the baton vaulted 0.09 m, under the test's
-- line, so it runs with the seat off (seatOn 0, as before 1.0); the seat itself is
-- tests/lua/test_seat.lua's.
local function plumb(fn)
	return function()
		local saved = tw.world.tune.seatOn
		tw.world.tune.seatOn = 0
		local ok, err = pcall(fn)
		tw.world.tune.seatOn = saved
		if not ok then error(err, 0) end
	end
end
local HL = tw.body.kinds.baton.hl

-- an upright baton tumbling forward at 34 rad/s and 6.6 m/s, its lower end
-- `low` metres under a kubb's top as its leading side reaches the kubb's near
-- face (`inset` past it), the centre falling at vz
local function throw(low, inset, vz)
	local w = world.new { surface = "grass", stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0, y = 1, yaw = 0 } } }
	local k = w.byId.k
	local z = 0.15 + HL + 0.026 - low
	local b = world.launch(w, "baton", "b", 0, 1 - 0.065 + inset, z, 1, 0, 0, 0, 0, 6.6, vz, -34, 0, 0)
	w.projectile = b
	local z0, top
	local stop = world.tune.maxTime
	while not world.isAtRest(w) and w.time < stop do
		world.step(w)
		if k.touchT and not z0 then z0 = b.z; top = z0 end
		if z0 and b.z > top then top = b.z end
	end
	return k, z0 and top - z0
end

test("a baton planted on a kubb's top vaults over it; lower, it fells it", plumb(function()
	local k, rise = throw(0, 0.02, -1.0)
	expect.truthy(rise, "the baton touched the kubb")
	expect.truthy(not k.toppled, "planted on the top: the kubb stands")
	expect.truthy(rise > 0.1, string.format("planted on the top: the baton vaults (%.2f m)", rise))
	for _, c in ipairs { { 0.01, -0.5 }, { 0.02, -1.0 }, { 0, 0.5 } } do
		local k2 = throw(0.06, c[1], c[2])
		expect.truthy(k2.toppled, string.format("6 cm lower (inset %.2f, vz %.1f): down", c[1], c[2]))
	end
end))
