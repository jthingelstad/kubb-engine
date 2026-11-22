-- Kubb on kubb (0.18): how a blow passes from one standing kubb to the next. Columns of
-- kubbs face to face along the throw and a few piles of the kind a throw-in leaves,
-- struck by a baton or by the front kubb itself set moving as a blow leaves it (no baton:
-- kubb on kubb alone). Read by tools/columnprobe.lua (our engine), by tools/mjref
-- (`export.lua <dir> --cases column`, the same cases in MuJoCo) and by
-- tests/lua/test_column.lua (the column of six, pinned against MuJoCo's band).
--
-- Frame: the front kubb's centre at (0, 0) on the ground, y away from the thrower, x to
-- the right; every kubb stands square (faces along x and y) unless a layout gives yaw.
-- A kubb is 7 cm square, so a column's step is 0.07 + gap.
local C = {}

C.kubb = 0.07

-- layouts: name -> list of { x, y [, yaw degrees] }
C.layouts = {}
local function column(n, gap)
	local pts = {}
	for k = 1, n do pts[k] = { 0, (k - 1) * (C.kubb + gap) } end
	return pts
end
C.gaps = { 0, 0.002, 0.005, 0.02 }
for _, n in ipairs { 3, 6 } do
	for _, gap in ipairs(C.gaps) do
		C.layouts[string.format("col%d-%g", n, gap)] = column(n, gap)
	end
end
-- a lone kubb, struck the same ways and by slower batons too, near where it stops
-- falling (`C.lone`; 0.18: where a baton's blow lands on the face)
C.layouts["col1"] = column(1, 0)
C.lone = { v = { 0.5, 0.7, 0.9, 1.1, 1.4 }, turn = { 0, 6 }, low = { 0.03, 0.045, 0.08 } }
-- piles (each kubb 2 mm or so from its neighbours, as kubbs thrown in and raised
-- toward each other stand)
C.layouts["block2x3"] = { { -0.072, 0 }, { 0, 0 }, { 0.072, 0 }, { -0.072, 0.072 }, { 0, 0.072 }, { 0.072, 0.072 } }
C.layouts["pile7"] = { { 0, 0 }, { -0.073, 0.073 }, { 0, 0.073 }, { 0.073, 0.073 }, { -0.073, 0.146 }, { 0, 0.146 },
	{ 0.073, 0.146 } }
C.layouts["fence4"] = { { -0.108, 0 }, { -0.036, 0 }, { 0.036, 0 }, { 0.108, 0 } }
C.layouts["wedge5"] = { { 0, 0 }, { -0.045, 0.074 }, { 0.045, 0.074 }, { -0.02, 0.153, 12 }, { 0.07, 0.152, -8 } }
C.layouts["line3-8cm"] = { { 0, 0 }, { 0, 0.15 }, { 0, 0.30 } }

-- A standing kubb with a kubb lying behind it (0.18, the owner's report of 2026-11-22: a
-- front kubb struck on its top edge tipped onto the kubb lying behind it and stood): the
-- lying kubb `gap` m behind the standing one's back face, its long axis across the throw
-- (square) or turned 30 degrees (skew), one of them or two (the second beside the first,
-- across). With none behind it (count 0), the same blows on a lone kubb.
-- The baton comes down at 20 degrees, leaning back 21 degrees and turning end over end
-- at `turn` rad/s, as the report's did, its lowest point `below` m under the kubb's top
-- edge as it reaches the face (a graze of the top edge, 2 to 12 mm), straight or `dx` m to
-- the side of the kubb's middle, the struck kubb square to the throw or turned `yaw` degrees
-- (a corner toward the baton, as the report's stood).
C.brace = { gaps = { 0.04, 0.08, 0.12 }, skews = { 0, 30 }, counts = { 0, 1, 2 },
	v = { 6, 8.6, 11 }, turn = { 0, 5 }, below = { 0.002, 0.006, 0.012 }, dx = { 0, 0.03, 0.045 }, yaw = { 0, 40 } }

-- The strikes. A baton flies level along +y, upright, the lower end of its segment `low`
-- m above the ground (0.045: plan.aimZFor's height, 0.3 of the way up a kubb; the
-- baton's round end reaches 2.2 cm lower), 5 cm short of the
-- front face, at v m/s, turning end over end at `turn` rad/s (top end forward) or not.
C.baton = { v = { 6, 9, 12 }, turn = { 0, 12 }, low = { 0.03, 0.045, 0.08 } }
-- A kubb pushed, no baton: the front kubb as a horizontal blow J (N s) along +y at
-- height h (m) on its back face leaves it (tools/mjref's `struck`).
C.push = { J = { 0.3, 0.6, 1.0 }, h = { 0.04, 0.10, 0.14 } }
-- Piles: a baton at the aim height, 9 or 12 m/s, turning or not, across the front
-- kubb's face at x offsets.
C.pile = { v = { 9, 12 }, turn = { 0, 12 }, dx = { -0.03, 0, 0.03 } }
return C
