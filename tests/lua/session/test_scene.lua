-- A match carries its scene: kept in the start like the kubb set, through checkStart,
-- renameStart, restore, replay and the pitch's options; never read by the rules. An id
-- is lowercase letters, digits and hyphens, 1 to 24 characters (pitch/lobby.isScene);
-- "day", the default, is not written. session.new keeps any such id (a match recorded
-- before 0.14 restores and replays as it was); since 0.14 a client's new holds it to the
-- catalogue (core/scenes; tests/lua/session/test_scenes.lua).
import "session/session"
import "session/json"
import "session/replay"
import "session/api"
import "pitch/lobby"
tw.web.session.useTune("pointer")
local session, json, replay, lobby, NULL = tw.web.session, tw.web.json, tw.web.replay, tw.shared.lobby,
	tw.web.json.null

local START = { year = 2026, month = 11, day = 20, hour = 12, min = 0 }

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
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

test("the pitch carries the host's scene to the match; a pitch without one is as before", function()
	local doc = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	expect.eq(doc.settings, nil, "no settings until the host sets one")
	expect.eq(pitch("optionsOf", { doc = doc }).scene, "day", "absent: the default")
	doc = pitch("setOptions", { doc = doc, options = { scene = "night" } })
	expect.eq(doc.settings.scene, "night")
	expect.eq(doc.options.scene, nil, "not in options, which an older engine rebuilds")
	expect.eq(pitch("optionsOf", { doc = doc }).scene, "night")
	expect.eq(pitch("setOptions", { doc = doc, options = { scene = "Not One" } }), nil, "refused: nothing changes")
	expect.eq(pitch("setOptions", { doc = doc, options = { scene = "dusk" } }), nil,
		"since 0.14 only a scene the engine lists is taken")
	local d2 = pitch("setOptions", { doc = doc, options = { wind = "light" } })
	expect.eq(d2.settings.scene, "night", "an update without the scene keeps it")
	expect.eq(pitch("cleanOptions", { options = { scene = "night" } }).scene, nil, "cleanOptions is the JavaScript's")
	expect.eq(pitch("lobbyOf", { doc = { settings = { scene = "x y" } } }).settings, nil, "an invalid one is dropped")
	expect.eq(pitch("lobbyOf", { doc = { settings = { scene = "dusk" } } }).settings.scene, "dusk",
		"a well formed one a newer engine wrote is kept")
	local lu = pitch("lineup", { doc = doc, members = { { id = "m1", me = { name = "Ada" } } } })
	local o = pitch("matchOptions", { doc = doc, lineup = lu, seed = 5, start = START })
	expect.eq(o.scene, "night")
	o.mode = "match"
	expect.eq(session.new(o).opts.scene, "night")
	local c = pitch("constants", {})
	expect.eq(c.OPTION_DEFAULTS.scene, "day")
	expect.eq(c.MATCH_OPTIONS[1][1], "scene", "since 0.14 the Scene row comes first")
end)

test("practice has a scene too", function()
	local s = session.new { mode = "practice", scene = "dusk" }
	expect.eq(s:view().scene, "dusk")
	expect.eq(session.new({ mode = "practice" }):view().scene, "day")
end)
