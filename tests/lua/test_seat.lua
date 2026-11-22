-- A kubb's seat (world.seat, world.tune.seatOn; docs/notes/physics.md "The seat"), on
-- from 1.0.0: a kubb standing plumb leans up to its surface's `seat` in a direction
-- seeded from where it stands, the same every time a world is built there; the grid and
-- the king stand plumb; a pose already off plumb is kept; the session draws the pose the
-- throw's world will build; a settle leaves a seated kubb alone; and with the seat off
-- (seatOn 0) every piece stands as 0.18.0 stood it.
import "core/world"
import "core/match"
import "core/autothrow"
import "session/throw"
local world, match, autothrow = tw.world, tw.match, tw.autothrow

local function tiltDeg(b)
	local r33 = 1 - 2 * (b.qx * b.qx + b.qy * b.qy)
	if r33 > 1 then r33 = 1 end
	return math.deg(math.acos(r33))
end

local function standAt(surface, x, y, yaw, kind)
	local w = world.new { surface = surface, stakes = false,
		pieces = { { id = "k", kind = kind or "kubb", x = x, y = y, yaw = yaw } } }
	return w.byId.k
end

test("seat: on as shipped, a kubb leans within its surface's seat, the same at the same place", function()
	expect.eq(world.tune.seatOn, 1)
	for _, surf in ipairs { "grass", "sand", "snow" } do
		local seat = world.surfaces[surf].seat
		expect.truthy(seat > 0, surf .. " has a seat")
		local any, most = 0, 0
		for i = 1, 60 do
			local x, y, yaw = -2 + (i % 10) * 0.45, 1 + math.floor(i / 10) * 1.1, 0.13 * i
			local b = standAt(surf, x, y, yaw)
			local t = tiltDeg(b)
			expect.truthy(t <= seat + 1e-9, string.format("%s: lean %.4f within %g", surf, t, seat))
			if t > 1e-6 then any = any + 1 end
			if t > most then most = t end
			-- asleep and standing, on the edge it leans to
			expect.eq(b.awake, false)
			expect.eq(b.toppled, false, surf .. ": a seated kubb stands")
			-- the same lean at the same place and turn, every rebuild
			local c = standAt(surf, x, y, yaw)
			expect.eq(c.qw, b.qw); expect.eq(c.qx, b.qx); expect.eq(c.qy, b.qy); expect.eq(c.qz, b.qz)
			expect.eq(c.z, b.z)
		end
		expect.truthy(any >= 55, surf .. ": nearly every kubb leans some (" .. any .. ")")
		expect.truthy(most > seat * 0.8, string.format("%s: the leans reach near the seat (%.2f)", surf, most))
	end
end)

