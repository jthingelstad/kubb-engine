-- Throw forensics for the Kubb Gym (docs/notes/gym.md "Forensics"): what one throw
-- physically did, read from the world while it runs to rest. Desktop only, a
-- measuring tool: it reads bodies after each world.step and listens on
-- w.onContact (the hook core/world already calls; the session's throw uses it
-- too). It writes nothing into a body, so a throw runs bit for bit as
-- world.run would run it (`lua5.4 tools/gym/match.lua --selftest`).
--
--   local forensics = dofile("tools/gym/forensics.lua")   -- after core/world is imported
--   local rec, res = forensics.run(w, ctx)
--   -- ctx = { projectile = "baton" | "kubb", stanceX, stanceY, aimX, aimY,
--   --         on = target piece id or nil, lineY, side }
--   -- rec: the flat record below; res: world.result(w)
--
-- The record (every distance in m, speeds m/s, angles degrees, times s):
--   rest            time to rest
--   ground1         the projectile's first contact was the ground (before any piece)
--   landAlong       where the projectile first met the ground, along the throw, minus the
--                   target's distance (negative: short of it); nil if it never landed
--   landAcross      the same across the throw (+ right of the line)
--   landSpeed       its speed just before that ground contact
--   runOn           how far its centre went along the throw from that contact to rest
--   first           the first standing piece it touched, or nil: { id, role, kind,
--                   where = top-face | top-edge | body | bottom, h (height up the piece),
--                   speed, lean (baton axis from vertical), descent, kept (speed 0.05 s
--                   later over speed before), fate }
--   touched         standing pieces the projectile touched (count)
--   hard            touches of standing pieces at >= forensics.tune.hardSpeed: { { id, speed, fate, where } }
--   toppled         pieces toppled this throw (count); byBaton, byKubb: how each fell
--                   (the projectile touched it; only another piece did)
--   targetDown      the target piece (ctx.on) toppled; targetTouched: the projectile touched it
--   eRise           the largest rise in total energy above its lowest since the first
--                   contact (J): the physics' energy check, coarse
--   propped         kubbs that moved this throw and rest standing tilted past proppedDeg:
--                   { { id, tilt } }
--   restX, restY    the projectile's rest (a drill: where the kubb ended), view frame
--   polled          an engine with no onContact (before 0.4.1): touches were found by
--                   the narrow phase between steps, the landing only when the ground was
--                   the first contact; kubb on kubb is not seen
import "core/world"
import "core/body"
import "core/collide"
local world, body, collide = tw.world, tw.body, tw.collide
local sqrt, abs, acos, atan, deg, max, min = math.sqrt, math.abs, math.acos, math.atan, math.deg, math.max, math.min

local forensics = {}

forensics.tune = {
	unmovedDeg = 1,     -- a struck piece that tilted less than this ...
	unmovedM = 0.01,    -- ... and moved less than this is unmoved
	rockDeg = 2,        -- tilted this far and stood: rocked
	slideM = 0.01,      -- moved this far and stood: slid
	hardSpeed = 3,      -- m/s: a touch this fast or faster is a hard one
	keptAfter = 0.05,   -- s after the first touch the baton's speed is read
	proppedDeg = 10,    -- a kubb counted standing but tilted past this rests propped
	topMargin = 0.01,   -- m: a touch within this of a piece's top is on the top
	innerMargin = 0.008, -- m: ... on the face when this far inside its edges, else the edge
}

local function pieceRole(p)
	return p.role or (p.kind == "king" and "king") or "base"
end

-- Where point (px, py, pz) is on box b: the up axis is the local axis nearest
-- vertical. Returns where, the height up the piece from its lowest face.
local function whereOn(b, px, py, pz)
	local dx, dy, dz = px - b.x, py - b.y, pz - b.z
	local l1 = b.r11 * dx + b.r21 * dy + b.r31 * dz
	local l2 = b.r12 * dx + b.r22 * dy + b.r32 * dz
	local l3 = b.r13 * dx + b.r23 * dy + b.r33 * dz
	local c1, c2, c3 = abs(b.r31), abs(b.r32), abs(b.r33)
	local h, half, o1, o2, h1, h2
	if c3 >= c1 and c3 >= c2 then
		h, half, o1, o2, h1, h2 = l3 * (b.r33 < 0 and -1 or 1), b.hz, l1, l2, b.hx, b.hy
	elseif c1 >= c2 then
		h, half, o1, o2, h1, h2 = l1 * (b.r31 < 0 and -1 or 1), b.hx, l2, l3, b.hy, b.hz
	else
		h, half, o1, o2, h1, h2 = l2 * (b.r32 < 0 and -1 or 1), b.hy, l1, l3, b.hx, b.hz
	end
	local t = forensics.tune
	local w
	if h > half - t.topMargin then
		local inner = abs(o1) < h1 - t.innerMargin and abs(o2) < h2 - t.innerMargin
		w = inner and "top-face" or "top-edge"
	elseif h < -half + t.topMargin then
		w = "bottom"
	else
		w = "body"
	end
	return w, h + half
