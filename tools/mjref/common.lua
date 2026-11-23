-- Loads the engine's core (core/) for the tools/mjref Lua scripts, with
-- the same import shim as tools/batonprobe.lua, and returns the helpers they
-- share: json, cases and the mode's surface.
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local sourceDir = here .. "/../.."
local imported = {}
function import(name)
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(sourceDir .. "/" .. name .. ".lua"))()
end
import "core/tw"
import "core/world"
import "core/collide"
import "core/flight"
import "core/drill"
import "core/throwplan"

local M = {}
M.json = dofile(here .. "/json.lua")
M.cases = dofile(here .. "/cases.lua")

-- The surface table for a mode. "mech": the flat plane (no texture) without
-- the turf's dig and bite, the mechanics MuJoCo can also model; rolling
-- resistance (roll) stays, MuJoCo has it too. "game": the surface as played.
function M.surface(name, mode)
	local s = tw.world.surfaces[name]
	if mode == "game" then return s end
	local flat = {}
	for k, v in pairs(s) do flat[k] = v end
	flat.texture, flat.dig, flat.bite = nil, 0, 0
	return flat
end

-- The case list a run uses: cases.all(), or with `--cases drive` (anywhere in arg) the
-- drive cases alone (cases.drive, 0.16.0), `--per n` throws a setting; `--cases column` the
-- columns and piles of kubb on kubb (cases.column, 0.18).
function M.list()
	local which, per = "all", nil
	for i = 1, #arg do
		if arg[i] == "--cases" then which = arg[i + 1] end
		if arg[i] == "--per" then per = tonumber(arg[i + 1]) end
	end
	if which == "drive" then return M.cases.drive(per) end
	if which == "column" then return M.cases.column() end
	return M.cases.all()
end

return M
