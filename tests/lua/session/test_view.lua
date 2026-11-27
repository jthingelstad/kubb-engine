-- A view from one side (1.4.0; session/wide "a view from one side", docs/SESSION.md): with
-- setView { side } every output is in that side's frame, the other side's throws come
-- with a camera at the viewer's end, framed at 4, 6 and 8 m on wide and tall boxes, and
-- nothing the match does changes.
import "session/api"
import "session/wide"
import "session/json"
import "core/camera"
import "core/pitch"
tw.web.session.useTune("pointer")
local api, wide, json, camera = tw.web.api, tw.web.wide, tw.web.json, tw.camera

local function call(method, a)
	local r = json.decode(api.call(method, a and json.encode(a) or nil))
	assert(not r.error, r.error)
	return r
end

-- the box a W x H window gives, in the 400 x 240 frame's coordinates (as test_wide's)
local function boxFor(W, H)
	local k = math.min(W / 400, H / 240)
	local ox, oy = (W - 400 * k) / 2, (H - 240 * k) / 2
	local top = (H > W * 1.05) and 132 or 70
	return { left = (16 - ox) / k, right = (W - 16 - ox) / k, top = (top - oy) / k, bottom = (H - 16 - oy) / k }, k
end

local function inside(c, box, x, y, z, what)
	local sx, sy = camera.project(c, x, y, z)
	expect.truthy(sx, what .. " in front of the camera")
	expect.truthy(sx >= box.left - 1e-6 and sx <= box.right + 1e-6 and sy >= box.top - 1e-6 and sy <= box.bottom + 1e-6,
		string.format("%s at %.1f, %.1f in %.1f..%.1f x %.1f..%.1f", what, sx, sy, box.left, box.right, box.top, box.bottom))
end

local START = { year = 2026, month = 11, day = 26, hour = 12, min = 0 }

test("setView: on with a side (and a box), off with {}", function()
	call("new", { mode = "match", cpu = "both", seed = 3, start = START })
	local v = call("setView", { side = "B" })
	expect.eq(v.side, "B")
	expect.eq(v.box.right, camera.tune["end"].box.right, "the default box")
	local b = { left = 0, top = 0, right = 400, bottom = 600 }
	expect.eq(call("setView", { side = "A", box = b }).box.bottom, 600)
	local off = call("setView", {})
	expect.eq(off.side, nil)
	expect.eq(call("view").view, nil, "off: no view field")
end)

test("the other side's throw: from a person's eyes on the viewer's baseline, framed at 4, 6 and 8 m, wide and tall", function()
	for _, wh in ipairs { { 400, 240 }, { 1440, 900 }, { 844, 390 }, { 390, 844 }, { 768, 1024 } } do
		local box, k = boxFor(wh[1], wh[2])
		for _, d in ipairs { 4, 6, 8 } do
			local what = string.format("%dx%d at %d m", wh[1], wh[2], d)
			-- the viewer's frame: its baseline at y = 0, the thrower on the far one
			local aim = { thrower = { x = 0.3, y = 8 }, marker = { x = -0.4, y = 8 - d } }
			local c = wide.endCamera(box, aim)
			expect.eq(c.kind, "end")
			-- (1.4.1) a person's eyes, just behind the middle of the viewer's baseline (the
			-- owner: "It should be like we are standing on the baseline")
			expect.near(c.px, 0, 1e-12, what .. " eyes across")
			expect.truthy(c.py < 0 and c.py >= -1.5, what .. " eyes just behind the line")
			expect.truthy(c.pz >= 1.4 and c.pz <= 1.8, what .. " eyes a person's height")
			inside(c, box, 0.3, 8, 1.2, what .. " thrower")
			inside(c, box, -0.4, 8 - d, 0, what .. " circle")
			inside(c, box, 0, 4, 0.3, what .. " king")
			-- looking down the pitch: nearer is lower and larger
			local _, yNear = camera.project(c, 0, 1.5, 0)
			local _, yFar = camera.project(c, 0, 8, 0)
			expect.truthy(yNear > yFar, what .. ": the viewer's end at the bottom")
			local near = camera.uprightPx(c, 0, 1.5, 0.15) * k
			local far = camera.uprightPx(c, 0, 8, 0.15) * k
			expect.truthy(near >= far, what .. ": near kubbs no smaller than far")
			-- a kubb at the circle, in CSS px: readable on a desktop window
			if wh[1] >= 1280 then
				expect.truthy(camera.uprightPx(c, -0.4, 8 - d, 0.15) * k >= 12, what .. " circle kubb size")
			end
		end
	end
end)

