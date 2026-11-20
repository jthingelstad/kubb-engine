-- A match carries its scene, a look only: kept in the start like the kubb set, through
-- checkStart, renameStart, restore, replay and the room's options; never read by the
-- physics or the rules. An id is lowercase letters, digits and hyphens, 1 to 24
-- characters (room/lobby.isScene); "day", the default, is not written.
import "session/session"
import "session/json"
import "session/replay"
import "session/api"
import "room/lobby"
tw.web.session.useTune("pointer")
local session, json, replay, lobby, NULL = tw.web.session, tw.web.json, tw.web.replay, tw.room.lobby,
	tw.web.json.null

local START = { year = 2026, month = 11, day = 20, hour = 12, min = 0 }

local function room(name, args)
	local out = json.decode(kubbCall("room." .. name, json.encode(args)), true)
	if out.error then error("room." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

local function watch(o)
	local m = { mode = "match", seed = 4, cpu = "both", start = START, raising = "auto", maxTurns = 4 }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

local function playOut(s)
	local log = {}
	for _ = 1, 400 do
		if s:need().kind == "over" then break end
		local a
		for _ = 1, 3000 do
			local f = s:frame { dt = 1 / 30 }
			if f.action then a = f.action break end
		end
		if not a then break end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
	end
	return log
end

test("an id is lowercase letters, digits and hyphens, 1 to 24 characters", function()
	for _, v in ipairs { "day", "dusk", "night-2", "a", string.rep("x", 24) } do
		expect.truthy(lobby.isScene(v), v)
	end
	for _, v in ipairs { "", "Dusk", "dusk!", "late night", string.rep("x", 25), 3, true } do
		expect.truthy(not lobby.isScene(v), tostring(v))
	end
end)

test("the scene is in the start when given; day or none is the start as before", function()
	local plain = watch()
	expect.eq(plain.opts.scene, nil)
	expect.eq(plain:view().scene, "day")
	expect.eq(watch({ scene = "day" }):snapshot(), plain:snapshot(), "day, the default, is not written")
	expect.eq(watch({ scene = "Dusk!" }):snapshot(), plain:snapshot(), "an id it does not take is no option")
	local dusk = watch { scene = "dusk" }
	expect.eq(dusk.opts.scene, "dusk")
	expect.eq(dusk:view().scene, "dusk")
	expect.truthy(dusk:snapshot():find('"scene":"dusk"', 1, true))
end)

test("a look only: the same match, throw for throw, in any scene", function()
	local a, b = watch(), watch { scene = "night" }
	local la, lb = playOut(a), playOut(b)
	expect.eq(#la, #lb)
	for i = 1, #la do
		expect.eq(json.encode(la[i].a), json.encode(lb[i].a), "action " .. i)
	end
	expect.eq(a.m.game.winner, b.m.game.winner)
end)

test("checkStart, renameStart, restore and replay keep the scene", function()
	local s = session.new { mode = "match", seed = 6, cpu = "B", start = START, scene = "dusk",
		teams = { A = { name = "Ada", players = { { name = "Ada", key = "m1" } } } } }
	local start = s:snapshot()
	expect.eq((session.startCheck(start)), true)
	expect.eq((session.startCheck((start:gsub('"scene":"dusk"', '"scene":"Dusk"')))), false,
		"a scene the engine would not keep is not a start")
	expect.eq(json.decode(session.renameStart(start, { A = "Bea" })).opts.scene, "dusk")
	local r = session.restore(start)
	expect.eq(r.opts.scene, "dusk")
	expect.eq(r:snapshot(), start)
	local w = watch { scene = "dusk", cpu = "both" }
	local wstart = w:snapshot()
	local log = playOut(w)
	expect.eq(replay.new({ start = wstart, log = log }):finish().differs, false)
	expect.eq(replay.new({ setup = session.setupOf(wstart), log = log }):finish().differs, false)
end)

test("the room carries the host's scene to the match; a room without one is as before", function()
	local doc = room("joinTeam", { doc = NULL, id = "m1", side = "A" })
	expect.eq(doc.options.scene, nil)
	doc = room("setOptions", { doc = doc, options = { scene = "dusk" } })
	expect.eq(doc.options.scene, "dusk")
	expect.eq(room("setOptions", { doc = doc, options = { scene = "Not One" } }), nil, "refused: nothing changes")
	local d2 = room("setOptions", { doc = doc, options = { surface = "sand" } })
	expect.eq(d2.options.scene, "dusk", "an update without the scene keeps it")
	expect.eq(room("cleanOptions", { options = { scene = "dusk" } }).scene, "dusk")
	expect.eq(room("cleanOptions", { options = { scene = "x y" } }).scene, nil)
	local lu = room("lineup", { doc = doc, members = { { id = "m1", me = { name = "Ada" } } } })
	local o = room("matchOptions", { doc = doc, lineup = lu, seed = 5, start = START })
	expect.eq(o.scene, "dusk")
	o.mode = "match"
	expect.eq(session.new(o).opts.scene, "dusk")
	local c = room("constants", {})
	expect.eq(c.OPTION_DEFAULTS.scene, "day")
	for _, row in ipairs(c.MATCH_OPTIONS) do expect.truthy(row[1] ~= "scene", "the client labels scenes") end
end)

test("practice has a scene too", function()
	local s = session.new { mode = "practice", scene = "dusk" }
	expect.eq(s:view().scene, "dusk")
	expect.eq(session.new({ mode = "practice" }):view().scene, "day")
end)
