-- Positions on the pitch in the game file (Planet Kubb Notation 2's position
-- lines): the frame conversion, what the engine records, which lines the file
-- writes and when, and saves from before and after.
import "core/rules"
import "core/notation"
import "core/camera"
import "core/save"
import "core/pitch"
local rules, notation, camera, save, pitch = tw.rules, tw.notation, tw.camera, tw.save, tw.pitch

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local thrower = dofile(here .. "/../../tools/thrower.lua")
local placedTurn = dofile(here .. "/placed.lua")

local function newGame(players)
	return rules.new {
		teams = { A = { name = "Jamie", players = players or { { name = "Jamie" } } },
			B = { name = "Playdate", players = { { name = "Club" } } } },
	}
end
local MISS = {}
local function topple(...) return { toppled = { ... } } end
local function land(x, y, a)
	return { rest = { x = x, y = y, standing = a == "stand", angle = type(a) == "number" and a or 0 }, moved = {} }
end
local function line(g, n) return notation.turnLine(g.sheet.turns[n or g.turn]) end
local function placed(g, n) return placedTurn(g.sheet.turns[n or g.turn]) end
local function batons(g, list) for _, o in ipairs(list) do g:throwBaton(o) end end
-- Turn 1: A misses twice. Turn 2: B topples a1 and a2. Turn 3: A to throw them in.
local function toTurn3(g)
	batons(g, { MISS, MISS })
	batons(g, { topple("a1"), topple("a2"), MISS, MISS })
	expect.eq(g.turn, 3)
	return g