test("a match watched from one end: outputs in that frame, the other side's at the end camera, nothing changes", function()
	local function play(view)
		call("new", { mode = "match", cpu = "both", seed = 7, maxTurns = 6, start = START })
		if view then call("setView", { side = "A" }) else call("setView", {}) end
		local seen = { A = 0, B = 0 }
		local acts = {}
		for _ = 1, 30 do
			local v = call("view")
			local n = v.need
			if n.kind ~= "throw" then break end
			local side = n.side
			if view then
				expect.eq(v.view, "A")
				expect.eq(n.frame, "A")
				if side == "B" then
					expect.truthy(v.aim.thrower.y > 4, "B throws from the far end in A's frame")
					expect.eq(v.camera.kind, "end", "the end camera for B's throw")
					expect.truthy(n.setup.lineY > 4, "B's line turned into A's frame")
				else
					expect.truthy(v.aim.thrower.y < 4, "A throws from its own end")
					expect.truthy(v.camera.kind ~= "end", "A's own camera")
				end
			end
			seen[side] = seen[side] + 1
			local o
			for _ = 1, 900 do
				o = call("frame", { dt = 1 / 30 })
				if o.action then break end
			end
			expect.truthy(o.action, "the computer threw")
			acts[#acts + 1] = json.encode(o.action)
			if view and side == "B" then
				local s0 = call("showAt", { t = 0 })
				expect.eq(s0.camera.kind, "end", "B's recording at the end camera")
				local pid = o.recording.projectile and o.recording.projectile.id
				for _, it in ipairs(s0.items) do
					if it.id == pid then expect.truthy(it.y > 4, "B's baton leaves from the far end") end
				end
				-- (1.4.1) the view follows the throw: the eyes stay, the look turns, and the
				-- baton is in the box while it is over the pitch in front of the eyes
				local dur = o.recording.duration
				local looks = {}
				for i = 0, 20 do
					local s = call("showAt", { t = dur * i / 20 })
					local c = s.camera
					expect.eq(c.kind, "end")
					expect.near(c.px, s0.camera.px, 1e-9, "the same eyes")
					expect.near(c.py, s0.camera.py, 1e-9, "the same eyes")
					expect.near(c.f, s0.camera.f, 1e-9, "the same lens")
					looks[string.format("%.4f %.4f", c.fx, c.fz)] = true
					for _, it in ipairs(s.items) do
						if it.id == pid and math.abs(it.x) < 2.6 and it.y > camera.tune["end"].nearY and it.y < 8.5 then
							inside(c, camera.tune["end"].box, it.x, it.y, it.z or 0, "B's baton at " .. i .. "/20")
						end
					end
				end
				local n = 0
				for _ in pairs(looks) do n = n + 1 end
				expect.truthy(n > 5, "the camera turns with the throw")
			end
			if seen.A >= 2 and seen.B >= 2 then break end
		end
		expect.truthy(seen.B >= 1, "B threw")
		return table.concat(acts, "\n"), json.encode(call("snapshot"))
	end
	local a0, s0 = play(false)
	local a1, s1 = play(true)
	expect.eq(a1, a0, "the same throws with the view on")
	expect.eq(s1, s0, "the same snapshot with the view on")
	call("setView", {})
end)

test("the raise camera (1.4.1): over the lying group, close enough to see a kubb", function()
	-- the owner's picture of build 284: three kubbs just short of the middle line by the left
	-- sideline, on a 402 x 874 phone held upright
	local W, H = 402, 874
	local k = math.min(W / 400, H / 240)
	local ox, oy = (W - 400 * k) / 2, (H - 240 * k) / 2
	local box = { left = (16 - ox) / k, right = (W - 16 - ox) / k, top = (148 - oy) / k, bottom = (H - 34 - 238 - oy) / k }
	local lying = { { -1.86, 3.51 }, { -1.77, 3.56 }, { -1.66, 3.56 } }
	local pts = {}
	for _, p in ipairs(lying) do
		pts[#pts + 1] = { p[1], p[2], 0 }
		pts[#pts + 1] = { p[1] - 0.11, p[2], 0 }
		pts[#pts + 1] = { p[1] + 0.11, p[2], 0 }
	end
	local c = camera.fromEnd(nil, pts, box, "raise")
	expect.eq(c.kind, "raise")
	-- behind the group from the raiser's side, looking down at it
	expect.truthy(c.py < 3.51 and c.pz > 1 and c.pz < 3, "over the group from the raiser's side")
	for _, p in ipairs(lying) do
		inside(c, box, p[1], p[2], 0, "a lying kubb")
		-- a lying kubb's length on the screen (it was about 5 pt in 1.4.0's far camera)
		local x1 = camera.project(c, p[1] - 0.075, p[2], 0.035)
		local x2 = camera.project(c, p[1] + 0.075, p[2], 0.035)
		expect.truthy((x2 - x1) * k >= 25, string.format("a lying kubb %.1f pt long", (x2 - x1) * k))
	end
	-- one kubb alone is not drawn huge: at least `half` m of ground round it
	local one = camera.fromEnd(nil, { { 0.5, 2, 0 } }, box, "raise")
	local a = camera.project(one, 0.5 - camera.tune.raise.half, 2, 0)
	local b = camera.project(one, 0.5 + camera.tune.raise.half, 2, 0)
	expect.truthy(a >= box.left - 1 and b <= box.right + 1, "the ground round a lone kubb shows")
end)

test("needTo: a raise's poses turn, and its camera is made again at the viewer's end", function()
	local n = { kind = "raise", side = "A", pose = { x = 1, y = 2, z = 0.07, qw = 1, qx = 0, qy = 0, qz = 0 },
		lying = { { id = "f1", pose = { x = 1, y = 2, z = 0.07, qw = 1, qx = 0, qy = 0, qz = 0 },
			choices = {}, ends = { { pose = { x = 1.1, y = 2.1, z = 0, qw = 1, qx = 0, qy = 0, qz = 0 } } } } } }
	local o = wide.needTo(n, "B")
	expect.near(o.pose.x, -1, 1e-12)
	expect.near(o.pose.y, 6, 1e-12)
	expect.near(o.lying[1].ends[1].pose.y, 5.9, 1e-12)
	expect.eq(o.frame, "B")
	expect.eq(o.actionFrame, "A")
	expect.eq(o.camera.kind, "end")
	expect.eq(n.pose.x, 1, "the session's need is not changed")
	local same = wide.needTo(n, "A")
	expect.eq(same.pose.x, 1)
	expect.eq(same.frame, "A")
end)

test("cpuPlay through the door with a view: B's recordings come turned, the same steps as without", function()
	local function run(view)
		call("new", { mode = "match", cpu = "both", seed = 5, maxTurns = 3, start = START })
		call("setView", view and { side = "A" } or {})
		return call("cpuPlay", { recordings = true })
	end
	local a, b = run(false), run(true)
	expect.truthy(#a.steps > 0)
	expect.eq(#b.steps, #a.steps)
	local turned = 0
	for i, st in ipairs(b.steps) do
		expect.eq(st.h, a.steps[i].h, "the same hash at step " .. i)
		local l0, l1 = a.steps[i].recording.result, st.recording.result
		if st.side == "B" and l0.landY then
			expect.near(l1.landY, 8 - l0.landY, 1e-9, "B landing in A frame")
			turned = turned + 1
		end
	end
	expect.truthy(turned > 0, "some of B's throws compared")
	expect.eq(b.need.frame, "A")
	call("setView", {})
end)

test("cpuPlay with the wide view: recordings in the world frame, the view at the wide camera", function()
	local function run(on)
		call("new", { mode = "match", cpu = "both", seed = 5, maxTurns = 3, start = START })
		call("setView", {})
		if on then call("setWide", { box = { left = 0, top = 0, right = 400, bottom = 240 } })
		else call("setWide", {}) end
		return call("cpuPlay", { recordings = true })
	end
	local a, b = run(false), run(true)
	local wcam = call("setWide", { box = { left = 0, top = 0, right = 400, bottom = 240 } }).camera
	expect.eq(#b.steps, #a.steps)
	local turned = 0
	for i, st in ipairs(b.steps) do
		local l0, l1 = a.steps[i].recording.result, st.recording.result
		if st.side == "B" and l0.landY then
			expect.near(l1.landY, 8 - l0.landY, 1e-9, "B landing in the world frame")
			turned = turned + 1
		elseif l0.landY then
			expect.near(l1.landY, l0.landY, 1e-12, "A's as it was")
		end
	end
	expect.truthy(turned > 0)
	expect.truthy(b.view and b.view.camera, "cpuPlay gives the view")
	expect.eq(json.encode(b.view.camera), json.encode(wcam), "the wide camera")
	call("setWide", {})
end)
