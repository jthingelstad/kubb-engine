-- Tip up kubbs in any order (1.4.0): the raise need lists every field kubb still lying,
-- the raise action names the kubb and its end, a stale raise is refused cleanly, and one
-- camera shows the whole raise.
import "session/session"
import "session/json"
import "core/autothrow"
import "pitch/seats"
tw.web.session.useTune("pointer")
local session, json, autothrow, seats = tw.web.session, tw.web.json, tw.autothrow, tw.shared.seats
local START = { year = 2026, month = 11, day = 26, hour = 12, min = 0 }

-- Play until a person's raise with two or more kubbs lying (people's throws scripted).
local function toRaise(seed)
	local s = session.new { mode = "match", seed = seed, start = START, cpu = "B" }
	local r = autothrow.rng(seed)
	for _ = 1, 3000 do
		local n = s:need()
		if n.kind == "over" then return nil end
		if n.kind == "raise" then
			if #n.lying >= 2 then return s end
			s:apply { type = "raise" }
		elseif n.kind == "punish" then
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		elseif n.cpu then
			s:cpuPlay()
		else
			local ts = s.ts
			local c = autothrow.choose(s.setup, r, 1)
			tw.web.throw.showAim(ts, c)
			local L, how = tw.web.throw.cpuLaunch(ts, c)
			ts.playerX, ts.playerY = c.x, c.y
			s:apply(json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
				stop = c.swing.releaseAngle }))))
		end
	end
end

local function findRaise()
	for seed = 1, 40 do
		local s = toRaise(seed)
		if s then return s end
	end
	error("no raise with two kubbs lying in 40 seeds")
end

test("the raise need lists every lying kubb, each with its own ends, and a camera", function()
	local s = findRaise()
	local n = s:need()
	expect.eq(n.lying[1].id, n.kubb)
	expect.truthy(#n.lying >= 2)
	for _, e in ipairs(n.lying) do
		expect.truthy(e.pose and e.choices and e.ends and e.default)
	end
	expect.truthy(n.camera and n.camera.f and n.camera.kind == "raise")
	expect.eq(n.frame, n.side)
	-- (1.4.0) the raising side's players, with each one's throw level
	expect.truthy(n.players and #n.players >= 1 and n.players[1].id and n.players[1].name)
	-- every lying kubb and the king fall in the camera's box
	local box = tw.camera.tune["end"].box
	for _, e in ipairs(n.lying) do
		local px, py = tw.camera.project(n.camera, e.pose.x, e.pose.y, 0)
		expect.truthy(px >= box.left - 1 and px <= box.right + 1 and py >= box.top - 1 and py <= box.bottom + 1,
			"kubb " .. e.id .. " at " .. tostring(px) .. "," .. tostring(py))
	end
end)

test("raise the second lying kubb first: the list is made again, the counts go on", function()
	local s = findRaise()
	local n = s:need()
	local second = n.lying[2]
	local c = second.choices[second.default]
	local r = s:apply { type = "raise", kubb = second.id, which = c.which }
	expect.truthy(r.ok)
	local n2 = r.need
	if n2.kind == "raise" then
		for _, e in ipairs(n2.lying) do expect.truthy(e.id ~= second.id) end
		expect.eq(n2.n, n.n + 1)
	end
	-- the same raise again (a teammate's, re-applied after the pitch refused it): refused
	local again = s:apply { type = "raise", kubb = second.id, which = c.which }
	expect.eq(again.ok, false)
	expect.eq(again.why, "not lying")
	-- an end that is not a choice is refused, the match as it was
	if n2.kind == "raise" then
		local h = s:hash()
		local bad = s:apply { type = "raise", kubb = n2.lying[1].id, which = 7 }
		expect.eq(bad.ok, false)
		expect.eq(s:hash(), h)
	end
end)

test("a raise without a kubb raises need.kubb as before", function()
	local s = findRaise()
	local t = session.restore(s:snapshot())
	local n = s:need()
	s:apply { type = "raise" }
	t:apply { type = "raise", kubb = n.kubb }
	expect.eq(s:hash(), t:hash())
end)

test("two clients raising in the same order agree; the pitch replays either", function()
	local s = findRaise()
	local u = session.restore(s:snapshot())
	local n = s:need()
	for i = #n.lying, 1, -1 do
		local id = n.lying[i].id
		local a = { type = "raise", kubb = id }
		local x, y = s:apply(a), u:apply(a)
		expect.eq(x.ok, y.ok)
		expect.eq(s:hash(), u:hash())
	end
end)

test("seats: any connected member of the defending team may raise any kubb", function()
	local s = findRaise()
	local n = s:need()
	local side = n.side
	local ctx = { players = { [side] = { { id = "m1" }, { id = "m2" }, { id = "c", cpu = true } },
		[side == "A" and "B" or "A"] = { { id = "o1" } } }, cpu = nil, host = "o1", connected = { "m1", "m2", "o1" } }
	local actors = seats.actorsFor(n, ctx)
	expect.eq(#actors, 2)
	expect.truthy(seats.mayAct(n, ctx, "m1"))
	expect.truthy(seats.mayAct(n, ctx, "m2"))
	expect.eq(seats.mayAct(n, ctx, "o1"), false)
	expect.eq(seats.mayAct(n, ctx, "c"), false)
end)
