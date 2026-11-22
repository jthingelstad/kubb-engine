-- Two positions where a baton goes into a tight group of field kubbs (0.16.0, the
-- drive: docs/notes/throw.md "The drive"). Written out by hand, to the centimetre and
-- the degree, after two positions a player reported from a solo match on 0.15.1; the
-- reports themselves are private and are not copied here. The thrower's view frame:
-- the thrower's line at y = 0, the far baseline at y = 8, x to the right.
--
--   group1  from the baseline: a group of six standing field kubbs 4.2 to 5.2 m out,
--           a kubb already felled lying beside the front one. On 0.15.1 the default
--           plan (loft 12.6, 8.3 m/s) felled the front kubb only and ran on 2.3 m past.
--   group2  from the advantage line 2.84 m out: six standing field kubbs 1.4 to 2.3 m
--           in front, a felled kubb and a baton lying at the front one. On 0.15.1 the
--           default plan was a lob (loft 5.2 at the floor of ARC, 3.7 m/s).
--
-- Each piece: kind, x, y, yaw (degrees: a kubb's face; a lying piece's long axis from
-- +x), lying (a piece already down). `target` is the front kubb the thrower aims at
-- (index into pieces), `stance` where the thrower stands. Field kubbs are the standing
-- kubbs with `field = true`; base kubbs and the king are also on the pitch.
local P = {}

P.group1 = {
	stance = { x = 2.17, y = 0 },
	target = 1,
	pieces = {
		{ kind = "kubb", x = 2.17, y = 4.17, yaw = 95, field = true },
		{ kind = "kubb", x = 2.07, y = 4.38, yaw = 95, field = true },
		{ kind = "kubb", x = 2.14, y = 4.55, yaw = 87, field = true },
		{ kind = "kubb", x = 2.04, y = 4.68, yaw = 84, field = true },
		{ kind = "kubb", x = 2.27, y = 4.79, yaw = 122, field = true },
		{ kind = "kubb", x = 2.25, y = 5.20, yaw = 72, field = true },
		{ kind = "kubb", x = 2.29, y = 4.18, yaw = 96, lying = true },
		{ kind = "baton", x = 1.96, y = 6.51, yaw = 78, lying = true },
		{ kind = "kubb", x = 2.00, y = 8.00, yaw = 0 },
		{ kind = "king", x = 0, y = 4, yaw = 0 },
	},
}

P.group2 = {
	stance = { x = 2.03, y = 2.84 },
	target = 1,
	pieces = {
		{ kind = "kubb", x = 2.03, y = 4.26, yaw = 95, field = true },
		{ kind = "kubb", x = 2.25, y = 4.32, yaw = 89, field = true },
		{ kind = "kubb", x = 2.02, y = 4.47, yaw = 99, field = true },
		{ kind = "kubb", x = 2.09, y = 4.50, yaw = 98, field = true },
		{ kind = "kubb", x = 1.69, y = 4.81, yaw = -158, field = true },
		{ kind = "kubb", x = 2.14, y = 5.11, yaw = 36, field = true },
		{ kind = "kubb", x = 2.11, y = 4.22, yaw = 94, lying = true },
		{ kind = "baton", x = 2.19, y = 4.25, yaw = -88, lying = true },
		{ kind = "kubb", x = 1.83, y = 2.84, yaw = 119 }, -- a field kubb in the thrower's own half
		{ kind = "king", x = 0, y = 4, yaw = 0 },
	},
}

-- world.addPiece entries for a position (ids p1, p2, ...). A lying kubb lies on a face
-- with its long axis along yaw; a lying baton likewise.
function P.pieces(pos)
	local out = {}
	for i, p in ipairs(pos.pieces) do
		local yaw = math.rad(p.yaw or 0)
		local e = { id = "p" .. i, kind = p.kind, x = p.x, y = p.y }
		if p.lying and p.kind == "baton" then
			e.yaw = yaw - math.pi / 2 -- world.addPiece lays a baton's segment along +y at yaw 0
		elseif p.lying then
			-- local z (the long axis) turned onto +x (a quarter turn about y), then yaw about z
			local h = 0.5 * math.pi / 2
			local aw, ay = math.cos(h), math.sin(h)
			local bw, bz = math.cos(yaw / 2), math.sin(yaw / 2)
			e.qw, e.qx, e.qy, e.qz = bw * aw, -bz * ay, bw * ay, bz * aw
		else
			e.yaw = yaw
		end
		out[i] = e
	end
	return out
end

return P