test("seat: the grid's kubbs and every king stand plumb; a pose off plumb is kept", function()
	expect.eq(world.surfaces.grid.seat, 0)
	for i = 1, 20 do
		local b = standAt("grid", -1 + i * 0.1, 3, 0.2 * i)
		expect.eq(b.qx, 0); expect.eq(b.qy, 0)
		local k = standAt("sand", -1 + i * 0.1, 4, 0.2 * i, "king")
		expect.eq(k.qx, 0, "the king is not seated"); expect.eq(k.qy, 0)
	end
	-- a kubb given a pose already off plumb (an earlier throw's) keeps it exactly
	local qw, qx, qy, qz = tw.quat.fromAxisAngle(1, 0, 0, math.rad(1.2))
	local w = world.new { surface = "sand", stakes = false,
		pieces = { { id = "k", kind = "kubb", x = 0.3, y = 3, qw = qw, qx = qx, qy = qy, qz = qz, z = 0.08 } } }
	local b = w.byId.k
	expect.eq(b.qx, qx); expect.eq(b.qw, qw); expect.eq(b.z, 0.08)
end)

test("seat: off (seatOn 0) every kubb stands plumb, as in 0.18.0", function()
	local saved = world.tune.seatOn
	world.tune.seatOn = 0
	local ok, err = pcall(function()
		for _, surf in ipairs { "grass", "sand", "snow" } do
			for i = 1, 20 do
				local b = standAt(surf, -1 + i * 0.1, 2 + i * 0.05, 0.3 * i)
				local qw, qx, qy, qz = tw.quat.fromAxisAngle(0, 0, 1, 0.3 * i)
				-- (setPose normalises the quaternion: the last bit may differ)
				expect.near(b.qw, qw, 1e-15); expect.eq(b.qx, 0); expect.eq(b.qy, 0); expect.near(b.qz, qz, 1e-15)
				expect.near(b.z, tw.body.kinds.kubb.hz, 1e-15)
			end
		end
	end)
	world.tune.seatOn = saved
	assert(ok, err)
end)

-- A match on sand: what a client draws (the session's items) is the pose each throw's
-- world starts from, and a settle wakes no seated kubb.
test("seat: a client's drawn pose is the throw world's, and a settle leaves seats alone", function()
	local throw = tw.web.throw
	local m = match.new { start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }, surface = "Sand",
		teams = { A = { name = "A", players = { { name = "a" } } }, B = { name = "B", players = { { name = "b" } } } } }
	local r = autothrow.rng(5)
	local woke, compared = 0, 0
	local real = match.settleStanding
	match.settleStanding = function(mm, ss)
		local k = real(mm, ss)
		woke = woke + k
		return k
	end
	local ok, err = pcall(function()
		for _ = 1, 40 do
			if match.over(m) then break end
			local s = match.setup(m)
			if not s then break end
			local items = throw.itemsOf(s.pieces, s.debris, s.surface)
			local w = world.new { surface = s.surface, pieces = match.worldPieces(s) }
			for _, it in ipairs(items) do
				local b = w.byId[it.id]
				if b and it.kind == "kubb" and not it.toppled then
					compared = compared + 1
					local dot = math.abs(it.qw * b.qw + it.qx * b.qx + it.qy * b.qy + it.qz * b.qz)
					expect.truthy(dot > 1 - 1e-12, it.id .. ": drawn as the world stands it")
				end
			end
			local a = autothrow.choose(s, r)
			autothrow.launch(w, s, a)
			world.run(w)
			match.resolve(m, world.result(w), not a.legal)
		end
	end)
	match.settleStanding = real
	assert(ok, err)
	expect.truthy(compared > 200, "kubbs compared: " .. compared)
	expect.eq(woke, 0, "seated kubbs woken by a settle")
end)

test("seat: the same kubb whichever side's view the world is built in", function()
	local frame = tw.frame
	for i = 1, 40 do
		local x, y, a = -2.2 + i * 0.11, 0.3 + i * 0.19, 0.4 * i
		local b = standAt("sand", x, y, a)
		-- side B's view of the same kubb: the half turn about the pitch's centre
		local bx, by = frame.point("B", x, y)
		local c = standAt("sand", bx, by, frame.angle("B", a))
		local qw, qx, qy, qz = frame.quat("B", b.qw, b.qx, b.qy, b.qz)
		local dot = math.abs(qw * c.qw + qx * c.qx + qy * c.qy + qz * c.qz)
		expect.truthy(dot > 1 - 1e-12, string.format("kubb %d: one lean in both views (%.3g)", i, 1 - dot))
	end
end)

test("seat: a settled kubb's seat is the pose it stands at in the next throw's world", function()
	local m = match.new { start = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }, surface = "Grass",
		teams = { A = { name = "A", players = { { name = "a" } } }, B = { name = "B", players = { { name = "b" } } } } }
	m.game.raisePolicy = "par"
	local r = autothrow.rng(3)
	local checked = 0
	for _ = 1, 120 do
		if match.over(m) or checked >= 6 then break end
		local s = match.setup(m)
		if not s then break end
		local w = world.new { surface = s.surface, pieces = match.worldPieces(s) }
		for _, e in ipairs(s.settled and s.settled.list or {}) do
			local b = w.byId[e.id]
			if e.seat and b and not b.toppled then
				local q = e.seat
				local qw, qx, qy, qz = tw.frame.quat(s.side, q.qw, q.qx, q.qy, q.qz)
				local dot = math.abs(qw * b.qw + qx * b.qx + qy * b.qy + qz * b.qz)
				expect.truthy(dot > 1 - 1e-12, e.id .. ": settled seat is the world's")
				checked = checked + 1
			end
		end
		local a = autothrow.choose(s, r)
		autothrow.launch(w, s, a)
		world.run(w)
		match.resolve(m, world.result(w), not a.legal)
	end
	expect.truthy(checked >= 3, "settled kubbs checked: " .. checked)
end)
