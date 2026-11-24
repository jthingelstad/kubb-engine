-- Writes the file of each of record mode's games (tests/fixtures/record/games.lua) into a
-- folder, for the notation gate: make test-node runs
--
--   lua5.4 tools/recordgames.lua --out build/recordgames
--   node tests/node/notation-gate.mjs build/recordgames
--
-- so every file record mode writes in its tests passes pk-kubb-score's grammar, canonical
-- writer and kubb.js with no warnings (docs/RECORD.md). --print writes them to stdout
-- instead, with each game's warnings.

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end

import "core/tw"
import "version"
import "core/record"
local record = tw.record

local out, show = nil, false
local i = 1
while i <= #arg do
	if arg[i] == "--out" then out = arg[i + 1]; i = i + 2
	elseif arg[i] == "--print" then show = true; i = i + 1
	else error("unknown argument " .. arg[i]) end
end
if not out and not show then error("usage: lua5.4 tools/recordgames.lua --out <dir> | --print") end

local games = assert(loadfile(sourceDir .. "/tests/fixtures/record/games.lua"))()
local names = {}
for name in pairs(games) do names[#names + 1] = name end
table.sort(names)

if out then os.execute("mkdir -p '" .. out .. "'") end
for _, name in ipairs(names) do
	local g = games[name]
	local r = record.build(g.setup, g.events)
	local text = record.render(r)
	if show then
		print("==== " .. name)
		io.write(text)
		for _, w in ipairs(r.warnings) do
			print(string.format("  warning %s at event %d (turn %s): %s", w.code, w.event, tostring(w.turn), w.text))
		end
	end
	if out then
		local f = assert(io.open(out .. "/record-" .. name .. ".txt", "w"))
		f:write(text)
		f:close()
	end
end
