-- The Kid rules (0.15.0, core/rules rules.kid; docs/notes/kid-mode.md): three base kubbs,
-- every kubb and baton at a kubb from the Kid line, an early king stood back up, no
-- punishment kubbs, no illegal throws. A game with no rules is the standard one.
import "core/rules"
import "core/notation"
import "core/raising"
import "core/match"
import "core/save"
import "core/cards"
local rules, notation, raising, match, save, pitch = tw.rules, tw.notation, tw.raising, tw.match, tw.save, tw.pitch

local function newGame(o)
	o = o or {}
	return rules.new {
		teams = { A = { name = "Jamie", players = { { name = "Jamie" } } },
			B = { name = "Playdate", players = { { name = "Kid" } } } },
		opening = o.opening, first = o.first, rules = o.rules == nil and "kid" or o.rules or nil,
	}
end

local MISS = {}
local function topple(...) return { toppled = { ... } } end
local function land(x, y, a, extra)
	local o = { rest = { x = x, y = y, standing = a == "stand", angle = type(a) == "number" and a or 0 }, moved = {} }
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end
local function line(g, n) return notation.turnLine(g.sheet.turns[n or g.turn], (notation.fileIds(g.teams))) end
local function misses(g, n) for _ = 1, n do g:throwBaton(MISS) end end

-- Turn 1: A misses twice. Turn 2: B topples a1 and a2. Turn 3: A throws them in.
local function toTurn3(g)
	misses(g, 2)
	g:throwBaton(topple("a1")); g:throwBaton(topple("a2")); misses(g, 2)
	expect.eq(g.turn, 3)
	return g
end

