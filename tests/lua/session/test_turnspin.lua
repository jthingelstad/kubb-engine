-- A kubb's spin is a turn setting (Jamie, 2026-11-20: "Keep between throws"): the spin a
-- person threw a kubb with stays for the rest of that side's kubbs in the inkast turn,
-- and goes back to none when the turn ends, the side changes or a match starts. Arc and
-- tilt are throw settings: back to the plan's own at every throw.
import "session/session"
import "session/json"
import "session/check"
import "core/autothrow"
tw.web.session.useTune("pointer")
local session, json, throw, autothrow, check = tw.web.session, tw.web.json, tw.web.throw, tw.autothrow,
	tw.web.check

local START = { year = 2026, month = 11, day = 20, hour = 10, min = 0 }

local function sweep(from, to, dps)
	local out, dt = {}, 1 / 60
	local step = dps * dt * ((to > from) and 1 or -1)
	local a = from
	while (step > 0 and a < to) or (step < 0 and a > to) do
		a = a + step
		if (step > 0 and a > to) or (step < 0 and a < to) then a = to end
		out[#out + 1] = a
	end
	return out
end

-- A person's throw on the dial, at the plan's power and release.
local function dialThrow(s)
	local sol = s.ts.sol
	local back = (sol.powerLo + sol.powerHi) / 2
	local arms = { 0, -5 }
	for _, a in ipairs(sweep(-5, -back, 400)) do arms[#arms + 1] = a end
	for _, a in ipairs(sweep(-back, sol.release, 2400)) do arms[#arms + 1] = a end
	for _ = 1, 6 do arms[#arms + 1] = sol.release end
	for _, a in ipairs(arms) do
		local o = s:frame { dt = 1 / 60, arm = a }
		if o.action then return o end
	end
	error("no release")
end

-- The computer's choice thrown as a scripted action (its batons knock kubbs down, so
-- there are kubbs to throw in).
local function scripted(s, r)
	local ts = s.ts
	local a = autothrow.choose(s.setup, r, 1)
	throw.showAim(ts, a)
	local L, how = throw.cpuLaunch(ts, a)
	ts.playerX, ts.playerY = a.x, a.y
	local act = s:throwAction(L, how, { scripted = true, back = a.swing.back, stop = a.swing.releaseAngle })
	return s:apply(json.decode(json.encode(act)))
end

-- Settle by hand where asked (the default choice, the cursor).
local function settle(s)
	local n = s:need()
	if n.kind == "raise" then s:apply { type = "raise" } return true end
	if n.kind == "punish" then
		s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		return true
	end
	return false
end

-- Play scripted throws until a person's side has two kubbs or more to throw in.
local function toInkast(s, r)
	for _ = 1, 400 do
		if not settle(s) then
			local n = s:need()
			if n.kind == "over" then return nil end
			if n.kind == "throw" and not n.cpu and n.setup.projectile == "kubb" and n.setup.n == 1
				and n.setup.of >= 2 then
				return n
			end
			if n.cpu then
				for _ = 1, 600 do if s:frame({ dt = 1 / 30 }).action then break end end
			else
				scripted(s, r)
			end
		end
	end
	return nil
end

-- A match (seed upward) whose person side comes to an inkast of two kubbs or more.
local function matchAtInkast(cpu)
	for seed = 1, 40 do
		local s = session.new { mode = "match", seed = seed, cpu = cpu, start = START, raising = "auto",
			teams = { A = { name = "North", players = { { name = "Alex" } } }, B = { name = "South",
				players = { { name = "Sam" } } } } }
		local r = autothrow.rng(500 + seed)
		local n = toInkast(s, r)
		if n then return s, n, r end
	end
	error("no inkast in 40 seeds")
end

test("a kubb's spin stays for the side's next kubb; arc and tilt do not", function()
	local s, n = matchAtInkast("B")
	local side = n.side
	expect.eq(s.ts.spin, 0, "the first kubb starts with no spin")
	s:stepSide(1)
	s:stepSide(1)
	s:stepArc(1)
	expect.eq(s.ts.spin, 2)
	expect.eq(s.ts.arcSet, true)
	local o = dialThrow(s)
	expect.eq(o.action.plan.spin, 2.0, "the action names the planned spin")
	expect.near(o.action.launch.spin, 2 * tw.plan.tune.spinPerStep + tw.drill.tune.spiral, 1e-9)
	local n2 = s:need()
	expect.eq(n2.kind, "throw")
	expect.eq(n2.side, side)
	expect.eq(n2.setup.projectile, "kubb")
	expect.eq(s.ts.spin, 2.0, "kept for the next kubb")
	expect.eq(s.ts.arcSet, false, "the arc is the plan's own again")
	expect.eq(s:view().aim.plan.spin, 2.0, "the view shows the kept spin")
	-- the snapshot carries it, so a restore (a late joiner, a reload) has it too
	local snap = s:snapshot()
	expect.truthy(snap:find('"keptSpin":2.0', 1, true), "in the aim memory")
	local r = session.restore(snap)
	expect.eq(r:snapshot(), snap)
	expect.eq(r.ts.spin, 2.0, "restored with the kept spin")
	-- changing it on this kubb changes what is kept
	s:stepSide(-1)
	dialThrow(s)
	local n3 = s:need()
	if n3.kind == "throw" and n3.side == side and n3.setup.projectile == "kubb" then
		expect.eq(s.ts.spin, 1.0, "the last kubb's spin is kept")
	end
end)

test("the kept spin goes when the side's inkast turn ends, and a new match has none", function()
	local s, n, r = matchAtInkast("B")
	local side = n.side
	s:stepSide(3)
	dialThrow(s)
	-- the rest of the turn: kubbs (kept), then batons (none), then the computer
	local sawBaton, sawOther = false, false
	for _ = 1, 400 do
		if not settle(s) then
			local m = s:need()
			if m.kind == "over" then break end
			if m.cpu then
				sawOther = true
				for _ = 1, 600 do if s:frame({ dt = 1 / 30 }).action then break end end
			elseif m.setup.projectile == "kubb" then
				if sawBaton or sawOther then
					-- the side's next inkast turn: from none
					expect.eq(s.ts.spin, 0, "a new inkast turn starts with no spin")
					expect.eq(s.ts.keptSpin, nil)
					break
				end
				expect.eq(s.ts.spin, 3.0, "kept within the turn (rethrows too)")
				dialThrow(s)
			else
				sawBaton = true
				expect.eq(s.ts.keptSpin, nil, "a baton ends the kubbs' turn")
				expect.eq(s.ts.tilt, 0)
				scripted(s, r)
			end
		end
	end
	expect.truthy(sawBaton, "the turn went on to batons")
	local fresh = session.new { mode = "match", seed = 1, start = START }
	expect.eq(fresh.ts.spin, 0)
	expect.eq(fresh.ts.keptSpin, nil)
end)

test("the side changes: the other side's kubbs start from none", function()
	-- pass and play: both sides are people
	local s, n, r = matchAtInkast({})
	local side = n.side
	s:stepSide(2)
	for _ = 1, 400 do
		if not settle(s) then
			local m = s:need()
			if m.kind == "over" then break end
			if m.setup.projectile == "kubb" and m.side == side then
				dialThrow(s)
			elseif m.setup.projectile == "kubb" then
				expect.eq(s.ts.spin, 0, "the other side's kubbs start with no spin")
				return
			else
				scripted(s, r)
			end
		end
	end
end)

test("another client applying the actions holds the same kept spin and hash", function()
	local s, n = matchAtInkast("B")
	local other = session.restore(s:snapshot())
	other:setControl { sides = {}, cpu = false }
	s:stepSide(-2)
	local o = dialThrow(s)
	other:apply(o.action)
	expect.eq(other:hash().hash, s:hash().hash, "the same hash")
	expect.eq(other.ts.keptSpin, s.ts.keptSpin)
	expect.eq(other.ts.spin, -2.0)
end)

test("the computer's throws are its own whatever a person's kept spin", function()
	local s = matchAtInkast("B")
	s:stepSide(3)
	dialThrow(s)
	for _ = 1, 400 do
		if not settle(s) then
			local m = s:need()
			if m.kind == "over" then break end
			if m.cpu then
				local want = check.cpuAction(s)
				local got
				for _ = 1, 600 do
					local f = s:frame({ dt = 1 / 30 })
					if f.action then got = f.action break end
				end
				expect.truthy(check.same(got, want), "the computer's action")
				expect.eq(got.plan, nil, "a computer's throw has no plan")
				if m.setup.projectile == "kubb" then return end
			elseif m.setup.projectile == "kubb" then
				dialThrow(s)
			else
				scripted(s, autothrow.rng(9))
			end
		end
	end
end)

test("practice: KUBBS on keeps the spin until reset or batons", function()
	local s = session.new { mode = "practice", drill = true }
	s:stepSide(2)
	dialThrow(s)
	expect.eq(s.ts.spin, 2, "kept from throw to throw")
	s:reset()
	expect.eq(s.ts.spin, 0, "reset: none")
	s:stepSide(1)
	s:setDrill(false)
	expect.eq(s.ts.spin, 0, "batons: none")
	s:setDrill(true)
	expect.eq(s.ts.spin, 0)
end)
