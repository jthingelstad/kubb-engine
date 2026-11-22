-- Raising by side (0.12.0): the computer by its level (core/cpu.raising), a person by the
-- engine's advice (cpu.advice), the defender's policy in match.settle
-- (match.raisePolicy), and a match that names no sides raising as before.
import "core/match"
import "core/cpu"
import "core/raising"
import "core/autothrow"
local match, cpu, raising, autothrow = tw.match, tw.cpu, tw.raising, tw.autothrow

local MISS = {}
local function topple(...) return { toppled = { ... } } end
local function land(x, y, a)
	return { rest = { x = x, y = y, standing = a == "stand", angle = type(a) == "number" and a or 0 }, moved = {} }
end

-- A match of one player a side; B's player at `levelB` (nil: none).
local function newMatch(o)
	o = o or {}
	return match.new {
		teams = { A = { name = "Ada", players = { { name = "Ada", level = o.levelA } } },
			B = { name = "Bo", players = { { name = "Bo", level = o.levelB } } } },
		cpu = o.cpu, raising = o.raising, mode = o.mode,
	}
end

-- Turn 3 of a match: A tosses three kubbs into B's half. Two stand, at (1, 5.5) and
-- (1.4, 5.2); the third lies across at (1.15, 5.2), its feet at x 1.04, in line in front
-- of the first standing kubb, and x 1.26, level with the second (the case in
-- test_raising_par). apart takes x 1.04 (farther from the nearest kubb), par x 1.26 (out
-- of the line). Lying at angle 0 its end 1 is x 1.26, so first agrees with par; at angle
-- pi its end 1 is x 1.04, so first agrees with apart. Two ends, three policies: each
-- test below uses the angle that tells apart the two it compares.
local function toRaise(m, angle)
	local g = m.game
	g:throwBaton(MISS); g:throwBaton(MISS)
	g:throwBaton(topple("a1")); g:throwBaton(topple("a2")); g:throwBaton(topple("a3")); g:throwBaton(MISS)
	expect.eq(g.turn, 3)
	g:toss(land(1, 5.5, "stand"))
	g:toss(land(1.4, 5.2, "stand"))
	g:toss(land(1.15, 5.2, angle or 0))
	local n = g:need()
	expect.eq(n.kind, "raise", "a kubb to raise")
	expect.eq(n.side, "B", "B defends")
	expect.eq(n.kubb, "a3")
	expect.eq(#n.decision.choices, 2, "a choice of end")
	return g
end

-- Where match.settle stood a3: its x (1.04 or 1.26).
local function settledX(m)
	match.settle(m)
	local p = m.game.kubbs.a3.pose
	expect.truthy(p.standing, "a3 stands")
	return p.x
end

-- Where each policy would stand it, lying at `angle`.
local function picks(angle)
	local m = newMatch {}
	local g = toRaise(m, angle)
	local n = g:need()
	local ctx = g:context(n.side, n.kubb)
	local out = {}
	for _, name in ipairs { "apart", "par", "first" } do
		out[name] = n.decision.choices[raising.choose(n.decision, ctx, name)].pose.x
	end
	return out
end

test("the computer's raising by level, and a person's", function()
	expect.eq(cpu.raisePolicy("beginner"), "first")
	expect.eq(cpu.raisePolicy("club"), "apart")
	expect.eq(cpu.raisePolicy("pro"), "par")
	expect.eq(cpu.raisePolicy(nil), cpu.raising[autothrow.tune.level], "no level: autothrow.tune.level's")
	expect.eq(cpu.raisePolicy("kid"), "first", "kid raises simply (0.15.0)")
	expect.eq(cpu.raisePolicy("toddler"), "apart", "a level it does not name raises apart")
	expect.eq(cpu.advice, "par", "a person: the engine's best advice")
	for level, name in pairs(cpu.raising) do
		expect.truthy(raising.policies[name], level .. "'s policy " .. name .. " is the engine's")
	end
	expect.truthy(tw.plays["raise.par"], "raise.par is a play the computer carries out")
	expect.eq(tw.plays["raise.par"].levels[1], "pro")
end)

test("match.raisePolicy: which side the computer plays decides, its level picks", function()
	-- named sides, a list or a set
	local m = newMatch { cpu = { "B" }, levelB = "pro", levelA = "beginner" }
	expect.eq(type(match.raisePolicy(m, "B")), "function", "the computer: cpu.raise at its level")
	expect.eq(match.raisePolicy(m, "A"), "par", "a person, whatever their own level")
	m = newMatch { cpu = { B = true } }
	expect.eq(match.raisePolicy(m, "A"), "par")
	expect.eq(type(match.raisePolicy(m, "B")), "function")
	-- no computer at all: both persons
	m = newMatch { cpu = {} }
	expect.eq(match.raisePolicy(m, "A"), "par")
	expect.eq(match.raisePolicy(m, "B"), "par")
	-- the Playdate's VS PLAYDATE: Team B is the computer
	m = newMatch { mode = "Vs Playdate" }
	expect.eq(match.raisePolicy(m, "A"), "par")
	expect.eq(type(match.raisePolicy(m, "B")), "function")
	-- nothing said: the game's own policy (nil to Game:raise)
	m = newMatch {}
	expect.eq(match.raisePolicy(m, "A"), nil)
	expect.eq(match.raisePolicy(m, "B"), nil)
	expect.eq(m.game.raisePolicy, "apart")
	-- named outright: it wins
	m = newMatch { cpu = { "B" }, raising = { B = "together" } }
	expect.eq(match.raisePolicy(m, "B"), "together")
	expect.eq(match.raisePolicy(m, "A"), "par")
	expect.eq(match.sideLevel(newMatch { levelB = "club" }, "B"), "club")
	expect.eq(match.sideLevel(newMatch {}, "B"), nil)
end)

test("match.settle raises with the defender's policy", function()
	local p0, pi_ = picks(0), picks(math.pi)
	expect.near(p0.apart, 1.04, 1e-9, "apart: the foot farther from the nearest kubb")
	expect.near(p0.par, 1.26, 1e-9, "par: out of the first kubb's line")
	expect.near(p0.first, 1.26, 1e-9, "first, lying at angle 0: end 1")
	expect.near(pi_.first, 1.04, 1e-9, "first, lying at angle pi: end 1")
	-- the computer defends, by its level: pro against club where par and apart differ,
	-- beginner against club where first and apart differ
	for _, c in ipairs { { "pro", 0, p0.par }, { "club", 0, p0.apart }, { "beginner", 0, p0.first },
		{ "pro", math.pi, pi_.par }, { "club", math.pi, pi_.apart }, { "beginner", math.pi, pi_.first } } do
		local m = newMatch { cpu = { "B" }, levelB = c[1] }
		toRaise(m, c[2])
		expect.near(settledX(m), c[3], 1e-9, c[1] .. " stands it by " .. cpu.raising[c[1]] .. " (angle " .. c[2] .. ")")
	end
	-- the attacker's level and kind do not matter: B, a person, gets the advice even when
	-- A is the computer at beginner
	local m = newMatch { cpu = { "A" }, levelA = "beginner" }
	toRaise(m)
	expect.near(settledX(m), p0.par, 1e-9, "a person's automatic raise: par")
	-- and the computer at pro defending while a person attacks
	m = newMatch { mode = "Vs Playdate", levelB = "pro" }
	toRaise(m)
	expect.near(settledX(m), p0.par, 1e-9, "VS PLAYDATE: the Playdate at pro")
end)

test("the computer's raise keeps its reason in cpu.last, a person's does not", function()
	cpu.last = nil
	local m = newMatch { cpu = { "B" }, levelB = "pro" }
	toRaise(m)
	match.settle(m)
	local d = cpu.last
	expect.truthy(d, "a decision")
	expect.eq(d.kind, "raise")
	expect.eq(d.why.play, "raise.par")
	expect.near(m.game.kubbs.a3.pose.x, 1.26, 1e-9, "par's end")
	expect.eq(d.intent["end"], 1)
	expect.eq(d.intent.choice, 1)
	local f = d.why.facts
	expect.eq(f.level, "pro")
	expect.eq(f.policy, "par")
	expect.eq(f.choices, 2)
	expect.eq(f.tie, false)
	expect.truthy(f.exposure < f.over, "the end chosen leaves less in line than the other")
	expect.truthy(cpu.text(d.why), "a sentence a game can show")
	-- club: a decision with no play (apart carries out none in the reference)
	cpu.last = nil
	m = newMatch { cpu = { "B" }, levelB = "club" }
	toRaise(m)
	match.settle(m)
	expect.eq(cpu.last.kind, "raise")
	expect.eq(cpu.last.why.play, nil)
	expect.eq(cpu.last.why.facts.policy, "apart")
	-- a person's automatic raise is not the computer's decision
	cpu.last = nil
	m = newMatch { cpu = { "A" } }
	toRaise(m)
	match.settle(m)
	expect.eq(cpu.last, nil)
	-- and none of it reaches the game
	expect.eq(m.game.raisePolicy, "apart")
end)

test("a match built the old way raises exactly as before", function()
	-- no cpu, no raising, no levels: the game's one policy, apart, for both sides, as
	-- 0.11.2's match.settle (g:raise(nil)) did
	local m = newMatch {}
	toRaise(m)
	expect.near(settledX(m), picks(0).apart, 1e-9)
	local old = newMatch {}
	toRaise(old)
	old.game:raiseAll()
	local a, b = m.game.kubbs.a3.pose, old.game.kubbs.a3.pose
	expect.eq(a.x, b.x); expect.eq(a.y, b.y); expect.eq(a.angle, b.angle)
	-- levels alone (the Gym's teams, a client that passes no cpu) change nothing either
	m = newMatch { levelA = "pro", levelB = "pro" }
	toRaise(m)
	expect.near(settledX(m), picks(0).apart, 1e-9)
	-- and a game's raisePolicy set by its caller is still the one used
	m = newMatch {}
	m.game.raisePolicy = "first"
	toRaise(m)
	expect.near(settledX(m), picks(0).first, 1e-9)
end)

test("a saved match: cpu and raising are not saved, the mode is", function()
	import "core/save"
	local m = newMatch { cpu = { "B" }, levelB = "pro", raising = { A = "first" } }
	local d = tw.save.pack(m)
	expect.eq(d.cpu, nil)
	expect.eq(d.raising, nil)
	local back = tw.save.unpack(d)
	expect.eq(match.raisePolicy(back, "B"), nil, "a client sets m.cpu again on resume")
	local vs = tw.save.unpack(tw.save.pack(newMatch { mode = "Vs Playdate", levelB = "pro" }))
	expect.eq(type(match.raisePolicy(vs, "B")), "function", "VS PLAYDATE survives a resume")
	expect.eq(match.raisePolicy(vs, "A"), "par")
end)
