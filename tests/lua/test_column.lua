-- Kubb on kubb (0.18 study, docs/notes/physics.md "A blow down a column"): the column of
-- six 2 mm apart and the piles of tests/fixtures/contact/columns.lua, on the flat ground
-- the reference engine models, pinned where our engine stands, each beside MuJoCo's band
-- over its five solver variants (tools/mjref `--cases column`, tools/mjref/column.py,
-- 2026-11-22). The column of six struck by a baton is the one place ours stands outside
-- the band, below it; this pins that, so a change to the contacts that moves it shows
-- here first. Counts are kubbs toppled of all thrown at.
import "core/world"
import "core/flight"
import "core/drill"
import "core/throwplan"
local world, body = tw.world, tw.body
local cases = dofile("tools/mjref/cases.lua")
local C = dofile("tests/fixtures/contact/columns.lua")
local LIST = cases.columnFrom(C)

local function flat()
	local s = {}
	for k, v in pairs(world.surfaces.grass) do s[k] = v end
	s.texture, s.dig, s.bite = nil, 0, 0
	return s
end

-- kubbs toppled over every case of one layout and kind of strike
local function toppled(layout, kind, low)
	local down, of = 0, 0
	for _, c in ipairs(LIST) do
		if c.extra.layout == layout and c.extra.kind == kind and (not low or c.params.low == low) then
			local w = world.new { surface = flat(), stakes = false, groundSeed = 1 }
			for _, d in ipairs(c.bodies) do
				local p, q, v, a = d.pos, d.quat, d.vel, d.angvel
				if d.projectile then
					world.launch(w, d.kind, d.id, p[1], p[2], p[3], q[1], q[2], q[3], q[4], v[1], v[2], v[3], a[1], a[2], a[3])
				else
					local b = world.addPiece(w, { id = d.id, kind = d.kind, x = p[1], y = p[2], z = p[3],
						qw = q[1], qx = q[2], qy = q[3], qz = q[4] })
					if not d.resting then
						body.setVelocity(b, v[1], v[2], v[3], a[1], a[2], a[3])
						world.wake(b)
					end
				end
			end
			world.run(w, c.duration)
			local r = world.result(w)
			local set = {}
			for _, id in ipairs(r.toppled) do set[id] = true end
			for _, id in ipairs(c.extra.field) do
				of = of + 1
				if set[id] then down = down + 1 end
			end
		end
	end
	return down, of
end

local function within(name, down, of, lo, hi, band)
	expect.truthy(down >= lo and down <= hi, string.format("%s: %d of %d toppled, pinned %d to %d (MuJoCo %s)",
		name, down, of, lo, hi, band))
end

test("column: six kubbs 2 mm apart struck by a baton, below MuJoCo's band (pinned)", function()
	local down, of = toppled("col6-0.002", "baton")
	expect.eq(of, 108)
	-- ours 13 (12%); MuJoCo 35 to 66 (32 to 61%; its stiffest contact 41, 38%)
	within("col6-0.002 baton", down, of, 7, 20, "35 to 66")
end)

test("column: the same column pushed by its front kubb, no baton, inside MuJoCo's band", function()
	local down, of = toppled("col6-0.002", "push")
	expect.eq(of, 54)
	-- ours 2 (4%); MuJoCo 0 to 3 (0 to 6%)
	within("col6-0.002 push", down, of, 0, 5, "0 to 3")
end)

test("column: piles a throw-in leaves, at or over MuJoCo's band", function()
	-- ours / MuJoCo's band: block2x3 44 / 40 to 42 of 72, pile7 50 / 38 to 47 of 84,
	-- wedge5 60 / 58 to 60 of 60
	local d, of = toppled("block2x3", "pile")
	within("block2x3", d, of, 38, 50, "40 to 42")
	d, of = toppled("pile7", "pile")
	within("pile7", d, of, 42, 58, "38 to 47")
	d, of = toppled("wedge5", "pile")
	within("wedge5", d, of, 54, 60, "58 to 60")
end)
