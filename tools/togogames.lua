-- Matches that open with the throw to go (1.4.0; docs/SESSION.md "The throw to go"),
-- played through the session to the end: Team A a person whose throws the computer's
-- autothrow scripts (its baton to go too), Team B the computer. Writes each game file
-- (with its [Engine:first] line) and the places its sheet kept beside it, for the notation
-- gate (`make games`).
--
--   lua5.4 tools/togogames.lua [--n 2] [--seed 1] [--out build/togogames] [--maxturns 30]

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end

import "session/session"
import "session/json"
import "core/autothrow"
import "core/togo"
import "core/match"
local session, json, autothrow, togo, match = tw.web.session, tw.web.json, tw.autothrow, tw.togo, tw.match
local sheetPlaces = dofile(here .. "/sheetplaces.lua")
session.useTune("pointer")

local n, seed, out, maxTurns = 2, 1, "build/togogames", 30
local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--n" then n = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--seed" then seed = tonumber(arg[i + 1]); i = i + 1
	elseif a == "--out" then out = arg[i + 1]; i = i + 1
	elseif a == "--maxturns" then maxTurns = tonumber(arg[i + 1]); i = i + 1
	else error("togogames: unknown argument " .. a) end
	i = i + 1
end
os.execute("mkdir -p '" .. out .. "'")


for gi = 1, n do
	local sd = seed * 1000 + gi
	-- a day each, so every game file has its own name
	local s = session.new { mode = "match", seed = sd, start = { year = 2026, month = 11, day = gi, hour = 12, min = 0 }, cpu = "B", togo = true, maxTurns = maxTurns,
		teams = { A = { name = "Team A", players = { { name = "Alex" } } }, B = { name = "Team B", players = { { name = "Sam" } } } } }
	local r = autothrow.rng(sd)
	local over, at
	for step = 1, 5000 do
		local nd = s:need()
		at = { year = 2026, month = 11, day = gi, hour = 12 + (step // 60) % 12, min = step % 60 }
		if nd.kind == "over" then over = nd; break end
		if nd.kind == "togo" then
			local setup = match.togoSetup(s.m, nd.side)
			local c = togo.cpuThrow(setup, r, "club", 1)
			local L = c.launch
			local res = s:apply(json.decode(json.encode {
				type = "togo", side = nd.side, round = nd.round, how = "baton", at = at,
				launch = { speed = L.speed, loft = L.loft, swivel = L.swivel, tilt = L.tilt or 0, tumble = L.tumble or 0,
					legal = true },
				stance = { x = c.x, y = c.y, set = true }, target = { x = c.tx, y = c.ty, set = true }, scripted = true,
			}))
			assert(res.ok, res.why)
		elseif nd.kind == "raise" then
			s:apply { type = "raise", at = at }
		elseif nd.kind == "punish" then
			s:apply { type = "punish", x = nd.cursor.x, y = nd.cursor.y, at = at }
		elseif nd.cpu then
			s:cpuPlay { at = at }
		else
			local ts = s.ts
			local c = autothrow.choose(s.setup, r, 1)
			tw.web.throw.showAim(ts, c)
			local L, how = tw.web.throw.cpuLaunch(ts, c)
			ts.playerX, ts.playerY = c.x, c.y
			local a = s:throwAction(L, how, { scripted = true, back = c.swing.back, stop = c.swing.releaseAngle })
			a.at = at
			s:apply(json.decode(json.encode(a)))
		end
	end
	assert(over and over.file, "togogames " .. gi .. ": no end")
	assert(over.file.text:find("[Engine:first \"", 1, true), "togogames " .. gi .. ": no [Engine:first]")
	local name = over.file.name
	local f = assert(io.open(out .. "/" .. name, "w"))
	f:write(over.file.text)
	f:close()
	f = assert(io.open(out .. "/" .. name:gsub("%.txt$", ".places.json"), "w"))
	f:write(sheetPlaces(s.m.game))
	f:close()
	print(string.format("togogames %d: first %s (%s); %s in %d turns", gi, s.m.game.first or "?",
		s.m.game.firstBy or "?", tostring(s.m.game.winner), s.m.game.turn))
end
