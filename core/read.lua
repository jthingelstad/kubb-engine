-- Read: the situation, with no decisions in it (docs/notes/computer-player.md, "Four
-- parts"). What the computer works out about the pitch before it chooses a play: the
-- field kubbs near each basket, the lying kubbs near one and the innermost of them,
-- whether a spot is clear for a drill, and how many standing field kubbs stand in a
-- front kubb's lane. Its words are docs/reference/SITUATIONS.md's. Nothing here draws
-- from a random stream or chooses; core/cpu does that.
--
-- The tune numbers it reads (basket*, spot*, lane*) stay in autothrow.tune, where the
-- Gym's --set autothrow.tune.* and the session's tune files have always found them;
-- they are read at each call, so a change to them takes effect at once.
--
--   read.basketAt(s, side)            -> x, y of basket side (-1 left, 1 right)
--   read.basketCounts(s)              -> field kubbs near the left and right baskets
--   read.lyingNear(s, bx, by)         -> n, mean x, mean y of lying kubbs near (bx, by)
--   read.innermostLying(s, side)      -> the lying kubb nearest the middle by basket side
--   read.spotClear(s, x, y, shortLying, except) -> can a drill be aimed at (x, y)?
--   read.byId(s)                      -> { [id] = piece }
--   read.lane(s, pos, f)              -> n, lo, hi: front kubb f's lane
import "core/tw"

-- autothrow (for its tune) is imported at the end, once tw.read is set: autothrow
-- imports core/cpu, which needs core/read, so whichever of the three a host imports
-- first, each finds the others in place.
local autothrow

local read = {}

-- Is piece p a field kubb of the half s's thrower throws at (the far half)? Kubbs in
-- the thrower's own half never count.
function read.farField(s, p)
	return p.role == "field" and p.half ~= s.side
end

-- Where basket `side` is (view frame): -1 left, 1 right.
function read.basketAt(s, side)
	local t = autothrow.tune
	return side * t.basketX, s.lineY + t.basketY
end

-- Is piece p within basketNear of (bx, by)?
function read.nearBasket(p, bx, by)
	local t = autothrow.tune
	local dx, dy = p.x - bx, p.y - by
	return dx * dx + dy * dy < t.basketNear * t.basketNear
end

-- How many field kubbs of the far half, lying or standing, lie within basketNear of
-- the left basket and of the right one (a kubb near both counts for both).
function read.basketCounts(s)
	local t = autothrow.tune
	local left, right = 0, 0
	local ky = s.lineY + t.basketY
	local near2 = t.basketNear * t.basketNear
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side then
			local dy = p.y - ky
			local dl, dr = p.x + t.basketX, p.x - t.basketX
			if dl * dl + dy * dy < near2 then left = left + 1 end
			if dr * dr + dy * dy < near2 then right = right + 1 end
		end
	end
	return left, right
end

-- The lying field kubbs of the far half within basketNear of (bx, by): how many, and
-- the middle of them (nil, nil when there are none).
function read.lyingNear(s, bx, by)
	local near2 = autothrow.tune.basketNear
	near2 = near2 * near2
	local n, cx, cy = 0, 0, 0
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side and p.toppled then
			local dx, dy = p.x - bx, p.y - by
			if dx * dx + dy * dy < near2 then n, cx, cy = n + 1, cx + p.x, cy + p.y end
		end
	end
	if n == 0 then return 0, nil, nil end
	return n, cx / n, cy / n
end

-- The innermost lying field kubb by basket `side`: of those within basketNear of it,
-- the one nearest the middle of the pitch (the first in s.pieces on a tie). nil when
-- none lies there.
function read.innermostLying(s, side)
	local t = autothrow.tune
	local bx, by = side * t.basketX, s.lineY + t.basketY
	local near2 = t.basketNear * t.basketNear
	local best
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side and p.toppled then
			local dx, dy = p.x - bx, p.y - by
			if dx * dx + dy * dy < near2 and (not best or side * p.x < side * best.x) then best = p end
		end
	end
	return best
end

-- Is (x, y) a spot a drill can be aimed at: on the allowed part of the half, not on a
-- field kubb and with none in the lane it comes down and runs on in (a lying one within
-- shortLying short of it, a standing one within spotShortStanding)? Piece `except` (or
-- nil) is left out.
function read.spotClear(s, x, y, shortLying, except)
	local t = autothrow.tune
	local ax = x < 0 and -x or x
	if ax > t.spotMaxX or y < s.lineY + t.spotMinY then return false end
	for _, p in ipairs(s.pieces) do
		if p ~= except and p.role == "field" and p.half ~= s.side then
			local dx, dy = (p.x - x) / t.spotClearX, (p.y - y) / t.spotClearY
			if dx * dx + dy * dy < 1 then return false end
			local lx, short = p.x - x, y - p.y
			if lx < 0 then lx = -lx end
			if lx < t.spotLane and short > 0
				and short < (p.toppled and shortLying or t.spotShortStanding) then
				return false
			end
		end
	end
	return true
end

-- The setup's pieces by id: one table a throw.
function read.byId(s)
	local pos = {}
	for _, p in ipairs(s.pieces) do pos[p.id] = p end
	return pos
end

-- The lane (2026-11-16): a baton takes two kubbs when one stands behind the other along
-- its flight. For front kubb f, how many standing field kubbs (the targets, f among
-- them) stand within laneHalf across of it and within laneDeep behind it, and the least
-- and greatest x among them. pos is read.byId(s).
function read.lane(s, pos, f)
	local t = autothrow.tune
	local n, lo, hi = 0, f.x, f.x
	for _, id2 in ipairs(s.targets) do
		local p = pos[id2]
		if p and p.role == "field" then
			local dx, dy = p.x - f.x, p.y - f.y
			if dx < t.laneHalf and dx > -t.laneHalf and dy >= 0 and dy <= t.laneDeep then
				n = n + 1
				if p.x < lo then lo = p.x elseif p.x > hi then hi = p.x end
			end
		end
	end
	return n, lo, hi
end

tw.read = read

import "core/autothrow"
autothrow = tw.autothrow
