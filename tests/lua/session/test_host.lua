-- What the host sets at start-up (docs/SESSION.md "Starting"): the engine's version,
-- the tune and the client label written into game files.
import "session/api"
import "session/json"
tw.web.session.useTune("pointer") -- the web's tune: these tests were written for it
local session, json, api = tw.web.session, tw.web.json, tw.web.api

local function call(method, a)
	return json.decode(api.call(method, a and json.encode(a) or nil))
end

local function kubbCall(method, a)
	return json.decode(_G.kubbCall(method, a and json.encode(a) or ""))
end

local START = { year = 2026, month = 11, day = 17, hour = 9, min = 0 }

test("engineVersion is version.lua's, and engine.json carries the same", function()
	local v = call("engineVersion")
	expect.eq(v.version, tw.engine.version)
	expect.truthy(v.version:match("^%d+%.%d+%.%d+$"), "a major.minor.patch version")
	local here = arg[0]:match("^(.*)/[^/]*$") or "."
	local f = assert(io.open(here .. "/../../engine.json"))
	local m = json.decode(f:read("a"))
	f:close()
	expect.eq(m.version, v.version, "engine.json version")
end)

test("the default client label is kubb-engine and the version", function()
	expect.eq(session.client, "kubb-engine " .. tw.engine.version)
end)

test("setClient's label is what the game file is scored by", function()
	local old = session.client
	expect.eq(call("setClient", { label = "web 9.9.9" }).client, "web 9.9.9")
	local s = session.new { mode = "match", seed = 3, cpu = "both", start = START, maxTurns = 1 }
	local sheet = s:sheet()
	expect.truthy(sheet.text:find("[Scored by \"Throwing Wood web 9.9.9\"]", 1, true), "the sheet names the client")
	session.setClient(old)
	expect.truthy(not s:sheet().text:find("web 9.9.9", 1, true), "read when the file is written")
end)

test("the client label is not in the snapshot, so it never changes a hash", function()
	local old = session.client
	local o = { mode = "match", seed = 11, cpu = "both", start = START, wind = "light" }
	local a = session.new(o)
	session.setClient("ios 1.0.0")
	local b = session.new(o)
	session.setClient(old)
	expect.eq(a:hash(), b:hash())
end)

test("setClient refuses what a game file line could not carry", function()
	for _, bad in ipairs { "", "web\n1", " web", "web ", string.rep("x", 41), "web/1", 7 } do
		local r = kubbCall("setClient", { label = bad })
		expect.truthy(r.error, "refused: " .. tostring(bad))
	end
	expect.eq(session.client, "kubb-engine " .. tw.engine.version, "unchanged")
end)

test("useTune keeps its first choice: the same name again is fine, another is refused", function()
	expect.eq(call("useTune", { name = "pointer" }).tune, "pointer")
	expect.truthy(kubbCall("useTune", { name = "touch" }).error, "another tune")
	expect.truthy(kubbCall("useTune", { name = "../core/tw" }).error, "not a tune name")
	expect.truthy(kubbCall("useTune", {}).error, "no name")
	expect.eq(session.tuneName, "pointer")
end)

test("the pointer tune is in the core's tables", function()
	expect.eq(tw.swing.tune.fullFlickDps, tw.tune.pointer.swing.fullFlickDps)
	expect.eq(tw.web.tune, tw.tune.pointer)
end)
