-- The computer player's regression: autothrow.choose's whole result, and where it leaves
-- the random stream, over tests/lua/cpucases.lua's setups, line for line against a
-- fixture. tests/fixtures/cpu/choose.txt is 0.11.0's (tools/cpufixture.lua), and the
-- engine as shipped still matches it: field.line and inkast.depth are built switched off
-- in 0.11.3 (docs/notes/computer-player.md, "How a play gets in"). Integers
-- and strings must match exactly. Floats must agree to one part in 10^9: the fixture
-- was written on one desktop and the test runs on others, whose maths libraries differ
-- in a result's last digit (docs/DETERMINISM.md: stock desktop Lua is for logic tests,
-- never for hashes). A choice that changed would move a number by far more than that.
import "core/tw"
import "core/autothrow"
import "core/cpu"

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

-- Every line of tests/lua/cpucases.lua's setups against a fixture file.
local function against(file)
	local cases = dofile(root .. "/tests/lua/cpucases.lua")
	local got = cases.lines()
	local want = {}
	for line in io.lines(root .. "/tests/fixtures/cpu/" .. file) do want[#want + 1] = line end
	local case = "?"
	for i = 1, math.max(#got, #want) do
		local g, w = got[i], want[i]
		if w and w:match("^case ") then case = w end
		if g ~= w and not near(g, w) then
			error(string.format("%s line %d (%s): expected %s, got %s", file, i, case, tostring(w), tostring(g)))
		end
	end
	expect.eq(#got, #want, "lines")
	expect.truthy(#want > 10000, "the fixture is there")
end

-- The engine as shipped: the plays 0.11.3 built know no level, so the computer chooses
-- exactly as 0.11.0 did.
test("autothrow.choose matches the 0.11.0 fixture in every field", function()
	against("choose.txt")
end)

-- And with every play 0.11.3 built switched off entirely too (cpu.tune's on = 0), the
-- way the Gym and the tests switch them: the same fixture.
test("with the 0.11.3 plays off (on = 0), autothrow.choose matches the 0.11.0 fixture", function()
	local cpu = tw.cpu
	local saved = {}
	for name, p in pairs(cpu.tune) do saved[name] = p.on; p.on = 0 end
	local ok, err = pcall(against, "choose.txt")
	for name, p in pairs(cpu.tune) do p.on = saved[name] end
	if not ok then error(err, 0) end
end)
