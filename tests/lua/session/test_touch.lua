import "session/session"
import "session/json"
tw.web.session.useTune("pointer")
local session, json = tw.web.session, tw.web.json

-- The same piecewise-linear path at two hardware rates. The paint loop can
-- deliver the points singly or together, including down and up in one frame.
local function swipe(hz, forwardTime, opts)
	opts = opts or {}
	local s = session.new { mode = "practice" }
	local points = {}
	local function add(t, x, y, phase)
		points[#points + 1] = { x = x, y = 0.9 + y, t = 83.25 + t, phase = phase }
	end
	local wind = opts.wind or 0.2
	add(0, 0, 0, "down")
	for i = 1, hz / 2 do add(i / hz, 0, wind * i / (hz / 2)) end
	local n = math.floor(forwardTime * hz + 0.5)
	for i = 1, n do
		local x = opts.shake and (i % 2) * 0.03 or 0
		add(0.5 + i / hz, x, wind - (wind + (opts.stop or 0.15)) * i / n,
			i == n and (opts.cancel and "cancel" or "up") or nil)
	end
	if opts.batch then return s:frame { touch = points } end
	for _, p in ipairs(points) do
		local out = s:frame { touch = { p } }
		if out.event then return out end
		expect.eq(s:frame {}.event, nil, "a paint without a sample")
	end
end

test("the same pendulum at 60 and 120 Hz gives the identical launch, even in one paint", function()
	local slowScreen = swipe(60, 1/6)
	local fastScreen = swipe(120, 1/6, { batch = true })
	expect.eq(slowScreen.event, "release")
	expect.eq(json.encode(slowScreen.action), json.encode(fastScreen.action))
	expect.eq(slowScreen.action.input, "touch")
	expect.eq(fastScreen.recording.input, "touch")
	expect.eq(fastScreen.action.swing.back, 120)
	expect.eq(fastScreen.action.swing.stop, 90)
end)

test("a smaller pull stores less power; an easier flick delivers less of it", function()
	local fast = swipe(120, 1/6).action
	local easy = swipe(120, 1/3).action
	local short = swipe(120, 1/8, { wind = 0.12 }).action
	expect.truthy(fast.launch.speed > easy.launch.speed)
	expect.truthy(fast.launch.speed > short.launch.speed)
	expect.eq(fast.swing.stop, easy.swing.stop)
	expect.truthy(swipe(120, 1/6, { stop = 0.08 }).action.launch.loft < fast.launch.loft)
end)

test("a lateral stutter costs steadiness in the core swing", function()
	local straight = swipe(120, 1/6)
	local shaky = swipe(120, 1/6, { shake = true })
	expect.eq(straight.action.verdicts.steady, true)
	expect.eq(shaky.action.verdicts.steady, false)
	expect.truthy(math.abs(shaky.action.launch.tilt) > math.abs(straight.action.launch.tilt))
end)

test("a slow return, a cancelled flick and lifting behind the bottom let down", function()
	for _, out in ipairs { swipe(60, 1), swipe(120, 1/6, { cancel = true }), swipe(120, 1/6, { stop = -0.04 }) } do
		expect.eq(out.event, "letdown")
		expect.eq(out.action, nil)
	end
end)

test("the core releases a sky ball before lift", function()
	local s = session.new { mode = "practice" }
	local out = s:frame { touch = {
		{ phase = "down", t = 0, x = 0, y = 1 },
		{ t = 0.3, x = 0, y = 1.2 }, { t = 0.5, x = 0, y = 0.65 },
	} }
	expect.eq(out.event, "release")
	expect.truthy(out.action.swing.stop >= 180)
	expect.eq(s:frame { touch = { { phase = "up", t = 0.51, x = 0, y = 0.65 } } }.action, nil)
end)
