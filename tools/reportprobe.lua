-- A filed report's last throw, replayed through the session exactly as the game played it
-- (session.restore of the report's `before` snapshot, then apply of its last action), with
-- the world watched step by step: for each piece named, its speed, its tilt from upright,
-- its height, every contact it had that step with the net normal impulse (world.onContact),
-- and the moment it was first struck. The report is private: pass its JSON (decompressed)
-- on the command line; nothing of it is written anywhere.
--
--   gzcat report.json.gz > /private/dir/r.json
--   lua5.4 tools/reportprobe.lua /private/dir/r.json --watch b2,b4 [--every 2] [--until 1.5]
--     [--set world.tune.x=v] [--engine DIR] [--drop id,id] (lying debris taken off the
--     pitch first: what the struck piece does without them) [--case T FILE] (every body
--     within a metre of the first watched piece, and the thrown baton, as they are at T s, in
--     tools/mjref's case format, written to FILE: the same moment for MuJoCo)
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
for k = 1, #arg - 1 do if arg[k] == "--engine" then sourceDir = arg[k + 1] end end
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end
import "session/session"
import "session/json"
local session, json = tw.web.session, tw.web.json
if session.useTune then session.useTune("pointer") end
local world = tw.world
local fmt, sqrt, deg, acos = string.format, math.sqrt, math.deg, math.acos

local path = assert(arg[1], "usage: reportprobe.lua <report.json> --watch id,id")
local watch, every, untilT, sets = {}, 2, 1.5, {}
local drop = nil
local caseT, caseOut, caseDone = nil, nil, false
local i = 2
while i <= #arg do
	local a, v = arg[i], arg[i + 1]
	if a == "--watch" then for id in v:gmatch("[^,]+") do watch[#watch + 1] = id end; i = i + 1
	elseif a == "--every" then every = tonumber(v); i = i + 1
	elseif a == "--until" then untilT = tonumber(v); i = i + 1
	elseif a == "--set" then sets[#sets + 1] = v; i = i + 1
	elseif a == "--engine" then i = i + 1
	elseif a == "--case" then caseT, caseOut = tonumber(v), arg[i + 2]; i = i + 2
	elseif a == "--drop" then drop = {}; for id in v:gmatch("[^,]+") do drop[id] = true end; i = i + 1
	else error("unknown option " .. a) end
	i = i + 1
end
for _, s in ipairs(sets) do
	local p, val = s:match("^([%w_%.]+)=(.+)$")
	local t = tw
	local keys = {}
	for k in p:gmatch("[^%.]+") do keys[#keys + 1] = k end
	for k = 1, #keys - 1 do t = t[keys[k]] end
	t[keys[#keys]] = tonumber(val)
end

local f = assert(io.open(path, "r"))
local doc = json.decode(f:read("a"))
f:close()
local r = doc.report or doc
local before = r.snapshots and r.snapshots.before
local a = r.lastThrow and r.lastThrow.action or r.last
assert(before and a, "the report has no `before` snapshot or last action")

if drop then
	-- take lying debris (batons and kubbs this turn knocked down) off the pitch
	local snap = json.decode(before)
	local d = snap.save and snap.save.debris
	if d and d.list then
		local keep = {}
		for _, e in ipairs(d.list) do if not drop[e.id] then keep[#keep + 1] = e end end
		d.list = keep
	end
	before = json.encode(snap)
end
local s = session.restore(before)
s:need()

local step0 = world.step
local W
local touched = {}
local per = {}
world.step = function(w)
	if W ~= w then
		W = w
		w.onContact = function(t, x, other, lnmax, ln)
			for _, id in ipairs(watch) do
				local me = (x and x.id == id) and x or ((other and other.id == id) and other or nil)
				if me then
					local o = (me == x) and other or x
					local key = id
					per[key] = per[key] or {}
					local on = o and o.id or "ground"
					per[key][on] = (per[key][on] or 0) + (ln or lnmax)
					if o and o.kind == "baton" and not touched[id] then touched[id] = t end
				end
			end
		end
	end
	for k in pairs(per) do per[k] = nil end
	step0(w)
	if caseT and w.time >= caseT and not caseDone then
		caseDone = true
		local c0
		for _, b in ipairs(w.bodies) do if b.id == watch[1] then c0 = b end end
		local bodies = {}
		for _, b in ipairs(w.bodies) do
			local near = (b.x - c0.x) ^ 2 + (b.y - c0.y) ^ 2 < 1
			if (near or b == w.projectile) and b.kind ~= "stake" then
				bodies[#bodies + 1] = { id = b.id, kind = b.kind, pos = { b.x, b.y, b.z }, quat = { b.qw, b.qx, b.qy, b.qz },
					vel = { b.vx, b.vy, b.vz }, angvel = { b.wx, b.wy, b.wz }, projectile = (b == w.projectile) or nil,
					resting = (not b.awake) or nil }
			end
		end
		local out = assert(io.open(caseOut, "w"))
		out:write(json.encode({ { id = "report-" .. watch[1], scen = "report", group = "report", params = {},
			surface = "grass", duration = 2.5, extra = { field = { watch[1] } }, bodies = bodies } }))
		out:close()
	end
	if (w.steps % every == 0) and w.time <= untilT then
		for _, id in ipairs(watch) do
			for _, b in ipairs(w.bodies) do
				if b.id == id and b.awake then
					local up = b.r33 < -1 and -1 or (b.r33 > 1 and 1 or b.r33)
					local parts = {}
					for on, ln in pairs(per[id] or {}) do parts[#parts + 1] = fmt("%s %.3f", on, ln) end
					table.sort(parts)
					print(fmt("t %.3f %s v %.2f (%+.2f %+.2f %+.2f) w %.1f tilt %.1f z %.4f  %s", w.time, id,
						sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz), b.vx, b.vy, b.vz,
						sqrt(b.wx * b.wx + b.wy * b.wy + b.wz * b.wz), deg(acos(up)), b.z, table.concat(parts, "  ")))
				end
			end
		end
	end
end
local rec = s:apply(a)
world.step = step0
print(fmt("the throw: %s; first struck by a baton: %s", rec and rec.ruling and rec.ruling.short or "?",
	(function() local o = {} for id, t in pairs(touched) do o[#o + 1] = fmt("%s at %.3f s", id, t) end return table.concat(o, ", ") end)()))
