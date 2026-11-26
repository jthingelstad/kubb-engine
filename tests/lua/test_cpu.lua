-- core/cpu and core/plays: the decision names the play it carries out and its facts,
-- the intent is what autothrow throws, and the reason stays off the throw's table.
import "core/tw"
import "core/cpu"
import "core/throwplan"

local cpu, plays, autothrow, plan = tw.cpu, tw.plays, tw.autothrow, tw.plan

-- These cases are the choices 0.11.1 made, with the plays 0.12.0 added switched off
-- (test_cpu_plays has those): run fn with every cpu.tune play's on = 0.
local function plain(fn)
	return function()
		local saved = {}
		for name, p in pairs(cpu.tune) do saved[name] = p.on; p.on = 0 end
		local ok, err = pcall(fn)
		for name, p in pairs(cpu.tune) do p.on = saved[name] end
		if not ok then error(err, 0) end
	end
end

local function k(id, half, x, y, toppled, role)
	return { id = id, kind = "kubb", role = role or "field", half = half, x = x, y = y, toppled = toppled }
end

local function toss(pieces, of, n)
	return { kind = "toss", side = "A", lineY = 0, forwardY = 0, kubb = "a1", pieces = pieces or {},
		of = of or 3, n = n or 1, surface = "grass" }
end

local function baton(pieces, targets, extra)
	local s = { kind = "baton", side = "A", lineY = 0, forwardY = 0, batonId = "baton1", pieces = pieces,
		targets = targets, surface = "grass" }
	for key, v in pairs(extra or {}) do s[key] = v end
	return s
end

-- A stream that counts its draws.
local function counting(seed)
	local r = autothrow.rng(seed)
	local c = { n = 0 }
	function c.next() c.n = c.n + 1; return r.next() end
	function c.normal(sd) c.n = c.n + 1; return r.normal(sd) end
	function c.uniform(a, b) c.n = c.n + 1; return r.uniform(a, b) end
	return c
end

