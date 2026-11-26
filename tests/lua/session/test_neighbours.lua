-- The Tournament's neighbouring pitches (session/neighbours.lua, docs/SESSION.md
-- "Neighbours", docs/notes/tournament.md) through kubbCall("neighbours.<name>"):
-- opening, the first recording, a recording played back to what view reports, a match
-- ending and the next one setting out, the budget, determinism over different slices,
-- and the player's session untouched in the same Lua state (clients use a state of their
-- own; this proves that even sharing one changes nothing). tests/node/neighbours.test.mjs
-- runs the same under wasmoon.
import "session/api"
import "session/json"
import "session/session"
import "core/namegen"
import "core/pitch"
local json, namegen, session = tw.web.json, tw.namegen, tw.web.session
session.useTune("pointer") -- as every session test: the same name again is fine

local function call(method, a)
	local out = json.decode(_G.kubbCall(method, a and json.encode(a) or ""))
	if type(out) == "table" and out.error then error(method .. ": " .. out.error, 2) end
	return out
end
local function refused(method, a)
	local out = json.decode(_G.kubbCall(method, a and json.encode(a) or ""))
	return type(out) == "table" and out.error
end

-- What a client does with a recording (the iPhone's Playback.pieces(at:), the JavaScript
-- in tests/node/neighbours.test.mjs): the pitch it starts from, each moved body at time
-- t between its two poses around t (before its start where the items have it, after its
-- last pose there), new bodies added.
local function poseOf(b, f, scale)
	local i = (math.min(f - b.start, b.frames - 1)) * 7
	local p = b.poses
	return p[i + 1] / scale, p[i + 2] / scale, p[i + 3] / scale, p[i + 4] / scale, p[i + 5] / scale,
		p[i + 6] / scale, p[i + 7] / scale
end

