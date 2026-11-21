-- The computer player's regression: autothrow.choose's whole result, and where it leaves
-- the random stream, over tests/lua/cpucases.lua's setups, line for line against a
-- fixture. tests/fixtures/cpu/choose.txt is the engine as shipped (tools/cpufixture.lua
-- rewrote it in 0.12.0 when field.line and inkast.depth were switched on);
-- tests/fixtures/cpu/choose-0.11.txt is 0.11.0's, which the engine must still match with
-- those plays switched off (docs/notes/computer-player.md, "How a play gets in"). Integers
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

-- 0.12.0's plays as shipped (field.line and inkast.depth, both at pro only):
-- tests/fixtures/cpu/choose.txt, rewritten by tools/cpufixture.lua when they were
-- switched on.
test("autothrow.choose matches the 0.12.0 fixture in every field", function()
	against("choose.txt")
end)

-- With every play 0.12.0 added switched off (cpu.tune's on = 0), the computer chooses
-- exactly as 0.11.0 did: tests/fixtures/cpu/choose-0.11.txt is the fixture 0.11.0 wrote,
-- untouched.
test("with the 0.12.0 plays off, autothrow.choose matches the 0.11.0 fixture", function()
	local cpu = tw.cpu
	local saved = {}
	for name, p in pairs(cpu.tune) do saved[name] = p.on; p.on = 0 end
	local ok, err = pcall(against, "choose-0.11.txt")
	for name, p in pairs(cpu.tune) do p.on = saved[name] end
	if not ok then error(err, 0) end
end)
