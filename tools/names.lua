-- Every generated name (core/namegen, docs/NAMES.md "Review"): writes or checks
-- tests/names/<kind>.txt, one name a line, sorted. The files are committed so a pull
-- request that changes core/namewords shows every name it adds or takes away.
--
--   lua5.4 tools/names.lua --write     (make names)
--   lua5.4 tools/names.lua --check     (make names-check, part of make test)
--   lua5.4 tools/names.lua --sample N  (N rolled names of each kind, seed 1)

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end

import "core/namegen"
local namegen = tw.namegen

local mode, n = arg[1], tonumber(arg[2])

local function path(kind) return sourceDir .. "/tests/names/" .. kind .. ".txt" end

if mode == "--sample" then
	math.randomseed(1)
	for _, kind in ipairs(namegen.KINDS) do
		local out = {}
		for _ = 1, n or 20 do out[#out + 1] = (namegen.roll(kind, math.random)) end
		print(kind .. ": " .. table.concat(out, ", "))
	end
	return
end

local bad = 0
for _, kind in ipairs(namegen.KINDS) do
	local text = table.concat(namegen.all(kind), "\n") .. "\n"
	if mode == "--write" then
		local f = assert(io.open(path(kind), "w"))
		f:write(text)
		f:close()
		print(("names: %s, %d names"):format(kind, select(2, text:gsub("\n", ""))))
	elseif mode == "--check" then
		local f = io.open(path(kind))
		local had = f and f:read("a")
		if f then f:close() end
		if had ~= text then
			print(("names: tests/names/%s.txt is not what core/namewords makes; run make names and review the diff"):format(kind))
			bad = bad + 1
		end
	else
		error("usage: tools/names.lua --write | --check | --sample N")
	end
end
os.exit(bad == 0 and 0 or 1)
