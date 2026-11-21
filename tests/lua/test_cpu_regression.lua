-- The computer player chooses as 0.11.0 did (docs/notes/computer-player.md, "the split
-- itself, with no change in play"): autothrow.choose's whole result, and where it leaves
-- the random stream, over tests/lua/cpucases.lua's setups, line for line against
-- tests/fixtures/cpu/choose.txt (written by tools/cpufixture.lua from 0.11.0). Floats
-- must match exactly: the fixture and the test both run on desktop Lua.
import "core/tw"
import "core/autothrow"

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local root = here .. "/../.."

test("autothrow.choose matches the 0.11.0 fixture in every field", function()
	local cases = dofile(root .. "/tests/lua/cpucases.lua")
	local got = cases.lines()
	local want = {}
	for line in io.lines(root .. "/tests/fixtures/cpu/choose.txt") do want[#want + 1] = line end
	local case = "?"
	for i = 1, math.max(#got, #want) do
		local g, w = got[i], want[i]
		if w and w:match("^case ") then case = w end
		if g ~= w then
			error(string.format("line %d (%s): expected %s, got %s", i, case, tostring(w), tostring(g)))
		end
	end
	expect.eq(#got, #want, "lines")
	expect.truthy(#want > 10000, "the fixture is there")
end)
