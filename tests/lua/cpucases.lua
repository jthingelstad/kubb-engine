-- The computer player's regression cases (0.11.1, "the split itself, with no change in
-- play": docs/notes/computer-player.md). Builds a few hundred match setups from seeds,
-- calls autothrow.choose on each and writes every number and string of its result, and
-- the next number of the random stream after it (so a draw added, dropped or moved
-- shows), one line per field. tests/fixtures/cpu/choose.txt holds these lines as 0.11.0
-- wrote them; test_cpu_regression fails on any difference. Both run on desktop Lua, so
-- floats are written to 17 digits; the test holds them to one part in 10^9.
--
--   local cases = dofile(root .. "/tests/lua/cpucases.lua")
--   local lines = cases.lines()     -- every line, in order
--
-- The setups are synthetic (no physics): tosses with 1 to 10 kubbs in hand and field
-- kubbs lying and standing near the baskets and elsewhere, batons at fields of different
-- shapes (lanes, scatter, one kubb), base kubbs and king shots, each level and an unknown
-- one, both sides, the three surfaces, and a few with the inkast tune changed for the
-- call (row 0, into 0) so the paths only the Gym uses are covered too.
import "core/tw"
import "core/autothrow"

local autothrow = tw.autothrow
local fmt = string.format

local cases = {}

