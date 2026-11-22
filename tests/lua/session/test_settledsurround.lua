-- The surroundings of what the engine raised and placed (0.17.0): each setup.settled
-- entry's `others` and `king`, in the raiser's view frame as the pieces stood while it was
-- done, are what raiseInfo (or punishInfo) gives a person raising (or placing) the same
-- kubbs by hand. Output only: nothing in a snapshot or a hash.
import "session/session"
import "session/json"
import "session/wide"
import "core/autothrow"
import "core/frame"
tw.web.session.useTune("pointer")
local session, json, autothrow, frame, wide = tw.web.session, tw.web.json, tw.autothrow, tw.frame, tw.web.wide

local START = { year = 2026, month = 11, day = 22, hour = 12, min = 0 }

local function personThrow(s, r, wild)
	local ts = s.ts
	local c = autothrow.choose(s.setup, r, 1)
	tw.web.throw.showAim(ts, c)
	local L, how = tw.web.throw.cpuLaunch(ts, c)
	if wild and s.setup.projectile == "kubb" then L.swivel = L.swivel + 1.2 end
	ts.playerX, ts.playerY = c.x, c.y
	s:apply(json.decode(json.encode(s:throwAction(L, how, { scripted = true, back = c.swing.back,
		stop = c.swing.releaseAngle }))))
end

-- Plays until stop(s, need) is true (returns true then), or the end (false).
local function playUntil(s, stop, wild)
	local r = autothrow.rng(7)
	for _ = 1, 4000 do
		local n = s:need()
		if n.kind == "over" then return false end
		if stop(s, n) then return true end
		if n.kind == "raise" then
			s:apply { type = "raise" }
		elseif n.kind == "punish" then
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		elseif n.cpu then
			for _ = 1, 2000 do if s:frame { dt = 1 / 30 }.action then break end end
		else
			personThrow(s, r, wild)
		end
	end
	return false
end

local function samePose(a, b, what)
	expect.near(a.x, b.x, 1e-12, what .. " x")
	expect.near(a.y, b.y, 1e-12, what .. " y")
	expect.near(a.angle or 0, b.angle or 0, 1e-12, what .. " angle")
	expect.eq(a.standing, b.standing, what .. " standing")
end

