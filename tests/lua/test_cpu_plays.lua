-- The plays 0.12.0 adds to Choose (core/cpu): field.line and inkast.depth, on hand-made
-- setups with a known right answer, each with its level switch and its off switch.
import "core/tw"
import "core/cpu"
import "core/throwplan"
import "core/raising"

local cpu, autothrow, read = tw.cpu, tw.autothrow, tw.read

local function k(id, half, x, y, toppled, angle, role)
	local p = { id = id, kind = "kubb", role = role or "field", half = half, x = x, y = y, toppled = toppled }
	if angle then p.pose = { angle = angle } end
	return p
end

local function baton(pieces, targets, forwardY)
	return { kind = "baton", side = "A", lineY = 0, forwardY = forwardY or 0, batonId = "baton1",
		pieces = pieces, targets = targets, surface = "grass" }
end

local function toss(pieces, of, n)
	return { kind = "toss", side = "A", lineY = 0, forwardY = 0, kubb = "a1", pieces = pieces or {},
		of = of or 6, n = n or 1, surface = "grass" }
end

local rng = autothrow.rng

-- Run fn with cpu.tune's play `name` set for `level` (and on), then put it back.
local function with(name, level, v, fn)
	local p = cpu.tune[name]
	local old = p[level]
	p[level] = v
	local ok, err = pcall(fn)
	p[level] = old
	if not ok then error(err, 0) end
end

-- ---------- field.line ----------

-- Two kubbs on a diagonal: 0.25 m across and 0.5 m along apart. Straight down the pitch
-- neither is behind the other (laneHalf 7 cm); from x = 1.0 - 0.25 x 5 / 0.5 = -1.5 on the
-- baseline they line up exactly.
local function diagonal()
	return { k("front", "B", 1.0, 5.0), k("back", "B", 1.25, 5.5), k("lone", "B", -1.5, 6.5),
		{ id = "king", kind = "king", role = "king", x = 0, y = 4 } }, { "front", "back", "lone" }
end

test("field.line: the levels that know it (pro), and off for the others", function()
	local pieces, targets = diagonal()
	expect.eq(cpu.tune.line.pro, 1, "pro knows field.line")
	for _, lv in ipairs { "beginner", "club" } do
		local d = cpu.decide(baton(pieces, targets), rng(1), lv)
		expect.eq(d.why.play, "field.roles", lv)
		expect.eq(d.why.facts.lane, 1, lv)
		expect.eq(d.intent.on, "front", lv .. ": the nearest front on a tie")
		expect.near(d.intent.stance.x, 1.0, 0, lv .. ": straight behind")
	end
	with("line", "pro", 0, function()
		local d = cpu.decide(baton(pieces, targets), rng(1), "pro")
		expect.eq(d.why.play, "field.roles", "pro with field.line switched off")
	end)
end)

test("field.line moves along the line until two kubbs stand one behind the other", function()
	local pieces, targets = diagonal()
	with("line", "pro", 1, function()
		local d = cpu.decide(baton(pieces, targets), rng(1), "pro")
		expect.eq(d.why.play, "field.line")
		expect.eq(d.intent.on, "front")
		expect.eq(d.why.facts.lane, 2)
		expect.eq(d.why.facts.over, 1, "field.roles saw singles")
		expect.near(d.intent.stance.x, -1.5, 1e-9)
		expect.near(d.intent.stance.y, 0, 0)
		-- aimed at the front kubb, both kubbs on the line from the stance
		expect.near(d.intent.tx, 1.0, 1e-9)
		expect.near(d.intent.ty, 5.0, 1e-9)
		expect.near(d.why.facts.range, math.sqrt(2.5 * 2.5 + 25), 1e-9)
		expect.eq(cpu.text(d.why), "Stood off to the side so 2 kubbs line up behind the front one.")
		-- club does not know it at the default, and on = 0 switches it off everywhere
		expect.eq(cpu.decide(baton(pieces, targets), rng(1), "club").why.play, "field.roles")
		cpu.tune.line.on = 0
		local d0 = cpu.decide(baton(pieces, targets), rng(1), "pro")
		cpu.tune.line.on = 1
		expect.eq(d0.why.play, "field.roles")
		expect.near(d0.intent.stance.x, 1.0, 0)
	end)
end)

test("field.line keeps the straight stance when the lane is straight down the pitch", function()
	local pieces = { k("f1", "B", 1.9, 4.6), k("f2", "B", 1.9, 4.8), k("f3", "B", 1.92, 5.0), k("s", "B", -1, 5) }
	with("line", "pro", 1, function()
		local d = cpu.decide(baton(pieces, { "f1", "f2", "f3", "s" }), rng(1), "pro")
		expect.eq(d.intent.on, "f1")
		expect.eq(d.why.facts.lane, 3)
		expect.eq(d.why.play, "field.roles", "straight behind: no move, field.roles' own throw")
		expect.truthy(math.abs(d.intent.stance.x - 1.9) < 0.05, d.intent.stance.x)
	end)
end)

