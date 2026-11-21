-- Writes the computer player's regression fixture (tests/lua/cpucases.lua says what is
-- in it): every field of autothrow.choose's result over a few hundred seeded setups.
-- Written once from 0.11.0's autothrow, before the computer player was split into
-- read, plays, cpu and autothrow (0.11.1); test_cpu_regression holds every later
-- version to it. Rewrite it only in a release that changes play on purpose (a minor
-- version, with `make golden`), never to make the test pass.
--
--   lua5.4 tools/cpufixture.lua [--out tests/fixtures/cpu/choose.txt]
--   lua5.4 tools/cpufixture.lua --stdout > x.txt

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local root = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(root .. "/" .. name .. ".lua"))()
end

local out = root .. "/tests/fixtures/cpu/choose.txt"
local i = 1
while i <= #arg do
	if arg[i] == "--out" then out = arg[i + 1]; i = i + 1
	elseif arg[i] == "--stdout" then out = nil
	else error("unknown argument " .. arg[i]) end
	i = i + 1
end

local cases = dofile(root .. "/tests/lua/cpucases.lua")
local text = table.concat(cases.lines(), "\n") .. "\n"
if out then
	local f = assert(io.open(out, "w"))
	f:write(text)
	f:close()
	io.stderr:write(string.format("cpufixture: %d setups, %d bytes to %s\n", cases.count, #text, out))
else
	io.write(text)
end