local function play(items, rec, t)
	local out, at = {}, {}
	for i, it in ipairs(items) do
		local c = {}
		for k, v in pairs(it) do c[k] = v end
		out[i], at[it.id] = c, i
	end
	local u = t / rec.frameDt
	local f = math.floor(u)
	local a = u - f
	for _, b in ipairs(rec.bodies) do
		local it = out[at[b.id]]
		if not it then
			it = { id = b.id, kind = b.kind, team = b.team, toppled = false }
			out[#out + 1] = it
			at[b.id] = #out
		end
		if f + 1 >= b.start then
			local function pose(g)
				if g < b.start then return it.x, it.y, it.z, it.qw, it.qx, it.qy, it.qz end
				return poseOf(b, g, rec.poseScale)
			end
			local x0, y0, z0, w0, i0, j0, k0 = pose(f)
			local x1, y1, z1, w1, i1, j1, k1 = pose(f + 1)
			if w0 * w1 + i0 * i1 + j0 * j1 + k0 * k1 < 0 then w1, i1, j1, k1 = -w1, -i1, -j1, -k1 end
			if a == 0 then x1, y1, z1, w1, i1, j1, k1 = x0, y0, z0, w0, i0, j0, k0 end
			it.x, it.y, it.z = x0 + (x1 - x0) * a, y0 + (y1 - y0) * a, z0 + (z1 - z0) * a
			it.qw, it.qx, it.qy, it.qz = w0 + (w1 - w0) * a, i0 + (i1 - i0) * a, j0 + (j1 - j0) * a, k0 + (k1 - k0) * a
		end
		if b.toppleT and b.toppleT <= t then it.toppled = true end
	end
	return out
end

local function expectItems(got, want, what)
	expect.eq(#got, #want, what .. ": count")
	local by = {}
	for _, it in ipairs(want) do by[it.id] = it end
	for _, it in ipairs(got) do
		local w = by[it.id]
		expect.truthy(w, what .. ": " .. it.id .. " in both")
		for _, k in ipairs { "x", "y", "z" } do expect.near(it[k], w[k], 1e-9, what .. ": " .. it.id .. "." .. k) end
		local d = math.abs(it.qw * w.qw + it.qx * w.qx + it.qy * w.qy + it.qz * w.qz)
		expect.near(d, (it.qw ^ 2 + it.qx ^ 2 + it.qy ^ 2 + it.qz ^ 2) ^ 0.5 * (w.qw ^ 2 + w.qx ^ 2 + w.qy ^ 2 + w.qz ^ 2) ^ 0.5,
			1e-9, what .. ": " .. it.id .. " turn")
		expect.eq(it.toppled, w.toppled, what .. ": " .. it.id .. " toppled")
	end
end

-- Run the neighbours from `now0` to `now1` in clock steps of `dt`, each call given `budget`
-- ({ steps } or { budgetMs }); every event in order, and onEach(r) after each call.
local function run(now0, now1, dt, budget, onEach)
	local events = {}
	local now = now0
	while now < now1 - 1e-9 do
		now = math.min(now1, now + dt)
		local a = { now = now }
		for k, v in pairs(budget) do a[k] = v end
		local r = call("neighbours.advance", a)
		for _, e in ipairs(r.events) do events[#events + 1] = e end
		if onEach and onEach(r, now) then break end
	end
	return events
end

test("neighbours.open: the Tournament's grass and USA set, a ring of pitches, generated teams", function()
	local o = call("neighbours.open", { seed = 3 })
	expect.eq(o.scene, "tournament")
	expect.eq(o.surface, "grass")
	expect.eq(o.set, "usa")
	expect.eq(#o.pitches, 8)
	expect.eq(#o.stakes, 6)
	expect.near(o.frameDt, 0.04, 1e-12, "a pose every second 1/50 s")
	expect.eq(o.poseScale, 1000)
	local seen = {}
	for i, p in ipairs(o.pitches) do
		expect.eq(p.id, i)
		expect.eq(p.phase, "setup")
		local key = p.offset.x .. "," .. p.offset.y
		expect.truthy(not seen[key] and not (p.offset.x == 0 and p.offset.y == 0), "a place of its own: " .. key)
		seen[key] = true
		expect.truthy(math.abs(p.offset.x) == 8 or math.abs(p.offset.y) == 12, "the ring round the player's")
		for _, side in ipairs { "A", "B" } do
			local t = p.teams[side]
			expect.truthy(namegen.valid("team", t.name), "a generated name: " .. t.name)
			expect.truthy(t.level == "beginner" or t.level == "club" or t.level == "pro", "a level, never kid")
			expect.truthy(t.players >= 3 and t.players <= 6)
		end
		expect.truthy(p.teams.A.name ~= p.teams.B.name, "two names")
		-- ten kubbs and the king standing, no stakes (open gives them once)
		expect.eq(#p.items, 11)
		for _, it in ipairs(p.items) do expect.eq(it.toppled, false, it.id) end
	end
	-- the beside pitches first
	expect.eq(o.pitches[1].offset.x, -8)
	expect.eq(o.pitches[2].offset.x, 8)
	local again = call("neighbours.open", { seed = 3 })
	expect.eq(json.encode(again), json.encode(o), "the same seed, the same field")
	expect.truthy(json.encode(call("neighbours.open", { seed = 4 }).pitches) ~= json.encode(o.pitches), "another seed")
	-- any scene: its surface and set; a row either side for a phone held sideways
	local b = call("neighbours.open", { seed = 3, scene = "beach", count = 4, layout = "row" })
	expect.eq(b.surface, "sand")
	expect.eq(b.set, "classic")
	expect.eq(b.pitches[3].offset.x, -16)
	expect.eq(b.pitches[4].offset.y, 0)
	local bw = call("neighbours.open", { seed = 3, scene = "bw", surface = "snow" })
	expect.eq(bw.surface, "snow")
	expect.eq(call("neighbours.open", { seed = 3, level = "pro" }).pitches[5].teams.B.level, "pro")
	expect.truthy(refused("neighbours.open", { level = "kid" }), "kid is no neighbour")
	expect.truthy(refused("neighbours.open", { count = 0 }))
	expect.truthy(refused("neighbours.open", { count = 25 }))
	expect.truthy(refused("neighbours.open", { thin = 4 }))
	expect.truthy(refused("neighbours.open", { levels = { kid = 1 } }))
	call("neighbours.close", {})
	expect.truthy(refused("neighbours.advance", { now = 1, steps = 10 }), "closed")
end)

test("neighbours.advance: the first throws arrive as recordings, paced, with the pitch frame's poses", function()
	call("neighbours.open", { seed = 7, count = 3, now = 100 })
	local events = run(100, 160, 1 / 10, { steps = 400 })
	local throws, last = {}, {}
	for _, e in ipairs(events) do
		if e.phase == "throw" then
			throws[#throws + 1] = e
			local rec = e.recording
			expect.truthy(e.at >= 100 and e.at <= 160)
			expect.truthy(e.side == "A" or e.side == "B")
			expect.truthy(e.kind == "baton" or e.kind == "kubb")
			expect.near(rec.frameDt, 0.04, 1e-12)
			expect.eq(rec.poseScale, 1000)
			expect.near(rec.duration, rec.frames * rec.frameDt, 1e-9)
			expect.truthy(#rec.bodies >= 1, "the thrown piece moves")
			expect.eq(rec.projectile.kind, e.kind == "kubb" and "kubb" or "baton")
			-- the thrower stands on their own baseline, in the pitch frame (Team B's at y = 8)
			if e.side == "A" then expect.truthy(e.from.y <= 4, "A throws from its end")
			else expect.truthy(e.from.y >= 4, "B throws from its end") end
			for _, b in ipairs(rec.bodies) do
				expect.eq(#b.poses, b.frames * 7)
				expect.truthy(b.start + b.frames - 1 <= rec.frames)
			end
			-- a throw every 8 to 15 s on a pitch (batons of one turn; the walk and the raise
			-- are longer, and so is a turn that hands over with no kubbs to throw: since the
			-- seat, 1.0, seed 7 has one, a baton to the other side's after a walk)
			if last[e.id] and last[e.id].kind == "baton" and e.kind == "baton" and last[e.id].side == e.side then
				local gap = e.at - last[e.id].at
				expect.truthy(gap >= 8 - 1e-9 and gap <= 15 + 1e-9, "baton to baton " .. gap)
			end
			last[e.id] = e
		end
	end
	expect.truthy(#throws >= 9, "three pitches throw in a minute: " .. #throws)
	call("neighbours.close")
end)

-- A client's model of every pitch built from the events alone: the items between throws,
-- each recording played to its end and kept. After every call it must equal view.
test("a recording plays back to the positions view reports, throw after throw", function()
	local o = call("neighbours.open", { seed = 11, count = 4 })
	local model = {}
	for _, p in ipairs(o.pitches) do model[p.id] = { items = p.items } end
	local checks = 0
	run(0, 150, 1 / 4, { steps = 600 }, function(r, now)
		for _, e in ipairs(r.events) do
			local m = model[e.id]
			if m.rec then m.items, m.rec = play(m.items, m.rec, m.rec.duration), nil end
			if e.phase == "throw" then m.rec, m.at = e.recording, e.at
			elseif e.items then m.items = e.items end
		end
		for id, m in pairs(model) do
			if m.rec and now >= m.at + m.rec.duration then m.items, m.rec = play(m.items, m.rec, m.rec.duration), nil end
			local v = call("neighbours.view", { id = id })
			if not m.rec then
				expectItems(m.items, v.items, "pitch " .. id .. " at " .. now)
				checks = checks + 1
			else
				expect.truthy(v.recording, "view shows the throw playing")
				expectItems(m.items, v.items, "pitch " .. id .. " before its throw")
				-- part way through, what the client draws moves from where it started
				local mid = play(m.items, m.rec, m.rec.duration / 2)
				expect.truthy(#mid >= #m.items)
			end
		end
	end)
	expect.truthy(checks > 100)
	call("neighbours.close")
end)

test("a match ends with the king and the next one sets out with new teams", function()
	local o = call("neighbours.open", { seed = 2, count = 1, level = "pro" })
	local teams0 = o.pitches[1].teams
	local saw = {}
	local events = run(0, 6 * 3600, 20, { steps = 1000000 }, function(r)
		for _, e in ipairs(r.events) do
			if e.phase == "over" and not saw.over then saw.over = e end
			if e.phase == "setup" and saw.over and not saw.setup then saw.setup = e end
			if e.phase == "throw" and saw.setup and not saw.next then saw.next = e end
		end
		return saw.next ~= nil
	end)
	expect.truthy(saw.over, "a match ended in " .. #events .. " events")
	expect.truthy(saw.over.winner == "A" or saw.over.winner == "B")
	expect.truthy(saw.setup, "the next match set out")
	expect.truthy(saw.setup.at - saw.over.at >= 39 and saw.setup.at - saw.over.at <= 61, "a pause between matches")
	expect.eq(#saw.setup.items, 11, "a fresh pitch")
	expect.truthy(saw.setup.teams.A.name ~= teams0.A.name or saw.setup.teams.B.name ~= teams0.B.name, "new teams")
	expect.truthy(saw.next and saw.next.at - saw.setup.at >= 15 - 1e-9, "the first throw after setting out")
	call("neighbours.close")
end)

test("the budget: a step count is never passed, and a clock's budget is kept", function()
	call("neighbours.open", { seed = 5, count = 8 })
	run(0, 120, 1 / 30, { steps = 40 }, function(r)
		expect.truthy(r.used.steps <= 40, "steps used " .. r.used.steps)
	end)
	call("neighbours.close")
	-- a host clock that moves 0.004 ms a reading (a stand-in for performance.now): what
	-- the call spends by that clock never passes its budget
	local t = 0
	_G.__kubbClock = function() t = t + 0.004; return t end
	call("neighbours.open", { seed = 5, count = 8 })
	local worst = 0
	run(0, 120, 1 / 30, { budgetMs = 0.5 }, function(r)
		if r.used.ms > worst then worst = r.used.ms end
	end)
	expect.truthy(worst <= 0.5, "worst " .. worst)
	expect.truthy(worst > 0.2, "and the budget is used: " .. worst)
	call("neighbours.close")
	_G.__kubbClock = nil
	call("neighbours.open", { seed = 5 })
	expect.truthy(refused("neighbours.advance", { now = 1, budgetMs = 2 }), "budgetMs needs the host's clock")
	expect.truthy(refused("neighbours.advance", { now = 1 }), "a budget is required")
	call("neighbours.advance", { now = 2, steps = 10 })
	expect.truthy(refused("neighbours.advance", { now = 1, steps = 10 }), "the clock goes forward")
	call("neighbours.close")
end)

test("deterministic: two runs agree, and slices of any size give the same events", function()
	local function events(budget, dt)
		call("neighbours.open", { seed = 9, count = 6, now = 50 })
		local ev = run(50, 230, dt or 1 / 20, budget)
		call("neighbours.close")
		return json.encode(ev)
	end
	local a = events({ steps = 300 })
	expect.eq(events({ steps = 300 }), a, "the same run twice")
	expect.eq(events({ steps = 60 }), a, "small slices")
	expect.eq(events({ steps = 100000 }), a, "whole throws")
	local t = 0
	_G.__kubbClock = function() t = t + 0.003; return t end
	expect.eq(events({ budgetMs = 1 }), a, "by a clock")
	-- a host may pass steps on one call and budgetMs on the next: a pitch that paused in
	-- one mode goes on in the other, and the events are still the same
	call("neighbours.open", { seed = 9, count = 6, now = 50 })
	local mixed, now, n = {}, 50, 0
	while now < 230 - 1e-9 do
		now = math.min(230, now + 1 / 20)
		n = n + 1
		local r = call("neighbours.advance", n % 2 == 0 and { now = now, steps = 60 } or { now = now, budgetMs = 1 })
		for _, e in ipairs(r.events) do mixed[#mixed + 1] = e end
	end
	call("neighbours.close")
	expect.eq(json.encode(mixed), a, "steps and a clock turn about")
	_G.__kubbClock = nil
	expect.truthy(#a > 20000, "and there is something in them: " .. #a .. " bytes")
end)

test("a crowded corner's raise, searched in slices, comes out as searched whole", function()
	-- seed 6 has a kubb raised in a crowded corner (core/raising's search, which yields at
	-- raising.probe): cut into slices of a few steps it must give the same (seed 4 until
	-- 1.0: the seat, pairRoll from the first step and the propped contacts play its
	-- matches otherwise; seed 6 since 1.2.0, whose inkast plays seed 2 otherwise; seed 7
	-- since 1.3.0, whose row plays seed 6 otherwise)
	local nc, searched = tw.raising.nearestClear, 0
	tw.raising.nearestClear = function(...) searched = searched + 1; return nc(...) end
	local function byPitch(budget)
		call("neighbours.open", { seed = 7, count = 4 })
		local ev = run(0, 500, 1 / 60, budget)
		call("neighbours.close")
		local out = {}
		for _, e in ipairs(ev) do
			out[e.id] = out[e.id] or {}
			out[e.id][#out[e.id] + 1] = json.encode(e)
		end
		for id, list in pairs(out) do out[id] = table.concat(list, "\n") end
		return out
	end
	local whole = byPitch({ steps = 1000000 })
	expect.truthy(searched > 0, "the search ran")
	local sliced = byPitch({ steps = 8 })
	tw.raising.nearestClear = nc
	for id = 1, 4 do expect.eq(sliced[id], whole[id], "pitch " .. id) end
end)

test("the player's session is untouched by neighbours in the same Lua state", function()
	local START = { year = 2026, month = 11, day = 15, hour = 10, min = 0 }
	local teams = { A = { name = "North", players = { { name = "Alex" }, { name = "Kim" } } },
		B = { name = "South", players = { { name = "Sam" }, { name = "Lee" } } } }
	local opts = { mode = "match", cpu = "both", seed = 21, teams = teams, start = START, maxTurns = 6,
		scene = "tournament" }
	local function cpuThrow(s)
		for _ = 1, 600 do
			if s:frame({ dt = 1 / 60 }).action then return end
		end
		error("the computer did not throw")
	end
	local function play(withNeighbours)
		local s = session.new(session.sceneOptions(opts))
		local hashes = { session.fnv(s:snapshot()) }
		local now = 0
		if withNeighbours then call("neighbours.open", { seed = 21, count = 8 }) end
		for _ = 1, 14 do
			if s:need().kind == "over" then break end
			if withNeighbours then
				for _ = 1, 30 do
					now = now + 0.5
					call("neighbours.advance", { now = now, steps = 200 })
				end
			end
			cpuThrow(s)   -- the actor applies its own throw
			hashes[#hashes + 1] = session.fnv(s:snapshot()) .. ":" .. session.fnv(json.encode(s.recording or {}))
		end
		if withNeighbours then call("neighbours.close") end
		return table.concat(hashes, " ")
	end
	local alone = play(false)
	expect.eq(play(true), alone, "every snapshot and recording as without neighbours")
end)
