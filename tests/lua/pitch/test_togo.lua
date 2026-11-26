-- The throw to go on a shared pitch (1.4.0): the pitch setting `togo` in `settings`, the
-- MATCH_OPTIONS row, and who throws each side's baton (seats.togoActor).
import "session/api"
import "session/json"
local json = tw.web.json
local lobby, seats = tw.shared.lobby, tw.shared.seats
local function wire(doc) return json.decode(json.encode(doc), true) end
local START = { year = 2026, month = 11, day = 26, hour = 14, min = 0 }

test("togo is a pitch setting: on in settings, off (absent) by default, in the options card", function()
	local doc = wire(lobby.joinTeam(nil, "host", "A"))
	expect.eq(doc.settings, nil)
	expect.eq(lobby.optionsOf(doc).togo, "off")
	doc = wire(lobby.setOptions(doc, { togo = "on" }))
	expect.eq(doc.settings.togo, "on")
	expect.eq(lobby.optionsOf(doc).togo, "on")
	expect.eq(lobby.setOptions(doc, { togo = "maybe" }), nil, "an unknown value changes nothing")
	local row
	for _, r in ipairs(lobby.MATCH_OPTIONS) do if r[1] == "togo" then row = r end end
	expect.eq(row[2], "Throw to go")
	expect.eq(lobby.optionLabel("togo", "on"), "On")
	doc = wire(lobby.joinTeam(doc, "guest", "B"))
	local lu = lobby.lineup(doc, { { id = "host", me = { name = "Ada" } }, { id = "guest", me = { name = "Bo" } } })
	local o = lobby.matchOptions(doc, lu, 3, START)
	expect.eq(o.togo, "on")
	o.mode = "match"
	tw.web.session.useTune("pointer")
	local s = tw.web.session.new(o)
	expect.eq(s:need().kind, "togo")
end)

test("a pitch without togo starts the match it always did", function()
	local doc = wire(lobby.joinTeam(nil, "host", "A"))
	doc = wire(lobby.joinTeam(doc, "guest", "B"))
	local lu = lobby.lineup(doc, { { id = "host", me = { name = "Ada" } }, { id = "guest", me = { name = "Bo" } } })
	local o = lobby.matchOptions(doc, lu, 3, START)
	expect.eq(o.togo, nil)
end)

test("seats: each side's baton to go is its first player's, else a teammate's, else the host's", function()
	local need = { kind = "togo", owe = { "A", "B" },
		throwers = { A = { key = "a1" }, B = { key = "b1" } } }
	local ctx = { players = { A = { { id = "a1" }, { id = "a2" } }, B = { { id = "b1" } } }, host = "a1",
		connected = { "a1", "a2", "b1" } }
	expect.eq(seats.togoActor(need, ctx, "A"), "a1")
	expect.eq(seats.togoActor(need, ctx, "B"), "b1")
	local both = seats.actorsFor(need, ctx)
	expect.eq(#both, 2)
	expect.truthy(seats.mayAct(need, ctx, "b1"))
	expect.eq(seats.mayAct(need, ctx, "a2"), false)
	-- a1 gone: a2 throws A's; b1 gone: the host's (here a2 is not the host: the host is a1, gone)
	ctx.connected = { "a2" }
	expect.eq(seats.togoActor(need, ctx, "A"), "a2")
	expect.eq(seats.togoActor(need, ctx, "B"), "a1")
	-- a side that has thrown owes nothing
	need.owe = { "B" }
	expect.eq(seats.togoActor(need, ctx, "A"), nil)
end)

test("controlFor with a togo need: the host who stands in for both throws only its own baton", function()
	local need = { kind = "togo", owe = { "A", "B" },
		throwers = { A = { key = "a1" }, B = { key = "b1" } } }
	local ctx = { players = { A = { { id = "a1" } }, B = { { id = "b1" } } }, host = "b1",
		connected = { "a1", "b1" } }
	local c = seats.controlFor(ctx, "b1", need)
	expect.eq(table.concat(c.sides, ","), "A,B", "the host may still stand in for both")
	expect.eq(table.concat(c.togo, ","), "B", "but throws only B's baton to go")
	expect.eq(table.concat(seats.controlFor(ctx, "a1", need).togo, ","), "A")
	expect.eq(seats.controlFor(ctx, "b1").togo, nil, "no need: as before")
	expect.eq(seats.sameControl(c, seats.controlFor(ctx, "b1")), false, "a togo list is part of the control")
	-- a1 gone: the host throws both
	ctx.connected = { "b1" }
	local c2 = seats.controlFor(ctx, "b1", need)
	expect.eq(table.concat(c2.togo, ","), "A,B")
	expect.eq(seats.sameControl(c, c2), false)
	-- through the door, and into the session: the host's session sets up B's baton, not A's
	local r = json.decode(kubbCall("pitch.controlFor", json.encode { ctx = { players = ctx.players, host = "b1",
		connected = { "a1", "b1" } }, me = "b1", need = need }), true).value
	expect.eq(table.concat(r.togo, ","), "B")
	local s = tw.web.session.new { mode = "match", seed = 4, start = START, togo = true,
		teams = { A = { name = "Team A", players = { { name = "Ann", key = "a1" } } },
			B = { name = "Team B", players = { { name = "Bo", key = "b1" } } } } }
	expect.eq(s:need().side, "A", "one device: A's first")
	local n = s:setControl { sides = r.sides, cpu = r.cpu, togo = r.togo }
	expect.eq(n.side, "B")
	expect.eq(n.setup.side, "B")
	n = s:setControl { sides = { "A", "B" } }
	expect.eq(n.side, "A", "no togo list: A then B again")
end)
