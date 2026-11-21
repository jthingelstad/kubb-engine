-- The computer player chooses as 0.11.0 did (docs/notes/computer-player.md, "the split
-- itself, with no change in play"): autothrow.choose's whole result, and where it leaves
-- the random stream, over tests/lua/cpucases.lua's setups, line for line against
-- tests/fixtures/cpu/choose.txt (written by tools/cpufixture.lua from 0.11.0). Integers
-- and strings must match exactly. Floats must agree to one part in 10^9: the fixture
-- was written on one desktop and the test runs on others, whose maths libraries differ
-- in a result's last digit (docs/DETERMINISM.md: stock desktop Lua is for logic tests,
-- never for hashes). A choice that changed would move a number by far more than that.
import "core/tw"
import "core/autothrow"

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local root = here .. "/../.."

-- Two "path = value" lines that differ only in a float's last digits. An integer is
-- written without a point or an exponent (cpucases' num) and is never near, only equal.
local TOL <const> = 1e-9
local function near(g, w)
	if not g or not w then return false end
	local gp, gv = g:match("^(.-) = (.+)$")
	local wp, wv = w:match("^(.-) = (.+)$")
	if not gp or gp ~= wp then return false end
	if not (gv:find("[%.eEn]") and wv:find("[%.eEn]")) then return false end
	local a, b = tonumber(gv), tonumber(wv)
	if not a or not b then return false end
	local scale = math.max(1, math.abs(b))
	return math.abs(a - b) <= TOL * scale
end

test("autothrow.choose matches the 0.11.0 fixture in every field", function()
	local cases = dofile(root .. "/tests/lua/cpucases.lua")
	local got = cases.lines()
	local want = {}
	for line in io.lines(root .. "/tests/fixtures/cpu/choose.txt") do want[#want + 1] = line end
	local case = "?"
	for i = 1, math.max(#got, #want) do
		local g, w = got[i], want[i]
		if w and w:match("^case ") then case = w end
		if g ~= w and not near(g, w) then
			error(string.format("line %d (%s): expected %s, got %s", i, case, tostring(w), tostring(g)))
		end
	end
	expect.eq(#got, #want, "lines")
	expect.truthy(#want > 10000, "the fixture is there")
end)
