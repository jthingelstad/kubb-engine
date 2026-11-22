-- A turn of the score sheet with the places the sheet keeps written after the
-- tokens they belong to, in the notation's frame (notation.point, the half
-- under attack): "3. jamie:2I (@ 2.50,2.00 3.50,2.00) 2A jamie:F (@ 2.50,2.00)".
-- For tests of what the rules engine records (t.inkastAt, a baton's at, the
-- advantage's metres) without the game file's position lines, which write
-- only what can be whole (notation.positionLines). Not a format any file uses.
local notation = tw.notation
local concat = table.concat

return function(t)
	local def = t.side == "A" and "B" or "A"
	local function at(list, most)
		if not list or #list == 0 or most <= 0 then return "" end
		local ps = {}
		for i = 1, math.min(#list, most) do ps[i] = notation.point(list[i].x, list[i].y, def) or "?" end
		return " (@ " .. concat(ps, " ") .. ")"
	end
	local parts = { t.n .. "." }
	for _, pid in ipairs(t.inkastOrder) do
		local k = t.inkast[pid]
		local most = k.I + k.R + k.P + k.Q + math.min(k.N, 5)
		parts[#parts + 1] = pid .. ":" .. notation.inkastBody(k) .. at(t.inkastAt and t.inkastAt[pid], most)
	end
	if t.advantage then parts[#parts + 1] = t.advantage .. "A" end
	for _, b in ipairs(t.batons) do
		local f, nb = notation.batonParts(b.token)
		parts[#parts + 1] = (b.player and (b.player .. ":") or "") .. b.token .. at(b.at, f + nb)
	end
	local line = concat(parts, " ")
	if #t.notes > 0 then line = line .. " # " .. concat(t.notes, "; ") end
	return line
end
