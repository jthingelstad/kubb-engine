-- Checking a shared match (session/check.lua, session/replay.lua's checks, docs/SESSION.md
-- "What a server can prove"): the computer's throws made again from the snapshot, a
-- person's throws held to what the dial can give, a side renamed in a start, the finished
-- room document of a replay, and the 0.7.2 additions to what a replay and a recording say
-- (rulings as codes, standing counts, the wide view's landing, the Location line), and
-- 0.7.4's: the Location line in every file a session writes, and short resign words.
import "session/session"
import "session/json"
import "session/check"
import "session/replay"
import "session/api"
import "session/wide"
import "core/autothrow"
import "core/frame"
import "room/lobby"
tw.web.session.useTune("pointer") -- the web's tune
local session, json, check, replay = tw.web.session, tw.web.json, tw.web.check, tw.web.replay
local autothrow, lobby, frame, plan = tw.autothrow, tw.room.lobby, tw.frame, tw.plan
local floor = math.floor

local START = { year = 2026, month = 11, day = 19, hour = 9, min = 0 }
local LEVELS = { "beginner", "club", "pro" }

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

local function call(method, a)
	local r = json.decode(kubbCall(method, a == nil and "" or json.encode(a)))
	if type(r) == "table" and r.error then error(method .. ": " .. r.error, 2) end
	return r
end

-- ---------- a person's throws, through the real dial ----------

-- The plan a person might set before throwing: their level, the arc (ARC is setArc, a
-- continuous value), a tilt or spin (stepSide), a stance (STAND) and a target.
local function aimAround(s, r)
	if r.next() < 0.35 then s:setLevel(LEVELS[1 + floor(r.next() * 3)]) end
	if r.next() < 0.3 then s:setArc(15 + r.next() * 150) end
	if r.next() < 0.3 then s:stepArc(r.next() < 0.5 and -1 or 1) end
	if r.next() < 0.4 then for _ = 1, floor(r.next() * 6) do s:stepSide(r.next() < 0.5 and -1 or 1) end end
	if r.next() < 0.3 then s:setStance(r.next() * 6 - 3, s.ts.lineY - r.next() * 4 + 0.5) end
	if r.next() < 0.3 then s:setTarget(r.next() * 7 - 3.5, s.ts.lineY + 3 + r.next() * 6, r.next() < 0.5) end
end

-- A pointer swing: back to `back` at an easy pace, then forward at `dps` (with some
-- roughness) to `stop`, held there until it leaves. Returns the frame that threw, or nil.
local function pointerThrow(s, r)
	local back, stop = 35 + r.next() * 175, 15 + r.next() * 200
	local dps, rough = 300 + r.next() * 1500, (r.next() < 0.5) and 0 or r.next() * 0.7
	local arm, dt = 0, 1 / 60
	while arm > -back do
		arm = math.max(-back, arm - 400 * dt)
		local o = s:frame { dt = dt, arm = arm }
		if o.action then return o end
	end
	for _ = 1, 600 do
		arm = math.min(stop, arm + dps * dt * (1 + rough * (r.next() * 2 - 1)))
		local o = s:frame { dt = dt, arm = arm }
		if o.action then return o end
		if arm >= stop then
			for _ = 1, 40 do
				o = s:frame { dt = dt, arm = arm }
				if o.action then return o end
			end
			return nil
		end
	end
end

-- A touch stroke (session/touch): down, a pull down the screen, a flick up, lifted.
local function touchThrow(s, r)
	local pts, t = {}, 10 + r.next()
	local wind, stop = 0.1 + r.next() * 0.35, 0.05 + r.next() * 0.4
	local back, fwd = 0.3 + r.next() * 0.4, 0.05 + r.next() * 0.3
	pts[1] = { x = 0.5, y = 0.5, t = t, phase = "down" }
	for i = 1, 30 do pts[#pts + 1] = { x = 0.5, y = 0.5 + wind * i / 30, t = t + back * i / 30 } end
	local n = 20
	for i = 1, n do
		local jx = (r.next() - 0.5) * 0.04 * (r.next() < 0.5 and 1 or 0)
		pts[#pts + 1] = { x = 0.5 + jx, y = 0.5 + wind - (wind + stop) * i / n, t = t + back + fwd * i / n,
			phase = i == n and "up" or nil }
	end
	for _, p in ipairs(pts) do
		local o = s:frame { dt = 1 / 60, touch = { p } }
		if o.action then return o end
	end
	return nil
end

-- A match against the computer (side B), the person's throws through the dial: the log
-- (each action through JSON) and, for each throw, the session as it stood before it.
local function playVsComputer(seed, o)
	o = o or {}
	local setup = { seed = seed, cpu = "B", start = START, raising = "hand",
		wind = ({ "off", "light", "strong" })[seed % 3 + 1], maxTurns = o.maxTurns or 8,
		surface = ({ "grass", "sand", "snow" })[seed % 3 + 1],
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	local s0 = copy(setup)
	s0.mode = "match"
	local s = session.new(s0)
	local start = s:snapshot()
	local log, throws, recs = {}, {}, {}
	local r = autothrow.rng(4000 + seed)
	local guard = 0
	while s:need().kind ~= "over" do
		guard = guard + 1
		assert(guard < 5000, "the match ends")
		local n = s:need()
		local a, rec
		if n.kind == "throw" and session.isCpu(s, s.setup.side) then
			local f
			for _ = 1, 2000 do f = s:frame { dt = 1 / 60 }; if f.action then break end end
			a, rec = f.action, f.recording
		elseif n.kind == "throw" then
			aimAround(s, r)
			local before = s:snapshot()
			local f
			for _ = 1, 20 do
				f = ((o.touch and r.next() < 0.5) and touchThrow or pointerThrow)(s, r)
				if f and f.action then break end
			end
			assert(f and f.action, "a person's throw leaves")
			a, rec = f.action, f.recording
			throws[#throws + 1] = { i = #log + 1, before = before, action = a }
		elseif n.kind == "raise" then
			a = { type = "raise", choice = #n.choices }
			s:apply(a)
		elseif n.kind == "punish" then
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
			assert(s:apply(a).ok ~= false)
		end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
		recs[#log] = rec
	end
	return { setup = setup, start = start, h0 = session.fnv(start), log = log, throws = throws, recs = recs,
		final = s }
end

local MATCHES = {}
local function match(seed, o)
	local key = seed .. (o and o.touch and "t" or "")
	MATCHES[key] = MATCHES[key] or playVsComputer(seed, o)
	return MATCHES[key]
end

local function noH(log)
	local out = {}
	for i, e in ipairs(log) do out[i] = { a = copy(e.a) } end
	return out
end

local function cpuIndexes(m, pred)
	local out = {}
	for i, e in ipairs(m.log) do
		if e.a.type == "throw" and e.a.scripted and (not pred or pred(m.recs[i])) then out[#out + 1] = i end
	end
	return out
end

-- ---------- item 6: the computer's throws made again ----------

test("the computer's throw made again from the snapshot is the very action frame made", function()
	local n = 0
	for seed = 1, 3 do
		local m = match(seed)
		local s = session.restore(m.start, replay.NOBODY)
		for i, e in ipairs(m.log) do
			if e.a.type == "throw" and session.isCpu(s, s.setup.side) then
				local want = check.cpuAction(s)
				expect.truthy(check.same(e.a, want), "seed " .. seed .. " action " .. i .. ": "
					.. tostring(check.firstDiff(e.a, want)))
				n = n + 1
			end
			s:apply(e.a)
			expect.eq(s:hash(), e.h, "the replay keeps step")
		end
	end
	expect.truthy(n > 40, "many of the computer's throws: " .. n)
end)

test("a replay with checkCpu: an honest log passes; a computer throw at half speed is forged", function()
	local m = match(2)
	local r = replay.new { start = m.start, log = noH(m.log), checkCpu = true, checkThrows = true }
	local info = r:finish()
	expect.eq(info.forged, false, "honest: " .. tostring(info.forgedWhy))
	expect.eq(info.outOfBounds, false, "honest: " .. tostring(info.outOfBoundsWhy))
	expect.eq(info.differs, false)
	expect.truthy(info.over, "the match ends")
	expect.truthy(info.cpuChecked > 10 and info.throwsChecked > 10, "both kinds checked")
	-- the computer's throws that knocked nothing down: halving the speed of one of them
	local quiet = cpuIndexes(m, function(rec) return rec and #(rec.result.toppled or {}) == 0 end)
	expect.truthy(#quiet > 0, "a quiet computer throw")
	local i = quiet[1]
	local log = noH(m.log)
	log[i].a.launch.speed = log[i].a.launch.speed / 2
	local f = replay.new { start = m.start, log = log, checkCpu = true }
	local fi = f:finish()
	expect.eq(fi.forged, true, "forged")
	expect.eq(fi.forgedAt, i - 1, "at the halved throw (0-based)")
	expect.truthy(fi.forgedWhy:find("launch.speed", 1, true), fi.forgedWhy)
	-- without the check nothing says so: no hashes come with a shared match
	local plain = replay.new { start = m.start, log = noH(log) }
	local pi = plain:finish()
	expect.eq(pi.forged, false, "unchecked")
	expect.eq(pi.differs, false, "and the forged throw is not refused")
end)

test("a replay's checks find a refused action and an action that should not be there", function()
	local m = match(3)
	local log = noH(m.log)
	-- a throw played twice: the second is out of step and refused
	local t = m.throws[2].i
	table.insert(log, t + 1, { a = copy(log[t].a) })
	local r = replay.new { start = m.start, log = log, checkCpu = true, checkThrows = true }
	local info = r:finish()
	expect.eq(info.refusedAt, t, "the repeat (0-based)")
	expect.eq(info.differs, true)
	-- a person's throw put in on the computer's turn is not the computer's
	local c = cpuIndexes(m)[3]
	local log2 = noH(m.log)
	local p = copy(m.throws[1].action)
	p.seq = log2[c].a.seq
	log2[c].a = p
	local r2 = replay.new { start = m.start, log = log2, checkCpu = true }
	local i2 = r2:finish()
	expect.eq(i2.forged, true)
	expect.eq(i2.forgedAt, c - 1)
end)

-- ---------- item 7: checkThrow ----------

test("checkThrow takes every person's throw the dial made: pointer and touch, every level, batons and kubbs", function()
	local n, kubbs, lv, touch = 0, 0, {}, 0
	for _, k in ipairs { { 1 }, { 2 }, { 4, true }, { 5, true }, { 6 } } do
		local m = match(k[1], { touch = k[2] })
		for _, t in ipairs(m.throws) do
			local s = session.restore(t.before)
			local res = check.throw(s, t.action)
			expect.truthy(res.ok, "seed " .. k[1] .. " action " .. t.i .. ": " .. tostring(res.why) .. " "
				.. json.encode(t.action))
			expect.eq(res.computer, false)
			n = n + 1
			if t.action.how == "drill" then kubbs = kubbs + 1 end
			if t.action.input == "touch" then touch = touch + 1 end
			for _, l in ipairs(res.levels or {}) do lv[l] = true end
		end
	end
	expect.truthy(n > 100, "throws checked: " .. n)
	expect.truthy(kubbs > 10, "kubbs: " .. kubbs)
	expect.truthy(touch > 20, "touch throws: " .. touch)
	expect.truthy(lv.beginner and lv.club and lv.pro, "every level fits some throw")
end)

test("checkThrow refuses a throw at 30 m/s and other throws the dial cannot make", function()
	local m = match(1)
	local bat, kub
	for _, t in ipairs(m.throws) do
		if t.action.how == "baton" and t.action.launch.legal and t.action.swing.back < 110 and not bat then bat = t end
		-- (a drill released at the sky end or very early fits other releases with its
		-- nose moved, so the nose pins nothing there: from 0.9 match 1's first drill
		-- stops at 29 degrees and takes any nose; docs/notes, the owner's to decide)
		if t.action.how == "drill" and t.action.swing.stop > 60 and t.action.swing.stop < 160
			and not kub then kub = t end
	end
	local function refused(t, change, what)
		local a = copy(t.action)
		change(a)
		local res = check.throw(session.restore(t.before), a)
		expect.eq(res.ok, false, what)
		return res
	end
	expect.truthy(check.throw(session.restore(bat.before), bat.action).ok, "the throw as made")
	refused(bat, function(a) a.launch.speed = 30 end, "30 m/s")
	refused(kub, function(a) a.launch.speed = 30 end, "a kubb at 30 m/s")
	refused(bat, function(a) a.launch.speed = 20 end, "a short swing at 20 m/s")
	refused(bat, function(a) a.launch.loft = a.launch.loft + 3 end, "a loft its stop cannot give")
	refused(bat, function(a) a.launch.swivel = a.launch.swivel + 0.3 end, "17 degrees off its line")
	refused(bat, function(a) a.launch.tumble = 200 end, "a tumble too fast")
	refused(bat, function(a) a.launch.tumble = -3 end, "a tumble under the least (plan.launch clamps to tumbleMin)")
	refused(bat, function(a) a.launch.tumble = plan.tune.tumbleMin - 1e-6 end, "just under the least")
	refused(bat, function(a) a.launch.speed = -a.launch.speed end, "a backward speed")
	refused(bat, function(a) a.launch.speed = 0 end, "no speed")
	refused(kub, function(a) a.launch.spin = a.launch.spin + plan.tune.spinPerStep * 0.5 end, "a kubb's spin between steps")
	refused(kub, function(a) a.launch.rollLand = 0.1 end, "a kubb's roll")
	refused(bat, function(a) a.launch.tilt = 80; a.launch.legal = true end, "a helicopter called legal")
	refused(bat, function(a) a.swing.back = 260 end, "a backswing past the swing's cap")
	refused(bat, function(a) a.swing.stop = -10 end, "a backward release")
	refused(bat, function(a) a.verdicts.releaseV = (a.verdicts.releaseV + 2) % 3 - 1 end, "a release verdict changed")
	refused(bat, function(a) a.stance.y = a.stance.y + 2; a.stance.set = true end, "past the line")
	refused(bat, function(a) a.stance.x = 2.6; a.stance.set = true end, "off the line's end")
	refused(bat, function(a) a.target.x, a.target.y, a.target.on = 9, 20, nil end, "a target off the pitch")
	refused(bat, function(a) a.scripted = true end, "the computer's kind of throw on a person's side")
	refused(bat, function(a) a.how = "drill" end, "a drill when a baton is set up")
	refused(kub, function(a) a.launch.spin = a.launch.spin + 7 end, "a kubb's spin no plan gives")
	refused(kub, function(a) a.launch.noseDown = a.launch.noseDown + 5 end, "a kubb's nose")
	refused(kub, function(a) a.launch.tumble = 4 end, "a tumbling kubb")
	refused(kub, function(a) a.launch.scatter = 0.01 end, "a hand steadier than the level's")
	refused(kub, function(a) a.launch.scatter = false end, "a scatter that is not a number")
	refused(kub, function(a) a.launch.scatter = "1" end, "a scatter that is a string")
	-- a replay with checkThrows reports the first such throw
	local log = noH(m.log)
	log[bat.i].a.launch.speed = 30
	local r = replay.new { start = m.start, log = log, checkThrows = true }
	local info = r:finish()
	expect.eq(info.outOfBounds, true)
	expect.eq(info.outOfBoundsAt, bat.i - 1)
end)

-- Until 0.10 a drill released very early (stop about 29) or at the sky end (about 180)
-- took a forged nose, because the nose moved fitted another candidate release (0.9.0's
-- known gap, docs/SESSION.md "Checking a throw"). The nose now goes by the loft the kubb
-- left at (drill.noseFor), which the check holds, so none is taken.
test("a drill released very early or at the sky end takes no forged noseDown", function()
	local outside, taken = 0, 0
	for _, seed in ipairs { 1, 2 } do
		local m = match(seed)
		for _, t in ipairs(m.throws) do
			local a = t.action
			if a.how == "drill" and (a.swing.stop <= 60 or a.swing.stop >= 160) then
				outside = outside + 1
				local f = copy(a)
				f.launch.noseDown = f.launch.noseDown + 5
				if check.throw(session.restore(t.before), f).ok then taken = taken + 1 end
			end
		end
	end
	expect.truthy(outside > 0, "drills outside 60 to 160 in matches 1 and 2")
	expect.eq(taken, 0, taken .. " of " .. outside .. " forged noses taken")
end)

test("checkThrow's bounds: an overpowered swing at a near target, and the fastest legal baton", function()
	-- A full backswing at a near target overpowers: every 30 degrees past the power
	-- target multiplies the nerves, so the speed spreads wide. The dial can throw such a
	-- baton at 30 m/s honestly (about one legal throw in 300 here), and checkThrow takes
	-- them all.
	local n, fast = 0, 0
	for seed = 1, 8 do
		local s = session.new { mode = "match", seed = seed, cpu = "B", start = START,
			teams = { A = { name = "Ada", players = { { name = "Ada", level = LEVELS[seed % 3 + 1] } } },
				B = { name = "Computer", players = { { name = "Computer" } } } } }
		local r = autothrow.rng(seed * 7)
		for _ = 1, 3 do
			local s2 = session.restore(s:snapshot())
			s2:setTarget(r.next() * 2 - 1, s2.ts.lineY + 2 + r.next() * 2, false)
			local before = s2:snapshot()
			local arm, dt, o = 0, 1 / 60, nil
			while arm > -200 do arm = math.max(-200, arm - 600 * dt); o = s2:frame { dt = dt, arm = arm } end
			local stop = 40 + r.next() * 100
			for _ = 1, 200 do
				arm = math.min(stop, arm + (1500 + r.next() * 1500) * dt * (1 + (r.next() * 2 - 1) * r.next()))
				o = s2:frame { dt = dt, arm = arm }
				if o.action then break end
			end
			expect.truthy(o.action, "thrown")
			local res = check.throw(session.restore(before), o.action)
			expect.truthy(res.ok, tostring(res.why))
			n = n + 1
			if o.action.launch.speed > 15 then fast = fast + 1 end
		end
	end
	expect.truthy(fast > 5, "fast overpowered throws: " .. fast .. " of " .. n)
	-- The bound itself: speedFor(back as it counts) x a flick of at most 1 x sqrt(1 + ZMAX
	-- length sds). A legal baton's shake is pinned by its tilt (|tilt| <= legalTiltDeg,
	-- planned tilt within tiltMaxDeg), but the overpower multiplies the sds whatever the
	-- shake, so the widest is a 200 degree swing at the nearest plan.
	local t, best = plan.tune, 0
	for _, l in ipairs(LEVELS) do
		local lv = plan.level(l)
		for solBack = 30, 200, 5 do
			local back = 200
			local effBack = solBack + plan.shrink(back - solBack, lv.powerHalf, lv.inGain)
			local m = 1 + lv.overGain * math.max(0, back - (solBack + lv.powerHalf)) / t.overPerDeg
			local se = (t.legalTiltDeg + t.tiltMaxDeg) / t.shakeTiltDeg
			local shake = math.min(1, se / (lv.shakeGain * m))
			local _, sdLen = plan.nervesSd(lv, effBack, shake, m, false)
			local v = plan.speedFor(effBack) * math.sqrt(1 + check.ZMAX * sdLen)
			if v > best then best = v end
		end
	end
	expect.truthy(best > 45 and best < 60, "the fastest legal baton the bound allows: " .. best)
	expect.near(check.ZMAX, 7.4338, 1e-3, "ZMAX from plan.rng's 1e-12 floor")
end)

-- ---------- item 8: renameStart ----------

test("renameStart changes a side's names and nothing else: the same throws, other hashes", function()
	local m = match(4)
	local renamed = call("renameStart", { start = m.start, names = { A = "Shared" } }).start
	local a, b = json.decode(m.start), json.decode(renamed)
	expect.eq(b.opts.teams.A.name, "Shared")
	expect.eq(b.opts.teams.A.players[1].name, "Shared")
	expect.eq(b.opts.teams.A.players[1].key, "m1", "the key is not a name")
	-- set the names back and the snapshot is the original, byte for byte
	expect.eq(call("renameStart", { start = renamed, names = { A = "Ada" } }).start, m.start)
	-- the opts differ in the names alone
	local ao, bo = copy(a.opts), copy(b.opts)
	bo.teams.A.name, bo.teams.A.players[1].name = "Ada", "Ada"
	expect.eq(json.encode(ao), json.encode(bo))
	-- played on: the same pieces and results at every action; every hash differs
	local r1 = replay.new { start = m.start, log = noH(m.log), document = true }
	local r2 = replay.new { start = renamed, log = noH(m.log), document = true }
	expect.truthy(r1.firstHash ~= r2.firstHash, "h0 differs")
	local differ = 0
	for i = 1, #m.log do
		local o1, o2 = r1:step(), r2:step()
		expect.eq(o1.ok, true)
		expect.eq(o2.ok, true, "action " .. i .. " taken renamed")
		if o1.recording then
			local x1, x2 = copy(o1.recording), copy(o2.recording)
			x1.result.ruling, x2.result.ruling = nil, nil
			expect.eq(json.encode(x1), json.encode(x2), "the same throw " .. i)
			local w1, w2 = o1.recording.result.ruling, o2.recording.result.ruling
			expect.eq(json.encode(w1.parts), json.encode(w2.parts), "the same ruling " .. i)
			expect.eq(w1.text:gsub("Ada", "Shared"), w2.text, "its words differ in the name alone")
		end
		expect.eq(json.encode(r1.s:pitchItems()), json.encode(r2.s:pitchItems()), "the same pieces " .. i)
		if r1.hashes[i] ~= r2.hashes[i] then differ = differ + 1 end
	end
	expect.eq(differ, #m.log, "every hash after an action differs (the names are in the snapshot)")
	expect.eq(r1:info().over, true)
	expect.eq(r2:info().over, true)
	expect.eq(r1.s.m.game.winner, r2.s.m.game.winner)
	-- what a start must be
	expect.eq(call("checkStart", { start = m.start }).ok, true)
	local mid = session.restore(m.start)
	mid:apply(m.log[1].a)
	local no = call("checkStart", { start = mid:snapshot() })
	expect.eq(no.ok, false)
	expect.truthy(json.decode(kubbCall("renameStart", json.encode { start = mid:snapshot(), names = { A = "X" } })).error)
end)

-- A thrower action names a player by id, and the ids come from the names: a rename maps
-- the log too. On a one-player side the action is taken (naming its only player), so a
-- solo match against the computer can carry one.
local function cmatchCandidates(s) return tw.match.candidates(s.m) end

local function playWithThrowers(seed, sizeA, cpu)
	local s = session.new { mode = "match", seed = seed, cpu = cpu, start = START, maxTurns = 6,
		teams = matchTeams(sizeA, 1) }
	local start = s:snapshot()
	local log, recs, changes = {}, {}, 0
	local r = autothrow.rng(seed)
	local function put(a, out)
		log[#log + 1] = { a = json.decode(json.encode(a)) }
		recs[#log] = out and out.recording and json.encode(out.recording) or nil
	end
	local guard = 0
	while s:need().kind ~= "over" do
		guard = guard + 1
		assert(guard < 5000)
		local n = s:need()
		if n.kind == "throw" and not session.isCpu(s, s.setup.side) then
			local pick
			for _, c in ipairs(cmatchCandidates(s)) do
				if c.ok and (not c.current or sizeA == 1) then pick = c end
			end
			if pick and (sizeA == 1 or r.next() < 0.5) then
				local a = { type = "thrower", id = pick.id }
				local o = s:apply(a)
				expect.eq(o.ok, true, "the thrower change is taken: " .. tostring(o.why))
				put(a)
				changes = changes + 1
			end
			local f
			for _ = 1, 20 do f = pointerThrow(s, r); if f and f.action then break end end
			put(f.action, f)
		elseif n.kind == "throw" then
			local f
			for _ = 1, 2000 do f = s:frame { dt = 1 / 60 }; if f.action then break end end
			put(f.action, f)
		elseif n.kind == "raise" then
			local a = { type = "raise", choice = #n.choices }
			s:apply(a); put(a)
		else
			local a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
			s:apply(a); put(a)
		end
	end
	return start, log, recs, changes
end

test("renameStart maps the thrower actions' ids: a team of two, renamed, replays to its end", function()
	local start, log, recs, changes = playWithThrowers(12, 2, "B")
	expect.truthy(changes > 2, "thrower changes: " .. changes)
	-- unmapped, the renamed match stops at the first thrower action
	local out = call("renameStart", { start = start, names = { A = { name = "East", players = { "Uma", "Vic" } } },
		log = log })
	local plain = replay.new { start = out.start, log = noH(log) }
	local pi = plain:finish()
	expect.truthy(pi.refusedAt ~= nil, "the old ids are refused")
	local first
	for i, e in ipairs(log) do if e.a.type == "thrower" then first = first or i end end
	expect.eq(pi.refusedAt, first - 1)
	-- mapped: to the end, every recording the same but for the names
	local n = 0
	for _ in pairs(out.ids) do n = n + 1 end
	expect.eq(n, 3, "an id for each player")
	local r1 = replay.new { start = start, log = noH(log) }
	local r2 = replay.new { start = out.start, log = out.log }
	for i = 1, #log do
		local o1, o2 = r1:step(), r2:step()
		expect.eq(o2.ok, true, "action " .. i .. " renamed")
		if o1.recording then
			local x1, x2 = copy(o1.recording), copy(o2.recording)
			x1.result.ruling, x2.result.ruling = nil, nil
			expect.eq(json.encode(x1), json.encode(x2), "the same throw " .. i)
			expect.eq(json.encode(o1.recording), recs[i], "the original as played " .. i)
		end
	end
	expect.eq(r2:info().over, true, "the renamed match ends")
	expect.eq(r2:info().differs, false)
	expect.eq(r1.s.m.game.winner, r2.s.m.game.winner)
end)

test("a solo side can carry a thrower action, and the rename maps it", function()
	local start, log, _, changes = playWithThrowers(14, 1, "B")
	expect.truthy(changes > 0, "the sole player named")
	local out = call("renameStart", { start = start, names = { A = "Shared" }, log = log })
	local r = replay.new { start = out.start, log = out.log, checkCpu = true }
	local info = r:finish()
	expect.eq(info.over, true)
	expect.eq(info.refusedAt, nil)
	expect.eq(info.forged, false)
end)

test("renameStart renames a team of several by name and players", function()
	local s = session.new { mode = "match", seed = 9, cpu = "B", start = START, teams = matchTeams(3, 1) }
	local start = s:snapshot()
	local out = session.renameStart(start, { A = { name = "East", players = { "One", "Two", "Three" } } })
	local d = json.decode(out)
	expect.eq(d.opts.teams.A.name, "East")
	expect.eq(d.opts.teams.A.players[3].name, "Three")
	expect.truthy(not out:find("Alex", 1, true), "no old name left")
	expect.truthy(not pcall(session.renameStart, start, { A = { players = { "Only one" } } }), "one name each")
end)

-- ---------- item 9: the finished document ----------

-- A real room's match, as the web plays it: the lobby's reducers, START with the host's
-- first snapshot, every action committed with the snapshot after it.
local function realRoom(seed)
	local members = { { id = "m7", me = { name = "  Ada  ", level = "pro", engine = tw.engine.version } } }
	local doc = lobby.joinTeam(nil, "m7", "A")
	doc = lobby.setOptions(doc, { wind = "light", surface = "sand" }) or doc
	local lu = lobby.lineup(doc, members)
	local setup = json.decode(json.encode(lobby.matchOptions(doc, lu, seed, START)), true)
	setup.maxTurns = 6
	local o = copy(setup)
	o.mode = "match"
	local s = session.new(o)
	doc = lobby.startMatch(doc, { snap = s:snapshot(), hash = s:hash(), players = lu.players, cpu = lu.cpu,
		host = "m7", setup = setup, members = members })
	local r = autothrow.rng(seed)
	local seq = 0
	while s:need().kind ~= "over" do
		local n = s:need()
		local a
		if n.kind == "throw" and session.isCpu(s, s.setup.side) then
			local f
			for _ = 1, 2000 do f = s:frame { dt = 1 / 60 }; if f.action then break end end
			a = f.action
		elseif n.kind == "throw" then
			local f
			for _ = 1, 20 do f = pointerThrow(s, r); if f and f.action then break end end
			a = f.action
		elseif n.kind == "raise" then
			a = { type = "raise", choice = #n.choices }
			s:apply(a)
		else
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
			s:apply(a)
		end
		seq = seq + 1
		doc = lobby.commitAction(doc, { n = doc.n, seq = seq, snap = s:snapshot(), hash = s:hash(),
			action = json.decode(json.encode(a)), over = s:need().kind == "over" })
		assert(doc, "committed")
	end
	return json.decode(json.encode(doc), true), s
end

test("a replay's finished document is the one a real room wrote", function()
	local doc = realRoom(31)
	local m = doc.match
	expect.eq(m.over, true)
	local text = call("replayLoad", { setup = m.setup, h0 = m.h0, log = m.log, document = { host = "m7" } })
	expect.eq(text.replay.differs, false)
	local fin = call("replayFinish")
	expect.eq(fin.over, true)
	local out = call("replayDocument")
	call("replayEnd")
	expect.eq(json.encode(out.document), json.encode(doc), "the same document, byte for byte")
	expect.eq(out.h0, m.h0)
	expect.eq(out.hashes[#out.hashes], m.hash)
	expect.truthy(lobby.replayOf(json.decode(json.encode(out.document), true).match), "the room keeps its replay")
end)

test("a shared match's document from its start: teams, options, result, the last snapshot", function()
	local m = match(5)
	local r = replay.new { start = m.start, log = noH(m.log), document = true }
	r:finish()
	local doc = assert(r:document())
	local d = json.decode(json.encode(doc), true)
	expect.eq(d.started, true)
	expect.eq(d.teams.A[1], "m1", "the player's key is the member id")
	expect.eq(#d.teams.B, 0, "the computer has no member")
	expect.eq(d.match.cpu, "B")
	expect.eq(d.match.over, true)
	expect.eq(d.match.seq, #m.log)
	expect.eq(d.match.snap, m.final:snapshot(), "the last snapshot")
	expect.eq(d.match.hash, m.log[#m.log].h)
	expect.eq(d.match.h0, m.h0)
	expect.eq(d.options.wind, m.setup.wind)
	expect.eq(d.match.players.A[1].name, "Ada")
	local rep = lobby.replayOf(d.match)
	expect.truthy(rep, "a replay the room keeps")
	-- and that replay plays to the same end
	local again = replay.new { setup = rep.setup, h0 = rep.h0, log = rep.log }
	local info = again:finish()
	expect.eq(info.differs, false)
	expect.eq(again.s:hash(), d.match.hash)
	-- not finished, or refused: no document
	local half = replay.new { start = m.start, log = noH(m.log), document = true }
	half:step()
	expect.eq(half:document(), nil)
	local log = noH(m.log)
	table.insert(log, 2, { a = copy(log[1].a) })
	local bad = replay.new { start = m.start, log = log, document = true }
	bad:finish()
	expect.eq(bad:document(), nil)
end)

-- ---------- items 2, 3, 1 and the Location line ----------

test("rulings carry codes beside their words, and the words are as before", function()
	local seen = {}
	-- (13: from 0.9 seeds 1 to 12 drill no second kubb in a turn, so give no "in for now")
	for _, seed in ipairs { 1, 2, 3, 4, 5, 6, 13 } do
		local m = match(seed)
		for i, rec in pairs(m.recs) do
			local w = rec.result.ruling
			expect.truthy(w.code and w.parts and #w.parts >= 1, "a code for " .. tostring(w.text))
			expect.eq(w.code, w.parts[1].code)
			expect.eq(w.short, session.short(w.text))
			seen[w.code] = true
			local first = w.text:match("^[^;]*")
			if w.code == "miss" then expect.eq(first, "missed") end
			if w.code == "kingMiss" then expect.eq(first, "missed the king") end
			if w.code == "kingWin" then expect.truthy(first:find("^king down: "), first); expect.truthy(w.winner) end
			if w.code == "field" then
				expect.truthy(first:find((w.n == 1 and "field kubb" or (w.n .. " field kubbs")), 1, true), first)
			end
			if w.code == "base" then
				expect.truthy(first:find((w.n == 1 and "base kubb" or (w.n .. " base kubbs")), 1, true), first)
			end
			if w.code == "inForNow" then expect.eq(first, "kubb in for now") end
			if w.code == "in" then expect.truthy(first == "kubb in" or first == "all in", first) end
		end
	end
	expect.truthy(seen.miss and seen.base and seen.inForNow, "the common rulings")
end)

test("replayStep gives the kubbs standing before and after each action", function()
	local m = match(1)
	local r = replay.new { start = m.start, log = noH(m.log) }
	local last = nil
	for _ = 1, #m.log do
		local o = r:step()
		expect.truthy(o.standing and o.standing.before and o.standing.after)
		if last then expect.eq(json.encode(o.standing.before), json.encode(last), "after is the next before") end
		last = o.standing.after
		for _, side in ipairs { "A", "B" } do
			local st = o.standing.after[side]
			expect.truthy(st.field >= 0 and st.base >= 0 and st.base <= 5, "counts")
		end
	end
	expect.eq(json.encode(last), json.encode(m.final:standing()))
	local first = replay.new { start = m.start, log = noH(m.log) }:step()
	expect.eq(first.standing.before.A.base, 5)
	expect.eq(first.standing.before.B.base, 5)
	expect.eq(first.standing.before.king, true)
end)

test("the wide view un-turns Team B's landing, rest and first hit", function()
	local m = match(2)
	call("setWide", { box = { left = 0, top = 0, right = 1280, bottom = 800 } })
	call("replayLoad", { start = m.start, log = noH(m.log) })
	local n = 0
	for i = 1, #m.log do
		local o = call("replayStep")
		local rec, raw = o.recording, m.recs[i]
		if rec and raw and m.log[i].a.scripted then -- the computer: side B
			local x, y = frame.point("B", raw.result.landX, raw.result.landY)
			expect.near(rec.result.landX, x, 1e-12)
			expect.near(rec.result.landY, y, 1e-12)
			if raw.timeline.firstHit then
				local hx, hy = frame.point("B", raw.timeline.firstHit.x, raw.timeline.firstHit.y)
				expect.near(rec.timeline.firstHit.x, hx, 1e-12)
				expect.near(rec.timeline.firstHit.y, hy, 1e-12)
				expect.eq(rec.timeline.firstHit.t, raw.timeline.firstHit.t)
			end
			local lx, ly = frame.point("B", raw.landing.x, raw.landing.y)
			expect.near(rec.landing.x, lx, 1e-12)
			expect.near(rec.landing.y, ly, 1e-12)
			n = n + 1
		elseif rec and raw then -- side A: as it was
			expect.eq(rec.result.landX, raw.result.landX)
			expect.eq(rec.result.landY, raw.result.landY)
		end
	end
	call("replayEnd")
	call("setWide", {})
	expect.truthy(n > 5, "Team B's throws")
end)

test("setClient's location is the game file's Location line; by default it is Playdate's", function()
	local old = session.client
	local s = session.new { mode = "match", seed = 3, cpu = "both", start = START, maxTurns = 1 }
	expect.truthy(s:sheet().text:find('[Location "Playdate"]', 1, true), "today's default")
	expect.eq(call("setClient", { label = "web 9.9.9", location = "Web" }).location, "Web")
	expect.truthy(s:sheet().text:find('[Location "Web"]', 1, true), "the client's place")
	local h = s:hash()
	expect.truthy(json.decode(kubbCall("setClient", json.encode { label = "web 9.9.9", location = "a\nb" })).error)
	expect.eq(call("setClient", { label = old }).location, "Playdate", "absent: the default again, and said")
	expect.truthy(s:sheet().text:find('[Location "Playdate"]', 1, true))
	expect.eq(s:hash(), h, "not in the hash")
end)

-- ---------- 0.7.4: the Location line everywhere, and the short words of an end ----------

local function locationOf(text) return text:match('%[Location "([^"]*)"%]') end

test("setClient says what it set: { client, location }, Playdate when none is given", function()
	local old = session.client
	local r = call("setClient", { label = "web 9.9.9", location = "throwingwood.com" })
	expect.eq(r.client, "web 9.9.9")
	expect.eq(r.location, "throwingwood.com")
	r = call("setClient", { label = "web 9.9.9" })
	expect.eq(r.location, "Playdate")
	expect.eq(session.location, nil, "nothing set: the core's own line")
	for _, bad in ipairs { "", " throwingwood.com", "throwingwood.com ", "a\"b", "a]b", "a/b", "a:b",
		string.rep("x", 41), "é" } do
		expect.truthy(json.decode(kubbCall("setClient", json.encode { label = "web 9.9.9", location = bad })).error,
			"refused: " .. bad)
	end
	expect.truthy(json.decode(kubbCall("setClient", json.encode { label = "web 9.9.9", location = 7 })).error)
	call("setClient", { label = old })
end)

test("the Location line reaches the live sheet, the over card's file and a replay's, and no hash", function()
	local old = session.client
	local m = match(3)
	local final = m.final
	-- not set: Playdate, as before
	call("setClient", { label = old })
	expect.eq(locationOf(final:sheet().text), "Playdate")
	expect.eq(locationOf(final:need().file.text), "Playdate", "the over card's file, written at the end")
	call("replayLoad", { start = m.start, log = noH(m.log) })
	call("replayFinish")
	expect.eq(locationOf(call("need").file.text), "Playdate", "a replay's over file")
	expect.eq(locationOf(call("sheet").text), "Playdate", "a replay's sheet")
	local plainFile = call("need").file.text
	call("replayEnd")
	-- set: every file written from then on carries it
	call("setClient", { label = old, location = "throwingwood.com" })
	local live = session.new { mode = "match", seed = 3, cpu = "both", start = START, maxTurns = 1 }
	expect.eq(locationOf(live:sheet().text), "throwingwood.com", "a live sheet")
	local info = call("replayLoad", { start = m.start, log = m.log }).replay
	expect.eq(info.differs, false)
	info = call("replayFinish")
	expect.eq(info.replay and info.replay.differs or info.differs, false, "every hash as recorded")
	expect.eq(call("hash").hash, m.log[#m.log].h, "the last hash is the recorded one")
	local file = call("need").file.text
	expect.eq(locationOf(file), "throwingwood.com", "a replay's over file")
	expect.eq(locationOf(call("sheet").text), "throwingwood.com", "a replay's sheet")
	expect.eq((file:gsub('%[Location "[^"]*"%]', "")), (plainFile:gsub('%[Location "[^"]*"%]', "")),
		"only the Location line differs")
	call("replayEnd")
	-- a server's document of the same replay does not depend on it
	local function doc()
		local r = replay.new { start = m.start, log = noH(m.log), document = true }
		r:finish()
		return json.encode((r:document()))
	end
	local withLoc = doc()
	call("setClient", { label = old })
	expect.eq(doc(), withLoc, "the room document is the same with or without a location")
	expect.truthy(not withLoc:find("throwingwood.com", 1, true) and not withLoc:find("Playdate", 1, true),
		"no Location in the document")
end)

test("short: a resignation is RESIGNED whatever the team is called; nothing is cut inside a word", function()
	expect.eq(session.short("Riverside resigned: Oak wins"), "RESIGNED")
	expect.eq(session.short("rescue squad resigned: missed wins"), "RESIGNED")
	expect.eq(session.short("king down resigned: Oak wins"), "RESIGNED")
	expect.eq(session.short("resigned: Oak wins"), "RESIGNED")
	expect.eq(session.short("king down: Riverside wins"), "KING DOWN")
	expect.eq(session.short("king down early: Riverside wins"), "KING TOO EARLY: GAME OVER")
	expect.eq(session.short("missed the king"), "KING STANDS")
	expect.eq(session.short("2 field kubbs and base kubb down; pushed out: put back"), "3 DOWN")
	expect.eq(session.short("2 rescues"), "2 RESCUE")
	-- the fallback (no rule matches anything the core writes today)
	expect.eq(session.short("something new here"), "SOMETHING")
	expect.eq(session.short("short one"), "SHORT ONE")
	expect.eq(session.short("abcdefghijklmnop"), "ABCDEFGHIJKLMNOP", "one long word stays whole")
	expect.eq(session.short("twelve chars and more"), "TWELVE CHARS")
	-- a real resignation, through a match's end (the turn limit resigns)
	local m = match(3)
	local n = m.final:need()
	expect.eq(n.kind, "over")
	if m.final.m.game.how == "resigned" then
		expect.truthy(n.text:find(" resigned: "), n.text)
		expect.eq(n.short, "RESIGNED")
		expect.eq(n.last.short, "RESIGNED")
	end
	local s = session.new { mode = "match", cpu = "both", seed = 3, start = START,
		teams = { A = { name = "Riverside", players = { "Riv" } }, B = { name = "Oak", players = { "Oak" } } } }
	expect.truthy(s:apply { type = "resign", side = s:need().side }.ok ~= false)
	n = s:need()
	expect.eq(n.kind, "over")
	expect.truthy(n.text:find("^%a+ resigned: %a+ wins$"), n.text)
	expect.eq(n.short, "RESIGNED")
	expect.eq(n.last.short, "RESIGNED")
end)

-- ---------- 0.8.0: a person's baton planned under flight.tune.nearM ----------

-- A short baton's loft is the release's loft times the plan's loftShare, plus the
-- overpower heave (nearOverLoft) past the power target: a server must hold it to that,
-- not to the release's loft. A play-made advantage line rarely stands this near a
-- kubb, so the set-up's advantage line is moved up by hand, in both sessions alike.
test("check: a person's short baton fits, on the band, long, at any arc and level", function()
	local function at(d, level, arc)
		local s = session.new { mode = "match", seed = 7, cpu = "B", start = START, maxTurns = 4,
			teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
				B = { name = "Computer", players = { { name = "Computer" } } } } }
		s.setup.forwardY, s.ts.forwardY = 4.6, 4.6
		s:setStance(0, 4.6)
		s:setTarget(0, 4.6 + d, false)
		if level then s:setLevel(level) end
		if arc then s:setArc(arc) end
		return s
	end
	local function swingTo(s, back, stop)
		local arm, o = 0, nil
		while arm > -back do
			arm = math.max(-back, arm - 400 / 60)
			o = s:frame { dt = 1 / 60, arm = arm }
			if o.action then return o.action end
		end
		for _ = 1, 200 do
			arm = math.min(stop, arm + 2400 / 60)
			o = s:frame { dt = 1 / 60, arm = arm }
			if o.action then return o.action end
		end
		return s:frame({ dt = 1 / 60 }).action
	end
	local r = autothrow.rng(808)
	local cases = {}
	for _, d in ipairs { 0.35, 0.75, 1.25, 1.9 } do
		for over = 0, 1 do cases[#cases + 1] = { d = d, over = over } end
	end
	for _ = 1, 16 do
		cases[#cases + 1] = { d = 0.1 + r.next() * 1.9, level = LEVELS[1 + floor(r.next() * 3)],
			arc = r.next() < 0.5 and 15 + r.next() * 150 or nil, back = 35 + r.next() * 120,
			stopOff = (r.next() - 0.5) * 80 }
	end
	for _, c in ipairs(cases) do
		local s1 = at(c.d, c.level, c.arc)
		local p = s1:aimView().plan
		expect.truthy(p.dist < 2, "planned under nearM")
		local back = c.back or (p.powerLo + p.powerHi) / 2 + (c.over or 0) * (p.powerHi - p.powerLo)
		local a = swingTo(s1, back, math.max(5, p.release + (c.stopOff or 0)))
		expect.truthy(a, "the swing threw")
		local res = check.throw(at(c.d, c.level, c.arc), json.decode(json.encode(a)))
		expect.truthy(res.ok, string.format("%.2f m: %s", c.d, tostring(res.why)))
	end
	-- and a launch no swing gives is still refused
	local s1 = at(0.35)
	local p = s1:aimView().plan
	local a = json.decode(json.encode(swingTo(s1, (p.powerLo + p.powerHi) / 2, p.release)))
	a.launch.loft = a.launch.loft + 10
	expect.eq(check.throw(at(0.35), a).ok, false, "a loft 10 degrees off")
	a.launch.loft = a.launch.loft - 10
	a.launch.speed = a.launch.speed * 1.3
	expect.eq(check.throw(at(0.35), a).ok, false, "a speed 30% over")
end)
