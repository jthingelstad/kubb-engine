-- Kubb on kubb (0.18, docs/notes/physics.md "A blow passed down a column"): the columns
-- and piles of tests/fixtures/contact/columns.lua run in core/world, as tools/mjref's
-- `--cases column` runs them in both engines, on the flat ground MuJoCo can model ("mech":
-- no texture, dig or bite) or the game's grass (--game). Prints, per layout and strike,
-- the kubbs toppled (of all thrown at it) and each kubb's share of the throws that
-- toppled it, front first. A measuring tool: it changes nothing in the engine.
--
--   lua5.4 tools/columnprobe.lua [--only col6-0.002] [--kind baton|push|pile] [--game]
--     [--set world.tune.pairMu=0.2]  (any number in tw.*)
--     [--trace <case id>]  (one case step by step: every kubb's speed along the throw,
--     its turn, and the normal impulse (N s) of every pair that pressed, per step)
--     [--steps 80] [--z] (with each body's height and vertical speed)
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end
import "core/tw"
import "core/world"
import "core/collide"
import "core/flight"
import "core/drill"
import "core/throwplan"
local world, body = tw.world, tw.body
local fmt = string.format
local cases = dofile(here .. "/mjref/cases.lua")
local C = dofile(sourceDir .. "/tests/fixtures/contact/columns.lua")

local only, kindOnly, game, trace, steps = nil, nil, false, nil, 80
local showZ = false
local sets = {}
local i = 1
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--only" then only = v; i = i + 1
	elseif a == "--kind" then kindOnly = v; i = i + 1
	elseif a == "--game" then game = true
	elseif a == "--trace" then trace = v; i = i + 1
	elseif a == "--steps" then steps = tonumber(v); i = i + 1
	elseif a == "--z" then showZ = true
	elseif a == "--set" then sets[#sets + 1] = v; i = i + 1
	else error("unknown option " .. a) end
	i = i + 1
end
for _, s in ipairs(sets) do
	local path, val = s:match("^([%w_%.]+)=(.+)$")
	local keys = {}
	for k in path:gmatch("[^%.]+") do keys[#keys + 1] = k end
	local t = tw
	for k = 1, #keys - 1 do t = t[keys[k]] end
	assert(type(t[keys[#keys]]) == "number", path)
	t[keys[#keys]] = tonumber(val)
end

local function surface()
	local s = world.surfaces.grass
	if game then return s end
	local flat = {}
	for k, v in pairs(s) do flat[k] = v end
	flat.texture, flat.dig, flat.bite = nil, 0, 0
	return flat
end

-- one case in core/world (as tools/mjref/ours.lua runs it); returns the world and bodies
local function setup(c)
	local w = world.new { surface = surface(), stakes = false, groundSeed = 1 }
	local bodies = {}
	for _, d in ipairs(c.bodies) do
		local p, q, v, a = d.pos, d.quat, d.vel, d.angvel
		local b
		if d.projectile then
			b = world.launch(w, d.kind, d.id, p[1], p[2], p[3], q[1], q[2], q[3], q[4], v[1], v[2], v[3], a[1], a[2], a[3])
		else
			b = world.addPiece(w, { id = d.id, kind = d.kind, x = p[1], y = p[2], z = p[3],
				qw = q[1], qx = q[2], qy = q[3], qz = q[4] })
			if not d.resting then
				body.setVelocity(b, v[1], v[2], v[3], a[1], a[2], a[3])
				world.wake(b)
			end
		end
		bodies[#bodies + 1] = b
	end
	return w, bodies
end

local function run(c)
	local w = setup(c)
	local n = math.floor(c.duration / world.tune.dt + 0.5)
	for _ = 1, n do
		world.step(w)
		if world.isAtRest(w) then break end
	end
	local r = world.result(w)
	local down = {}
	for _, id in ipairs(r.toppled) do down[id] = true end
	return down
end

local list = cases.columnFrom(C)

if trace then
	local c
	for _, x in ipairs(list) do if x.id == trace then c = x end end
	assert(c, "no case " .. trace)
	local w, bodies = setup(c)
	local idx = {}
	for k, b in ipairs(bodies) do idx[b] = k end
	local P = {}
	w.onContact = function(_, a, b, ln)
		if not b then return end
		local ka, kb = idx[a], idx[b]
		if ka > kb then ka, kb = kb, ka end
		local key = bodies[ka].id .. "-" .. bodies[kb].id
		P[key] = (P[key] or 0) + ln
	end
	print(fmt("%s: per step, each body's vy (m/s) and wx (rad/s), then the pairs' normal impulse (N s)", c.id))
	for s = 1, steps do
		for k in pairs(P) do P[k] = nil end
		world.step(w)
		local line = { fmt("%3d", s) }
		for _, b in ipairs(bodies) do
			line[#line + 1] = fmt("%s %+5.2f %+6.1f", b.id, b.vy, b.wx)
			if showZ then line[#line + 1] = fmt("z %.4f vz %+.2f", b.z, b.vz) end
		end
		local keys = {}
		for k in pairs(P) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do line[#line + 1] = fmt("%s %.3f", k, P[k]) end
		print(table.concat(line, "  "))
	end
	return
end

local groups, order = {}, {}
local fam, famOrder = {}, {}
for _, c in ipairs(list) do
	if (not only or c.extra.layout == only or c.id:sub(1, #only) == only)
		and (not kindOnly or c.extra.kind == kindOnly) then
		local down = run(c)
		local g = groups[c.group]
		if not g then
			g = { n = 0, down = 0, by = {}, size = #c.extra.field }
			groups[c.group] = g
			order[#order + 1] = c.group
		end
		g.n = g.n + 1
		local fname = c.extra.layout:match("^(col%d)") or c.extra.layout
		fname = fname .. " " .. c.extra.kind
		local f = fam[fname]
		if not f then f = { down = 0, of = 0 }; fam[fname] = f; famOrder[#famOrder + 1] = fname end
		f.of = f.of + #c.extra.field
		for k, id in ipairs(c.extra.field) do
			if down[id] then
				f.down = f.down + 1
				g.down = g.down + 1
				g.by[k] = (g.by[k] or 0) + 1
			end
		end
	end
end
print(fmt("columnprobe: kubb on kubb, %s ground", game and "the game's grass" or "flat (mech)"))
print(fmt("%-28s %3s  %9s  %s", "layout and strike", "n", "toppled", "each kubb, front first"))
for _, name in ipairs(order) do
	local g = groups[name]
	local by = {}
	for k = 1, g.size do by[k] = fmt("%3.0f", 100 * (g.by[k] or 0) / g.n) end
	print(fmt("%-28s %3d  %3d / %3d  %s", name, g.n, g.down, g.n * g.size, table.concat(by, " ")))
end
print()
print("by family (toppled share)")
table.sort(famOrder)
for _, name in ipairs(famOrder) do
	local f = fam[name]
	print(fmt("%-28s %3.0f%%  (%d / %d)", name, 100 * f.down / f.of, f.down, f.of))
end
