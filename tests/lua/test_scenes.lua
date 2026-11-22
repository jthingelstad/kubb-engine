-- core/scenes (0.14): the catalogue a scene decides from, the Playdate's Black & White
-- options, and the Techno scene's floor, the grid surface (core/world): no texture,
-- a glide, a magnetic stop and a hold on a standing kubb, and still kubb.
import "core/scenes"
import "core/matchopts"
import "core/world"
import "core/flight"
local scenes, matchopts, world, flight = tw.scenes, tw.matchopts, tw.world, tw.flight

local function has(list, v)
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end

test("scenes: every entry is whole, its defaults among what it allows", function()
	expect.eq(#scenes.list, 7)
	for _, e in ipairs(scenes.list) do
		expect.truthy(type(e.name) == "string" and #e.name > 0, e.id .. " has a name")
		expect.truthy(has(e.surfaces, e.surface), e.id .. ": default surface allowed")
		expect.truthy(has(e.sets, e.set), e.id .. ": default set allowed")
		for _, k in ipairs(e.surfaces) do
			expect.truthy(world.surfaces[k] and has(scenes.SURFACES, k), e.id .. ": " .. k .. " is a world surface")
		end
		for _, k in ipairs(e.sets) do expect.truthy(has(scenes.SETS, k), e.id .. ": " .. k .. " is a set") end
		expect.eq(type(e.dark), "boolean"); expect.eq(type(e.ring), "boolean"); expect.eq(type(e.mono), "boolean")
	end
	for _, k in ipairs(scenes.SURFACES) do expect.truthy(has(world.SURFACES, k), k .. " offered by the world") end
	expect.eq(#scenes.SURFACES, #world.SURFACES)
end)

test("scenes: sweden and wisconsin are in no scene but still sets", function()
	for _, set in ipairs { "sweden", "wisconsin" } do
		expect.truthy(has(scenes.SETS, set))
		for _, e in ipairs(scenes.list) do expect.truthy(not has(e.sets, set), e.id .. " offers " .. set) end
	end
end)

test("scenes.resolve and choices: the scene decides; an unknown id is Park", function()
	local function r(...) return table.concat({ scenes.resolve(...) }, " ") end
	expect.eq(r("beach", "grass", "usa"), "beach sand classic")
	expect.eq(r("bw", "snow", nil), "bw snow classic")
	expect.eq(r("bw", "grid", nil), "bw grass classic")
	expect.eq(r("neon", nil, nil), "neon grid classic")
	expect.eq(r("tournament", "sand", "classic"), "tournament grass usa")
	expect.eq(r("minnesota", nil, nil), "minnesota snow minnesota")
	expect.eq(r("dusk", "snow", "usa"), "day grass classic")
	expect.eq(r(nil, "sand", nil), "day grass classic")
	expect.eq(table.concat(scenes.choices("bw"), ","), "surface")
	expect.eq(#scenes.choices("day"), 0)
	expect.eq(#scenes.choices("nope"), 0)
	expect.eq(scenes.known("neon"), true); expect.eq(scenes.known("dusk"), false); expect.eq(scenes.known(3), false)
end)

test("matchopts: the Playdate is Black & White; its Surface row is that scene's", function()
	local row = matchopts.list[1]
	expect.eq(row.key, "surface")
	expect.eq(table.concat(row.values, ","), "Grass,Sand,Snow")
	expect.eq(table.concat(row.shown, ","), "GRASS,SAND,SNOW")
	expect.eq(matchopts.apply({}, matchopts.defaults()).scene, "bw")
end)

-- ---------- the grid ----------

-- A baton thrown at a lone standing kubb from 5 m, on `surface` with ground seed `g`.
local function batonAt(surface, g, offset)
	local d = 5
	local w = world.new { surface = surface, stakes = false, groundSeed = g,
		pieces = { { id = "k", kind = "kubb", x = offset or 0, y = 1 + d } } }
	local h, fwd, _, _, tip = flight.handAt(d)
	local speed = flight.speedForCarry(d - 0.6, math.rad(30), h, tw.flight.tune.dragK.baton)
	local b = world.launchBaton(w, 0, 1, 0, 30, speed, 7, 3, "baton", h, fwd, tip)
	world.run(w)
	return w, b
end

test("grid: no texture, so the same throw does the same thing on any ground seed", function()
	local function rest(surface, g)
		local w, b = batonAt(surface, g, 0.06)
		return string.format("%.12f %.12f %.12f %s", b.x, b.y, w.byId.k.x, tostring(w.byId.k.toppled))
	end
	expect.eq(rest("grid", 1), rest("grid", 98765), "grid: ground seed changes nothing")
	local differs = false
	for g = 2, 6 do if rest("grass", 1) ~= rest("grass", g) then differs = true end end
	expect.truthy(differs, "grass: its patches vary")
end)

-- A lying piece set sliding along y at v m/s: how far it goes and how long it slides.
local function slide(surface, kind, v)
	local w = world.new { surface = surface, stakes = false }
	local qw, qx, qy, qz = tw.quat.fromAxisAngle(1, 0, 0, math.pi / 2) -- long axis along y
	if kind == "kubb" then qw, qx, qy, qz = tw.quat.fromAxisAngle(0, 1, 0, math.pi / 2) end -- across
	local z = kind == "kubb" and 0.035 or 0.022
	local b = world.launch(w, kind, "p", 0, 2, z + 0.0005, qw, qx, qy, qz, 0, v, 0, 0, 0, 0)
	local fastT, slowT = nil, nil
	while not world.isAtRest(w) and w.time < world.tune.maxTime do
		world.step(w)
		local s = math.sqrt(b.vx * b.vx + b.vy * b.vy)
		if not slowT and s < tw.world.surfaces[surface].texture.gripSpeed then slowT = w.time end
		if slowT and not fastT and s < 0.01 then fastT = w.time end
	end
	return b.y - 2, slowT and fastT and (fastT - slowT) or 0, math.abs(b.x)
end

test("grid: a landed piece glides straight and farther than on grass, then stops dead", function()
	for _, kind in ipairs { "baton", "kubb" } do
		local gd, gstop, gx = slide("grid", kind, 3)
		local sd = slide("grass", kind, 3)
		expect.truthy(gd > sd * 1.15, string.format("%s glides farther: grid %.2f m, grass %.2f m", kind, gd, sd))
		expect.truthy(gx < 0.01, string.format("%s straight: %.3f m aside", kind, gx))
		expect.truthy(gstop < 0.12, string.format("%s stops dead below gripSpeed: %.3f s", kind, gstop))
	end
end)

test("grid: still kubb: a shoved kubb falls, a good baton fells a kubb at 8 m", function()
	for _, v in ipairs { 1, 1.5, 2, 3 } do
		local w = world.new { surface = "grid", stakes = false, pieces = { { id = "k", kind = "kubb", x = 0, y = 4 } } }
		local k = w.byId.k
		world.wake(k)
		k.vy = v
		world.run(w)
		expect.truthy(k.toppled, "a kubb shoved at its centre at " .. v .. " m/s falls")
	end
	-- the base kubb from the baseline, a clean throw of the plan's
	local fell = 0
	for i = 1, 10 do
		local d = 8
		local w = world.new { surface = "grid", stakes = false, pieces = { { id = "k", kind = "kubb", x = 0, y = d } } }
		local h, fwd, _, _, tip = flight.handAt(d)
		local aimZ = tw.plan and tw.plan.aimZFor and tw.plan.aimZFor("baton", d) or 0.1
		local speed = flight.speedForCarry(d, math.rad(28 + i), h - aimZ, tw.flight.tune.dragK.baton)
		world.launchBaton(w, 0, 0, 0, 28 + i, speed, 7, 0, "baton", h, fwd, tip)
		world.run(w)
		if w.byId.k.toppled then fell = fell + 1 end
	end
	expect.truthy(fell >= 8, "a clean baton fells the 8 m kubb: " .. fell .. " of 10")
end)

test("grid: the hold settles a rocking kubb sooner and never holds one past its balance", function()
	-- a kubb set rocking about its foot's edge (a glancing touch), with and without the hold
	local function rock(hold, spin)
		local tex = world.surfaces.grid.texture
		local was = tex.hold
		tex.hold = hold
		local w = world.new { surface = "grid", stakes = false, pieces = { { id = "k", kind = "kubb", x = 0, y = 4 } } }
		local k = w.byId.k
		world.wake(k)
		k.wx = spin
		local last = 0
		while not world.isAtRest(w) and w.time < world.tune.maxTime do
			world.step(w)
			if math.sqrt(k.wx * k.wx + k.wy * k.wy) > 0.3 then last = w.time end
		end
		tex.hold = was
		return last, k.toppled, w.time
	end
	local base = world.surfaces.grid.texture.hold
	local t0 = rock(0, 15)
	local t1, down1 = rock(base, 15)
	expect.truthy(not down1, "a rock short of its balance stands")
	expect.truthy(t1 < t0, string.format("settles sooner: %.2f s against %.2f with no hold", t1, t0))
	-- a big one still falls, and comes to rest well inside the throw's time
	local _, down2, tEnd = rock(base, 20)
	expect.truthy(down2, "tipped past its balance it falls")
	expect.truthy(tEnd < 4, "at rest in " .. tEnd .. " s")
end)

test("the world's onGround hook: pieces that strike the ground, nothing when unset", function()
	local seen = {}
	local w = world.new { surface = "grid", stakes = false, pieces = { { id = "k", kind = "kubb", x = 0, y = 6 } } }
	w.onGround = function(t, b, impulse, x, y, speed)
		seen[#seen + 1] = { t = t, id = b.id, impulse = impulse, speed = speed }
	end
	local h, fwd, _, _, tip = flight.handAt(5)
	local speed = flight.speedForCarry(4.4, math.rad(30), h, tw.flight.tune.dragK.baton)
	world.launchBaton(w, 0, 1, 0, 30, speed, 7, 0, "baton", h, fwd, tip)
	world.run(w)
	expect.truthy(#seen > 0, "the baton struck the ground")
	for _, e in ipairs(seen) do
		expect.truthy(e.speed > world.tune.restitutionSpeed and e.impulse > 0, "a strike")
	end
end)
