-- The computer's turn, fast (1.4.0): Session:cpuPlay plays every computer throw until a
-- person is needed, with no frames, and ends exactly where a watched turn does.
import "session/session"
import "session/json"
import "core/autothrow"
tw.web.session.useTune("pointer")
local session, json = tw.web.session, tw.web.json
local START = { year = 2026, month = 11, day = 26, hour = 12, min = 0 }

-- A watched computer throw: frames until it releases.
local function watched(s)
	for _ = 1, 5000 do
		local o = s:frame { dt = 1 / 60 }
		if o.action then return o.action end
	end
	error("the computer never threw")
end

test("computer against computer: cpuPlay is the watched match, action for action, hash for hash", function()
	local a = session.new { mode = "match", seed = 17, start = START, cpu = "both", maxTurns = 6 }
	local b = session.restore(a:snapshot())
	local log = {}
	while a:need().kind == "throw" do
		local act = watched(a)
		log[#log + 1] = { a = json.encode(act), h = a:hash() }
	end
	local r = b:cpuPlay()
	expect.eq(#r.steps, #log)
	for i, st in ipairs(r.steps) do
		expect.eq(json.encode(st.a), log[i].a)
		expect.eq(st.h, log[i].h)
	end
	expect.eq(b:hash(), a:hash())
	expect.eq(r.need.kind, a:need().kind)
end)

test("against a person: cpuPlay stops at the person's throw (or their raise), and does nothing then", function()
	local s = session.new { mode = "match", seed = 2, start = START, cpu = "B", first = "B" }
	expect.truthy(s:need().cpu)
	local w = session.restore(s:snapshot())
	local r = s:cpuPlay()
	expect.truthy(#r.steps >= 1)
	expect.truthy(r.need.kind ~= "throw" or not r.need.cpu)
	for _, st in ipairs(r.steps) do
		local act = watched(w)
		expect.eq(json.encode(act), json.encode(st.a))
		expect.eq(w:hash(), st.h)
		expect.eq(st.side, "B")
	end
	expect.eq(#s:cpuPlay().steps, 0)
	-- a client that does not throw for the computer plays nothing
	local other = session.restore(w:snapshot(), { sides = { "A" }, cpu = false })
	expect.eq(#other:cpuPlay().steps, 0)
end)
