-- Two fixes from the web's QA pass (0.17.0), both output only: a Kid match's early king is
-- no kubb down in the recording's result, and a rethrown kubb is counted in its own round
-- ("rethrow 1 of 1", not "kubb 3 of 3"). The throws' outcomes are set by hand (a world
-- result made up here), so each case is exactly the one named; the session then sets up
-- the next throw from the match as it always does.
import "session/session"
import "core/match"
tw.web.session.useTune("pointer")
local session, cmatch = tw.web.session, tw.match

local START = { year = 2026, month = 11, day = 22, hour = 10, min = 0 }

local function new(o)
	local m = { mode = "match", seed = 3, start = START, raising = "auto", first = "A",
		teams = { A = { players = { "Mighty Maple" } }, B = { players = { "Quiet Juniper" } } } }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

-- A made-up world result: these pieces toppled; `rest` the thrown kubb's resting place
-- (view frame), lying, for a toss.
local function result(s, toppled, rest)
	local king = false
	for _, id in ipairs(toppled) do if id == "king" then king = true end end
	local res = { toppled = toppled, kingToppled = king, touched = {}, bodies = {} }
	if rest then
		local h = math.sqrt(0.5)
		res.bodies[s.setup.kubb] = { x = rest[1], y = rest[2], z = 0.04, qw = h, qx = h, qy = 0, qz = 0 }
	end
	return res
end

-- Apply a made-up throw to the session's match and set up the next, as applyThrow does.
-- Returns the recording result's flag and down as session.kingUpResult leaves them, from
-- what throw.fire would have given (down counts every piece toppled).
local function throwIt(s, toppled, rest)
	local res = result(s, toppled, rest)
	local drill = s.setup.kind == "toss"
	local r = { toppled = toppled, down = #toppled, flag = (not drill) and (#toppled > 0 and (#toppled .. " DOWN") or "MISS") or nil }
	cmatch.resolve(s.m, res, false)
	session.kingUpResult(r, s.m.ruling)
	local short = session.short(s.m.text)
	s:advance()
	return r, short, s.m.text
end

-- Misses until `side` is to throw kubbs in (the far base kubbs `toppled` on the first baton).
local function toInkast(s, toppled)
	throwIt(s, toppled)
	local guard = 0
	while s.setup and s.setup.kind ~= "toss" and guard < 20 do
		throwIt(s, {})
		guard = guard + 1
	end
	assert(s.setup and s.setup.kind == "toss", "an inkast set up")
end

test("a Kid baton that fells a kubb and the king early: 1 DOWN, the king not counted", function()
	local s = new { rules = "kid" }
	local r, short, text = throwIt(s, { "b1", "king" })
	expect.truthy(text:find("stood back up", 1, true), text)
	expect.eq(r.down, 1, "the kubb only")
	expect.eq(r.flag, "1 DOWN")
	expect.eq(short, "1 DOWN", "the session's short flag agrees")
end)

test("a Kid baton that fells only the king early: KING BACK UP, nothing down", function()
	local s = new { rules = "kid" }
	local r, short = throwIt(s, { "king" })
	expect.eq(r.down, 0)
	expect.eq(r.flag, "KING BACK UP")
	expect.eq(short, "KING BACK UP")
end)

test("a Kid kubb thrown in that knocks the king down: no kubb down, no flag", function()
	local s = new { rules = "kid" }
	toInkast(s, { "b1" })
	local r, short = throwIt(s, { "king" }, { 0, 6 })
	expect.eq(r.down, 0)
	expect.eq(r.flag, nil, "a kubb's throw keeps its rest text, no flag")
	expect.eq(short, "KING BACK UP")
	-- the standard rules: a king felled early is the end, and the result is untouched
	local t = new {}
	local r2 = throwIt(t, { "king" })
	expect.eq(r2.flag, "1 DOWN", "as before: no kingUp, nothing changed")
	expect.eq(r2.down, 1)
end)

-- The need, the label and the rail for the toss set up now.
local function shown(s)
	local n = s:need()
	return n.setup.n, n.setup.of, n.setup.rethrow, n.setup.label, s:aimView().rail
end

local IN, OUT = { 0, 6 }, { 5, 6 }

test("two kubbs, one out: rethrow 1 of 1", function()
	local s = new {}
	toInkast(s, { "b1", "b2" })
	local n, of, re, label = shown(s)
	expect.eq(n, 1); expect.eq(of, 2); expect.eq(re, false)
	expect.truthy(label:find("kubb 1 of 2", 1, true), label)
	throwIt(s, {}, IN)
	n, of = shown(s)
	expect.eq(n, 2); expect.eq(of, 2)
	throwIt(s, {}, OUT)
	local rail
	n, of, re, label, rail = shown(s)
	expect.eq(re, true, "the out kubb again")
	expect.eq(n, 1); expect.eq(of, 1)
	expect.truthy(label:find("rethrow 1 of 1", 1, true), label)
	expect.eq(rail.n, 1); expect.eq(rail.of, 1); expect.eq(rail.rethrow, true)
	-- the turn's count, which the computer's inkast reads, is as it was
	expect.eq(s.setup.n, 3); expect.eq(s.setup.of, 3)
end)

test("two kubbs, both out: rethrow 1 of 2, 2 of 2", function()
	local s = new {}
	toInkast(s, { "b1", "b2" })
	throwIt(s, {}, OUT)
	throwIt(s, {}, OUT)
	local n, of, re = shown(s)
	expect.eq(re, true); expect.eq(n, 1); expect.eq(of, 2)
	throwIt(s, {}, IN)
	n, of, re = shown(s)
	expect.eq(re, true); expect.eq(n, 2); expect.eq(of, 2)
end)

test("three kubbs, one and two out", function()
	local s = new {}
	toInkast(s, { "b1", "b2", "b3" })
	local n, of = shown(s)
	expect.eq(n, 1); expect.eq(of, 3)
	throwIt(s, {}, IN); throwIt(s, {}, OUT); throwIt(s, {}, IN)
	local re, label
	n, of, re, label = shown(s)
	expect.eq(re, true); expect.eq(n, 1); expect.eq(of, 1)
	expect.truthy(label:find("rethrow 1 of 1", 1, true), label)
	local t = new {}
	toInkast(t, { "b1", "b2", "b3" })
	throwIt(t, {}, OUT); throwIt(t, {}, IN); throwIt(t, {}, OUT)
	n, of, re = shown(t)
	expect.eq(re, true); expect.eq(n, 1); expect.eq(of, 2)
	throwIt(t, {}, IN)
	n, of, re = shown(t)
	expect.eq(re, true); expect.eq(n, 2); expect.eq(of, 2)
end)

test("a kubb out twice: no third throw; the punishment kubb, then the batons", function()
	local s = new {}
	toInkast(s, { "b1", "b2" })
	throwIt(s, {}, IN); throwIt(s, {}, OUT)
	local _, _, re = shown(s)
	expect.eq(re, true)
	local _, short = throwIt(s, {}, OUT)
	expect.eq(short, "OUT TWICE: PUNISHMENT")
	-- raised automatically, the punishment kubb placed: the batons follow
	expect.eq(s.setup.kind, "baton")
	expect.eq(s:need().setup.n, 1)
	-- by the Kid rules, stood at the fair spot
	local k = new { rules = "kid" }
	toInkast(k, { "b1", "b2" })
	throwIt(k, {}, IN); throwIt(k, {}, OUT)
	local _, short2 = throwIt(k, {}, OUT)
	expect.eq(short2, "OUT TWICE: PLACED")
	expect.eq(k.setup.kind, "baton")
end)
