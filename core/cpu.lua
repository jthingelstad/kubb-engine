-- Choose: which play, and why (docs/notes/computer-player.md, "Four parts"). For a
-- match setup it reads the pitch (core/read), makes the choices the computer makes and
-- returns them as an intent the hand (core/autothrow) can throw, with the reason:
--
--   local d = cpu.decide(s, r, level)
--   -- d = { kind = "toss" | "baton",
--   --       intent = toss:  { tx, ty (the spot, view frame), basket (-1 left, 1 right),
--   --                         spin (taps, + right), arc, standY (the line stood on) }
--   --                baton: { on (the piece's id), tx, ty (the aim point), aimZ,
--   --                         standY, stance = { x, y }, arc },
--   --       why = { play = an id in core/plays (nil when no play covers it),
--   --               facts = { ... } } }
--   cpu.text(d.why)   -- the play's sentence with its facts in it
--
-- 0.11.1 cut it out of autothrow.choose with no change in play: the same choices in the
-- same order, and the same draws from r (the basket's coin on a tie, nothing else). The
-- design's own stream for Choose comes with the first release that changes play.
-- cpu.last is the last decision made, for a host that wants the reason beside a throw;
-- autothrow.choose's result does not carry it, since that table reaches the session's
-- actions and recordings.
import "core/tw"
import "core/throwplan"
import "core/drill"
import "core/read"     -- before autothrow: read finishes loading it (core/read's note)
import "core/autothrow"
import "core/plays"

local plan, autothrow, read, plays = tw.plan, tw.autothrow, tw.read, tw.plays

local cpu = {}

-- The level a throw is made at: the one given, else the thrower's, else
-- autothrow.tune.level (and that when either is not a name).
function cpu.levelName(s, level)
	local t = autothrow.tune
	local lname = level or (s.thrower and s.thrower.level) or t.level
	if type(lname) ~= "string" then lname = t.level end
	return lname
end

-- inkast.corner: which basket a toss goes to, -1 (left, view frame) or 1 (right): the
-- one with more field kubbs of the far half within basketNear of it, so a turn's kubbs
-- group (Jamie, 2026-11-14). A tie is a coin from r, the only draw a decision makes.
-- Returns the side, the field kubbs near it and near the other, and whether it was the
-- coin.
function cpu.basket(s, r)
	local left, right = read.basketCounts(s)
	if left > right then return -1, left, right, false elseif right > left then return 1, right, left, false end
	return (r.next() < 0.5) and -1 or 1, left, right, true
end

-- inkast.roll, as 0.10 did it (2026-11-16, Jamie: "good drillers roll into other kubbs
-- because it is impossible to stop that much energy with just the ground and grass").
-- Once a kubb of the far half lies near the basket, a drill is aimed so that it would
-- rest intoShort in front of a lying kubb's near face, in that kubb's lane: the half of
-- the run-ons that would carry it on are stopped by the kubb, so the two end together.
-- A line (fewer than clusterFrom kubbs this turn): the front kubb of the group nearest
-- the basket, so the line grows toward the thrower. A cluster: in front of whichever
-- lying kubb leaves the aim nearest the group's middle, so the kubbs pile round it. nil
-- when no lying kubb is near the basket, or no aim in front of one is clear. Otherwise
-- x, y and the kubb it is aimed in front of.
local function intoSpot(s, t, bx, by, shortLying)
	local cluster = (s.of or 0) >= t.clusterFrom
	local n, cx, cy = read.lyingNear(s, bx, by)
	if n == 0 then return nil end
	local best, bestX, bestY, bestP
	for _, p in ipairs(s.pieces) do
		if p.role == "field" and p.half ~= s.side and p.toppled and read.nearBasket(p, bx, by) then
			-- the kubb's half extent along the throw (it lies along its angle)
			local a = p.pose and p.pose.angle or 0
			local ca, sa = math.cos(a), math.sin(a)
			if ca < 0 then ca = -ca end
			if sa < 0 then sa = -sa end
			local ext = 0.075 * sa + 0.035 * ca
			local x, y = p.x, p.y - ext - t.intoShort
			-- clear of every other kubb (this one is the backstop: the aim
			-- sits in its own clear ellipse on purpose)
			if read.spotClear(s, x, y, shortLying, p) then
				local cost
				if cluster then
					local ex, ey = x - cx, y - cy
					cost = ex * ex + ey * ey
				else
					-- the front of the group: least y, then nearest the basket across
					local ex = x - bx
					cost = y * 100 + ex * ex
				end
				if not best or cost < best - 1e-9 then best, bestX, bestY, bestP = cost, x, y, p end
			end
		end
	end
	if not best then return nil end
	return bestX, bestY, bestP
end

-- Where a toss to basket `side` should rest (view frame), for the level's inkast entry
-- ik (autothrow.tune.inkast; nil for a level it does not name). Returns x, y, how it was
-- chosen ("basket", "row", "into", "clear") and the lying kubb it goes beside (row and
-- into).
--   group 0 (beginner): the basket itself.
--   row (club, pro; 0.11): flank to flank with the innermost kubb lying by the basket.
--   otherwise (0.10, and a level ik does not name): into the group (intoSpot) when
--   tune.into is on, else the clear spot nearest the basket on a small grid (tune.spot*):
--   not on a kubb and with none in the lane it comes down and runs on in (a drill lands
--   short of its spot by its run on, so a kubb already down just past the spot is its
--   backstop). Nearest counts a step along the throw as little against one across (a
--   line along the throw) when the turn has fewer than clusterFrom kubbs to throw, else
--   the same (a cluster). The basket itself when every spot is taken.
function cpu.spot(s, side, ik)
	local t = autothrow.tune
	local bx, by = side * t.basketX, s.lineY + t.basketY
	if ik and ik.group == 0 then return bx, by, "basket" end
	if ik and ik.row ~= 0 then
		-- inkast.roll: rest flank to flank with the innermost kubb lying by the basket, on
		-- its inner side. The plan lands it short of that across and its spin rolls it
		-- in (drill.rollFor)
		local best = read.innermostLying(s, side)
		if best then return best.x - side * t.rowStep, best.y, "row", best end
		return bx, by, "basket"
	end
	local best, bestX, bestY
	local costY = ((s.of or 0) >= t.clusterFrom) and t.spotCostYCluster or t.spotCostY
	local shortLying = tw.drill.slideFor(plan.loftFor(plan.arcFor("drill")), s.surface)
	if shortLying < t.spotShortLying then shortLying = t.spotShortLying end
	if t.into ~= 0 then
		local ix, iy, ip = intoSpot(s, t, bx, by, shortLying)
		if ix then return ix, iy, "into", ip end
	end
	for i = -t.spotCols, t.spotCols do
		for j = -t.spotRows, t.spotRows do
			local x, y = bx + i * t.spotStepX, by + j * t.spotStepY
			if read.spotClear(s, x, y, shortLying) then
				local cx, cy = i, j * costY
				local cost = cx * cx + cy * cy
				if not best or cost < best - 1e-9 then best, bestX, bestY = cost, x, y end
			end
		end
	end
	if not best then return bx, by, "basket" end
	return bestX, bestY, "clear"
end

local function decideToss(s, r, lname, t)
	local ik = t.inkast[lname]
	local side, near, other, coin = cpu.basket(s, r)
	local tx, ty, how, beside = cpu.spot(s, side, ik)
	-- inkast.roll: spun to roll toward the sideline (the plan aims short of the spot by
	-- the roll); a level the inkast table does not name spins drillSpin
	local spin = ik and ik.spin * side or t.drillSpin
	local intent = { tx = tx, ty = ty, basket = side, spin = spin, arc = plan.arcFor("drill"), standY = s.lineY }
	-- a kubb aimed beside one already down carries out inkast.roll; one aimed at the
	-- basket or the clear spot nearest it, inkast.corner
	local play = (how == "row" or how == "into") and "inkast.roll" or "inkast.corner"
	local facts = { basket = side < 0 and "left" or "right", near = near, other = other, coin = coin,
		spot = how, beside = beside and beside.id, spin = spin, inHand = s.of, kubb = s.n }
	return { kind = "toss", intent = intent, why = { play = play, facts = facts } }
end

local function decideBaton(s, t)
	local pos = read.byId(s)
	local target = pos[s.targets[1]]
	-- the nearest target to the line
	for _, id in ipairs(s.targets) do
		local p = pos[id]
		if p and p.y < target.y then target = p end
	end
	local tx = target.x
	local play, lane
	if target.role == "field" then
		-- field.roles: the lane with the most standing field kubbs; the nearest front on
		-- a tie. Aimed across at the middle of the lane, along at its front kubb
		play, lane = "field.roles", 0
		for _, id in ipairs(s.targets) do
			local f = pos[id]
			if f and f.role == "field" then
				local n, lo, hi = read.lane(s, pos, f)
				if n > lane or (n == lane and f.y < target.y) then
					lane, target, tx = n, f, (lo + hi) / 2
				end
			end
		end
	end
	local ty = target.y - t.batonShort
	local king = s.kingShot or target.role == "king"
	-- through the piece at its aim height (plan.tune.aimHeightShare), as a
	-- player's circle on a piece is
	local aimZ = plan.aimZFor(king and "king" or "kubb")
	-- as far forward as allowed, never nearer than minRange; the king from the baseline
	local py = s.kingShot and s.lineY or (s.forwardY or s.lineY)
	if py > target.y - t.minRange then py = target.y - t.minRange end
	if py < s.lineY then py = s.lineY end
	local st = plan.stance(tx, ty, s.lineY, py, t.halfWidth, {})
	-- the default arc for the distance (plan.arcFor), as a player's is
	local dx, dy = tx - st.x, ty - st.y
	local arc = plan.arcFor("baton", math.sqrt(dx * dx + dy * dy))
	local intent = { on = target.id, tx = tx, ty = ty, aimZ = aimZ, standY = py, stance = st, arc = arc }
	local facts = { on = target.id, target = king and "king" or target.role, targets = #s.targets, lane = lane }
	return { kind = "baton", intent = intent, why = { play = play, facts = facts } }
end

-- The decision for match setup s (view frame) at level (a tw.plan level name; default
-- the thrower's, then autothrow.tune.level). Tosses: the basket (inkast.corner) and the
-- spot in it (inkast.roll), drilled from the baseline. Batons: the nearest live target,
-- at a field the lane with the most kubbs (field.roles), stood behind as far forward as
-- allowed. Draws from r only for the basket's coin.
function cpu.decide(s, r, level)
	local t = autothrow.tune
	local lname = cpu.levelName(s, level)
	local d
	if s.kind == "toss" then d = decideToss(s, r, lname, t) else d = decideBaton(s, t) end
	cpu.last = d
	return d
end

-- The sentence for a decision's reason (why), its {name}s filled from the facts; nil
-- when it names no play. A {name} with no fact of that name is left as it is.
function cpu.text(why)
	local p = why and why.play and plays[why.play]
	if not p then return nil end
	return (p.say:gsub("{(%w+)}", why.facts or {}))
end

tw.cpu = cpu
