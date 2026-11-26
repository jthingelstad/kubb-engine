-- The throw to go's verdict and distance (core/togo), and raising in any order
-- (core/rules raiseOptions, canRaise, raiseKubb; 1.4.0).
import "core/rules"
import "core/togo"
import "core/body"
import "core/pitch"
local rules, togo = tw.rules, tw.togo

test("togo.decide: closer wins, a felled king loses, both felled or a tie is thrown again", function()
	local d = togo.decide { A = { gap = 0.30 }, B = { gap = 0.41 } }
	expect.eq(d.first, "A"); expect.eq(d.how, "closer")
	d = togo.decide { A = { gap = 0.9 }, B = { gap = 0.1 } }
	expect.eq(d.first, "B")
	d = togo.decide { A = { gap = 0, toppled = true }, B = { gap = 2 } }
	expect.eq(d.first, "B"); expect.eq(d.how, "king")
	d = togo.decide { A = { gap = 3 }, B = { gap = 0, toppled = true } }
	expect.eq(d.first, "A"); expect.eq(d.how, "king")
	d = togo.decide { A = { gap = 0, toppled = true }, B = { gap = 0, toppled = true } }
	expect.eq(d.first, nil); expect.eq(d.how, "again"); expect.eq(d.why, "both king")
	-- equal to the millimetre is a tie; a millimetre apart is not
	d = togo.decide { A = { gap = 0.2501 }, B = { gap = 0.2504 } }
	expect.eq(d.how, "again"); expect.eq(d.why, "tie")
	d = togo.decide { A = { gap = 0.2510 }, B = { gap = 0.2499 } }
	expect.eq(d.first, "B")
	-- touching (0) against touching: a tie
	expect.eq(togo.decide { A = { gap = 0 }, B = { gap = 0 } }.why, "tie")
end)

test("togo.gap: from the baton's nearest part to the king's side, never below 0", function()
	local k = tw.pitch.king
	local kb = tw.body.kinds.baton
	local half = tw.pitch.kingSide / 2
	-- a baton lying across the pitch (its axis along x: a quarter turn about y), 1 m short
	local s = math.sqrt(0.5)
	local res = { bodies = { king = { x = k.x, y = k.y }, togoA = { x = k.x, y = k.y - 1, qw = s, qx = 0, qy = s, qz = 0 } } }
	local g, top = togo.gap(res, "togoA")
	expect.near(g, 1 - kb.r - half, 1e-9)
	expect.eq(top, false)
	-- lying along the pitch, pointing at the king: the near cap counts
	res.bodies.togoA = { x = k.x, y = k.y - 1, qw = s, qx = s, qy = 0, qz = 0 }
	g = togo.gap(res, "togoA")
	expect.near(g, 1 - kb.hl - kb.r - half, 1e-9)
	-- against the king: 0, and a felled king is reported
	res.bodies.togoA = { x = k.x + 0.02, y = k.y, qw = 1, qx = 0, qy = 0, qz = 0 }
	res.toppled = { "king" }
	g, top = togo.gap(res, "togoA")
	expect.eq(g, 0); expect.eq(top, true)
	expect.eq(togo.mm(0.12345), 123)
	expect.eq(togo.text({ A = { gap = 0.5 }, B = { toppled = true } }, nil, 2),
		"throw to go: Team A 0.50 m, Team B king down; 2 rounds")
end)

-- Turn 1: A misses twice. Turn 2: B topples a1 and a2. Turn 3: A tosses both into B's
-- half, each landing lying; B raises them.
local function twoLying()
	local g = rules.new {
		teams = { A = { name = "Jamie", players = { { name = "Jamie" } } },
			B = { name = "Playdate", players = { { name = "Club" } } } },
	}
	g:throwBaton({}); g:throwBaton({})
	g:throwBaton { toppled = { "a1" } }; g:throwBaton { toppled = { "a2" } }; g:throwBaton({}); g:throwBaton({})
	g:toss { rest = { x = -1, y = 6, standing = false, angle = 0 }, moved = {} }
	g:toss { rest = { x = 1, y = 5.5, standing = false, angle = math.pi / 2 }, moved = {} }
	return g
end

test("raise in any order: every lying kubb is listed, and the second may go first", function()
	local g = twoLying()
	expect.eq(g.phase, "raise")
	local n = g:need()
	expect.eq(n.kind, "raise")
	expect.eq(table.concat(n.lying, ","), "a1,a2")
	expect.eq(n.kubb, "a1", "need().kubb is still the first")
	expect.eq(#g:lyingKubbs(), 2)
	local dec = g:raiseOptions("a2")
	expect.truthy(dec and #dec.choices >= 1)
	local ok, i = g:canRaise("a2", dec.choices[1].which)
	expect.truthy(ok); expect.eq(i, 1)
	expect.eq(select(2, g:canRaise("a2", "nowhere")), "that end")
	expect.eq(select(2, g:canRaise("b1")), "not lying")
	g:raiseKubb("a2", dec.choices[1].which)
	expect.truthy(g.kubbs.a2.pose.standing)
	expect.eq(g.phase, "raise")
	n = g:need()
	expect.eq(table.concat(n.lying, ","), "a1", "recomputed after the raise")
	expect.eq(select(2, g:canRaise("a2")), "not lying", "a stale raise of a2")
	g:raiseKubb("a1")
	expect.eq(g.phase, "batons")
	expect.eq(select(2, g:canRaise("a1")), "not raising")
end)

test("raise with no kubb named is as before: the first lying one", function()
	local g = twoLying()
	g:raise(nil, "first")
	expect.truthy(g.kubbs.a1.pose.standing)
	expect.truthy(not g.kubbs.a2.pose.standing)
end)
