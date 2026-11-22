-- What the score sheet kept of a game's positions, as JSON, for the notation
-- gate's round trip (tests/node/notation-gate.mjs): written beside each game
-- file a tool writes (<name>.places.json), so the gate can read the game file's
-- position lines back with pk-kubb-score's grammar and compare them with what
-- the engine had. In the engine's world frame (metres, x across -2.5..2.5, y
-- from Team A's baseline), never converted here:
--
--   { "turns": [ { "n": 3, "half": "b",          the half under attack
--                  "inkast": [[x, y], ...],      every player's t.inkastAt, or null
--                  "batons": [ [[x, y], ...] | null, ... ] } ] }   each baton's at
--
-- Needs `import` and core/notation loaded by the caller.
local fmt, concat = string.format, table.concat

local function points(list)
	if not list then return "null" end
	local out = {}
	for i, p in ipairs(list) do out[i] = fmt("[%.17g,%.17g]", p.x, p.y) end
	return "[" .. concat(out, ",") .. "]"
end

return function(game)
	local turns = {}
	for _, t in ipairs(game.sheet.turns) do
		local inkast = nil
		if t.inkastAt then
			inkast = {}
			for _, pid in ipairs(t.inkastOrder) do
				for _, p in ipairs(t.inkastAt[pid] or {}) do inkast[#inkast + 1] = p end
			end
		end
		local batons = {}
		for i, b in ipairs(t.batons) do batons[i] = points(b.at) end
		turns[#turns + 1] = fmt('{"n":%d,"half":"%s","inkast":%s,"batons":[%s]}', t.n,
			t.side == "A" and "b" or "a", points(inkast), concat(batons, ","))
	end
	return '{"turns":[' .. concat(turns, ",\n") .. "]}\n"
end
