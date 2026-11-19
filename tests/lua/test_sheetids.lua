-- The ids a game file writes (engine 0.7.1): no player prefix for a team of
-- one, the initial (or the shortest start that tells players apart) for a
-- team of more, and the header naming each player with the id the turn
-- lines use. The game keeps every full id; only the file is shorter.
import "core/rules"
import "core/notation"
import "core/order"
import "core/gamefile"
import "core/match"
local notation, rules, gamefile = tw.notation, tw.rules, tw.gamefile

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local thrower = dofile(here .. "/../../tools/thrower.lua")

local function teams(a, b)
	local function t(names)
		local ps = {}
		for i, n in ipairs(names) do ps[i] = { name = n } end
		return { name = names[1], players = ps }
	end
	local ts = { A = t(a), B = t(b) }
	notation.assignIds(ts)
	return ts
end

local function ids(a, b)
	local ts = teams(a, b)
	local prefix, header = notation.fileIds(ts)
	local out = {}
	for _, side in ipairs { "A", "B" } do
		for _, p in ipairs(ts[side].players) do
			out[#out + 1] = p.id .. "=" .. tostring(prefix[p.id]) .. "/" .. header[p.id]
		end
	end
	return table.concat(out, " ")
end

test("file ids: one player a team writes no prefix; the header keeps the full id", function()
	expect.eq(ids({ "Jamie" }, { "Club" }), "jamie=false/jamie club=false/club")
end)

test("file ids: a team of two writes initials; the computer's team of one writes none", function()
	expect.eq(ids({ "Kim", "Max" }, { "Playdate" }), "kim=k/k max=m/m playdate=false/playdate")
end)

test("file ids: six players, initials across both teams", function()
	expect.eq(ids({ "Alex", "Kim", "Max", "Nell", "Otto", "Pia" }, { "Ray", "Kit" }),
		"alex=a/a kim=kim/kim max=m/m nell=n/n otto=o/o pia=p/p ray=r/r kit=kit/kit", "kim and kit share ki")
end)

test("file ids: shared initials take the shortest start that tells them apart", function()
	expect.eq(ids({ "Kim", "Karl" }, { "Sam" }), "kim=ki/ki karl=ka/ka sam=false/sam")
	expect.eq(ids({ "Sam", "Sol", "Sue" }, { "Dee", "Dave" }),
		"sam=sa/sa sol=so/so sue=su/su dee=de/de dave=da/da")
	expect.eq(ids({ "Ann", "Annie" }, { "X" }), "ann=ann/ann annie=anni/anni x=false/x")
	-- a prefix never ends at an underscore
	expect.eq(ids({ "Jo Ann", "Jo Bo" }, { "X" }), "jo_ann=jo_a/jo_a jo_bo=jo_b/jo_b x=false/x")
end)

test("file ids: identical names keep assignIds' suffix after the initial", function()
	expect.eq(ids({ "Dana", "Dana" }, { "Kim" }), "dana=d/d dana_b=d_b/d_b kim=false/kim")
	expect.eq(ids({ "Dana", "Dana" }, { "Dana", "Dee" }),
		"dana=da/da dana_b=da_b/da_b dana_c=da_c/da_c dee=de/de")
	-- the first Dana alone on her team: the other's prefix needs no suffix
	expect.eq(ids({ "Dana" }, { "Dana", "Kim" }), "dana=false/dana dana_b=d/d kim=k/k")
end)

test("file ids: a prefix never equals a one-player team's id", function()
	expect.eq(ids({ "K" }, { "Kim", "Max" }), "k=false/k kim=kim/kim max=m/m")
	for _, side in ipairs { "A", "B" } do
		-- every id the file writes is one the grammar's player token accepts
		local ts = teams({ "Dana", "Dana", "Jo Ann", "Jo" }, { "Jo Bo", "Q" })
		local _, header = notation.fileIds(ts)
		for _, p in ipairs(ts[side].players) do expect.truthy(header[p.id]:match("^[a-z_]+$"), header[p.id]) end
	end
end)

test("turn line: without ids every throw keeps the full id (as before)", function()
	local s = notation.sheet()
	s:beginTurn(3, "A")
	s:ink("kim", "I", 2); s:baton("kim", "F"); s:baton("max", "-")
	expect.eq(notation.turnLine(s.turns[3]), "3. kim:2I kim:F max:-")
	expect.eq(notation.turnLine(s.turns[3], { kim = "k", max = "m" }), "3. k:2I k:F m:-")
	expect.eq(notation.turnLine(s.turns[3], { kim = false, max = false }), "3. 2I F -")
end)

-- A short game: team A (two players) throws its batons in turn 1, Team B
-- (one) tosses and throws in turn 2, then A resigns in turn 3.
local function shortGame(a, b)
	local g = rules.new { teams = { A = { name = "Snow Kubbs", players = a }, B = { name = "Playdate", players = b } } }
	local A1, A2 = g.teams.A.players[1].id, g.teams.A.players[#g.teams.A.players].id
	g:throwBaton({ toppled = { "b3" } }, A1); g:throwBaton({}, A2)
	g:toss({ rest = { x = 0.5, y = 2.5, standing = true, angle = 0 }, moved = {} })
	for _ = 1, 4 do g:throwBaton({}) end
	g:resign("A", A2)
	return g
end

test("render: a two-player team against a one-player team", function()
	local g = shortGame({ { name = "Kim" }, { name = "Karl" } }, { { name = "Club" } })
	local text = notation.render(g, { levels = { "kim pro", "karl club", "club club" } })
	expect.truthy(text:find('[Team A Players "Kim (ki), Karl (ka)"]', 1, true), text)
	expect.truthy(text:find('[Team B Players "Club (club)"]', 1, true), text)
	expect.truthy(text:find('[Throw Levels "ki pro, ka club, club club"]', 1, true), text)
	expect.truthy(text:find("\n1. ki:B (@ 2.50,8.00) ka:-\n", 1, true), text)
	expect.truthy(text:find("\n2. I (@ 3.00,2.50) - - - -\n", 1, true), text)
	expect.truthy(text:find("\n3. 2A ka:G X X X X X X\n", 1, true), text)
	-- the game itself keeps the full ids
	expect.eq(g.sheet.turns[1].batons[1].player, "kim")
	expect.eq(g.sheet.turns[3].batons[1].player, "karl")
end)

test("render: one player a team writes no prefix in any turn", function()
	local g = shortGame({ { name = "Jamie" } }, { { name = "Club" } })
	local text = notation.render(g, {})
	expect.truthy(text:find('[Team A Players "Jamie (jamie)"]', 1, true), text)
	for line in text:gmatch("[^\n]+") do
		if line:match("^%d+%.") then expect.eq(line:find(":", 1, true), nil, line) end
	end
end)

-- Every throw of the sheet, in file order: { turn, player } with the full id.
local function sheetThrows(g)
	local out = {}
	for _, t in ipairs(g.sheet.turns) do
		for _, pid in ipairs(t.inkastOrder) do out[#out + 1] = { t.n, pid } end
		for _, b in ipairs(t.batons) do
			local _, _, _, thrown = tw.cards.batonCounts(b.token)
			if thrown then out[#out + 1] = { t.n, b.player } end
		end
	end
	return out
end

-- The file's throws mapped back to full ids through the header's roster
-- (which lists a team's players in the game's order).
local function roundTrip(g, text)
	local s = assert(gamefile.parse(text))
	local full = {}
	for _, side in ipairs { "A", "B" } do
		expect.eq(#s.roster[side], #g.teams[side].players)
		for i, e in ipairs(s.roster[side]) do
			expect.eq(e.name, g.teams[side].players[i].name)
			full[e.id] = g.teams[side].players[i].id
		end
	end
	local want = sheetThrows(g)
	expect.eq(#s.throws, #want)
	for i, t in ipairs(s.throws) do
		expect.eq(t.turn, want[i][1])
		expect.eq(full[t.player], want[i][2], "throw " .. i .. " of turn " .. t.turn)
	end
	return s
end

test("round trip: every throw of 200 seeded games is attributed to its player", function()
	local multi, prefixed, bare = 0, 0, 0
	for seed = 1, 200 do
		local g = thrower.playGame(seed * 100003 + seed)
		local text = notation.render(g, {})
		roundTrip(g, text)
		for _, side in ipairs { "A", "B" } do
			if #g.teams[side].players > 1 then multi = multi + 1 end
		end
		for tok in text:gmatch("\n%d+%. ([^\n]*)") do
			if tok:find(":", 1, true) then prefixed = prefixed + 1 else bare = bare + 1 end
		end
	end
	expect.truthy(multi > 50 and prefixed > 0 and bare > 0, multi .. " " .. prefixed .. " " .. bare)
end)

test("round trip: shared initials and identical names", function()
	local g = shortGame({ { name = "Dana" }, { name = "Dana" }, { name = "Dee" } }, { { name = "Dana" } })
	local text = notation.render(g, {})
	expect.truthy(text:find('[Team A Players "Dana (da), Dana (da_b), Dee (de)"]', 1, true), text)
	expect.truthy(text:find('[Team B Players "Dana (dana_c)"]', 1, true), text)
	roundTrip(g, text)
end)

test("an old file (a full id on every throw) still reads, every throw attributed", function()
	local old = table.concat({
		'[Team A "Twin Pines"]', '[Team A Players "Dana (dana), Dana (dana_b)"]',
		'[Team B "Backyard"]', '[Team B Players "Backyard (backyard)"]',
		'[First "Team A"]', '[Win "Team B"]', "",
		"1. dana:B dana_b:-",
		"2. backyard:I backyard:F backyard:- backyard:- backyard:- backyard:-",
		"3. dana_b:2I dana:F dana_b:G X X X X X",
	}, "\n") .. "\n"
	local s = assert(gamefile.parse(old))
	local got = {}
	for _, t in ipairs(s.throws) do got[#got + 1] = t.turn .. t.side .. ":" .. tostring(t.player) .. ":" .. t.token end
	expect.eq(table.concat(got, " "), "1A:dana:B 1A:dana_b:- 2B:backyard:I 2B:backyard:F 2B:backyard:- "
		.. "2B:backyard:- 2B:backyard:- 2B:backyard:- 3A:dana_b:2I 3A:dana:F")
	expect.eq(s.hits.A[1] .. "/" .. s.hits.A[2], "2/3")
	expect.eq(s.players.A .. "v" .. s.players.B, "2v1")
end)

test("match.file: a team of players against the computer", function()
	local m = tw.match.new { teams = {
		A = { name = "Snow Kubbs", players = { { name = "Kim", level = "pro" }, { name = "Max", level = "club" } } },
		B = { name = "Playdate", players = { { name = "Playdate" } } } } }
	tw.match.resign(m)
	local text = tw.match.file(m, { year = 2026, month = 11, day = 19, hour = 10, min = 0 }, "0.0.1")
	expect.truthy(text:find('[Team B Players "Playdate (playdate)"]', 1, true), text)
	local s = assert(gamefile.parse(text))
	expect.eq(s.players.A .. "v" .. s.players.B, "2v1")
	for _, t in ipairs(s.throws) do expect.truthy(t.player, t.token) end
end)