test("every play is a phase's play with levels and a sentence", function()
	local n = 0
	for id, p in pairs(plays) do
		n = n + 1
		expect.eq(id:match("^([a-z]+)%."), p.phase, id .. "'s phase")
		expect.truthy(#p.levels > 0 and type(p.say) == "string" and #p.say > 0, id)
	end
	expect.eq(n, 7, "0.18.0 carries out seven plays (field.drive since 0.18.0)")
end)

test("a toss beside a kubb already down: inkast.roll, with the basket and the kubb", plain(function()
	local t = autothrow.tune
	local s = toss({ k("f1", "B", 1.9, 4.8, true), k("f2", "B", 1.7, 4.9, true), k("f3", "B", -1.9, 4.8) }, 4, 3)
	local r = counting(1)
	local d = cpu.decide(s, r, "club")
	expect.eq(r.n, 0, "no tie, no draw")
	expect.eq(d.kind, "toss")
	expect.eq(d.why.play, "inkast.roll")
	local f = d.why.facts
	expect.eq(f.basket, "right")
	expect.eq(f.near, 2)
	expect.eq(f.other, 1)
	expect.eq(f.coin, false)
	expect.eq(f.spot, "row")
	expect.eq(f.beside, "f2")
	expect.eq(f.spin, 1)
	expect.eq(f.inHand, 4)
	expect.eq(f.kubb, 3)
	local it = d.intent
	expect.eq(it.basket, 1)
	expect.near(it.tx, 1.7 - t.rowStep, 1e-12)
	-- f2 lies at 4.9, deeper than club's basket and rowPast: aimed short of it (1.3.0)
	expect.near(it.ty, t.inkast.club.basketY + t.inkast.club.rowPast, 1e-12)
	expect.eq(it.spin, 1)
	expect.eq(it.standY, 0)
	expect.near(it.arc, plan.arcFor("drill"), 0)
	expect.eq(cpu.text(d.why), "Laid beside the kubb lying by the right basket, to roll in beside it.")
end))

-- A lying kubb of the far half with its pose (world frame; side A's view is the world's).
local function lying(id, x, y)
	local p = k(id, "B", x, y, true)
	p.pose = { x = x, y = y, standing = false, angle = math.pi / 2 }
	return p
end

test("a kubb out for now is not built on: the row goes beside the one in (1.2.0)", plain(function()
	local t = autothrow.tune
	-- f1 went out past the right sideline, f2 lies in by the right basket
	local s = toss({ lying("f1", 2.75, 4.5), lying("f2", 1.9, 4.5) }, 4, 3)
	local d = cpu.decide(s, counting(1), "club")
	expect.eq(d.why.facts.near, 1, "the kubb out is not counted for the basket")
	expect.eq(d.why.facts.beside, "f2")
	expect.near(d.intent.tx, 1.9 - t.rowStep, 1e-12)
	-- with only the kubb out lying there, the basket is empty: aim at the basket itself
	s = toss({ lying("f1", 2.75, 4.5), lying("f3", 1.9, 3.7) }, 4, 3)
	d = cpu.decide(s, counting(1), "club")
	expect.eq(d.why.facts.spot, "basket", "f3 lies short of the centre line: out too")
	-- 1.1's reading, every kubb counted
	t.inkastSkipOut = 0
	local ok, err = pcall(function()
		d = cpu.decide(toss({ lying("f1", 2.75, 4.5) }, 4, 3), counting(1), "club")
		expect.eq(d.why.facts.beside, "f1")
	end)
	t.inkastSkipOut = 1
	if not ok then error(err, 0) end
end))

-- Run fn with club's rowCap set to v (autothrow.tune.inkast.club), restored after.
local function withRowCap(v, fn)
	local ik = autothrow.tune.inkast.club
	local saved = ik.rowCap
	ik.rowCap = v
	local ok, err = pcall(fn)
	ik.rowCap = saved
	if not ok then error(err, 0) end
end

test("a row's later kubb is not aimed deeper than the cap when the first ran on (1.3.0)", plain(function()
	local t, ik = autothrow.tune, autothrow.tune.inkast.club
	-- the first kubb aimed at club's basket (4.45) ran on to 5.21; the next goes beside it
	local s = toss({ lying("f1", 1.9, 5.21) }, 4, 2)
	withRowCap(1, function()
		local d = cpu.decide(s, counting(1), "club")
		expect.eq(d.why.play, "inkast.roll")
		expect.eq(d.why.facts.spot, "row")
		expect.eq(d.why.facts.beside, "f1")
		expect.near(d.intent.tx, 1.9 - t.rowStep, 1e-12)
		expect.near(d.intent.ty, ik.basketY + ik.rowPast, 1e-12, "capped: the basket's depth and rowPast")
		-- a kubb lying short of the cap is laid level with, as before
		d = cpu.decide(toss({ lying("f2", 1.9, 4.5) }, 4, 2), counting(1), "club")
		expect.near(d.intent.ty, 4.5, 1e-12)
	end)
	-- switched off, 1.2's row: level with the kubb that ran on
	withRowCap(0, function()
		local d = cpu.decide(s, counting(1), "club")
		expect.near(d.intent.ty, 5.21, 1e-12)
	end)
end))

test("a first toss at an empty half: inkast.corner, the basket itself, one coin from the stream", plain(function()
	local t = autothrow.tune
	local r = counting(7)
	local d = cpu.decide(toss(), r, "pro")
	expect.eq(r.n, 1, "the coin")
	expect.eq(d.why.play, "inkast.corner")
	expect.eq(d.why.facts.coin, true)
	expect.eq(d.why.facts.spot, "basket")
	expect.near(math.abs(d.intent.tx), t.basketX, 0)
	expect.near(d.intent.ty, t.inkast.pro.basketY, 0, "pro's basket, nearer the centre line (1.2.0)")
	expect.eq(d.intent.spin, d.intent.basket, "one tap toward the sideline")
	expect.truthy(cpu.text(d.why):match("^Into the %a+ basket: 0 field kubbs by it, 0 by the other%.$"), cpu.text(d.why))
	-- a beginner throws at the basket with no spin, whatever lies there
	d = cpu.decide(toss { k("f1", "B", 1.9, 4.8, true) }, counting(1), "beginner")
	expect.eq(d.why.play, "inkast.corner")
	expect.eq(d.why.facts.spot, "basket")
	expect.eq(d.intent.spin, 0)
	expect.near(d.intent.tx, t.basketX, 0)
end))

test("a field baton: field.roles, the front of the fullest lane, aimed across its middle", plain(function()
	local t = autothrow.tune
	local pieces = {
		k("near", "B", -1.0, 4.5),                          -- nearest, alone
		k("front", "B", 0.5, 5.0), k("back", "B", 0.54, 5.4), -- a lane of two
		k("king", "B", 0, 4.0, false, "king"),
	}
	local s = baton(pieces, { "near", "front", "back" }, { forwardY = 1.5 })
	local r = counting(1)
	local d = cpu.decide(s, r, "club")
	expect.eq(r.n, 0, "a baton draws nothing to decide")
	expect.eq(d.kind, "baton")
	expect.eq(d.why.play, "field.roles")
	expect.eq(d.why.facts.on, "front")
	expect.eq(d.why.facts.lane, 2)
	expect.eq(d.why.facts.target, "field")
	expect.eq(d.why.facts.targets, 3)
	local it = d.intent
	expect.eq(it.on, "front")
	expect.near(it.tx, (0.5 + 0.54) / 2, 1e-12)
	expect.near(it.ty, 5.0 - t.batonShort, 0)
	expect.near(it.standY, 1.5, 0)
	expect.near(it.stance.x, it.tx, 0)
	expect.near(it.stance.y, 1.5, 0)
	expect.near(it.aimZ, plan.aimZFor("kubb"), 0)
	local dx, dy = it.tx - it.stance.x, it.ty - it.stance.y
	expect.near(it.arc, plan.sharedArcFor(math.sqrt(dx * dx + dy * dy)), 0)
	expect.eq(cpu.text(d.why), "At the lane with the most kubbs: 2 in line from the front one.")
end))

test("a base kubb baton and a king shot name no play, and say what they threw at", plain(function()
	local t = autothrow.tune
	local pieces = {
		k("b1", "B", -1, 8, false, "base"), k("b2", "B", 1, 7.95, false, "base"),
		{ id = "king", kind = "king", role = "king", x = 0, y = 4 },
	}
	local d = cpu.decide(baton(pieces, { "b1", "b2" }, { forwardY = 7.9 }), counting(1), "pro")
	expect.eq(d.why.play, nil)
	expect.eq(d.why.facts.target, "base")
	expect.eq(d.why.facts.on, "b2", "the nearest")
	expect.eq(d.why.facts.lane, nil)
	expect.near(d.intent.standY, 7.95 - t.minRange, 1e-12, "never nearer than minRange")
	expect.eq(cpu.text(d.why), nil)
	d = cpu.decide(baton(pieces, { "king" }, { kingShot = true, forwardY = 3 }), counting(1), "pro")
	expect.eq(d.why.play, nil)
	expect.eq(d.why.facts.target, "king")
	expect.eq(d.intent.on, "king")
	expect.eq(d.intent.standY, 0, "the king from the baseline")
	expect.near(d.intent.aimZ, plan.aimZFor("king"), 0)
end))

test("autothrow.choose throws the decision and leaves the reason on cpu.last only", plain(function()
	local s = toss({ k("f1", "B", 1.9, 4.8, true) }, 3, 2)
	local a = autothrow.choose(s, autothrow.rng(1), 0, "club")
	local d = cpu.last
	expect.eq(d.why.play, "inkast.roll")
	expect.near(a.plan.tx, d.intent.tx, 0)
	expect.near(a.plan.ty, d.intent.ty, 0)
	expect.near(a.drill.markerX, d.intent.tx, 0)
	expect.eq(a.why, nil)
	expect.eq(a.decision, nil)
	-- the level comes from the thrower when none is given, and a non-name falls back
	expect.eq(cpu.levelName({ thrower = { level = "pro" } }), "pro")
	expect.eq(cpu.levelName({ thrower = { level = "pro" } }, "beginner"), "beginner")
	expect.eq(cpu.levelName({ thrower = { level = 3 } }), autothrow.tune.level)
end))
