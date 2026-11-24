-- Record mode (docs/RECORD.md) through the door, kubbCall("record.<name>"): each game of
-- tests/fixtures/record/games.lua gives the lines, winner and warnings it expects; a game
-- rebuilt from its log is the game built event by event; undo is a rebuild without the
-- last event; a setup that cannot be a game (Kid rules among them) is refused. That each
-- file passes the notation gate is make test-node's (tools/recordgames.lua).
import "session/json"
import "session/api"
local json = tw.web.json

local games = assert(loadfile("tests/fixtures/record/games.lua"))()

local function call(name, a)
	local out = json.decode(kubbCall("record." .. name, a ~= nil and json.encode(a) or ""))
	if out.error then error("record." .. name .. ": " .. out.error, 2) end
	return out
end
local function callError(name, a)
	local out = json.decode(kubbCall("record." .. name, json.encode(a)))
	return out.error
end

local function lines(text)
	local out = {}
	for l in (text .. "\n"):gmatch("(.-)\n") do out[l] = true end
	return out
end

local function codes(ws)
	local out = {}
	for i, w in ipairs(ws or {}) do out[i] = w.code end
	return table.concat(out, " ")
end

local names = {}
for name in pairs(games) do names[#names + 1] = name end
table.sort(names)

for _, name in ipairs(names) do
	local g = games[name]
	test("record game " .. name .. ": lines, winner and warnings", function()
		local out = call("build", { game = g.setup, events = g.events, want = { notation = true, sheet = true } })
		local text = out.notation.text
		local have = lines(text)
		for _, l in ipairs(g.expect.lines) do expect.truthy(have[l], name .. ": line " .. l .. " in\n" .. text) end
		for _, s in ipairs(g.expect.absent or {}) do
			expect.truthy(not text:find(s, 1, true), name .. ": " .. s .. " is not written")
		end
		expect.eq(out.state.over, true, name .. ": over")
		expect.eq(out.state.winner, g.expect.winner, name .. ": winner")
		expect.eq(out.state.how, g.expect.how, name .. ": how")
		expect.eq(codes(out.warnings), table.concat(g.expect.warnings or {}, " "), name .. ": warnings")
		expect.eq(out.state.next.kind, "over", name .. ": next")
		expect.truthy(#out.sheet.rows > 0, name .. ": sheet rows")
		expect.eq(out.state.events, #g.events, name .. ": events counted")
	end)
end

test("record: a game added event by event is the game rebuilt from its log", function()
	for _, name in ipairs(names) do
		local g = games[name]
		call("new", { game = g.setup })
		local warned = 0
		for i, e in ipairs(g.events) do
			local out = call("add", { event = e })
			expect.eq(out.added.index, i - 1, name .. ": index")
			warned = warned + #out.added.warnings
			for _, w in ipairs(out.added.warnings) do expect.eq(w.event, i - 1, name .. ": warning's event") end
		end
		local inc = call("view", { want = { notation = true, sheet = true } })
		expect.eq(warned, #inc.warnings, name .. ": added warnings are all the warnings")
		local log = call("events").events
		expect.eq(#log, #g.events, name .. ": log length")
		local re = call("rebuild", { events = log, want = { notation = true, sheet = true } })
		expect.eq(re.notation.text, inc.notation.text, name .. ": same file")
		expect.eq(json.encode(re.state), json.encode(inc.state), name .. ": same state")
		expect.eq(json.encode(re.sheet), json.encode(inc.sheet), name .. ": same sheet")
		local built = call("build", { game = g.setup, events = g.events, want = { notation = true } })
		expect.eq(built.notation.text, inc.notation.text, name .. ": build is the same")
	end
end)

test("record: undo is the game rebuilt without its last event, back to the start", function()
	local g = games.example
	call("new", { game = g.setup })
	for _, e in ipairs(g.events) do call("add", { event = e }) end
	for n = #g.events - 1, 0, -1 do
		local undone = call("undo", { want = { notation = true } })
		local partial = {}
		for i = 1, n do partial[i] = g.events[i] end
		local built = call("build", { game = g.setup, events = partial, want = { notation = true } })
		expect.eq(undone.notation.text, built.notation.text, "after undo to " .. n)
		expect.eq(json.encode(undone.state), json.encode(built.state), "state after undo to " .. n)
		expect.eq(undone.state.events, n, "events after undo to " .. n)
	end
	local start = call("view")
	expect.eq(start.state.turn, 1)
	expect.eq(start.state.phase, "batons")
	expect.eq(start.state.attacker, "A")
	expect.eq(start.state.batons.left, 2)
	expect.eq(call("undo").state.events, 0, "undo with nothing to undo")
end)

test("record: the state a scorer's screen needs, mid-game", function()
	local g = games.example
	-- after turn 4's tosses: Team B throws batons at four field kubbs in Team A's half
	local partial = {}
	for i = 1, 22 do partial[i] = g.events[i] end
	local s = call("build", { game = g.setup, events = partial }).state
	expect.eq(s.turn, 4)
	expect.eq(s.attacker, "B")
	expect.eq(s.defender, "A")
	expect.eq(s.phase, "batons")
	expect.eq(s.next.kind, "baton")
	expect.eq(s.next.n, 1)
	expect.eq(s.next.of, 6)
	expect.eq(s.next.targets, "field")
	expect.eq(s.sides.A.field, 4)
	expect.eq(s.sides.A.base, 3)
	expect.eq(s.sides.B.base, 3)
	expect.eq(s.sides.A.fieldComplete, true)
	expect.eq(#s.sides.A.fieldPositions, 4)
	expect.eq(s.advantage.applies, false)
	expect.eq(s.batons.left, 6)
	expect.eq(s.throwers.cap, 3, "two players, six batons: at most three each (II.B.5)")
	expect.eq(s.sides.B.players[1].file, "s")
	-- mid-inkast of turn 5: one toss of three
	partial = {}
	for i = 1, 29 do partial[i] = g.events[i] end
	s = call("build", { game = g.setup, events = partial }).state
	expect.eq(s.phase, "inkast")
	expect.eq(s.next.kind, "toss")
	expect.eq(s.inkast.left, 2)
	expect.eq(s.inkast.dueAtStart, 3)
	expect.eq(s.advantage.applies, true, "a kubb stands in Team A's own half")
end)

test("record: kubbs to throw in, rethrows and a punishment kubb", function()
	local g = games.called
	local partial = {}
	for i = 1, 9 do partial[i] = g.events[i] end -- turn 2: in, out, out
	local s = call("build", { game = g.setup, events = partial }).state
	expect.eq(s.inkast.due, 0)
	expect.eq(s.inkast.rethrows, 2)
	expect.eq(s.next.rethrow, true)
	partial[10] = g.events[10] -- out again: a punishment kubb
	partial[11] = g.events[11]
	s = call("build", { game = g.setup, events = partial }).state
	expect.eq(s.phase, "batons")
	expect.eq(s.inkast.punish, 1)
	expect.eq(s.allowed[2], "punish", "the punishment kubb can be placed")
	partial[12] = g.events[12]
	s = call("build", { game = g.setup, events = partial }).state
	expect.eq(s.inkast.punishPlaced, 1)
	expect.eq(s.sides.A.field, 3)
end)

test("record: Kid rules and a setup that cannot be a game are refused", function()
	local base = games.bare.setup
	local function with(k, v)
		local s = {}
		for key, x in pairs(base) do s[key] = x end
		s[k] = v
		return s
	end
	expect.truthy((callError("new", { game = with("rules", "kid") }) or ""):find("Kid", 1, true), "kid rules")
	expect.truthy(callError("new", { game = with("opening", "1-2-3") }), "an opening")
	expect.truthy(callError("new", { game = with("surface", "ice") }), "a surface")
	expect.truthy(callError("new", { game = with("wind", "gale") }), "a wind")
	expect.truthy(callError("new", { game = with("first", "C") }), "first")
	expect.truthy(callError("new", { game = with("client", "bad\"label") }), "a client label")
	expect.truthy(callError("new", { game = with("teams", { A = { players = {} }, B = { players = { "Sam" } } }) }),
		"a team with nobody")
	expect.truthy(callError("build", { game = with("rules", "kid"), events = {} }), "build refuses kid rules too")
	expect.truthy(json.decode(kubbCall("record.nope", "{}")).error, "an unknown call")
end)

test("record: an event never errors; a bad one is a warning and changes nothing", function()
	call("new", { game = games.bare.setup })
	local before = call("view", { want = { notation = true } })
	for _, e in ipairs { 7, { type = "jump" }, { type = "toss", result = "in" }, { type = "baton", time = { year = "x" } } } do
		local out = call("add", { event = e })
		expect.truthy(#out.added.warnings > 0, "warned: " .. json.encode(e))
	end
	local after = call("view", { want = { notation = true } })
	expect.eq(after.state.batons.thrown, 1, "only the baton counted")
	expect.truthy(before.notation.text ~= after.notation.text)
end)

test("record: options, the capture header and names", function()
	local o = call("options")
	expect.eq(o.format, 1)
	expect.eq(table.concat(o.openings, " "), "2-4-6 six")
	expect.eq(table.concat(o.surfaces, " "), "grass sand snow")
	expect.eq(table.concat(o.winds, " "), "off light strong")
	expect.eq(table.concat(o.switches, " "), "players pitch lay stance")
	local s = call("build", { game = { teams = { A = { name = "Café, Inc.", players = { "Ana (left), B." } },
		B = { players = { { name = "Jo", id = "jo" }, { name = "Mo", id = "mo" } } } }, event = "Spring Cup, day 1",
		location = "Field 3, Town" }, events = {}, want = { notation = true } })
	local text = s.notation.text
	expect.truthy(text:find('[Event "Spring Cup, day 1"]', 1, true), "event keeps its comma")
	expect.truthy(text:find('[Location "Field 3, Town"]', 1, true), "location keeps its comma")
	expect.truthy(text:find('[Scored by "Kubb: Pitchside"]', 1, true), "scored by")
	expect.truthy(not text:find("[Win", 1, true), "no winner yet")
	expect.truthy(text:find('[Team B Players "Jo (j), Mo (m)"]', 1, true), "the file's ids are short")
	expect.truthy(text:find('[Team A Players "Ana left B. (ana_left_b)"]', 1, true), "a name loses commas and parentheses")
	expect.eq(s.state.sides.B.players[1].id, "jo", "the id given is the id events name")
	expect.eq(s.state.sides.B.players[1].file, "j")
end)

test("record: a null event keeps its place in the log, so a rebuild gives the same indexes", function()
	call("new", { game = games.bare.setup })
	local first = json.decode(kubbCall("record.add", '{"event":null}'))
	expect.eq(first.added.index, 0)
	expect.eq(#first.added.warnings, 1)
	local second = call("add", { event = { type = "baton", base = 1 } })
	expect.eq(second.added.index, 1)
	local inc = call("view", { want = { notation = true } })
	local re = json.decode(kubbCall("record.rebuild", '{"events":[null,{"type":"baton","base":1}],"want":{"notation":true}}'))
	expect.eq(re.notation.text, inc.notation.text, "same file")
	expect.eq(json.encode(re.warnings), json.encode(inc.warnings), "same warnings, same indexes")
	expect.eq(re.state.events, 2)
	expect.eq(#call("events").events, 2)
	local undone = call("undo")
	expect.eq(undone.state.events, 1)
	expect.eq(#undone.warnings, 1, "the null's warning stays")
end)

test("record: nulls in an event list keep their places, trailing ones too", function()
	local game = json.encode(games.bare.setup)
	local only = json.decode(kubbCall("record.build", '{"game":' .. game .. ',"events":[null]}'))
	expect.eq(only.state.events, 1)
	expect.eq(#only.warnings, 1)
	local trail = json.decode(kubbCall("record.build", '{"game":' .. game .. ',"events":[{"type":"baton","base":1},null,null]}'))
	expect.eq(trail.state.events, 3)
	expect.eq(#trail.warnings, 2)
	expect.eq(trail.warnings[2].event, 2)
	local re = json.decode(kubbCall("record.rebuild", '{"game":' .. game .. ',"events":[null,{"type":"baton"},null]}'))
	expect.eq(re.state.events, 3)
	expect.eq(#call("events").events, 3)
	expect.eq(call("undo").state.events, 2)
end)