local function sameOthers(got, want, what)
	expect.eq(#got, #want, what .. ": as many others")
	for i, w in ipairs(want) do
		expect.eq(got[i].id, w.id, what .. " other " .. i)
		samePose(got[i].pose, w.pose, what .. " " .. w.id)
	end
end

-- A person's side raising (and placing) by hand at the first chance after `from`
-- settles; the same snapshot restored with Raising: Automatic, where the engine does it
-- and hands it out. Their surroundings must agree, entry by entry.
local function compare(o, wild, want)
	local s = session.new(o)
	local found = playUntil(s, function(_, n)
		if want then return n.kind == want end
		return n.kind == "raise" or n.kind == "punish"
	end, wild)
	expect.truthy(found, "a settle by hand")
	local snap = s:snapshot()
	local byHand = {}
	while true do
		local n = s:need()
		if n.kind == "raise" then
			local info = s:raiseInfo()
			byHand[#byHand + 1] = { kind = "raise", side = n.side, kubb = n.kubb, others = info.others, king = info.king }
			s:apply { type = "raise" }
		elseif n.kind == "punish" then
			local info = s:punishInfo()
			local king
			for _, k in ipairs(info.keepOut) do if k.kind == "king" then king = k end end
			byHand[#byHand + 1] = { kind = "punish", side = n.side, kubb = n.kubb, others = info.others, king = king }
			s:apply { type = "punish", x = n.cursor.x, y = n.cursor.y }
		else
			break
		end
	end
	local d = json.decode(snap, true)
	d.opts.raising = "auto"
	local a = session.restore(json.encode(d))
	local n = a:need()
	expect.eq(n.kind, "throw")
	local list = n.setup.settled and n.setup.settled.list or {}
	expect.eq(#list, #byHand, "the engine did what the person did")
	for i, e in ipairs(list) do
		local h = byHand[i]
		expect.eq(e.kind, h.kind); expect.eq(e.id, h.kubb); expect.eq(e.side, h.side)
		sameOthers(e.others, h.others, e.kind .. " " .. e.id)
		if e.kind == "raise" then samePose(e.king, h.king, "the king")
		else expect.near(e.king.x, h.king.x, 1e-12); expect.near(e.king.y, h.king.y, 1e-12) end
	end
	return list, a, n
end

local function person(side)
	local t = {}
	t[side] = { name = "Ada", players = { { name = "Ada", level = "club", key = "m1" } } }
	return t
end

test("surroundings: Team A raising, as raiseInfo gives a person the same kubbs", function()
	local list = compare({ mode = "match", seed = 31, cpu = "B", raising = "hand", start = START, maxTurns = 14,
		teams = person("A") })
	expect.truthy(#list > 0)
	for _, e in ipairs(list) do expect.eq(e.side, "A") end
end)

test("surroundings: Team B raising", function()
	local list = compare({ mode = "match", seed = 32, cpu = "A", raising = "hand", start = START, maxTurns = 14,
		teams = person("B") })
	expect.truthy(#list > 0)
	for _, e in ipairs(list) do expect.eq(e.side, "B") end
end)

test("surroundings: a punishment kubb, as punishInfo gives it", function()
	-- pass and play, every kubb thrown wide, so a person places the punishment kubb
	local list = compare({ mode = "match", seed = 41, raising = "hand", start = START, maxTurns = 10,
		teams = { A = { players = { "Mighty Maple" } }, B = { players = { "Quiet Juniper" } } } }, true, "punish")
	local p = 0
	for _, e in ipairs(list) do if e.kind == "punish" then p = p + 1 end end
	expect.truthy(p > 0, "a punishment kubb among them")
end)

test("surroundings: a later raise sees the earlier one standing; the wide view turns them", function()
	local list, a, n = compare({ mode = "match", seed = 31, cpu = "B", raising = "hand", start = START, maxTurns = 14,
		teams = person("A") })
	if #list >= 2 then
		local first = list[1]
		local seenStanding = false
		for _, o in ipairs(list[2].others) do
			if o.id == first.id then
				samePose(o.pose, first.standing, "the first raised kubb, standing, among the second's others")
				seenStanding = true
			end
		end
		expect.truthy(seenStanding)
	end
	local r = wide.out({ need = json.decode(json.encode(n)) }, { kind = "side" }, a.frameSide, a.frameSide)
	for i, e in ipairs(r.need.setup.settled.list) do
		local v = list[i]
		expect.eq(e.frame, "world")
		samePose(e.king, frame.pose(v.side, v.king), "the king, world")
		for j, o in ipairs(e.others) do samePose(o.pose, frame.pose(v.side, v.others[j].pose), "other, world") end
	end
	-- and a restore after hands out none, as before
	local c = session.restore(a:snapshot())
	expect.eq(c:need().setup.settled, nil)
end)

test("surroundings: a team of computers raising in a mixed match", function()
	local s = session.new { mode = "match", seed = 31, raising = "hand", start = START, maxTurns = 14, teams = {
		A = { players = { { name = "Mighty Maple" }, { cpu = true, level = "pro" } } },
		B = { players = { { cpu = true, level = "beginner" }, { cpu = true, level = "pro" } } } } }
	local checked = 0
	playUntil(s, function(s2, n)
		if n.kind ~= "throw" or not n.setup.settled then return false end
		-- rebuilt from the game as it stands: the pitch now, each later kubb back where it lay
		local list = n.setup.settled.list
		for k, e in ipairs(list) do
			if e.kind == "raise" and e.side == "B" then
				local later = {}
				for j = k + 1, #list do
					if list[j].kind == "raise" then later[list[j].id] = frame.pose(e.side, list[j].lying)
					else later[list[j].id] = false end
				end
				local want = {}
				for _, p in ipairs(s2.m.game:onPitch()) do
					if p.id ~= e.id and later[p.id] ~= false then
						local pose = later[p.id] or p.pose
						want[#want + 1] = { id = p.id, pose = frame.pose(e.side, { x = pose.x, y = pose.y,
							standing = pose.standing and true or false, angle = pose.angle or 0 }) }
					end
				end
				sameOthers(e.others, want, "B's raise " .. e.id)
				samePose(e.king, frame.pose(e.side, s2.m.game.king.pose), "the king")
				checked = checked + 1
			end
		end
		return false
	end)
	expect.truthy(checked > 0, "the computers' team raised and was handed out: " .. checked)
end)
