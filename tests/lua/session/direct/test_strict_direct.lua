-- The strict restore and replayLoad for a Lua caller that imports the session and the
-- replay directly and never loads session/api (which would load session/names for it).
-- Run in a Lua state of its own (make test-session's second step): in the state the other
-- session tests share, session/api is already loaded and would hide a missing import.
import "session/session"
import "session/replay"
import "session/json"
tw.web.session.useTune("pointer")
local session, json = tw.web.session, tw.web.json

test("strict restore works with session/api never imported", function()
	expect.eq(tw.web.api, nil)
	local s = session.new { mode = "match", surface = "Grass", seed = 7,
		start = { year = 2026, month = 11, day = 21, hour = 10, min = 0 },
		teams = { A = { name = "Mighty Maple", players = { { name = "Mighty Maple" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	local text = s:snapshot()
	local r = session.restore(text, nil, { names = "check" })
	expect.truthy(r, "an honest snapshot restores through the strict door")
	local d = json.decode(text)
	d.save.game.teams.A.name = "Typed Team"
	local ok, why = pcall(session.restore, json.encode(d), nil, { names = "check" })
	expect.eq(ok, false)
	expect.truthy(tostring(why):find("names not allowed", 1, true), tostring(why))
	expect.truthy(tw.web.namecheck.isDefault("Computer"))
end)