end
-- The rendered file's lines under turn n (its position lines).
local function under(g, n)
	local text = notation.render(g, {})
	local out, inTurn = {}, false
	for l in text:gmatch("([^\n]*)\n") do
		if l:match("^%d+%.") then inTurn = l:match("^(%d+)%.") == tostring(n)
		elseif inTurn then out[#out + 1] = l end
	end
	return table.concat(out, "\n")
end

local function at(x, y, half)
	local a, d = notation.toPitch(x, y, half)
	return a, d
end

test("frame: the corners, the centre line, the king and both baselines", function()
	-- the origin is the centre-line stake on Team A's left (engine x = -2.5, y = 4);
	-- across runs to the other stake (x = 2.5), depth from the centre line to a baseline
	local a, d = at(-2.5, 4, "A"); expect.near(a, 0, 1e-12); expect.near(d, 0, 1e-12)
	a, d = at(2.5, 4, "B"); expect.near(a, 5, 1e-12); expect.near(d, 0, 1e-12)
	-- the four corners: depth 4 at both baselines, the same in both halves
	a, d = at(-2.5, 0, "A"); expect.near(a, 0, 1e-12); expect.near(d, 4, 1e-12)
	a, d = at(2.5, 0, "A"); expect.near(a, 5, 1e-12); expect.near(d, 4, 1e-12)
	a, d = at(-2.5, 8, "B"); expect.near(a, 0, 1e-12); expect.near(d, 4, 1e-12)
	a, d = at(2.5, 8, "B"); expect.near(a, 5, 1e-12); expect.near(d, 4, 1e-12)
	-- the king, on the centre line in the middle
	expect.eq(notation.point(pitch.king.x, pitch.king.y, "A"), "2.50,0.00")
	expect.eq(notation.point(pitch.king.x, pitch.king.y, "B"), "2.50,0.00")
	-- the base kubbs: a1..a5 at x = -2..2 on Team A's baseline, b1..b5 on Team B's
	for i, x in ipairs(pitch.baseX) do
		expect.eq(notation.point(x, pitch.baseline.A, "A"), ("%.2f,4.00"):format(i - 0.5))
		expect.eq(notation.point(x, pitch.baseline.B, "B"), ("%.2f,4.00"):format(i - 0.5))
	end
	-- a point a metre from the centre line is depth 1 in either half
	expect.eq(notation.point(0.25, 3, "A"), "2.75,1.00")
	expect.eq(notation.point(0.25, 5, "B"), "2.75,1.00")
	-- and back
	local x, y = notation.fromPitch(2.75, 1, "A"); expect.near(x, 0.25, 1e-12); expect.near(y, 3, 1e-12)
	x, y = notation.fromPitch(2.75, 1, "B"); expect.near(x, 0.25, 1e-12); expect.near(y, 5, 1e-12)
	x, y = notation.fromPitch(0, 4, "B"); expect.near(x, -2.5, 1e-12); expect.near(y, 8, 1e-12)
end)

test("frame: across runs left to right as Team A sees the pitch from its baseline", function()
	-- the aim camera on Team A's baseline puts b1 (x = -2) left of the screen's
	-- middle and b5 (x = 2) right of it, and b1 has the smaller across
	local c = camera.new()
	camera.aim(c, 0, pitch.baseline.A, 0)
	local sx1 = camera.project(c, pitch.baseX[1], pitch.baseline.B, 0)
	local sx5 = camera.project(c, pitch.baseX[5], pitch.baseline.B, 0)
	expect.truthy(sx1 < c.cx and sx5 > c.cx, "b1 on the left, b5 on the right")
	expect.truthy(at(pitch.baseX[1], 8, "B") < at(pitch.baseX[5], 8, "B"))
end)

test("frame: points round to the centimetre, half way to even; no minus sign, nothing outside the half", function()
	expect.eq(notation.point(1.125 - 2.5, 4, "B"), "1.12,0.00")   -- 1.125 is exact in binary: to even
	expect.eq(notation.point(1.375 - 2.5, 4, "B"), "1.38,0.00")
	expect.eq(notation.point(-2.5 - 0.004, 4 + 0.004, "A"), "0.00,0.00", "a hair over a line rounds onto it, not to -0.00")
	expect.eq(notation.point(2.504, 8.004, "B"), "5.00,4.00")
	expect.eq(notation.point(0, 3.9, "B"), nil, "a kubb of half b over the centre line has no point there")
	expect.eq(notation.point(-2.6, 6, "B"), nil, "nor one off the side")
	expect.eq(notation.point(0, 8.006, "B"), nil, "nor one behind the baseline")
end)

test("positions: the sheet keeps each kubb on the token of the player who threw it, in the order of its last throw", function()
	local g = toTurn3(newGame { { name = "Jamie" }, { name = "Kim" } })
	g:toss(land(0, 8.4, 0), "jamie")     -- a1 over the baseline: rethrown
	g:toss(land(1, 6, "stand"), "kim")   -- a2 in, standing
	g:toss(land(-1, 7, "stand"), "kim")  -- a1 rethrown by kim
	expect.eq(g.phase, "batons")
	expect.eq(placed(g), "3. jamie:I kim:IR (@ 3.50,2.00 1.50,3.00)")
	-- the file: one pitch line for the half thrown into, in the canonical order
	expect.eq(line(g), "3. jamie:I kim:IR")
	expect.eq(under(g, 3), "@b 1.50,3.00 3.50,2.00")
end)

test("positions: a game that ends mid-inkast writes none for it", function()
	-- a kubb that topples the king: E, every due kubb counted, no raising, no positions
	local g = toTurn3(newGame())
	g:toss(land(0, 6, "stand"))
	g:toss { rest = { x = 0.2, y = 4.1, standing = false, angle = 0 }, moved = {}, kingToppled = true }
	expect.eq(g.phase, "over")
	expect.eq(line(g), "3. jamie:2IE X X X X X X # king toppled by a thrown kubb")
	expect.eq(under(g, 3), "")
	-- a resign before the inkast is done: none either
	g = toTurn3(newGame())
	g:toss(land(0, 6, "stand"))
	g:resign("A")
	expect.eq(line(g), "3. jamie:2I jamie:G X X X X X X # resigned during the inkast")
	expect.eq(under(g, 3), "")
end)

test("positions: a felled word is where its kubbs stood, field then base; an early base kubb and the king have none", function()
	local g = toTurn3(newGame())
	g:toss(land(0, 6, "stand")); g:toss(land(1, 6, "stand"))
	-- a1 and the base kubb b1 (raised again, II.B.4a): F with a1's place only
	batons(g, { topple("a1", "b1"), MISS, topple("a2", "b2") })
	expect.eq(placed(g), "3. jamie:2I (@ 2.50,2.00 3.50,2.00) jamie:F (@ 2.50,2.00) jamie:- jamie:FB (@ 3.50,2.00 1.50,4.00)"
		.. " # b1 toppled a base kubb early; raised (II.B.4a)")
	expect.eq(under(g, 3), "@b 2.50,2.00 3.50,2.00\n*b 2.50,2.00 - 3.50,2.00+1.50,4.00")
	-- a turn of misses only has no felled line
	g = newGame()
	batons(g, { MISS, MISS })
	expect.eq(under(g, 1), "")
end)

test("positions: no pitch line when a kubb stands from an earlier turn or a punishment kubb was placed", function()
	-- turn 3 leaves a2 standing in half b; turn 5's inkast joins it: no pitch line,
	-- and the felled words are still written
	local g = toTurn3(newGame())
	g:toss(land(0, 6, "stand")); g:toss(land(1, 6, "stand"))
	batons(g, { topple("a1"), MISS, MISS, MISS, MISS, MISS })   -- a2 stays
	g:toss(land(0, 2, "stand"))                                 -- 4: B throws a1 back in ...
	batons(g, { topple("a1"), topple("a3"), MISS, MISS, MISS, MISS })   -- ... and takes it and a3
	expect.eq(g.turn, 5)
	g:toss(land(-1, 7, "stand")); g:toss(land(0.5, 7, "stand"))
	expect.eq(g.phase, "batons")
	expect.eq(line(g), "5. jamie:2I")
	batons(g, { topple("a2"), topple("a1") })
	expect.eq(under(g, 5), "*b 3.50,2.00 1.50,3.00")
	-- a punishment kubb: the sheet does not say which kubb is the P
	g = toTurn3(newGame())
	g:toss(land(0, 8.4, 0)); g:toss(land(1, 6, "stand")); g:toss(land(0, 8.4, 0))
	g:autoPunishment()
	expect.eq(line(g), "3. jamie:2IRP")
	expect.eq(under(g, 3), "")
end)

test("positions: a felled field kubb that an earlier baton moved is -, so the pitch line still finds every felled kubb", function()
	local g = toTurn3(newGame())
	g:toss(land(0, 6, "stand")); g:toss(land(1, 6, "stand"))
	-- b1 pushes a2 along without toppling it; b2 topples it where it now stands
	batons(g, { { moved = { a2 = { x = 1.2, y = 6.3, standing = true, angle = 0 } } }, topple("a2"), topple("a1") })
	expect.eq(placed(g), "3. jamie:2I (@ 2.50,2.00 3.50,2.00) jamie:- jamie:F (@ 3.70,2.30) jamie:F (@ 2.50,2.00)")
	expect.eq(under(g, 3), "@b 2.50,2.00 3.50,2.00\n*b - - 2.50,2.00")
end)

-- A saved match as JSON would give it back.
local function roundTrip(m)
	return save.unpack(save.plain(save.plain(save.pack(m, nil))))
end

test("positions: a save keeps them, and a save from before positions still loads", function()
	local g = toTurn3(newGame())
	g:toss(land(0, 6, "stand")); g:toss(land(1, 6, "stand"))
	batons(g, { topple("a1") })
	local want = placed(g)
	local back = roundTrip { game = g, start = {}, mode = "Pass and Play", turn = g.turn, tossed = 2 }
	expect.eq(placed(back.game), want, "positions round-trip")
	back.game:throwBaton(topple("a2"))
	expect.eq(placed(back.game), want .. " jamie:F (@ 3.50,2.00)", "and the game plays on with them")
	expect.eq(under(back.game, 3), "@b 2.50,2.00 3.50,2.00\n*b 2.50,2.00 3.50,2.00")

	-- before positions: no inkastAt, no baton at, no inkBy or tossSeq on kubbs
	local function strip(t)
		if type(t) ~= "table" then return end
		t.inkastAt, t.at, t.inkBy, t.tossSeq = nil, nil, nil, nil
		for _, v in pairs(t) do strip(v) end
	end
	g = toTurn3(newGame())
	g:toss(land(0, 6, "stand"))                         -- mid-inkast when saved
	local d = save.plain(save.pack({ game = g, start = {}, turn = g.turn, tossed = 1 }, nil))
	strip(d)
	local old = save.unpack(d)
	expect.truthy(old, "an old save unpacks")
	expect.eq(line(old.game), "3. jamie:I")
	old.game:toss(land(1, 6, "stand"))
	-- its one inkaster gets both; the kubb thrown before the save has no
	-- throw order and comes first
	expect.eq(placed(old.game), "3. jamie:2I (@ 2.50,2.00 3.50,2.00)")
	-- a whole save from before positions renders, with no position lines for them
	local older = save.plain(save.pack({ game = toTurn3(newGame()), start = {}, turn = 3, tossed = 0 }, nil))
	strip(older)
	local text = notation.render(save.unpack(older).game, {})
	expect.truthy(text:find("\n2. B B - -\n3.\n", 1, true) ~= nil, text)
end)

-- An inkast's kubbs stand raised or placed in the half they were thrown at.
-- A baton's stood where they were before it, which is on the pitch but not
-- always in their half: an earlier baton can push a kubb over the centre
-- line without toppling it (II.B.7 keeps it where it came to rest).
test("positions: in 60 random games the sheet's places are on the pitch, and the file writes them as they are", function()
	local kept = { inkast = 0, baton = 0 }
	local wrote = { pitch = 0, felled = 0, turns = 0 }
	for seed = 1, 60 do
		local g = thrower.playGame(seed)
		for _, t in ipairs(g.sheet.turns) do
			local def = t.side == "A" and "B" or "A"
			local function check(list, most, what, inHalf)
				if not list then return 0 end
				if #list > most then error(("seed %d turn %d: %d positions for %s"):format(seed, t.n, #list, what)) end
				for _, p in ipairs(list) do
					if not (inHalf and pitch.inHalf(def, p.x, p.y) or not inHalf and pitch.onPitch(p.x, p.y)) then
						error(("seed %d turn %d: %s position %.2f,%.2f not in half %s"):format(seed, t.n, what, p.x, p.y, def))
					end
				end
				return #list
			end
			for _, pid in ipairs(t.inkastOrder) do
				local k = t.inkast[pid]
				local most = k.I + k.R + k.P + k.Q + math.min(k.N, 5)
				kept.inkast = kept.inkast + check(t.inkastAt and t.inkastAt[pid], most, pid .. " inkast", true)
			end
			for _, b in ipairs(t.batons) do
				local f, nb = notation.batonParts(b.token)
				kept.baton = kept.baton + check(b.at, f + nb, b.token)
				if b.at then expect.eq(#b.at, f + nb, "a baton keeps every kubb it counts") end
			end
		end
		-- every point the file writes is one the sheet kept, in the half under attack
		local text = notation.render(g, {})
		local n = 0
		for l in text:gmatch("([^\n]*)\n") do
			local tn = l:match("^(%d+)%.")
			if tn then n = tonumber(tn); wrote.turns = wrote.turns + 1 end
			local mark, h, rest = l:match("^([@*])([ab]) (.*)$")
			if mark then
				local t = g.sheet.turns[n]
				local def = t.side == "A" and "B" or "A"
				expect.eq(h, def:lower(), "a line for the half under attack")
				local kept = {}
				local function keep(list) for _, p in ipairs(list or {}) do kept[notation.point(p.x, p.y, def) or "?"] = true end end
				if mark == "@" then
					wrote.pitch = wrote.pitch + 1
					for _, pid in ipairs(t.inkastOrder) do keep(t.inkastAt[pid]) end
				else
					wrote.felled = wrote.felled + 1
					for _, b in ipairs(t.batons) do keep(b.at) end
				end
				for p in rest:gmatch("[%d.,]+") do
					expect.truthy(kept[p], ("seed %d turn %d: %s written, not kept"):format(seed, n, p))
				end
			end
		end
	end
	expect.truthy(kept.inkast > 500 and kept.baton > 300,
		("positions kept: %d inkast, %d baton"):format(kept.inkast, kept.baton))
	expect.truthy(wrote.pitch > 100 and wrote.felled > 200,
		("lines written: %d pitch, %d felled in %d turns"):format(wrote.pitch, wrote.felled, wrote.turns))
end)
