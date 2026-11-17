-- The golden driver under desktop Lua (docs/DETERMINISM.md): plays the matches and
-- prints JSON like hashes.json. Stock desktop Lua is for logic tests only: compare
-- with `node tests/golden/golden.mjs --compare <file>` to see how far its libm agrees.
--   lua5.4 tests/golden/native.lua [dt] > build/golden-native.json
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local root = here .. "/../.."
local imported = {}
function import(name)
	name = name:gsub("%.lua$", "")
	if imported[name] then return nil end
	imported[name] = true
	return assert(loadfile(root .. "/" .. name .. ".lua"))()
end
import "tests/golden/drive"
local golden, json = tw.golden, tw.web.json
local dt = tonumber(arg[1] or "") or 1 / 60
local out = {}
for i, m in ipairs(golden.matches()) do
	out[i] = golden.play(m, dt)
	io.stderr:write(string.format("%s: %d actions\n", m.name, #out[i].actions))
end
io.write(json.encode({ matches = out }), "\n")