test("field.line never throws through the king or past a kubb in front", function()
	-- the line from (-1.5, 0) through the diagonal pair passes the king put on it
	local pieces, targets = diagonal()
	local kx = -1.5 + 2.5 * 4 / 5
	pieces[4] = { id = "king", kind = "king", role = "king", x = kx, y = 4 }
	with("line", "pro", 1, function()
		local d = cpu.decide(baton(pieces, targets), rng(1), "pro")
		expect.truthy(math.abs(d.intent.stance.x - -1.5) > 0.2, "the king is on that line")
		expect.eq(d.why.facts.lane, 1)
	end)
	-- read.lineLane: a kubb in the lane short of the front kubb rules the stance out
	local pos = read.byId(baton(pieces, targets))
	local s = baton({ k("a", "B", 0, 5), k("b", "B", 0, 4.7) }, { "a", "b" })
	local n, _, _, range, bad = read.lineLane(s, read.byId(s), read.byId(s).a, 0, 0)
	expect.eq(bad, true)
	expect.near(range, 5, 1e-12)
	n, _, _, range, bad = read.lineLane(s, read.byId(s), read.byId(s).b, 0, 0)
	expect.eq(bad, false)
	expect.eq(n, 2)
	-- a field kubb of the thrower's own half by the path (II.B.11: touching it forfeits
	-- the baton) rules the stance out; field.line steps along the line clear of it
	local own = { k("t", "B", 1.9, 4.12), k("o", "A", 1.95, 3.97) }
	s = baton(own, { "t" }, 3.97)
	_, _, _, _, bad = read.lineLane(s, read.byId(s), read.byId(s).t, 1.9, 3.87)
	expect.eq(bad, true, "the own kubb beside the straight stance")
	with("line", "pro", 1, function()
		local d = cpu.decide(s, rng(1), "pro")
		expect.eq(d.why.play, "field.roles", "no stance clears it: field.roles' throw")
		own[2].x = 1.4
		d = cpu.decide(s, rng(1), "pro")
		expect.eq(d.why.play, "field.roles", "clear: straight behind")
		-- an own kubb just in front of the straight stance, the target far: a step aside
		s = baton({ k("t", "B", 1.9, 5.0), k("o", "A", 1.9, 3.1) }, { "t" }, 3.0)
		d = cpu.decide(s, rng(1), "pro")
		expect.eq(d.why.play, "field.line")
		expect.near(d.intent.stance.x, 1.9 - cpu.tune.line.step, 1e-12)
		expect.near(d.intent.stance.y, 3.0, 0)
	end)
	expect.truthy(pos.front, "pieces by id")
end)

test("field.line weighs the longer throw: a far double from the side against a near triple", function()
	-- a triple straight down at 4.5 m and a diagonal double: the triple wins
	local pieces = { k("t1", "B", -1.9, 4.5), k("t2", "B", -1.9, 4.7), k("t3", "B", -1.9, 4.9),
		k("front", "B", 1.0, 5.0), k("back", "B", 1.25, 5.5) }
	with("line", "pro", 1, function()
		local d = cpu.decide(baton(pieces, { "t1", "t2", "t3", "front", "back" }), rng(1), "pro")
		expect.eq(d.intent.on, "t1")
		expect.eq(d.why.facts.lane, 3)
	end)
end)

-- ---------- inkast.depth ----------

local HALF = math.pi / 2  -- a kubb lying along the throw

test("inkast.depth: the level that knows it (pro), and the row without it", function()
	expect.eq(cpu.tune.depth.pro, 1)
	expect.eq(cpu.tune.depth.club, 0, "club lays the row, as in 0.11.2")
	local s = toss({ k("f1", "B", 1.9, 4.75, true, HALF) }, 6, 2)
	expect.eq(cpu.decide(s, rng(1), "pro").why.play, "inkast.depth")
	local c = cpu.decide(s, rng(1), "club")
	expect.eq(c.why.play, "inkast.roll")
	expect.eq(c.why.facts.spot, "row")
	with("depth", "pro", 0, function()
		local d = cpu.decide(s, rng(1), "pro")
		expect.eq(d.why.play, "inkast.roll")
		expect.eq(d.why.facts.spot, "row")
	end)
	with("depth", "club", 1, function()
		expect.eq(cpu.decide(s, rng(1), "club").why.play, "inkast.depth", "the switch reaches club")
		cpu.tune.depth.on = 0
		local d = cpu.decide(s, rng(1), "club")
		cpu.tune.depth.on = 1
		expect.eq(d.why.facts.spot, "row", "on = 0: off at every level")
	end)
end)

