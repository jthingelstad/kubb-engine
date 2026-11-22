-- Computer seats on a shared pitch (0.17.0, docs/PITCH.md "Computer seats"): the
-- document's `computers`, the host's reducers, the lineup and START checks, and who acts
-- for a mixed team (a person never for a computer partner, nor the computer for a
-- person), including a host change mid-match.
import "session/api"
import "session/json"
import "core/namegen"
local json, namegen = tw.web.json, tw.namegen
kubbCall("useTune", json.encode { name = "pointer" })
local NULL = json.null

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

local function members(list)
	local out = {}
	for _, id in ipairs(list) do
		out[#out + 1] = { id = id, connected = true, me = { name = "Mighty Maple", level = "club", engine = tw.engine.version } }
	end
	return out
end

-- Jamie and Tyler with a pro computer partner each (the owner's second example).
local function twoByTwo()
	local d = pitch("joinTeam", { doc = NULL, id = "jamie001", side = "A" })
	d = pitch("joinTeam", { doc = d, id = "tyler001", side = "B" })
	d = pitch("addComputer", { doc = d, side = "A", level = "pro", seed = 11 })
	d = pitch("addComputer", { doc = d, side = "B", level = "pro", seed = 12 })
	return d
end

test("addComputer: a seat with a level and a generated name", function()
	local d = twoByTwo()
	expect.eq(d.teams.A[2], "cpu:1")
	expect.eq(d.teams.B[2], "cpu:2")
	expect.eq(d.computers["cpu:1"].level, "pro")
	expect.truthy(namegen.valid("player", d.computers["cpu:1"].name))
	expect.truthy(d.computers["cpu:1"].name ~= d.computers["cpu:2"].name, "no two seats share a name")
	-- the same seed, the same name on every client
	local e = pitch("addComputer", { doc = pitch("joinTeam", { doc = NULL, id = "jamie001", side = "A" }), side = "A",
		level = "pro", seed = 11 })
	expect.eq(e.computers["cpu:1"].name, d.computers["cpu:1"].name)
	-- a name given is kept; refusals
	local n = pitch("addComputer", { doc = NULL, side = "B", level = "club", name = "Proud Plum" })
	expect.eq(n.computers["cpu:1"].name, "Proud Plum")
	expect.eq(pitch("addComputer", { doc = d, side = "A", level = "kid", seed = 1 }), nil, "Kid is the match's")
	expect.eq(pitch("addComputer", { doc = d, side = "A", level = "expert", seed = 1 }), nil)
	expect.eq(pitch("addComputer", { doc = d, side = "C", level = "club", seed = 1 }), nil)
	expect.eq(pitch("addComputer", { doc = d, side = "A", level = "club" }), nil, "no seed and no name")
	expect.eq(pitch("addComputer", { doc = d, side = "A", level = "club", name = "Typed Name", seed = 2.5 }), nil)
	-- six a team, people and computers together
	local f = d
	for k = 1, 4 do f = pitch("addComputer", { doc = f, side = "A", level = "club", seed = k }) end
	expect.eq(#f.teams.A, 6)
	expect.eq(pitch("addComputer", { doc = f, side = "A", level = "club", seed = 9 }), nil, "a full side")
	expect.eq(pitch("joinTeam", { doc = f, id = "other001", side = "A" }), nil, "a seat is a place")
	-- a team of computers only is allowed
	local t = pitch("addComputer", { doc = d, side = "B", level = "club", seed = 3 })
	expect.truthy(t)
end)

test("setComputerLevel, moveComputer, removeComputer", function()
	local d = twoByTwo()
	local l = pitch("setComputerLevel", { doc = d, id = "cpu:1", level = "beginner" })
	expect.eq(l.computers["cpu:1"].level, "beginner")
	expect.eq(pitch("setComputerLevel", { doc = l, id = "cpu:1", level = "beginner" }), nil, "unchanged")
	expect.eq(pitch("setComputerLevel", { doc = l, id = "cpu:1", level = "kid" }), nil)
	expect.eq(pitch("setComputerLevel", { doc = l, id = "cpu:9", level = "club" }), nil, "no such seat")
	-- first in A's throwing order
	local m = pitch("moveComputer", { doc = d, id = "cpu:1", side = "A", index = 0 })
	expect.eq(m.teams.A[1], "cpu:1")
	expect.eq(m.teams.A[2], "jamie001")
	expect.eq(pitch("moveComputer", { doc = m, id = "cpu:1", side = "A", index = 0 }), nil, "already there")
	-- to the other team, last
	local x = pitch("moveComputer", { doc = d, id = "cpu:1", side = "B" })
	expect.eq(#x.teams.A, 1)
	expect.eq(x.teams.B[3], "cpu:1")
	local r = pitch("removeComputer", { doc = x, id = "cpu:1" })
	expect.eq(r.computers["cpu:1"], nil)
	expect.eq(#r.teams.B, 2)
	local r2 = pitch("removeComputer", { doc = r, id = "cpu:2" })
	expect.eq(r2.computers, nil, "no seat left: no computers key")
	expect.eq(pitch("removeComputer", { doc = r2, id = "cpu:2" }), nil)
	-- and none while a match runs
	local started = twoByTwo()
	started.started = true
	expect.eq(pitch("addComputer", { doc = started, side = "A", level = "club", seed = 1 }), nil)
	expect.eq(pitch("moveComputer", { doc = started, id = "cpu:1", side = "B" }), nil)
	expect.eq(pitch("removeComputer", { doc = started, id = "cpu:1" }), nil)
	expect.eq(pitch("setComputerLevel", { doc = started, id = "cpu:1", level = "club" }), nil)
end)

test("lobbyOf never half-holds a seat; a document without one is as before", function()
	local d = pitch("lobbyOf", { doc = { teams = { A = { "jamie001", "cpu:1", "cpu:3" }, B = { "cpu:2" } },
		computers = { ["cpu:1"] = { level = "pro", name = "Proud Plum" }, ["cpu:2"] = { level = "kid" },
			["cpu:4"] = { level = "club" } } } })
	expect.eq(#d.teams.A, 2, "cpu:3 has no record")
	expect.eq(d.teams.A[2], "cpu:1")
	expect.eq(#d.teams.B, 0, "cpu:2's level is not a seat's")
	expect.eq(d.computers["cpu:4"], nil, "a record no team holds")
	local typed = pitch("lobbyOf", { doc = { teams = { A = { "cpu:1" } }, computers = { ["cpu:1"] = { level = "club", name = "Typed" } } } })
	expect.eq(typed.computers["cpu:1"].name, nil, "a name that is not generated is not kept")
	local plain = pitch("lobbyOf", { doc = { teams = { A = { "jamie001" } } } })
	expect.eq(plain.computers, nil)
	expect.eq(pitch("joinTeam", { doc = d, id = "cpu:1", side = "B" }), nil, "a seat is no member")
	local p = pitch("pruneTeams", { doc = twoByTwo(), present = { "jamie001" } })
	expect.eq(#p.teams.A, 2, "pruning keeps the computers")
	expect.eq(p.teams.B[1], "cpu:2")
	local listing = pitch("openListing", { doc = (function() local x = twoByTwo(); x.open = true; return x end)(),
		members = members { "jamie001", "tyler001" } })
	expect.eq(listing.seats, 10)
end)

test("the lineup, matchOptions and the session take both of the owner's examples", function()
	-- 2 v 2 with pro partners
	local d = twoByTwo()
	local lu = pitch("lineup", { doc = d, members = members { "jamie001", "tyler001" } })
	expect.eq(lu.cpu, NULL, "no side is the computer's whole")
	expect.eq(lu.players.A[2].cpu, true)
	expect.eq(lu.players.A[2].level, "pro")
	expect.eq(lu.players.A[2].name, d.computers["cpu:1"].name)
	local o = pitch("matchOptions", { doc = d, lineup = lu, seed = 5, start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 } })
	expect.eq(o.teams.A.players[2].cpu, true)
	expect.eq(o.teams.A.players[2].key, "cpu:1")
	o.mode = "match"
	local v = json.decode(kubbCall("new", json.encode(o)))
	expect.eq(v.error, nil, tostring(v.error))
	-- three friends against a team of three computers, two at club and one at pro
	local t = NULL
	for _, id in ipairs { "ann00001", "bob00001", "cat00001" } do t = pitch("joinTeam", { doc = t, id = id, side = "A" }) end
	t = pitch("addComputer", { doc = t, side = "B", level = "club", seed = 1 })
	t = pitch("addComputer", { doc = t, side = "B", level = "club", seed = 2 })
	t = pitch("addComputer", { doc = t, side = "B", level = "pro", seed = 3 })
	local lu2 = pitch("lineup", { doc = t, members = members { "ann00001", "bob00001", "cat00001" } })
	expect.eq(lu2.cpu, NULL)
	expect.eq(#lu2.players.B, 3)
	local check = pitch("startCheck", { players = lu2.players, members = members { "ann00001", "bob00001", "cat00001" },
		host = "ann00001" })
	expect.eq(check.ok, true, "computers have no engine to check")
	expect.eq(check.why, nil)
	local o2 = pitch("matchOptions", { doc = t, lineup = lu2, seed = 6 })
	o2.mode = "match"
	local v2 = json.decode(kubbCall("new", json.encode(o2)))
	expect.eq(v2.error, nil, tostring(v2.error))
	expect.eq(json.decode(kubbCall("need", "")).teams.B, "Team B")
	-- the empty side still gets the computer at the match's level
	local e = pitch("lineup", { doc = pitch("joinTeam", { doc = NULL, id = "ann00001", side = "A" }), members = members { "ann00001" } })
	expect.eq(e.cpu, "B")
end)

test("START refuses a lineup the session would refuse, with a reason", function()
	local m = members { "jamie001" }
	local none = pitch("startCheck", { players = { A = { { id = "cpu:1", name = "Proud Plum", level = "pro", cpu = true } }, B = {} },
		members = m, host = "jamie001" })
	expect.eq(none.ok, false)
	expect.eq(none.why, "person")
	expect.truthy(none.text)
	local lv = pitch("startCheck", { players = { A = { { id = "jamie001", name = "A" } },
		B = { { id = "cpu:1", name = "Proud Plum", level = "kid", cpu = true } } }, members = m, host = "jamie001" })
	expect.eq(lv.why, "level")
	local big = { { id = "jamie001", name = "A" } }
	for k = 1, 6 do big[#big + 1] = { id = "cpu:" .. k, name = "Proud Plum", level = "club", cpu = true } end
	local sz = pitch("startCheck", { players = { A = big, B = {} }, members = m, host = "jamie001" })
	expect.eq(sz.why, "size")
	local ok = pitch("startCheck", { players = { A = { { id = "jamie001", name = "A" } }, B = {} }, members = m, host = "jamie001" })
	expect.eq(ok.ok, true)
	expect.eq(ok.why, nil, "no refusal, no why")
	-- startMatch refuses it too, and keeps a computer player's cpu and level
	expect.eq(pitch("startMatch", { doc = NULL, snap = "s", hash = "h", players = none.ok and {} or
		{ A = { { id = "cpu:1", name = "Proud Plum", level = "pro", cpu = true } }, B = {} }, cpu = "B", host = "jamie001",
		members = m }), nil)
	local d = twoByTwo()
	local mm = members { "jamie001", "tyler001" }
	local lu = pitch("lineup", { doc = d, members = mm })
	local s = pitch("startMatch", { doc = d, snap = "s", hash = "h", players = lu.players, cpu = lu.cpu, host = "jamie001",
		members = mm })
	expect.eq(s.match.players.A[2].cpu, true)
	expect.eq(s.match.players.A[2].level, "pro")
	expect.eq(s.match.players.A[1].cpu, nil)
	local rep = json.decode(kubbCall("names.check", json.encode { document = d, members = mm }))
	expect.eq(rep.allowed, true, json.encode(rep.refused))
	local bad = twoByTwo()
	bad.computers["cpu:1"].name = "Typed Name"
	local rep2 = json.decode(kubbCall("names.check", json.encode { document = bad }))
	expect.eq(rep2.allowed, false, "a seat's typed name is refused")
end)

-- who acts: Jamie (host) and a pro partner on A, Tyler and a pro partner on B
local function ctx(host, connected)
	return {
		players = { A = { { id = "jamie001", name = "Mighty Maple" }, { id = "cpu:1", name = "Proud Plum", cpu = true, level = "pro" } },
			B = { { id = "tyler001", name = "Quiet Juniper" }, { id = "cpu:2", name = "Feisty Fir", cpu = true, level = "pro" } } },
		cpu = NULL, host = host, connected = connected or { "jamie001", "tyler001" },
	}
end
local function throwNeed(side, key, cpu)
	return { kind = "throw", side = side, cpu = cpu, setup = { thrower = { key = key, cpu = cpu or nil } } }
end

test("who acts for a mixed team", function()
	local c = ctx("jamie001")
	-- Tyler's computer partner: the host's engine throws it, nobody acts by hand
	local n = throwNeed("B", "cpu:2", true)
	expect.eq(pitch("shownActor", { need = n, ctx = c }), "cpu")
	expect.eq(pitch("mayAct", { need = n, ctx = c, me = "tyler001" }), false, "a person never acts for a computer partner")
	expect.eq(pitch("mayAct", { need = n, ctx = c, me = "jamie001" }), false, "nor the host by hand")
	-- Tyler's own throw: Tyler's, never the computer's
	local t = throwNeed("B", "tyler001", false)
	expect.eq(pitch("mayAct", { need = t, ctx = c, me = "tyler001" }), true)
	expect.eq(pitch("shownActor", { need = t, ctx = c }), "tyler001")
	-- Tyler gone: his throw goes to the host, as a person's throw always has, never to his partner
	local gone = ctx("jamie001", { "jamie001" })
	local who = pitch("actorsFor", { need = t, ctx = gone })
	expect.eq(#who, 1)
	expect.eq(who[1], "jamie001")
	-- a raise is for the defending team's people
	local raise = { kind = "raise", side = "B" }
	local mates = pitch("actorsFor", { need = raise, ctx = c })
	expect.eq(#mates, 1)
	expect.eq(mates[1], "tyler001")
	-- teamIds: the people only
	local ids = pitch("teamIds", { ctx = c, side = "A" })
	expect.eq(#ids, 1)
	expect.eq(ids[1], "jamie001")
	-- control: each person their side, the computer only the host's
	local cj = pitch("controlFor", { ctx = c, me = "jamie001" })
	expect.eq(cj.cpu, true)
	local ct = pitch("controlFor", { ctx = c, me = "tyler001" })
	expect.eq(ct.cpu, false)
	expect.eq(#ct.sides, 1)
	expect.eq(ct.sides[1], "B")
	-- the host changes mid-match: Tyler throws for both computers from now
	local after = ctx("tyler001", { "tyler001" })
	local ct2 = pitch("controlFor", { ctx = after, me = "tyler001" })
	expect.eq(ct2.cpu, true)
	expect.eq(pitch("actorsFor", { need = throwNeed("A", "cpu:1", true), ctx = after })[1], "tyler001")
	expect.eq(pitch("mayAct", { need = throwNeed("A", "cpu:1", true), ctx = after, me = "tyler001" }), false,
		"by its engine, not by hand")
	expect.eq(pitch("playingSide", { ctx = c, me = "cpu:1" }), nil, "a computer is no member")
end)