end

-- The deepest contact point of projectile p with box b (a small margin: they
-- touched in the step just run), as whereOn reads it; nil when none is found.
local C = collide.C
local function contactOn(p, b)
	C.n = 0
	if p.shape == 1 then collide.boxBox(p, b, 0.003) else collide.capsuleBox(p, b, 0.003) end
	local best, bi = nil, nil
	for i = 1, C.n do
		if not best or C.sep[i] < best then best, bi = C.sep[i], i end
	end
	local px, py, pz = bi and C.px[bi], bi and C.py[bi], bi and C.pz[bi]
	C.n = 0
	if not bi then return nil end
	return whereOn(b, px, py, pz)
end

local function fateOf(tr, toppled)
	local t = forensics.tune
	if toppled then return "toppled" end
	if not tr.woke then return "unmoved" end
	local tilt, d = deg(tr.maxTilt), tr.maxD
	if tilt < t.unmovedDeg and d < t.unmovedM then return "unmoved" end
	if tilt >= t.rockDeg then return "rocked" end
	if d >= t.slideM then return "slid" end
	return "nudged"
end

-- Runs world w (its projectile launched) to rest, as world.run does, and
-- returns the record and world.result(w). pieces: the setup's pieces (for
-- roles), any list of { id, role }.
function forensics.run(w, ctx, pieces)
	local t = forensics.tune
	local proj = w.projectile
	local roles = {}
	for _, p in ipairs(pieces or {}) do roles[p.id] = pieceRole(p) end
	-- the standing pieces at the start: their start pose, how far they move and tilt
	local track, tracked = {}, {}
	for i = 1, w.n do
		local b = w.bodies[i]
		if b ~= proj and not b.static and b.shape == 1 and not b.toppled then
			local tr = { b = b, x0 = b.x, y0 = b.y, ax = b.r13, ay = b.r23, az = b.r33, maxD = 0, maxTilt = 0,
				woke = false, projT = nil, projSpeed = nil, pieceT = nil, role = roles[b.id] or pieceRole(b) }
			track[b.id] = tr
			tracked[#tracked + 1] = tr
		end
	end
	-- the throw's line: stance to aim point
	local sx, sy = ctx.stanceX or proj.x, ctx.stanceY or proj.y
	local ux, uy = (ctx.aimX or sx) - sx, (ctx.aimY or sy + 1) - sy
	local ul = sqrt(ux * ux + uy * uy)
	if ul < 1e-9 then ux, uy, ul = 0, 1, 1 end
	ux, uy = ux / ul, uy / ul
	local tAlong = ul
	local tgt = ctx.on and w.byId[ctx.on]
	if tgt then tAlong = (tgt.x - sx) * ux + (tgt.y - sy) * uy end

	local rec = { touched = 0, hard = {}, toppled = 0, byBaton = 0, byKubb = 0, eRise = 0, propped = {} }
	-- the projectile's state before the step (for what it was doing at a contact)
	local pvx, pvy, pvz, pr33 = proj.vx, proj.vy, proj.vz, proj.r33
	local groundT, firstPieceT, keptBase, firstTr
	local landX, landY
	local pairHit = {}   -- piece id -> true: touched by another piece (not the projectile)
	local eMin, contactSeen = nil, false
	local pending, nPending = {}, 0
	local landPending = false
	-- engines before 0.4.1 have no onContact: their throws are read by polling (below)
	local hooked, polling = false, false
	w.onContact = function(time, a, other, imp)
		hooked = true
		if other == nil then
			if a == proj and not groundT then
				groundT = time
				rec.landSpeed = sqrt(pvx * pvx + pvy * pvy + pvz * pvz)
				landPending = true
			end
			contactSeen = true
			return
		end
		contactSeen = true
		local o
		if a == proj then o = other elseif other == proj then o = a end
		if o then
			local tr = track[o.id]
			if tr and not tr.projT then
				tr.projT = time
				tr.projSpeed = sqrt(pvx * pvx + pvy * pvy + pvz * pvz)
				rec.touched = rec.touched + 1
				tr.pending = true
				nPending = nPending + 1
				pending[nPending] = tr
				local vh = sqrt(pvx * pvx + pvy * pvy)
				tr.lean, tr.descent, tr.afterGround = deg(acos(min(1, abs(pr33)))), deg(atan(-pvz, vh)), groundT ~= nil
				if not firstPieceT then
					firstPieceT = time
					firstTr = tr
					keptBase = tr.projSpeed
				end
			end
		else
			if track[a.id] then pairHit[a.id] = true end
			if track[other.id] then pairHit[other.id] = true end
		end
	end
	local nTracked = #tracked
	local each = ctx.each
	repeat
		pvx, pvy, pvz, pr33 = proj.vx, proj.vy, proj.vz, proj.r33
		world.step(w)
		if each then each(w) end
		-- where each newly touched piece was met: the narrow phase between steps, as
		-- tools/physcheck does (world.step clears that buffer before it uses it)
		for k = 1, nPending do
			local tr = pending[k]
			pending[k] = nil
			tr.where, tr.h = contactOn(proj, tr.b)
		end
		nPending = 0
		if not hooked and not polling and w.firstContact then polling = true; rec.polled = true end
		if polling then
			local fc = w.firstContact
			if not groundT and fc.with == "ground" then
				groundT = fc.t
				rec.landSpeed = sqrt(pvx * pvx + pvy * pvy + pvz * pvz)
				landX, landY = fc.x, fc.y
			end
			contactSeen = true
			for k = 1, nTracked do
				local tr = tracked[k]
				if not tr.projT then
					local where, h = contactOn(proj, tr.b)
					if where then
						tr.projT = w.time
						tr.projSpeed = sqrt(pvx * pvx + pvy * pvy + pvz * pvz)
						tr.where, tr.h = where, h
						rec.touched = rec.touched + 1
						local vh = sqrt(pvx * pvx + pvy * pvy)
						tr.lean, tr.descent, tr.afterGround = deg(acos(min(1, abs(pr33)))), deg(atan(-pvz, vh)), groundT ~= nil
						if not firstPieceT then firstPieceT, firstTr, keptBase = w.time, tr, tr.projSpeed end
					end
				end
			end
		end
		if landPending then
			-- the contact point when the ground was its first contact, else its centre
			landPending = false
			local fc = w.firstContact
			if fc and fc.with == "ground" and fc.t == groundT then landX, landY = fc.x, fc.y
			else landX, landY = proj.x, proj.y end
		end
		for k = 1, nTracked do
			local tr = tracked[k]
			local b = tr.b
			if b.awake then
				tr.woke = true
				local dx, dy = b.x - tr.x0, b.y - tr.y0
				local d = dx * dx + dy * dy
				if d > tr.maxD then tr.maxD = d end
				local c = tr.ax * b.r13 + tr.ay * b.r23 + tr.az * b.r33
				if c > 1 then c = 1 elseif c < -1 then c = -1 end
				local a = acos(c)
				if a > tr.maxTilt then tr.maxTilt = a end
			end
		end
		if firstPieceT and keptBase and not rec.kept and w.time >= firstPieceT + t.keptAfter then
			local v = sqrt(proj.vx * proj.vx + proj.vy * proj.vy + proj.vz * proj.vz)
			rec.kept = keptBase > 0 and v / keptBase or 0
		end
		if contactSeen then
			local e = world.energy(w)
			if not eMin or e < eMin then eMin = e end
			if e - eMin > rec.eRise then rec.eRise = e - eMin end
		end
	until world.isAtRest(w)
	w.onContact = nil
	for k = 1, nTracked do tracked[k].maxD = sqrt(tracked[k].maxD) end
	local res = world.result(w)
	rec.rest = w.time
	rec.ground1 = w.firstContact ~= nil and w.firstContact.with == "ground"
	rec.restX, rec.restY = proj.x, proj.y
	if landX then
		local ax, ay = landX - sx, landY - sy
		rec.landAlong = ax * ux + ay * uy - tAlong
		rec.landAcross = ax * uy - ay * ux
		local rx, ry = proj.x - landX, proj.y - landY
		rec.runOn = rx * ux + ry * uy
	end
	local down = {}
	for _, id in ipairs(res.toppled) do down[id] = true end
	rec.toppled = #res.toppled
	for _, id in ipairs(res.toppled) do
		local tr = track[id]
		if tr and tr.projT then rec.byBaton = rec.byBaton + 1
		elseif pairHit[id] then rec.byKubb = rec.byKubb + 1 end
	end
	rec.targetDown = ctx.on ~= nil and down[ctx.on] == true
	local ttr = ctx.on and track[ctx.on]
	if ttr then rec.targetTouched = ttr.projT ~= nil end
	for k = 1, nTracked do
		local tr = tracked[k]
		tr.fate = fateOf(tr, down[tr.b.id])
		if tr.projT and tr.projSpeed >= t.hardSpeed then
			rec.hard[#rec.hard + 1] = { id = tr.b.id, role = tr.role, speed = tr.projSpeed, fate = tr.fate,
				tilt = deg(tr.maxTilt), moved = tr.maxD, where = tr.where }
		end
		-- a kubb that moved and rests standing at a slant
		local b = tr.b
		if tr.woke and not down[b.id] and b.kind == "kubb" then
			local tilt = deg(acos(min(1, abs(b.r33))))
			if tilt > t.proppedDeg then rec.propped[#rec.propped + 1] = { id = b.id, role = tr.role, tilt = tilt } end
		end
	end
	if firstTr then
		local f = { where = firstTr.where, h = firstTr.h, lean = firstTr.lean, descent = firstTr.descent,
			afterGround = firstTr.afterGround }
		f.id, f.role, f.kind, f.speed, f.fate = firstTr.b.id, firstTr.role, firstTr.b.kind, firstTr.projSpeed, firstTr.fate
		f.tilt, f.moved = deg(firstTr.maxTilt), firstTr.maxD
		f.kept = rec.kept
		rec.first = f
	end
	return rec, res
end

tw.forensics = forensics
return forensics
