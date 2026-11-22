-- A match's length (0.17.0): no throw carried a time, so every match lasted 0 minutes. A
-- host now passes `at` to frame (and cpuAction) and on a raise or punish action; the
-- engine puts it on the action it makes, every client applying the action gets the same
-- finish, and a match no action stamped has no End or Duration line and no minutes.
import "session/session"
import "session/json"
import "session/check"
import "core/autothrow"
import "session/api"
tw.web.session.useTune("pointer")
local function call(method, a) return tw.web.json.decode(kubbCall(method, tw.web.json.encode(a))) end
local session, json, check, autothrow = tw.web.session, tw.web.json, tw.web.check, tw.autothrow

local START = { year = 2026, month = 11, day = 22, hour = 9, min = 0 }
local function clockAt(minutes)
	local h = 9 + minutes // 60
	return { year = 2026, month = 11, day = 22, hour = h, min = minutes % 60 }
end

-- Play a computer-against-computer match by frames; stamp(n) gives each frame's `at` (or
-- nil). Returns the session, the log of actions (through JSON) and the over need.
local function playOut(o, stamp)
	local m = { mode = "match", seed = 5, cpu = "both", start = START, maxTurns = 6, raising = "auto" }
	for k, v in pairs(o or {}) do m[k] = v end
	local s = session.new(m)
	local start = s:snapshot()
	local log, frames = {}, 0
	for _ = 1, 400000 do
		local n = s:need()
		if n.kind == "over" then return s, log, n, start end
		frames = frames + 1
		local f = s:frame { dt = 1 / 30, at = stamp and stamp(frames, #log) or nil }
		if f.action then log[#log + 1] = json.decode(json.encode(f.action)) end
	end
	error("the match did not end")
end

test("stamps: no stamp, no finish: no End or Duration line and no minutes", function()
	local s, log, over = playOut()
	for _, a in ipairs(log) do expect.eq(a.at, nil, "no action carries a stamp") end
	expect.truthy(not over.file.text:find("Duration", 1, true), "no Duration line")
	expect.truthy(not over.file.text:find("%[End "), "no End line")
	expect.eq(s.overInfo.winner.minutes, nil, "no minutes")
end)

test("stamps: frame puts the host's at on the action; a replica applying the log has the same finish", function()
	local s, log, over, start = playOut(nil, function(_, k) return clockAt(2 * k) end)
	local last = log[#log]
	expect.truthy(last.at and last.at.hour >= 9, "the action carries the stamp")
	local mins = s.overInfo.winner.minutes
	expect.eq(mins, 2 * (#log - 1), "the last stamp is the finish")
	expect.truthy(over.file.text:find("[Duration \"" .. mins .. "m\"]", 1, true), "the Duration line")
	-- another client: the same start, the same log, through apply
	local c = session.restore(start)
	for _, a in ipairs(log) do
		if c:need().kind == "over" then break end
		if a.type == "throw" then c:apply(a) end
		-- (the computer's own raises are the engine's; nothing to apply)
		while c:need().kind ~= "throw" and c:need().kind ~= "over" do c:frame { dt = 1 / 30 } end
	end
	expect.eq(c:need().kind, "over")
	expect.eq(c.overInfo.winner.minutes, mins, "the same minutes")
	expect.eq(c:need().file.text, over.file.text, "the same file")
	expect.eq(c:hash(), s:hash(), "the same match")
end)

test("stamps: a stamp is not part of what checkThrow compares, and a bad one is no stamp", function()
	local s = session.new { mode = "match", seed = 5, cpu = "both", start = START, maxTurns = 6 }
	local a = s:cpuAction(clockAt(7))
	expect.eq(a.at.min, 7)
	expect.truthy(check.throw(s, a).ok, "the computer's throw with a stamp is its throw")
	local b = s:cpuAction({ year = 2026, month = "11" })
	expect.eq(b.at, nil, "a stamp that is not whole numbers is dropped")
	local c = s:cpuAction()
	expect.eq(c.at, nil)
	expect.truthy(session.stampOf(clockAt(61)).hour == 10)
end)

test("stamps: a raise and a punishment kubb by hand carry the host's stamp", function()
	local s = session.new { mode = "match", seed = 31, cpu = "B", start = START, maxTurns = 6, raising = "hand",
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer" } } } } }
	local r = autothrow.rng(3)
	local raised = false
	for _ = 1, 4000 do
		local n = s:need()
		if n.kind == "over" or raised then break end
		if n.kind == "raise" then
			s:apply { type = "raise", at = clockAt(33) }
			expect.eq(s.finish.min, 33, "the raise's stamp is the finish so far")
			raised = true
		elseif n.kind == "punish" then
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y, at = clockAt(34) }
		elseif n.cpu then
			for _ = 1, 2000 do if s:frame { dt = 1 / 30 }.action then break end end
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
	expect.truthy(raised, "a person raised by hand")
end)

test("stamps: the start's utcOffset is kept, round-trips, and moves a hash only when given", function()
	local function new(start)
		return session.new { mode = "match", seed = 5, cpu = "both", start = start, maxTurns = 6 }
	end
	local plain = new { year = 2026, month = 11, day = 22, hour = 9, min = 0 }
	local snap = json.decode(plain:snapshot())
	expect.eq(snap.opts.start.utcOffset, nil, "absent stays absent")
	local off = new { year = 2026, month = 11, day = 22, hour = 9, min = 0, utcOffset = -360 }
	expect.eq(off.opts.start.utcOffset, -360)
	expect.truthy(off:hash() ~= plain:hash(), "a new match that gives it has other hashes")
	local back = session.restore(off:snapshot())
	expect.eq(back.opts.start.utcOffset, -360, "through the snapshot")
	expect.eq(back:hash(), off:hash())
	expect.eq(call("names.check", { snap = off:snapshot() }).allowed, true, "names.check allows it")
	local bad = new { year = 2026, month = 11, day = 22, hour = 9, min = 0, utcOffset = "UTC-6" }
	expect.eq(bad.opts.start.utcOffset, nil, "not whole minutes: dropped")
	expect.eq(bad:hash(), plain:hash())
end)

test("stamps: a stamp before the start is no finish", function()
	local s, log, over = playOut(nil, function() return { year = 2026, month = 11, day = 22, hour = 8, min = 0 } end)
	expect.eq(s.overInfo.winner.minutes, nil)
	expect.truthy(not over.file.text:find("Duration", 1, true))
end)
