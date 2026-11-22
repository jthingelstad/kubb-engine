-- The engine's own match settings (computer, scene) live in the pitch document's
-- top-level `settings`, so a client on 0.8 sharing the lobby keeps them: its lobbyOf
-- rebuilds `options` from the five keys it knows but passes a top-level key it does not
-- know through untouched. Proven here with 0.8.2's own reducers:
-- tests/fixtures/room-0.8.2/lobby.lua is `git show v0.8.2:room/lobby.lua`, unedited.
import "session/api"
import "session/json"
local json, NULL = tw.web.json, tw.web.json.null
local lobby = tw.shared.lobby

-- 0.8.2's lobby, loaded beside this engine's. It imports "room/js", which is pitch/js now
-- (loaded already), and stores itself on tw.room.lobby, which is tw.shared.lobby (the old
-- name is the same table), so the current one is put back after.
local function oldLobby()
	local now = tw.shared.lobby
	local chunk = assert(loadfile("tests/fixtures/room-0.8.2/lobby.lua"))
	local plain = import
	import = function(name) return plain((name:gsub("^room/", "pitch/"))) end
	local ok, err = pcall(chunk)
	import = plain
	assert(ok, err)
	local old = tw.shared.lobby
	tw.shared.lobby = now
	assert(old ~= now)
	return old
end
local old = oldLobby()

-- Each write goes over the wire as JSON, as between two clients.
local function wire(doc) return json.decode(json.encode(doc), true) end

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

test("a 0.9 host's computer level and scene survive a 0.8 client's joinTeam and setAccess", function()
	local doc = wire(lobby.joinTeam(nil, "host", "A"))
	doc = wire(lobby.setOptions(doc, { computer = "pro", scene = "night", wind = "light" }))
	expect.eq(doc.settings.computer, "pro")
	expect.eq(doc.settings.scene, "night")
	-- the 0.8 client joins, then sets the pitch open
	doc = wire(old.joinTeam(doc, "guest", "B"))
	expect.eq(doc.teams.B[1], "guest")
	doc = wire(old.setAccess(doc, true))
	expect.eq(doc.open, true)
	expect.eq(doc.settings.computer, "pro", "kept through 0.8's writes")
	expect.eq(doc.settings.scene, "night")
	expect.eq(doc.options.wind, "light")
	-- the 0.9 host reads them all, and starts the match with them
	local all = lobby.optionsOf(doc)
	expect.eq(all.computer, "pro")
	expect.eq(all.scene, "night")
	local lu = lobby.lineup(doc, { { id = "host", me = { name = "Ada" } }, { id = "guest", me = { name = "Bo" } } })
	local o = lobby.matchOptions(doc, lu, 3, { year = 2026, month = 11, day = 20, hour = 14, min = 0 })
	expect.eq(o.computer, "pro")
	expect.eq(o.scene, "night")
end)

test("why: inside options (as 0.9's first draft had them) a 0.8 write drops them", function()
	local doc = wire(lobby.joinTeam(nil, "host", "A"))
	doc.options.computer, doc.options.scene = "pro", "dusk"
	doc = wire(old.joinTeam(doc, "guest", "B"))
	expect.eq(doc.options.computer, nil)
	expect.eq(doc.options.scene, nil)
end)

test("settings: an invalid value is dropped, an absent one is the default, none is no key", function()
	local doc = wire(lobby.joinTeam(nil, "host", "A"))
	expect.eq(doc.settings, nil, "a pitch that never set one has no settings key")
	local all = lobby.optionsOf(doc)
	expect.eq(all.computer, "club")
	expect.eq(all.scene, "day")
	expect.eq(all.surface, "grass")
	expect.eq(lobby.setOptions(doc, { computer = "legend", scene = "Late Night" }), nil, "nothing valid: no change")
	local bad = lobby.lobbyOf { v = 1, teams = { A = { "host" }, B = {} }, settings = { computer = "legend", scene = "dusk" } }
	expect.eq(bad.settings.computer, nil, "an invalid one is dropped")
	expect.eq(bad.settings.scene, "dusk")
	expect.eq(lobby.lobbyOf({ v = 1, settings = { computer = 3 } }).settings, nil, "none valid: no key")
	-- one set, the other stays absent; a later update without it keeps it
	doc = wire(lobby.setOptions(doc, { scene = "night" }))
	expect.eq(doc.settings.scene, "night")
	expect.eq(doc.settings.computer, nil)
	doc = wire(lobby.setOptions(doc, { wind = "light" }))
	expect.eq(doc.settings.scene, "night")
	expect.eq(lobby.optionsOf(doc).computer, "club")
	-- through the door, as a client calls it
	expect.eq(pitch("optionsOf", { doc = doc }).scene, "night")
	expect.eq(pitch("optionsOf", { doc = NULL }).computer, "club")
end)

test("a document without settings reads and writes as before", function()
	local doc = wire(old.joinTeam(nil, "host", "A"))
	doc = wire(old.setOptions(doc, { wind = "strong" }))
	local now = lobby.lobbyOf(doc)
	expect.eq(json.encode(now), json.encode(old.lobbyOf(doc)))
end)