-- A small seeded generator of its own (a 31-bit LCG), so the setups do not depend on
-- the engine's rng.
local function gen(seed)
	local st = (seed * 2654435761 + 12345) % 2147483648
	local g = {}
	function g.next()
		st = (st * 1103515245 + 12345) % 2147483648
		return st / 2147483648
	end
	function g.int(a, b) return a + math.floor(g.next() * (b - a + 1)) end
	function g.range(a, b) return a + (b - a) * g.next() end
	function g.pick(t) return t[g.int(1, #t)] end
	return g
end

local LEVELS = { "beginner", "club", "pro" }
local SURFACES = { "grass", "sand", "snow" }

local function kubb(id, role, half, x, y, toppled, angle)
	local p = { id = id, kind = "kubb", role = role, half = half, x = x, y = y }
	if toppled then
		p.toppled = true
		if angle then p.pose = { angle = angle } end
	end
	return p
end

-- Field kubbs of the far half: some in groups near a basket, some anywhere past the
-- centre line, lying or standing. Returns the pieces and the standing ones' ids.
local function field(g, s, far, n, lyingShare)
	local pieces, standing = s.pieces, {}
	for i = 1, n do
		local x, y
		local where = g.next()
		if where < 0.55 then
			-- by a basket: either side, within about a metre
			local side = g.next() < 0.5 and -1 or 1
			x, y = side * 1.9 + g.range(-0.6, 0.4) * side, 4.75 + g.range(-0.5, 0.9)
		elseif where < 0.75 then
			-- behind the last one, nearly in its lane
			local last = pieces[#pieces]
			if last and last.role == "field" then
				x, y = last.x + g.range(-0.09, 0.09), last.y + g.range(0.05, 0.7)
			else
				x, y = g.range(-2.3, 2.3), g.range(4.1, 7.6)
			end
		else
			x, y = g.range(-2.3, 2.3), g.range(4.1, 7.6)
		end
		local lying = g.next() < lyingShare
		local angle = lying and g.next() < 0.8 and g.range(-3.2, 3.2) or nil
		local p = kubb("f" .. i, "field", far, x, s.lineY + y, lying, angle)
		pieces[#pieces + 1] = p
		if not lying then standing[#standing + 1] = p.id end
	end
	return standing
end

-- The thrower's own half has field kubbs now and then, which nothing should count.
local function ownHalf(g, s)
	for i = 1, g.int(0, 2) do
		s.pieces[#s.pieces + 1] = kubb("o" .. i, "field", s.side, g.range(-2, 2), s.lineY + g.range(1, 3.9),
			g.next() < 0.5, g.range(-1, 1))
	end
end

local function bases(g, s, far)
	local standing = {}
	for i = 1, 5 do
		local up = g.next() < 0.7
		local p = kubb("b" .. i, "base", far, -2 + (i - 1) + g.range(-0.05, 0.05), s.lineY + 8 + g.range(-0.05, 0.05),
			not up, g.range(-1, 1))
		s.pieces[#s.pieces + 1] = p
		if up then standing[#standing + 1] = p.id end
	end
	if #standing == 0 then
		s.pieces[1].toppled, s.pieces[1].pose = nil, nil
		standing[1] = s.pieces[1].id
	end
	return standing
end

local function king(g, s)
	s.pieces[#s.pieces + 1] = { id = "king", kind = "king", role = "king", x = g.range(-0.03, 0.03), y = s.lineY + 4 }
end

-- Setup number i (deterministic in i alone).
local function setup(i)
	local g = gen(i)
	local side = (i % 2 == 0) and "A" or "B"
	local far = side == "A" and "B" or "A"
	local s = { side = side, pieces = {}, lineY = 0, forwardY = 0, surface = g.pick(SURFACES) }
	if g.next() < 0.15 then s.lineY = g.range(-0.5, 0.5) end
	local kind = g.next()
	if i <= 12 then kind = 0 end -- the first few: tosses at an empty far half (the coin)
	if kind < 0.45 then
		s.kind, s.projectile = "toss", "kubb"
		s.kubb = "k" .. g.int(1, 10)
		s.of = g.int(1, 10)
		s.n = g.int(1, s.of)
		if g.next() < 0.1 then s.of = nil end
		if i > 12 then field(g, s, far, g.int(0, 9), g.next()) end
	elseif kind < 0.77 then
		s.kind, s.projectile = "baton", "baton"
		local standing = field(g, s, far, g.int(1, 10), 0.3 * g.next())
		if #standing == 0 then
			local p = s.pieces[g.int(1, #s.pieces)]
			p.toppled, p.pose = nil, nil
			standing[1] = p.id
		end
		s.targets = standing
		if g.next() < 0.5 then s.forwardY = g.range(0, 3.5) end
	elseif kind < 0.92 then
		s.kind, s.projectile = "baton", "baton"
		s.targets = bases(g, s, far)
		if g.next() < 0.3 then s.forwardY = g.range(0, 2) end
	else
		s.kind, s.projectile = "baton", "baton"
		bases(g, s, far)
		for _, p in ipairs(s.pieces) do p.toppled = true end
		s.kingShot = true
		s.targets = { "king" }
		if g.next() < 0.3 then s.forwardY = g.range(0, 3) end -- a king shot is from the baseline whatever this says
	end
	if s.kind == "baton" then
		s.batonId = "baton" .. g.int(1, 6)
		s.n, s.of = g.int(1, 6), 6
	end
	ownHalf(g, s)
	if s.kingShot or g.next() < 0.6 then king(g, s) end
	-- who throws: the level as an argument, on the setup's thrower, both, or neither
	local level
	local how = g.next()
	if how < 0.4 then level = g.pick(LEVELS)
	elseif how < 0.7 then s.thrower = { id = "p1", level = g.pick(LEVELS) }
	elseif how < 0.8 then level = g.pick(LEVELS); s.thrower = { id = "p1", level = g.pick(LEVELS) }
	elseif how < 0.88 then level = "toddler" -- a level autothrow does not know ("kid" until 0.15, when Kid became one)
	elseif how < 0.93 then s.thrower = { id = "p1", level = 3 } -- not a string
	end
	local scale = g.pick { false, 0, 0.3, 1, 1, 1, 1.7 }
	if scale == false then scale = nil end
	-- the tune the Gym may set: a level that groups without a row, and no aim into the group
	local tuneCase
	if s.kind == "toss" then
		local u = g.next()
		if u < 0.12 then tuneCase = "row0" elseif u < 0.18 then tuneCase = "row0into0" end
	end
	return s, scale, level, tuneCase, g.int(1, 1000000)
end

local function num(v)
	if math.type(v) == "integer" then return fmt("%d", v) end
	local t = fmt("%.17g", v)
	if not t:find("[%.eEn]") then t = t .. ".0" end
	return t
end

-- Every leaf of v under `path`, keys sorted, as "path = value" lines.
local function walk(out, path, v, seen)
	local ty = type(v)
	if ty == "table" then
		if seen[v] then out[#out + 1] = path .. " = <seen " .. seen[v] .. ">"; return end
		seen[v] = path
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then return ta < tb end
			return a < b
		end)
		if #keys == 0 then out[#out + 1] = path .. " = {}" end
		for _, k in ipairs(keys) do walk(out, path .. "." .. tostring(k), v[k], seen) end
	elseif ty == "number" then out[#out + 1] = path .. " = " .. num(v)
	elseif ty == "string" then out[#out + 1] = path .. " = " .. fmt("%q", v)
	else out[#out + 1] = path .. " = " .. tostring(v) end
end

cases.count = 480

local function withTune(tuneCase, fn)
	if not tuneCase then return fn() end
	local t = autothrow.tune
	local saved, savedInto = t.inkast.club, t.into
	t.inkast.club = { spin = 1, hand = 0.26, group = 1, row = 0 }
	if tuneCase == "row0into0" then t.into = 0 end
	local ok, a, b = pcall(fn)
	t.inkast.club, t.into = saved, savedInto
	if not ok then error(a, 0) end
	return a, b
end

-- Every line, in order: per case a header, then the result's leaves, then the stream.
function cases.lines()
	local out = {}
	for i = 1, cases.count do
		local s, scale, level, tuneCase, seed = setup(i)
		out[#out + 1] = fmt("case %d %s side=%s level=%s thrower=%s scale=%s tune=%s pieces=%d", i, s.kind, s.side,
			tostring(level), tostring(s.thrower and s.thrower.level), tostring(scale), tostring(tuneCase), #s.pieces)
		local r = autothrow.rng(seed)
		local a = withTune(tuneCase, function() return autothrow.choose(s, r, scale, level) end)
		walk(out, "a", a, {})
		out[#out + 1] = "next = " .. num(r.next())
	end
	return out
end

return cases
