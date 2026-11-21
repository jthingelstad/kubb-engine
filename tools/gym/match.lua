-- The Kubb Gym's match worker (docs/notes/gym.md): plays seeded matches with real
-- physics, as tools/physmatch.lua does, thrown by the computer
-- (core/autothrow) or by the human thrower (tools/gym/human.lua), with
-- forensics on every throw (tools/gym/forensics.lua). Writes each game file
-- (for kubb.js's counting) and one line of JSON per throw. tools/gym.mjs runs
-- several of these in parallel and reads what they write. A measuring tool:
-- nothing in the engine changes.
--
--   lua5.4 tools/gym/match.lua --out DIR [--thrower cpu|human] [--level club]
--     [--surface Grass] [--seed 1] [--from 1] [--to 10] [--maxturns 40]
--     [--model tools/gym/human-model.json] [--scatter 1] [--set path=value ...]
--   lua5.4 tools/gym/match.lua ... --repro <match>:<throw> [--dump file] [--every 1]
--   lua5.4 tools/gym/match.lua --selftest [--to 3]
--   (any of them) --engine DIR   the engine's Lua from DIR instead of this checkout
--   versus (two teams that play differently; tools/gym/versus.lua):
--   lua5.4 tools/gym/match.lua --a SPEC --b SPEC --swap 0|1 ... [--probe]
--     SPEC: "level=pro;thrower=cpu;raise=apart;path=value...". --swap 0 puts team A on
--     side A and team B on side B, --swap 1 the other way round; the side that opens and
--     the random stream are the match's either way, so a seed's two games differ only in
--     which team plays which side. --probe plays the matches without forensics and prints
--     how often each team's tune settings were read while that team acted (JSON).
--
-- Match i of seed s is the same match whichever worker plays it: its stream is
-- autothrow.rng(s * 7919 + i) and its teams are physmatch's (Team A (i - 1) % 6 + 1
-- players, Team B (i + 1) % 6 + 1), so the computer's matches are physmatch's to the bit.
-- --set path=value sets a number in the engine's tune tables before the first throw,
-- by its path from tw (plan.tune.aimHeightShare=0.4, world.tune.dt=0.002,
-- autothrow.tune.swingScale.pro=1.2, plan.levels.pro.nervesDeg=0.4: a level's nerves
-- and tumble go to the computer's level table too). --repro plays match <match> up to
-- throw <throw> (counted from 1 over the whole match) and prints that throw in full;
-- --dump writes every body's state every --every steps (as physfuzz --dump).
-- --selftest throws each throw of a few matches with and without forensics and checks
-- that every body ends bit for bit the same.

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/../.."
-- --engine DIR: the engine (core, session, version) from another tree, the tools from
-- this one (tools/gym.mjs compare runs a git ref's engine this way)
for k = 1, #arg - 1 do if arg[k] == "--engine" then sourceDir = arg[k + 1] end end
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end

import "core/match"
import "core/world"
import "core/autothrow"
import "core/notation"
import "core/order"
import "version"
local match, world, autothrow, notation, order, plan = tw.match, tw.world, tw.autothrow, tw.notation, tw.order, tw.plan
local forensics = dofile(here .. "/forensics.lua")
local fmt, sqrt, floor = string.format, math.sqrt, math.floor

local NAMES = { A = { "Alex", "Kim", "Max", "Nell", "Otto", "Pia" }, B = { "Sam", "Lee", "Dana", "Rae", "Sol", "Tam" } }
local function team(side, size)
	local ps = {}
	for j = 1, size do ps[j] = { name = NAMES[side][j] } end
	return { name = "Team " .. side, players = ps }
end

local opt = { thrower = "cpu", level = "club", surface = "Grass", seed = 1, from = 1, to = 10, maxTurns = 40,
	model = here .. "/human-model.json", sets = {}, every = 1 }
local i = 1
while i <= #arg do
	local a = arg[i]
	local v = arg[i + 1]
	if a == "--out" then opt.out = v; i = i + 1
	elseif a == "--thrower" then opt.thrower = v; i = i + 1
	elseif a == "--level" then opt.level = v; i = i + 1
	elseif a == "--surface" then opt.surface = v; i = i + 1
	elseif a == "--seed" then opt.seed = tonumber(v); i = i + 1
	elseif a == "--from" then opt.from = tonumber(v); i = i + 1
	elseif a == "--to" then opt.to = tonumber(v); i = i + 1
	elseif a == "--maxturns" then opt.maxTurns = tonumber(v); i = i + 1
	elseif a == "--model" then opt.model = v; i = i + 1
	elseif a == "--scatter" then opt.scatter = tonumber(v); i = i + 1
	elseif a == "--set" then opt.sets[#opt.sets + 1] = v; i = i + 1
	elseif a == "--repro" then opt.repro = v; i = i + 1
	elseif a == "--dump" then opt.dump = v; i = i + 1
	elseif a == "--every" then opt.every = tonumber(v); i = i + 1
	elseif a == "--engine" then i = i + 1
	elseif a == "--selftest" then opt.selftest = true
	elseif a == "--a" then opt.specA = v; i = i + 1
	elseif a == "--b" then opt.specB = v; i = i + 1
	elseif a == "--swap" then opt.swap = tonumber(v); i = i + 1
	elseif a == "--probe" then opt.probe = true
	else error("unknown argument " .. a) end
	i = i + 1
end

-- --set: a number in tw's tune tables, by path
local LEVEL_TO_CPU = { nervesDeg = true, nervesLen = true, tumbleTurns = true, tumbleSd = true }
for _, s in ipairs(opt.sets) do
	local path, val = s:match("^([%w_%.]+)=(.+)$")
	assert(path, "--set path=value, got " .. s)
	local v = assert(tonumber(val), "--set: not a number: " .. val)
	local keys = {}
	for k in path:gmatch("[^%.]+") do keys[#keys + 1] = k end
	local t = tw
	for k = 1, #keys - 1 do
		t = t[keys[k]]
		assert(type(t) == "table", "--set: no table at " .. table.concat(keys, ".", 1, k))
	end
	local last = keys[#keys]
	assert(type(t[last]) == "number", "--set: " .. path .. " is not a number in the engine")
	t[last] = v
	if keys[1] == "plan" and keys[2] == "levels" and #keys == 4 and LEVEL_TO_CPU[last] then
		autothrow.cpuLevel(keys[3])[last] = v
	end
end

-- versus: each team's spec, installed in the tune tables (switched by versus.use)
local versus, teams, entries, entryOrder
if opt.specA or opt.specB then
	versus = dofile(here .. "/versus.lua")
	local ok, err = pcall(function()
		teams = { A = versus.parse(opt.specA, "A"), B = versus.parse(opt.specB, "B") }
		entries, entryOrder = versus.install(teams, LEVEL_TO_CPU)
	end)
	if not ok then
		io.stderr:write(tostring(err), "\n")
		os.exit(2)
	end
	opt.swap = opt.swap or 0
end

-- The team (its spec) that plays side `side` of this match.
local function teamOf(side)
	if opt.swap == 1 then side = side == "A" and "B" or "A" end
	return teams[side]
end

local human, model
local needHuman = opt.thrower == "human" or (teams and (teams.A.thrower == "human" or teams.B.thrower == "human"))
if needHuman then
	human = dofile(here .. "/human.lua")
	model = human.load(opt.model)
elseif opt.thrower ~= "cpu" then
	error("--thrower cpu or human")
end

-- ---------- JSON out (numbers rounded: these are statistics) ----------

local function enc(v, out)
	local tv = type(v)
	if tv == "number" then
		if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "null"
		elseif v == floor(v) and v > -1e15 and v < 1e15 then out[#out + 1] = fmt("%d", v)
		else out[#out + 1] = fmt("%.5g", v) end
	elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
	elseif tv == "string" then out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) return fmt("\\u%04x", c:byte()) end) .. '"'
	elseif tv == "table" then
		if #v > 0 or next(v) == nil then
			if next(v) == nil then out[#out + 1] = "[]"; return end
			out[#out + 1] = "["
			for k = 1, #v do
				if k > 1 then out[#out + 1] = "," end
				enc(v[k], out)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			local ks = {}
			for k in pairs(v) do ks[#ks + 1] = k end
			table.sort(ks)
			for _, k in ipairs(ks) do
				if not first then out[#out + 1] = "," end
				first = false
				out[#out + 1] = '"' .. k .. '":'
				enc(v[k], out)
			end
			out[#out + 1] = "}"
		end
	else out[#out + 1] = "null" end
end
local function json(v)
	local out = {}
	enc(v, out)
	return table.concat(out)
end

-- ---------- one throw ----------

-- The standing kubb or king nearest the aim point: the target of an engine whose
-- autothrow does not name it (before 0.8)
local function nearestTarget(s, P)
	if not P or not P.tx then return nil end
	local best, bd = nil, math.huge
	for _, p in ipairs(s.pieces) do
		if p.kind ~= "baton" and not p.toppled then
			local d = (p.x - P.tx) ^ 2 + (p.y - P.ty) ^ 2
			if d < bd then best, bd = p, d end
		end
	end
	return best and best.id
end

local function choose(s, r)
	local a
	local level, thrower, hand = opt.level, opt.thrower, opt.hand
	if teams then
		local t = teamOf(s.side)
		level, thrower, hand = t.level, t.thrower, t.hand
	end
	if thrower == "human" then a = human.choose(s, r, level, model, hand)
	else a = autothrow.choose(s, r, opt.scatter, level) end
	if not a.on and s.kind ~= "toss" then a.on = nearestTarget(s, a.plan) end
	return a
end

local function pieceById(s, id)
	for _, p in ipairs(s.pieces) do if p.id == id then return p end end
	return nil
end

local function targetRole(s, a)
	if s.kind == "toss" then return "drill" end
	if s.kingShot then return "king" end
	local p = a.on and pieceById(s, a.on)
	return p and (p.role or (p.kind == "king" and "king")) or "base"
end

-- Field kubbs standing in the half the batons are thrown at: how they are grouped.
local LINK_M, TOUCH_M = 0.20, 0.11
local function groupOf(s)
	local xs, ys = {}, {}
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side and not p.toppled then xs[#xs + 1], ys[#ys + 1] = p.x, p.y end
	end
	local n = #xs
	if n == 0 then return nil end
	local cx, cy = 0, 0
	for k = 1, n do cx, cy = cx + xs[k], cy + ys[k] end
	cx, cy = cx / n, cy / n
	local mean, far = 0, 0
	for k = 1, n do
		mean = mean + sqrt((xs[k] - cx) ^ 2 + (ys[k] - cy) ^ 2)
		for j = k + 1, n do
			local d = sqrt((xs[k] - xs[j]) ^ 2 + (ys[k] - ys[j]) ^ 2)
			if d > far then far = d end
		end
	end
	-- Kubbs joined in chains: `need` joins two whose centres are within LINK_M (a
	-- falling kubb or the baton's width reaches the next one), so it is the batons the
	-- group takes at best, each baton taking a whole chain; `touch` is the most kubbs
	-- in one chain of kubbs touching (within TOUCH_M: 7 cm kubbs, face to face or
	-- corner to corner), and `touching` how many kubbs touch another.
	local function chains(lim)
		local root, count, most, joined = {}, 0, 0, 0
		for k = 1, n do root[k] = k end
		local function find(k)
			while root[k] ~= k do k = root[k] end
			return k
		end
		local has = {}
		for k = 1, n do
			for j = k + 1, n do
				if (xs[k] - xs[j]) ^ 2 + (ys[k] - ys[j]) ^ 2 <= lim * lim then
					has[k], has[j] = true, true
					local a, b = find(k), find(j)
					if a ~= b then root[a] = b end
				end
			end
		end
		local size = {}
		for k = 1, n do
			local a = find(k)
			size[a] = (size[a] or 0) + 1
			if has[k] then joined = joined + 1 end
		end
		for _, v in pairs(size) do
			count = count + 1
			if v > most then most = v end
		end
		return count, most, joined
	end
	local need = chains(LINK_M)
	local _, touch, touching = chains(TOUCH_M)
	return { n = n, mean = mean / n, far = far, need = need, touch = touch, touching = touching }
end

-- The kubbs lying in the far half as the turn's last kubb comes to rest, before any
-- is raised (Jamie, 2026-11-21: "A good driller can get 6-7 kubbs all touching each
-- other in the basket"): how many touch another and the most in one touching chain.
-- A lying kubb is taken as three 7 cm discs along its long axis; two kubbs touch when
-- two of their discs are within LIE_GAP_M.
local LIE_GAP_M = 0.02
local function lyingOf(s, w)
	local half = {}
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side and p.toppled then half[p.id] = true end
	end
	if w.projectile then half[w.projectile.id] = true end
	local ks = {}
	for k = 1, w.n do
		local b = w.bodies[k]
		if half[b.id] then
			-- the long axis (local z) on the ground
			local ax, ay = 2 * (b.qx * b.qz + b.qw * b.qy), 2 * (b.qy * b.qz - b.qw * b.qx)
			local l = sqrt(ax * ax + ay * ay)
			if l > 0.5 then ks[#ks + 1] = { b.x, b.y, ax / l * 0.04, ay / l * 0.04 } end
		end
	end
	local n = #ks
	if n == 0 then return nil end
	local root, has = {}, {}
	for k = 1, n do root[k] = k end
	local function find(k)
		while root[k] ~= k do k = root[k] end
		return k
	end
	local lim = (0.07 + LIE_GAP_M) ^ 2
	for k = 1, n do
		for j = k + 1, n do
			local a, b, touch = ks[k], ks[j], false
			for u = -1, 1 do
				for v = -1, 1 do
					local dx, dy = a[1] + u * a[3] - b[1] - v * b[3], a[2] + u * a[4] - b[2] - v * b[4]
					if dx * dx + dy * dy <= lim then touch = true end
				end
			end
			if touch then
				has[k], has[j] = true, true
				local ra, rb = find(k), find(j)
				if ra ~= rb then root[ra] = rb end
			end
		end
	end
	local size, most, touching = {}, 0, 0
	for k = 1, n do
		local a = find(k)
		size[a] = (size[a] or 0) + 1
		if size[a] > most then most = size[a] end
		if has[k] then touching = touching + 1 end
	end
	return { n = n, touching = touching, most = most }
end

local function newWorld(s)
	return world.new { surface = s.surface, pieces = match.worldPieces(s) }
end

local function ctxOf(s, a)
	local P = a.plan or {}
	return { stanceX = a.x, stanceY = a.y, aimX = P.tx, aimY = P.ty, on = a.on, lineY = s.lineY }
end

-- ---------- self-test: forensics changes nothing ----------

local function state(w)
	local t = {}
	for k = 1, w.n do
		local b = w.bodies[k]
		t[#t + 1] = fmt("%s %.17g %.17g %.17g %.17g %.17g %.17g %.17g %s", b.id, b.x, b.y, b.z, b.qw, b.qx, b.qy, b.qz,
			tostring(b.toppled))
	end
	return table.concat(t, "\n") .. fmt("\nt=%.17g steps=%d", w.time, w.steps)
end

-- ---------- a match ----------

local base = { year = 2026, month = 11, day = 20, hour = 9, min = 0 }

-- The raising of both sides in a plain run (tools/gym/versus.lua's defaultRaise).
local plainRaise = dofile(here .. "/versus.lua").defaultRaise(opt.level, opt.thrower)

-- Plays match gi. each(s, a, ti) is called before every throw and returns how to
-- throw it: "plain" (world.run), "forensics", or "stop".
local function play(gi, each)
	local start = notation.addMinutes(base, (gi - 1) * 41)
	local m = match.new { start = start, first = (gi % 2 == 0) and "B" or "A", surface = opt.surface,
		teams = { A = team("A", (gi - 1) % 6 + 1), B = team("B", (gi + 1) % 6 + 1) } }
	-- a plain run: both sides raise as the engine raises such a side (0.12.0: the
	-- computer by its level, the human thrower by the engine's advice; before 0.12,
	-- apart), so a run scores the level as it plays. versus sets each team's own below
	if not teams then m.game.raisePolicy = plainRaise end
	local r = autothrow.rng(opt.seed * 7919 + gi)
	local ti = 0
	local throws = {}
	while not match.over(m) do
		if m.game.turn > opt.maxTurns then
			match.resign(m)
			break
		end
		if teams then
			-- the defender raises the turn's kubbs and places its punishment kubbs with
			-- its own policy and numbers (match.setup's settle then finds nothing to do);
			-- the rest of the setup, the throw and its ruling are the attacker's
			local n = m.game:need()
			if n.kind == "raise" or n.kind == "punish" then
				local d = teamOf(m.game.defender)
				versus.use(d.label)
				m.game.raisePolicy = versus.policy(d)
				match.settle(m)
			end
			versus.use(teamOf(m.game.attacker).label)
		end
		local s = match.setup(m)
		if not s then break end
		local a = choose(s, r)
		ti = ti + 1
		local how = each and each(s, a, ti, m) or "forensics"
		if how == "stop" then return m, throws, true end
		local w = newWorld(s)
		autothrow.launch(w, s, a)
		local rec, res
		if how == "plain" then
			world.run(w)
			res = world.result(w)
		else
			rec, res = forensics.run(w, ctxOf(s, a), s.pieces)
		end
		local turn = m.game.turn
		match.resolve(m, res, not a.legal)
		if rec then
			local P = a.plan or {}
			local o = { m = gi, t = ti, turn = turn, side = s.side, team = teams and teamOf(s.side).label, k = targetRole(s, a), n = s.n, of = s.of,
				legal = a.legal, adv = (s.forwardY or 0) > s.lineY,
				dist = P.tx and sqrt((P.tx - a.x) ^ 2 + (P.ty - a.y) ^ 2) or nil, f = rec }
			if a.launch then
				local L = a.launch
				o.v = { L.powerV, L.releaseV, L.steady and 1 or 0, L.sideV }
			end
			if s.kind == "toss" then
				local d = a.drill
				o.drill = { dx = rec.restX - d.markerX, dy = rec.restY - (s.lineY + d.markerY) }
				local j = m.game.judgment
				if j then o.drill.rethrow, o.drill.punish = j.rethrow, j.punish end
				if s.n == s.of then o.lying = lyingOf(s, w) end
			elseif s.n == 1 and not s.kingShot then
				o.group = groupOf(s)
			end
			-- slimmer: drop what is empty
			if #rec.hard == 0 then rec.hard = nil end
			if #rec.propped == 0 then rec.propped = nil end
			throws[#throws + 1] = o
		end
	end
	if teams then versus.use(nil) end
	return m, throws, false
end

-- ---------- --selftest ----------

if opt.selftest then
	local bad, n = 0, 0
	for gi = opt.from, math.min(opt.to, opt.from + 2) do
		play(gi, function(s, a)
			local w1 = newWorld(s)
			autothrow.launch(w1, s, a)
			world.run(w1)
			local w2 = newWorld(s)
			autothrow.launch(w2, s, a)
			forensics.run(w2, ctxOf(s, a), s.pieces)
			n = n + 1
			if state(w1) ~= state(w2) then bad = bad + 1 end
			return "plain"
		end)
	end
	print(fmt("selftest: %d throws, %d differ with forensics on", n, bad))
	os.exit(bad == 0 and 0 or 1)
end

-- ---------- --repro ----------

local function show(v, ind)
	ind = ind or "  "
	local ks = {}
	for k in pairs(v) do ks[#ks + 1] = k end
	table.sort(ks, function(x, y) return tostring(x) < tostring(y) end)
	for _, k in ipairs(ks) do
		local x = v[k]
		if type(x) == "table" then
			print(ind .. tostring(k) .. ":")
			show(x, ind .. "  ")
		elseif type(x) == "number" then
			print(fmt("%s%s = %.4f", ind, tostring(k), x))
		else
			print(fmt("%s%s = %s", ind, tostring(k), tostring(x)))
		end
	end
end

if opt.repro then
	local gi, want = opt.repro:match("^(%d+):(%d+)$")
	assert(gi, "--repro <match>:<throw>")
	gi, want = tonumber(gi), tonumber(want)
	play(gi, function(s, a, ti, m)
		if ti < want then return "plain" end
		local who = fmt("%s at %s, raise %s", opt.thrower, opt.level, plainRaise)
		if teams then
			local t = teamOf(s.side)
			who = fmt("versus, swap %d: team %s (%s at %s, raise %s)", opt.swap, t.label, t.thrower, t.level, t.raise)
		end
		print(fmt("match %d of seed %d (%s, %s), throw %d: turn %d, %s", gi, opt.seed, who,
			opt.surface, ti, m.game.turn, s.label))
		for _, p in ipairs(s.pieces) do
			if p.kind ~= "baton" then
				print(fmt("  %-6s %-5s %-6s (%.3f, %.3f)%s", p.id, p.kind, p.role or "", p.x, p.y, p.toppled and " lying" or ""))
			end
		end
		local P = a.plan or {}
		print(fmt("  from (%.3f, %.3f) at (%.3f, %.3f) on %s: swivel %.5f loft %.3f speed %.4f tumble %.3f tilt %.2f legal %s",
			a.x, a.y, P.tx or 0, P.ty or 0, tostring(a.on), a.swivel, a.loftDeg, a.speed, a.tumbleRate or 0, a.tilt or 0,
			tostring(a.legal)))
		if a.swing then
			local sw = a.swing
			print(fmt("  swing: back %.2f (plan %.2f, %.2f..%.2f) release %.2f (plan %.2f) flick %.3f shake %.3f pull %+d",
				sw.back, P.back or 0, P.powerLo or 0, P.powerHi or 0, sw.releaseAngle, P.release or 0, sw.flickFrac,
				sw.shake, sw.pull))
		end
		local w = newWorld(s)
		autothrow.launch(w, s, a)
		local fh = opt.dump and assert(io.open(opt.dump, "w"))
		local ctx = ctxOf(s, a)
		if fh then
			ctx.each = function(w2)
				if w2.steps % opt.every ~= 0 then return end
				local parts = { fmt("gym t=%.17g steps=%d", w2.time, w2.steps) }
				for k = 1, w2.n do
					local b = w2.bodies[k]
					parts[#parts + 1] = fmt("  %s %s %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g %s", b.id,
						tostring(b.awake), b.x, b.y, b.z, b.qw, b.qx, b.qy, b.qz, b.vx, b.vy, b.vz, tostring(b.toppled))
				end
				fh:write(table.concat(parts, "\n"), "\n")
			end
		end
		local rec, res = forensics.run(w, ctx, s.pieces)
		if fh then fh:close(); print("  trace written to " .. opt.dump) end
		print(fmt("  rest at %.3f s; first contact %s; toppled: %s", res.time,
			res.firstContact and fmt("%.3f s with %s", res.firstContact.t, res.firstContact.with) or "none",
			#res.toppled > 0 and table.concat(res.toppled, ", ") or "nothing"))
		print("  forensics:")
		show(rec, "    ")
		return "stop"
	end)
	os.exit(0)
end

-- How often each team's settings were read while each team acted (versus).
local function readsJson()
	local out = {}
	for _, path in ipairs(entryOrder or {}) do
		local e = entries[path]
		out[path] = { base = e.base, A = e.val.A, B = e.val.B, reads = e.reads }
	end
	return out
end

-- ---------- --probe (versus): which settings are read, no forensics ----------

if opt.probe then
	assert(teams, "--probe needs --a and --b")
	for gi = opt.from, opt.to do play(gi, function() return "plain" end) end
	print(json { probe = true, swap = opt.swap, from = opt.from, to = opt.to, sets = readsJson() })
	os.exit(0)
end

-- ---------- a run ----------

assert(opt.out, "--out DIR")
os.execute('mkdir -p "' .. opt.out .. '/games"')
local jf = assert(io.open(fmt("%s/throws-%05d-%05d.jsonl", opt.out, opt.from, opt.to), "w"))
local t0 = os.clock()
local nThrows = 0
for gi = opt.from, opt.to do
	local m, throws = play(gi)
	local bad = order.checkSheet(m.game)
	if #bad > 0 then error("gym match " .. gi .. ": " .. bad[1]) end
	local finish = notation.addMinutes(notation.addMinutes(base, (gi - 1) * 41), 5 + m.game.turn * 2)
	local text, name = match.file(m, finish, tw.engine and tw.engine.version or "0.0.0")
	local f = assert(io.open(opt.out .. "/games/" .. fmt("%05d-", gi) .. name, "w"))
	f:write(text)
	f:close()
	for _, o in ipairs(throws) do jf:write(json(o), "\n") end
	nThrows = nThrows + #throws
	local over = { m = gi, over = true, turns = m.game.turn, how = m.game.how, winner = m.game.winner }
	if teams then
		over.swap, over.first = opt.swap, m.game.first
		over.limit = m.game.turn > opt.maxTurns
		over.winnerTeam = m.game.winner and teamOf(m.game.winner).label
		over.firstTeam = teamOf(m.game.first).label
	end
	jf:write(json(over), "\n")
end
if teams then jf:write(json { reads = readsJson() }, "\n") end
jf:close()
print(fmt("gym: matches %d-%d, %d throws, %.2f s", opt.from, opt.to, nThrows, os.clock() - t0))