test("kid: three base kubbs a side, the middle three spots", function()
	local g = newGame()
	expect.eq(g.rules, "kid")
	expect.eq(#g:baseKubbs("A"), 3)
	expect.eq(#g:baseKubbs("B"), 3)
	expect.eq(g:census().total, 6)
	expect.eq(g.kubbs.a1.pose.x, -1); expect.eq(g.kubbs.a2.pose.x, 0); expect.eq(g.kubbs.a3.pose.x, 1)
	expect.eq(g.kubbs.b3.pose.y, 8)
	expect.eq(g.kubbs.a4, nil)
	local std = newGame { rules = false }
	expect.eq(std.rules, nil, "no rules: the standard game, as before 0.15")
	expect.eq(#std:baseKubbs("A"), 5)
end)

test("kid: batons at kubbs from the Kid line, the king from the baseline", function()
	local g = newGame()
	local n = g:need()
	expect.eq(n.kind, "baton"); expect.eq(n.throwY, 2, "Team A's Kid line, 2 m out")
	misses(g, 2)
	expect.eq(g:need().throwY, 6, "Team B's")
	-- A's three base kubbs down: B's king shot is from its baseline
	g:throwBaton(topple("a1", "a2", "a3"))
	misses(g, 3)
	expect.eq(g.turn, 3)
	-- A throws the three back in, standing deep in B's half
	g:toss(land(-1, 7.5, "stand")); g:toss(land(0.5, 7.5, "stand")); g:toss(land(1.5, 7.5, "stand"))
	expect.eq(g:need().throwY, 2)
	g:throwBaton(topple("a1", "a2", "a3"))
	g:throwBaton(topple("b1", "b2", "b3"))
	local k = g:need()
	expect.truthy(k.kingShot); expect.eq(k.throwY, 0, "the king shot from the baseline")
end)

test("kid: the advantage line wins when it is nearer the middle than the Kid line", function()
	local g = toTurn3(newGame())
	-- a1 stands 3 m out in B's half (y = 5), a2 deep
	g:toss(land(0.5, 5, "stand")); g:toss(land(-1.5, 7.5, "stand"))
	misses(g, 6)
	-- B's turn: a1 left standing at y = 5, 3 m from B's baseline: further than the Kid line
	expect.eq(g.turn, 4)
	expect.eq(g:need().throwY, 5)
	expect.eq(g.sheet.turns[4].advantage, 3, "the sheet marks the advantage line as kubb.js wants")
	local g2 = toTurn3(newGame())
	g2:toss(land(0.5, 7.5, "stand")); g2:toss(land(-1.5, 7.5, "stand"))
	misses(g2, 6)
	expect.eq(g2:need().throwY, 6, "a kubb left 0.5 m out: the Kid line is nearer the middle")
end)

test("kid: kubbs are thrown in from the Kid line", function()
	local g = toTurn3(newGame())
	local n = g:need()
	expect.eq(n.kind, "toss"); expect.eq(n.throwY, 2)
end)

test("kid: the king knocked down early is stood back up and the turn goes on", function()
	local g = toTurn3(newGame())
	g:toss(land(0.5, 6, "stand")); g:toss(land(-1, 6, "stand"))
	local before = { x = g.king.pose.x, y = g.king.pose.y }
	g:throwBaton({ toppled = { "a1", "king" }, kingToppled = true, moved = { king = { x = 0.4, y = 4.3 } } })
	expect.eq(g.winner, nil)
	expect.eq(g.phase, "batons")
	expect.eq(g.king.pose.x, before.x); expect.eq(g.king.pose.y, before.y)
	expect.truthy(g.king.pose.standing)
	expect.eq(g:need().n, 2, "the next baton")
	expect.eq(line(g), "3. 2I F # b1 knocked the king down early; stood back up (kid rules)")
	-- the king when it may fall is a win as ever
	local s = newGame()
	misses(s, 2)
	s:throwBaton(topple("a1", "a2", "a3")); misses(s, 3)
	s:toss(land(-1, 7.5, "stand")); s:toss(land(0.5, 7.5, "stand")); s:toss(land(1.5, 7.5, "stand"))
	s:throwBaton(topple("a1", "a2", "a3")); s:throwBaton(topple("b1", "b2", "b3"))
	s:throwBaton({ toppled = { "king" }, kingToppled = true })
	expect.eq(s.winner, "A"); expect.eq(s.how, "king")
end)

test("kid: a kubb thrown in that knocks the king down: stood back up, the inkast goes on", function()
	local g = toTurn3(newGame())
	g:toss(land(0.1, 4.2, 0, { kingToppled = true, moved = { king = { x = 0.2, y = 4.4 } } }))
	expect.eq(g.winner, nil)
	expect.eq(g.king.pose.x, 0); expect.eq(g.king.pose.y, 4)
	expect.eq(g:need().kind, "toss")
	g:toss(land(-1, 6, "stand"))
	expect.truthy(line(g):find("# a kubb thrown in knocked the king down; stood back up (kid rules)", 1, true))
	expect.truthy(not line(g):find("E", 1, true), "no E: nobody lost")
end)

test("kid: no illegal throws, a helicopter counts", function()
	local g = newGame()
	g:throwBaton({ illegal = true, toppled = { "b2" } })
	expect.eq(line(g, 1), "1. B # b1 helicopter; counted (kid rules)")
	-- a helicopter that knocks the king down early: stood back up, no loss
	g:throwBaton({ illegal = true, toppled = { "king" }, kingToppled = true })
	expect.eq(g.winner, nil)
	-- the standard rules: Z, as ever
	local s = newGame { rules = false }
	s:throwBaton({ illegal = true, toppled = { "b2" } })
	expect.eq(line(s, 1), "1. Z")
end)

test("kid: a kubb out twice is stood at the fair spot, no punishment kubb, nobody asked", function()
	local g = toTurn3(newGame())
	-- a1 out (over the sideline), a2 in; a1 rethrown and out again
	g:toss(land(3.2, 6, 0)); g:toss(land(0.5, 6, "stand"))
	expect.eq(g:need().kind, "toss"); expect.truthy(g:need().rethrow)
	g:toss(land(3.3, 6.5, 0))
	expect.eq(g:need().kind, "baton", "no punish phase: the engine placed it")
	local k = g.kubbs.a1
	expect.eq(k.where, "pitch"); expect.eq(k.kind, "field"); expect.eq(k.half, "B")
	expect.truthy(k.pose.standing)
	expect.truthy(raising.punishmentCheck(k.pose, g:context("B", "a1")), "a legal spot")
	expect.near(math.abs(k.pose.x), raising.tune.fairAcross, 0.051)
	expect.near(k.pose.y, pitch.center + raising.tune.fairDepth, 0.051)
	local l = line(g)
	expect.truthy(l:find("^3%. 2IR "), l)
	expect.truthy(not l:find("P", 1, true), "no P token")
	expect.truthy(l:find("stood at the fair spot, no punishment kubb (kid rules)", 1, true))
	expect.eq(g.sheet.turns[3].placed, 1)
end)

test("raising.fairSpot: off the king's line, 1 m past the centre line, never on a kubb", function()
	local g = newGame()
	local p = raising.fairSpot(g:context("B"))
	expect.eq(p.y, 5)
	expect.near(p.x, -1, 1e-9, "the left one on a tie")
	local ctx = g:context("A")
	expect.eq(raising.fairSpot(ctx).y, 3)
	-- a kubb on the left point: the right one
	ctx.others[#ctx.others + 1] = { id = "x", pose = { x = -1, y = 5, standing = true, angle = 0 } }
	local ctxB = g:context("B")
	ctxB.others[#ctxB.others + 1] = { id = "x", pose = { x = -1, y = 5, standing = true, angle = 0 } }
	expect.near(raising.fairSpot(ctxB).x, 1, 1e-9)
end)

test("kid: the game file says Base kubbs 3 and the Kid rules in words", function()
	local g = newGame()
	misses(g, 2)
	local text = notation.render(g, { version = "0.15.0" })
	expect.truthy(text:find('[Base kubbs "3"]', 1, true))
	expect.truthy(text:find('[Rules "Kid rules, 2-4-6: three base kubbs;', 1, true))
	local s = notation.render(newGame { rules = false }, { version = "0.15.0" })
	expect.truthy(s:find('[Base kubbs "5"]', 1, true))
	expect.truthy(s:find('[Rules "U.S. Championship 4.0, 2-4-6"]', 1, true))
end)

test("kid: match.setup gives the Kid line and where the thrower may stand", function()
	local m = match.new { start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }, rules = "kid", first = "B" }
	local s = match.setup(m)
	expect.eq(s.kind, "baton"); expect.eq(s.side, "B")
	expect.truthy(s.kid); expect.eq(s.kidY, 2); expect.eq(s.forwardY, 2); expect.eq(s.lineY, 0)
	local std = match.setup(match.new { start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 } })
	expect.eq(std.kid, nil); expect.eq(std.kidY, nil); expect.eq(std.forwardY, 0)
	-- a kid game saved and restored keeps its rules
	local back = save.unpack(save.pack(m, {}))
	expect.eq(back.game.rules, "kid")
	expect.eq(#back.game:baseKubbs("A"), 3)
	-- the cards draw three base slots a side
	local c = tw.cards.handoff and tw.cards.handoff(m, s) or nil
	if c then
		local base = 0
		for _, p in ipairs(c.pieces) do if p.kind == "base" then base = base + 1 end end
		expect.eq(base, 6)
	end
end)

test("kid: the Kid computer throws its kubbs and batons from the Kid line", function()
	import "core/autothrow"
	local autothrow = tw.autothrow
	local s = { kind = "toss", projectile = "kubb", side = "A", kubb = "b1", pieces = {}, lineY = 0, forwardY = 2,
		kid = true, n = 1, of = 1, surface = "grass" }
	local a = autothrow.choose(s, autothrow.rng(5), 1, "kid")
	expect.eq(a.y, 2)
	-- a standard toss: the baseline, whatever forwardY says
	s.kid = nil
	expect.eq(autothrow.choose(s, autothrow.rng(5), 1, "kid").y, 0)
	-- a baton: as far forward as allowed, the setup's forwardY
	local m = match.new { start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }, rules = "kid" }
	local b = match.setup(m)
	expect.eq(autothrow.choose(b, autothrow.rng(5), 1, "kid").y, 2)
	expect.eq(tw.cpu.raisePolicy("kid"), "first")
end)
