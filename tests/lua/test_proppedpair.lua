-- A piece propped on another comes to rest (1.0): three contact faults that kept a
-- propped or edge-borne piece awake to the 12 s limit, found by the Gym gate with the seat
-- on (human pro, human club and human pro at seeds 1, 1 and 5). core/collide cornersInto:
-- a corner outside the other box, beside it past a face's edge, is at most touching, never
-- inside (b2 propped on a4 was kicked awake every few tenths of a second by a push for a
-- corner read 3.1 mm deep while it was 2.4 mm clear). capsuleBox: a projection that stops
-- just over the margin no longer drops the pair's other contacts, and a stretch end within
-- CLIP_GAP of the projected point is kept when it is the deeper (a kubb on its long edge
-- against a sleeping baton lost its prop by turns and its sleep reset each time).
import "core/world"
local world = tw.world
local P = dofile("tests/fixtures/contact/propped-pair.lua")

test("a kubb propped on a lying kubb comes to rest", function()
	local pieces = {}
	for i, p in ipairs(P) do
		pieces[i] = { id = p.id, kind = p.kind, x = p.x, y = p.y, z = p.z, qw = p.qw, qx = p.qx, qy = p.qy, qz = p.qz,
			toppled = p.toppled }
	end
	local w = world.new { surface = "grass", pieces = pieces, groundSeed = 1 }
	for _, p in ipairs(P) do if p.awake then world.wake(w.byId[p.id]) end end
	local x0, y0 = w.byId.b2.x, w.byId.b2.y
	world.run(w)
	expect.truthy(world.isAtRest(w) and w.time < 2, string.format("at rest at %.2f s", w.time))
	local b2 = w.byId.b2
	expect.truthy((b2.x - x0) ^ 2 + (b2.y - y0) ^ 2 < 0.001 ^ 2, "b2 stays where it was propped")
	expect.truthy(b2.toppled and w.byId.a4.toppled, "both down")
end)

-- A kubb lying on a long edge against a sleeping baton (core/collide capsuleBox, 1.0): the
-- Gym gate's unsettled throw at 20:332 (human club, seed 1). The closest pair the
-- projection finds is 2.19 mm apart, just over the step's 2.18 mm margin, while the
-- stretch's end at the face's edge is 0.56 mm in. Before 1.0 the miss dropped every
-- contact of the pair, one step in four, and the kubb's sleep reset on that step (it was
-- held by the ground alone on an edge): the throw ran to the 12 s limit.
test("a baton's contact with a box is kept when the projection stops just over the margin", function()
	local collide = tw.collide
	local w = world.new { surface = "grass", stakes = false, pieces = {
		{ id = "baton3", kind = "baton", x = 1.7865550148259886, y = 5.0275199562256114, z = 0.021744798412828181,
			qw = -0.47931204437094099, qx = -0.35366041847809898, qy = -0.6114947189473392, qz = 0.52082480857036706 },
		{ id = "a3", kind = "kubb", x = 1.8663957607264363, y = 4.9662568641428431, z = 0.047702764073636078,
			qw = 0.25122804953541156, qx = -0.42846552737069415, qy = 0.56250880617675325, qz = 0.66097322332692854,
			toppled = true },
	} }
	collide.reset()
	collide.capsuleBox(w.byId.baton3, w.byId.a3, 0.0021821798312352705)
	local C, deepest = collide.C, 1
	for i = 1, C.n do if C.sep[i] < deepest then deepest = C.sep[i] end end
	expect.truthy(C.n >= 1, "a contact")
	expect.truthy(deepest < -0.0004, string.format("the edge's end, inside: %.5f", deepest))
end)

-- And when the stretch's end lies within CLIP_GAP of the projected point (the Gym gate's
-- unsettled throw at 22:400 of seed 5, human pro): the end, 0.54 mm in, is 1.7 mm deeper
-- than the projected point and carries the kubb; before 1.0 it was dropped on the steps
-- its end fell inside t - CLIP_GAP, so the kubb on its long edge lost its prop by turns.
test("a stretch end near the projected point is kept when it is the deeper", function()
	local collide = tw.collide
	local w = world.new { surface = "grass", stakes = false, pieces = {
		{ id = "baton3", kind = "baton", x = 1.7442783017531773, y = 5.6653874682065464, z = 0.021996662302377453,
			qw = -0.37129591185026645, qx = -0.44482304559525265, qy = -0.54965642048680985, qz = 0.60178868664031115 },
		{ id = "a2", kind = "kubb", x = 1.8076709056271483, y = 5.6207385368992542, z = 0.049030642323045839,
			qw = -0.66289866341490578, qx = 0.62721440427840469, qy = 0.32550080232536638, qz = 0.24742004929665729,
			toppled = true },
	} }
	collide.reset()
	collide.capsuleBox(w.byId.baton3, w.byId.a2, 0.0021748589826670354)
	local C, deepest = collide.C, 1
	for i = 1, C.n do if C.sep[i] < deepest then deepest = C.sep[i] end end
	expect.truthy(deepest < -0.0004, string.format("the load-bearing end: %.5f", deepest))
end)
