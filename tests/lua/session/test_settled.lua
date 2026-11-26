-- What the engine raised and placed, handed out (0.16.0): the throw need's
-- setup.settled, kubb by kubb in the order done, in the raiser's view frame (raiseInfo's
-- frame and shape), turned to the world frame in the wide view. Output only: nothing in
-- a snapshot or a hash.
import "session/session"
import "session/json"
import "session/wide"
import "core/autothrow"
import "core/frame"
tw.web.session.useTune("pointer")
local session, json, autothrow, frame, wide = tw.web.session, tw.web.json, tw.autothrow, tw.frame, tw.web.wide

local START = { year = 2026, month = 11, day = 22, hour = 12, min = 0 }

-- A match played out (computer sides by frames, a person's throws scripted at club);
-- at each throw need with setup.settled, onSettled(s, need) is called first.
local function playOut(s, onSettled, wild)
	local r = autothrow.rng(7)
	for _ = 1, 4000 do
		local n = s:need()
		if n.kind == "over" then return end
		if n.kind == "throw" and n.setup.settled then onSettled(s, n) end
		if n.kind == "raise" then
			s:apply { type = "raise" }
		elseif n.kind == "punish" then
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		elseif n.cpu then
			for _ = 1, 2000 do
				if s:frame { dt = 1 / 30 }.action then break end
			end
		else
			local ts = s.ts
			local c = autothrow.choose(s.setup, r, 1)
			tw.web.throw.showAim(ts, c)
			local L, how = tw.web.throw.cpuLaunch(ts, c)
			-- wild: a person's kubbs thrown far off to the side, out twice (a punishment kubb)
			if wild and s.setup.projectile == "kubb" then L.swivel = L.swivel + 1.2 end
			ts.playerX, ts.playerY = c.x, c.y
			s:apply(json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
				stop = c.swing.releaseAngle }))))
		end
	end
	error("the match did not end")
end

local function near(a, b, what)
	expect.near(a.x, b.x, 1e-9, what .. " x")
	expect.near(a.y, b.y, 1e-9, what .. " y")
	expect.near(a.angle or 0, b.angle or 0, 1e-9, what .. " angle")
	expect.eq(a.standing, b.standing, what .. " standing")
end

-- Every entry against the game: a raised kubb stands where its `standing` pose says (in
-- its raiser's frame), its lying pose is a lying pose, its end is 1 or 2; a punishment
-- kubb stands at its pose. Returns counts by kind, side, displaced or crowded.
local function check(s, n, seen)
	local st = n.setup.settled
	expect.truthy(#st.list == st.raised + st.punished, "one entry a kubb")
	local g = s.m.game
	for _, e in ipairs(st.list) do
		local k = g.kubbs[e.id]
		expect.truthy(k, "a kubb of the game: " .. tostring(e.id))
		local world = frame.pose(e.side, e.kind == "raise" and e.standing or e.pose) -- the half turn is its own inverse
		-- (the kubb may have been moved since by a throw only after this need: here it has not)
		near(world, { x = k.pose.x, y = k.pose.y, angle = k.pose.angle or 0, standing = true }, e.id)
		if e.kind == "raise" then
			expect.eq(e.lying.standing, false, "it lay")
			expect.truthy(e.which == 1 or e.which == 2, "an end")
			if e.displaced or e.crowded then seen.moved = seen.moved + 1 end
		end
		seen[e.kind] = seen[e.kind] + 1
		seen[e.side] = seen[e.side] + 1
	end
end

test("settled: the computer's raises and an automatic match's, kubb by kubb, as the game stands", function()
	local seen = { raise = 0, punish = 0, A = 0, B = 0, moved = 0 }
	for _, o in ipairs {
		{ seed = 31, cpu = "B", raising = "hand" },  -- the computer raises a person's kubbs
		{ seed = 32, cpu = "B", raising = "auto" },  -- and the engine a person's in an automatic match
		{ seed = 33, cpu = { "A", "B" }, raising = "auto" },
		{ seed = 34, cpu = { "A", "B" }, raising = "auto", computer = "beginner" },
		{ seed = 35, cpu = { "A", "B" }, raising = "auto", computer = "beginner" },
		-- (1.2.0: the inkast nearer the centre line plays these seeds otherwise; 37 has a
		-- crowded raise)
		{ seed = 37, cpu = { "A", "B" }, raising = "auto" },
	} do
		local m = { mode = "match", start = START, maxTurns = 14,
			teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
				B = { name = "Computer", players = { { name = "Computer" } } } } }
		for k, v in pairs(o) do m[k] = v end
		local s = session.new(m)
		playOut(s, function(s2, n) check(s2, n, seen) end)
	end
	expect.truthy(seen.raise > 0, "raises handed out: " .. seen.raise)
	expect.truthy(seen.A > 0 and seen.B > 0, "by both sides: " .. seen.A .. " and " .. seen.B)
	expect.truthy(seen.moved > 0, "a crowded or displaced raise among them: " .. seen.moved)
	print(string.format("      %d raises, %d punishment kubbs, %d crowded or displaced", seen.raise, seen.punish, seen.moved))
end)

test("settled: a punishment kubb the engine placed", function()
	local found = 0
	local s = session.new { mode = "match", seed = 41, cpu = "B", raising = "auto", start = START, maxTurns = 6,
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	playOut(s, function(s2, n)
		local seen = { raise = 0, punish = 0, A = 0, B = 0, moved = 0 }
		check(s2, n, seen)
		found = found + seen.punish
	end, true)
	expect.truthy(found > 0, "a punishment kubb handed out")
end)

test("settled: the wide view turns each entry to the world frame; a restore hands out none", function()
	local s = session.new { mode = "match", seed = 33, cpu = { "A", "B" }, raising = "auto", start = START, maxTurns = 14 }
	local done = false
	local before
	playOut(s, function(s2, n)
		if done then return end
		local hasB = false
		for _, e in ipairs(n.setup.settled.list) do if e.side == "B" then hasB = true end end
		if not hasB then return end
		done = true
		before = s2:hash()
		local r = wide.out({ need = json.decode(json.encode(n)) }, { kind = "side" }, s2.frameSide, s2.frameSide)
		for i, e in ipairs(r.need.setup.settled.list) do
			local v = n.setup.settled.list[i]
			expect.eq(e.frame, "world")
			local want = frame.pose(v.side, v.kind == "raise" and v.standing or v.pose)
			local got = e.kind == "raise" and e.standing or e.pose
			expect.near(got.x, want.x, 1e-12); expect.near(got.y, want.y, 1e-12)
			if v.side == "A" then expect.near(got.x, (v.standing or v.pose).x, 1e-12, "Team A's frame is the world's") end
		end
		-- the session's own need is unturned
		expect.truthy(n.setup.settled.list[1].frame == nil)
		-- a session restored from this snapshot hands out none: the kubbs stand raised already
		local c = session.restore(s2:snapshot())
		local cn = c:need()
		expect.eq(cn.kind, "throw")
		expect.eq(cn.setup.settled, nil, "after a restore")
		expect.eq(c:hash(), before, "the same match")
	end)
	expect.truthy(done, "a raise by Team B was handed out")
end)
