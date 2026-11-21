-- core/read: what the computer reads off the pitch, on hand-made setups. Read decides
-- nothing and draws nothing.
import "core/tw"
import "core/read"

local read, autothrow = tw.read, tw.autothrow

local function k(id, half, x, y, toppled, role)
	return { id = id, kind = "kubb", role = role or "field", half = half, x = x, y = y, toppled = toppled }
end

local function setup(pieces, extra)
	local s = { kind = "toss", side = "A", lineY = 0, forwardY = 0, pieces = pieces }
	for key, v in pairs(extra or {}) do s[key] = v end
	return s
end

test("the baskets: where they are and the field kubbs of the far half near each", function()
	local t = autothrow.tune
	local x, y = read.basketAt(setup {}, -1)
	expect.near(x, -t.basketX, 0)
	expect.near(y, t.basketY, 0)
	x, y = read.basketAt(setup({}, { lineY = 0.5 }), 1)
	expect.near(x, t.basketX, 0)
	expect.near(y, 0.5 + t.basketY, 0)
	local s = setup {
		k("r1", "B", 1.9, 4.8), k("r2", "B", 2.0, 5.4, true), -- right, lying or standing
		k("l1", "B", -1.8, 4.6),
		k("m1", "B", 0, 7.5),                     -- near neither
		k("o1", "A", 1.9, 4.75),                  -- the thrower's own half
		k("b1", "B", 1.9, 4.75, false, "base"),   -- not a field kubb
	}
	local left, right = read.basketCounts(s)
	expect.eq(left, 1)
	expect.eq(right, 2)
	expect.truthy(read.farField(s, s.pieces[1]) and not read.farField(s, s.pieces[5]), "far field")
	expect.truthy(read.nearBasket(s.pieces[1], t.basketX, t.basketY), "near")
	expect.truthy(not read.nearBasket(s.pieces[4], t.basketX, t.basketY), "not near")
end)

test("the lying kubbs near a basket, their middle, and the innermost of them", function()
	local s = setup {
		k("a", "B", 1.9, 4.8, true), k("b", "B", 1.7, 5.0, true),
		k("c", "B", 1.5, 4.9),          -- standing: not lying
		k("d", "B", -1.9, 4.75, true),  -- by the other basket
		k("e", "A", 1.8, 4.75, true),   -- own half
	}
	local t = autothrow.tune
	local n, cx, cy = read.lyingNear(s, t.basketX, t.basketY)
	expect.eq(n, 2)
	expect.near(cx, 1.8, 1e-12)
	expect.near(cy, 4.9, 1e-12)
	expect.eq(read.innermostLying(s, 1).id, "b")
	expect.eq(read.innermostLying(s, -1).id, "d")
	n, cx, cy = read.lyingNear(setup {}, t.basketX, t.basketY)
	expect.eq(n, 0)
	expect.eq(cx, nil)
	expect.eq(read.innermostLying(setup { k("c", "B", 1.5, 4.9) }, 1), nil)
end)

test("a clear spot: inside the allowed part, off every kubb, with none short of it in its lane", function()
	local t = autothrow.tune
	local s = setup {}
	expect.truthy(read.spotClear(s, 1.9, 4.75, 0.12), "an empty half")
	expect.truthy(not read.spotClear(s, t.spotMaxX + 0.01, 4.75, 0.12), "too near the sideline")
	expect.truthy(not read.spotClear(s, 1.9, t.spotMinY - 0.01, 0.12), "too near the centre line")
	s = setup { k("on", "B", 1.9, 4.75, true) }
	expect.truthy(not read.spotClear(s, 1.95, 4.8, 0.12), "on a kubb")
	expect.truthy(read.spotClear(s, 1.95, 4.8, 0.12, s.pieces[1]), "on the kubb left out")
	-- short of the spot in its lane: a lying kubb within shortLying, a standing one within spotShortStanding
	s = setup { k("short", "B", 1.9, 4.55, true) }
	expect.truthy(not read.spotClear(s, 1.9, 4.75, 0.3), "a lying kubb 0.2 short, shortLying 0.3")
	expect.truthy(read.spotClear(s, 1.9, 4.75, 0.12), "a lying kubb 0.2 short, shortLying 0.12")
	s = setup { k("short", "B", 1.9, 4.35) }
	expect.truthy(not read.spotClear(s, 1.9, 4.75, 0.12), "a standing kubb 0.4 short")
	expect.truthy(read.spotClear(s, 1.9 + t.spotLane + 0.01, 4.75, 0.12), "out of the lane")
	expect.truthy(read.spotClear(setup { k("own", "A", 1.9, 4.75, true) }, 1.9, 4.75, 0.12), "own half")
end)

test("a front kubb's lane: standing field targets close across and not far behind", function()
	local s = setup({
		k("f", "B", 0.5, 5.0),
		k("in1", "B", 0.55, 5.3), k("in2", "B", 0.46, 5.55),
		k("wide", "B", 0.6, 5.2),    -- 0.1 across: out of the lane
		k("deep", "B", 0.5, 5.7),    -- 0.7 behind: past laneDeep
		k("front", "B", 0.5, 4.9),   -- in front of f, not behind it
		k("base", "B", 0.5, 5.1, false, "base"),
	}, { kind = "baton", targets = { "f", "in1", "in2", "wide", "deep", "front", "base", "gone" } })
	local pos = read.byId(s)
	expect.eq(pos.in1, s.pieces[2])
	local n, lo, hi = read.lane(s, pos, pos.f)
	expect.eq(n, 3)
	expect.near(lo, 0.46, 0)
	expect.near(hi, 0.55, 0)
	n = read.lane(s, pos, pos.front)
	expect.eq(n, 3, "front, f and in1 (in2 is 0.65 behind it)")
	n = read.lane(s, pos, pos.deep)
	expect.eq(n, 1, "itself")
end)