test("inkast.depth lays each kubb in front of the last, down the baton's path", function()
	local t, dt = autothrow.tune, cpu.tune.depth
	with("depth", "pro", 1, function()
		local step = 0.15 + dt.gap
		-- an empty basket: the basket, or deeper so that a full column of the kubbs in hand
		-- (up to run) fits in front of it without crossing `front`
		local d = cpu.decide(toss({ k("x", "B", -1.9, 4.75) }, 2, 1), rng(1), "pro")
		expect.eq(d.why.play, "inkast.depth")
		expect.near(d.intent.tx, t.basketX * d.intent.basket, 0)
		expect.near(d.intent.ty, t.basketY, 0, "two in hand fit in front of the basket")
		d = cpu.decide(toss({ k("x", "B", -1.9, 4.75) }, 6, 1), rng(1), "pro")
		expect.near(d.intent.ty, dt.front + (dt.run - 1) * step, 1e-12, "a full column of four")
		-- one lying along the throw: the next rests gap in front of it, in its lane
		d = cpu.decide(toss({ k("f1", "B", 1.9, 4.75, true, HALF) }, 6, 2), rng(1), "pro")
		expect.eq(d.why.play, "inkast.depth")
		expect.eq(d.why.facts.beside, "f1")
		expect.near(d.intent.tx, 1.9, 1e-12)
		expect.near(d.intent.ty, 4.75 - 0.075 - dt.gap - 0.075, 1e-12)
		expect.eq(d.intent.spin, 1, "the row's spin toward the sideline: its dead landing and roll")
		expect.eq(cpu.text(d.why), "Laid one behind another down the baton's path, in the right basket.")
		-- three in the column: in front of the front one
		local y1 = dt.front + 3 * step + 0.01
		local c = { k("f1", "B", 1.9, y1, true, HALF), k("f2", "B", 1.9, y1 - step, true, HALF),
			k("f3", "B", 1.91, y1 - 2 * step, true, HALF) }
		d = cpu.decide(toss(c, 6, 4), rng(1), "pro")
		expect.eq(d.why.facts.beside, "f3")
		expect.near(d.intent.ty, y1 - 3 * step, 1e-12)
		-- four: the column is full; the next starts beside its back kubb, on the inner side
		c[4] = k("f4", "B", 1.9, y1 - 3 * step, true, HALF)
		d = cpu.decide(toss(c, 6, 5), rng(1), "pro")
		expect.eq(d.why.facts.spot, "column")
		expect.eq(d.why.facts.beside, "f1")
		expect.near(d.intent.tx, 1.9 - t.rowStep, 1e-12)
		expect.near(d.intent.ty, y1, 0)
		-- and that column grows forward beside the first
		c[5] = k("g1", "B", 1.9 - t.rowStep, y1, true, HALF)
		d = cpu.decide(toss(c, 6, 6), rng(1), "pro")
		expect.eq(d.why.facts.spot, "depth")
		expect.eq(d.why.facts.beside, "g1")
		expect.near(d.intent.tx, 1.9 - t.rowStep, 1e-12)
		expect.near(d.intent.ty, y1 - step, 1e-12)
		-- never nearer the centre line than `front`: a column of three whose next spot would
		-- cross it is full, and the next column starts beside it
		local c2 = { k("f1", "B", 1.9, 4.75, true, HALF), k("f2", "B", 1.9, 4.75 - step, true, HALF),
			k("f3", "B", 1.9, 4.75 - 2 * step, true, HALF) }
		d = cpu.decide(toss(c2, 6, 4), rng(1), "pro")
		expect.truthy(4.75 - 3 * step < dt.front, "the next spot would cross front")
		expect.eq(d.why.facts.spot, "column")
		expect.near(d.intent.ty, 4.75, 0)
	end)
	-- a beginner throws at the basket whatever the switch says
	with("depth", "beginner", 1, function()
		local d = cpu.decide(toss({ k("f1", "B", 1.9, 4.75, true, HALF) }, 6, 2), rng(1), "beginner")
		expect.eq(d.why.facts.spot, "basket")
	end)
end)

test("a column is a shape raise.par cannot take apart; a row across is one it can", function()
	-- raising.parExposure of two standing kubbs: a column's pair whichever ends the
	-- defender picks (kubbs lying end to end 0.17 apart stand 0.06 to 0.39 apart, in one
	-- lane), against a row's pair stood on the same end (side by side: nothing behind it
	-- straight on, a little from the far end of the throwing line)
	local ex = tw.raising.parExposure
	local t = tw.raising.tune
	local worst = math.huge
	for _, da in ipairs { -0.11, 0.11 } do
		for _, db in ipairs { -0.11, 0.11 } do
			local e = ex(1.9, 4.75 + da, 1.9, 4.58 + db, 1, 0, t)
			if e < worst then worst = e end
		end
	end
	local row = ex(1.9, 4.86, 1.825, 4.86, 1, 0, t)
	expect.truthy(worst > 1, "a column stays exposed however it stands: " .. worst)
	expect.truthy(row < 0.5, "a row stood level is seen only from the far end of the line: " .. row)
end)
