-- core/gamefile: what the games list shows of a game file.
import "core/gamefile"
local gamefile = tw.gamefile

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local dir = here .. "/../fixtures/games/"

local function read(name)
	local f = assert(io.open(dir .. name, "r"))
	local s = f:read("a")
	f:close()
	return s
end

test("gamefile: the hand-written game's summary", function()
	local s = assert(gamefile.parse(read("2026-11-20-1942-jamie-v-playdate.txt")))
	expect.eq(s.a, "Jamie"); expect.eq(s.b, "Playdate")
	expect.eq(s.winner, "A"); expect.eq(s.first, "A")
	expect.eq(s.turns, 5); expect.eq(s.minutes, 16)
	expect.eq(s.date, "NOV 20")
	-- Jamie's batons: B - | B - B - - - | 3F 2F B B K X  -> 6 thrown in turn 5, X not
	expect.eq(s.hits.A[2], 2 + 6 + 5)
	expect.eq(s.hits.A[1], 1 + 2 + 5)
	expect.eq(s.kingBaton, 5)
	expect.eq(gamefile.rate(s, "A"), math.floor(100 * 8 / 13 + 0.5))
end)

test("gamefile: every fixture game parses, with turns and a winner", function()
	local n = 0
	for name in io.popen('ls "' .. dir .. '"'):lines() do
		if name:match("%.txt$") then
			local s, why = gamefile.parse(read(name))
			expect.truthy(s, name .. ": " .. tostring(why))
			if s then
				expect.truthy(s.turns > 0, name .. " turns")
				expect.truthy(s.winner == "A" or s.winner == "B", name .. " winner")
				expect.truthy(s.hits.A[1] <= s.hits.A[2] and s.hits.B[1] <= s.hits.B[2], name .. " hits")
			end
			n = n + 1
		end
	end
	expect.truthy(n >= 10, "fixtures found: " .. n)
end)

test("gamefile: a note after # is not counted as throws", function()
	local text = '[Team A "Ash"]\n[Team B "Birch"]\n[First "Team A"]\n[Win "Team B"]\n\n'
		.. "1. a:B a:- # b1 toppled the king early\n2. b:- b:F\n"
	local s = assert(gamefile.parse(text))
	expect.eq(s.hits.A[2], 2)
	expect.eq(s.hits.A[1], 1)
	expect.eq(s.hits.B[2], 2)
end)

local function same(s, bare)
	expect.eq(s.turns, bare.turns); expect.eq(s.kingBaton, bare.kingBaton); expect.eq(#s.throws, #bare.throws)
	for _, side in ipairs { "A", "B" } do
		expect.eq(s.hits[side][1], bare.hits[side][1]); expect.eq(s.hits[side][2], bare.hits[side][2])
	end
end

test("gamefile: position lines are not throws or score sheet lines; a game reads as it does without them", function()
	local text = read("2026-11-21-0855-team-a-v-team-b.txt")
	expect.truthy(text:find("\n@a ", 1, true) and text:find("\n*b ", 1, true), "the fixture has position lines")
	local s = assert(gamefile.parse(text))
	local bare = assert(gamefile.parse((text:gsub("\n[@~^*][ab] [^\n]*", ""))))
	same(s, bare)
	for _, l in ipairs(s.lines) do expect.truthy(not gamefile.isPosition(l), l) end
	expect.eq(#s.lines, #bare.lines)
	-- Team A: - Z B Z | F - 2F B B B | 3F 2F F F B K: 16 thrown, 12 hits
	expect.eq(s.hits.A[2], 16); expect.eq(s.hits.A[1], 12)
	expect.eq(s.kingBaton, 6)
	expect.eq(s.headers["Notation"], "2")
end)

test("gamefile: a file an older client wrote (positions in comments, nA) still reads the same", function()
	local f = assert(io.open(here .. "/../fixtures/legacy/2026-11-21-0855-team-a-v-team-b.txt", "r"))
	local old = f:read("a"); f:close()
	expect.truthy(old:find("(@ ", 1, true), "the legacy fixture has positions comments")
	local s = assert(gamefile.parse(old))
	same(s, assert(gamefile.parse(read("2026-11-21-0855-team-a-v-team-b.txt"))))
	-- an advantage line written with its metres is not a throw either
	local t = assert(gamefile.parse('[Team A "Ash"]\n[Team B "Birch"]\n\n1. a:B a:-\n2. b:I 2A b:F b:-\n3. a:I A a:- a:-\n'))
	expect.eq(t.hits.B[2], 2); expect.eq(t.hits.A[2], 4); expect.eq(#t.throws, 8)
end)

test("gamefile: not a game file", function()
	expect.eq((gamefile.parse("hello")), nil)
	expect.eq((gamefile.parse(nil)), nil)
end)

test("gamefile: the score sheet on screen leaves positions out", function()
	expect.truthy(gamefile.isPosition("@b 1.50,3.00 3.50,2.00") and gamefile.isPosition("*a - 2.50,4.00"))
	expect.truthy(gamefile.isPosition("~b 4.59,0.06/4.63,-0.08") and gamefile.isPosition("^a 4.20,4.00 -"))
	expect.truthy(not gamefile.isPosition("3. A max:2F") and not gamefile.isPosition('[Event "x"]') and not gamefile.isPosition(""))
	expect.eq(gamefile.shown("@b 1.50,3.00 3.50,2.00"), "")
	expect.eq(gamefile.shown("3. max:2I (@ 4.39,4.61 4.34,5.21) max:F (@ 4.39,4.61) kim:Z # b3 note (II.B.11)"),
		"3. max:2I max:F kim:Z # b3 note (II.B.11)")
	expect.eq(gamefile.shown("2. ash:I (windy) ash:F"), "2. ash:I (windy) ash:F")
	expect.eq(gamefile.shown('[Rules "U.S. Championship 4.0, 2-4-6"]'), '[Rules "U.S. Championship 4.0, 2-4-6"]')
end)
