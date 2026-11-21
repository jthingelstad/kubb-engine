-- Raising by side through the session (0.11.3, switched off): a person raising by hand is
-- offered the engine's advice first, and a raise action with no choice takes it; a
-- person's kubbs raised automatically go up by the advice; the computer's by its level.
-- Switched off, the advice and every level are apart, as in 0.11.2; the tests of the
-- raising as decided (a person par, pro par) switch it on inside the test (decided).
import "session/session"
import "session/json"
import "core/autothrow"
import "core/raising"
tw.web.session.useTune("pointer")
local session, json, autothrow, raising = tw.web.session, tw.web.json, tw.autothrow, tw.raising

local START = { year = 2026, month = 11, day = 21, hour = 12, min = 0 }

-- The raising as Jamie decided it (Q7, owner-2026-11-21#s5), switched on for one test.
local function decided(fn)
	return function()
		local cpu = tw.cpu
		local was, advice = cpu.raising, cpu.advice
		cpu.raising, cpu.advice = { beginner = "first", club = "apart", pro = "par" }, "par"
		local ok, err = pcall(fn)
		cpu.raising, cpu.advice = was, advice
		if not ok then error(err, 0) end
	end
end

local function vsComputer(o)
	local m = { mode = "match", seed = 21, cpu = "B", computer = "pro", start = START, raising = "hand",
		maxTurns = 8 }
	for k, v in pairs(o or {}) do m[k] = v end
	return session.new(m)
end

-- Play the match out; the person's throws are the computer's choice at club, scripted.
-- onRaise(s, n) is called at each raise by hand and returns the action to apply.
local function playOut(s, onRaise)
	local r = autothrow.rng(42)
	for _ = 1, 3000 do
		local n = s:need()
		if n.kind == "over" then return end
		if n.kind == "raise" then
			local a = onRaise and onRaise(s, n)
			if a == nil then a = { type = "raise" } end
			if a then s:apply(a) end
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
			ts.playerX, ts.playerY = c.x, c.y
			s:apply(json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
				stop = c.swing.releaseAngle }))))
		end
	end
	error("the match did not end")
end

test("by hand, switched off: the end offered first is apart's, as in 0.11.2", function()
	local asked = 0
	local s = vsComputer { seed = 21 }
	playOut(s, function(s2, n)
		local g = s2.m.game
		local need = g:need()
		local ctx = g:context(need.side, need.kubb)
		expect.eq(n.default, raising.choose(need.decision, ctx, "apart"), "the default is apart's")
		asked = asked + 1
		return { type = "raise" }
	end)
	expect.truthy(asked > 0, "the person raised by hand")
end)

test("by hand, switched on: the end offered first is par's, and a raise with no choice takes it", decided(function()
	local asked, differ = 0, 0
	for _, seed in ipairs { 21, 22, 23 } do
		local s = vsComputer { seed = seed }
		playOut(s, function(s2, n)
			local g = s2.m.game
			local need = g:need()
			local ctx = g:context(need.side, need.kubb)
			local par = raising.choose(need.decision, ctx, "par")
			local apart = raising.choose(need.decision, ctx, "apart")
			expect.eq(need.side, "A", "only the person raises by hand")
			expect.eq(n.default, par, "the default is par's")
			asked = asked + 1
			if #need.decision.choices > 1 and par ~= apart then differ = differ + 1 end
			return { type = "raise" }
		end)
	end
	expect.truthy(asked > 0, "the person raised by hand")
	expect.truthy(differ > 0, "and par and apart differed at least once (" .. differ .. " of " .. asked .. ")")
end))

test("a raise with no choice stands the kubb on the end offered", function()
	local checked = 0
	local s = vsComputer { seed = 22 }
	playOut(s, function(s2, n)
		local g = s2.m.game
		local need = g:need()
		local c = need.decision.choices[n.default].pose
		local id = need.kubb
		s2:apply { type = "raise" }
		local p = g.kubbs[id].pose
		expect.truthy(p.standing)
		expect.eq(p.x, c.x); expect.eq(p.y, c.y)
		checked = checked + 1
		return false
	end)
	expect.truthy(checked > 0)
end)

test("automatic, switched on: a person's kubbs by par, the computer's by its level; restored the same", decided(function()
	local seen = { A = {}, B = {} }
	local orig = raising.choose
	raising.choose = function(dec, ctx, policy)
		if #dec.choices > 1 then
			local k = type(policy) == "function" and "cpu" or tostring(policy)
			seen[ctx.half][k] = (seen[ctx.half][k] or 0) + 1
		end
		return orig(dec, ctx, policy)
	end
	local ok, err = pcall(function()
		local s = vsComputer { raising = "auto", seed = 23 }
		playOut(s)
		-- a session restored from its snapshot knows which side the computer plays
		local t = session.restore(vsComputer { raising = "auto", seed = 23 }:snapshot())
		expect.eq(tw.match.raisePolicy(t.m, "A"), "par")
		expect.eq(type(tw.match.raisePolicy(t.m, "B")), "function")
	end)
	raising.choose = orig
	assert(ok, err)
	expect.truthy((seen.A.par or 0) > 0, "A, the person, raised by par")
	expect.eq(seen.A.apart, nil, "never apart")
	expect.truthy((seen.B.cpu or 0) > 0, "B, the computer, raised as the computer")
	expect.eq(tw.cpu.raisePolicy("pro"), "par")
end))

test("automatic, switched off: every kubb goes up apart, the person's and the computer's", function()
	local seen = { A = {}, B = {} }
	local orig = raising.choose
	raising.choose = function(dec, ctx, policy)
		if #dec.choices > 1 then
			local name = policy
			if type(policy) == "function" then name = "cpu:" .. tw.cpu.raisePolicy("pro") end
			seen[ctx.half][tostring(name)] = (seen[ctx.half][tostring(name)] or 0) + 1
		end
		return orig(dec, ctx, policy)
	end
	local ok, err = pcall(function() playOut(vsComputer { raising = "auto", seed = 23 }) end)
	raising.choose = orig
	assert(ok, err)
	expect.truthy((seen.A.apart or 0) > 0, "A, the person, raised apart")
	expect.eq(seen.A.par, nil, "never par")
	expect.truthy((seen.B["cpu:apart"] or 0) > 0, "B, the computer at pro, raised apart")
end)
