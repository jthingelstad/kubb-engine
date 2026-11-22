-- The log budget's measure (pitch/lobby.lua docSize, 0.7.3): a replay that commits a whole
-- match in one pass keeps each log entry's size instead of encoding the whole document
-- again on every action. Two clients on 0.7.2 and 0.7.3 commit the same document, so the
-- number must be js.asciiSize(l) itself, at every action: here every commit made with
-- sizes is made again the 0.7.2 way (js.asciiSize of the whole document), and the two
-- sizes and the two documents must be the same. Matches: the computer's throws on both
-- sides (natural matches), two long matches of short throws whose length the turn limit
-- sets (one ending just under LOG_BUDGET, one crossing it, so the drop happens), and
-- every commitAction step of the pitch's vectors.
import "session/session"
import "session/json"
import "session/replay"
import "session/api"
import "pitch/lobby"
import "pitch/js"
tw.web.session.useTune("pointer") -- the web's tune
local session, json, replay, lobby, js = tw.web.session, tw.web.json, tw.web.replay, tw.pitch.lobby, tw.pitch.js
local NULL = json.null

local START = { year = 2026, month = 11, day = 19, hour = 9, min = 0 }
local BUDGET = lobby.LOG_BUDGET

-- ---------- every sized commit checked against the 0.7.2 measure ----------

local realCommit, realSize = lobby.commitAction, lobby.docSize
local stats, lastSize

-- Without sizes: 0.7.2's measure, js.asciiSize of the whole document, called directly.
lobby.docSize = function(l, sizes)
	local v
	if sizes then v = realSize(l, sizes) else v = js.asciiSize(l) end
	lastSize = v
	return v
end

local function sameText(x, y) return js.text(x) == js.text(y) end

-- The two documents are the same: every key, the log entry by entry.
local function sameDoc(x, y, at)
	if x == nil or y == nil then
		expect.eq(x == nil, y == nil, at .. ": both refused or neither")
		return
	end
	for _, d in ipairs { { x, y }, { y, x } } do
		for k in pairs(d[1]) do
			if k ~= "match" then expect.truthy(sameText(d[1][k], d[2][k]), at .. ": key " .. k) end
		end
	end
	local mx, my = x.match, y.match
	if not js.isTable(mx) or not js.isTable(my) then
		expect.truthy(sameText(mx, my), at .. ": match")
		return
	end
	for _, d in ipairs { { mx, my }, { my, mx } } do
		for k in pairs(d[1]) do
			if k ~= "log" then expect.truthy(sameText(d[1][k], d[2][k]), at .. ": match." .. k) end
		end
	end
	local lx, ly = mx.log, my.log
	if not js.isArray(lx) or not js.isArray(ly) then
		expect.truthy(sameText(lx, ly), at .. ": log")
		return
	end
	expect.eq(#lx, #ly, at .. ": log length")
	for i = 1, #lx do
		expect.truthy(rawequal(lx[i].a, ly[i].a) or sameText(lx[i].a, ly[i].a), at .. ": entry " .. i)
		expect.eq(lx[i].h, ly[i].h, at .. ": entry " .. i .. " hash")
	end
end

lobby.commitAction = function(doc, a, sizes)
	if not sizes or not stats then return realCommit(doc, a, sizes) end
	local at = stats.name .. " seq " .. tostring(a.seq)
	lastSize = nil
	local was = realCommit(doc, a) -- 0.7.2
	local old = lastSize
	lastSize = nil
	local now = realCommit(doc, a, sizes)
	local new = lastSize
	expect.eq(new, old, at .. ": the measure")
	sameDoc(now, was, at)
	stats.commits = stats.commits + 1
	if old then
		stats.measured = stats.measured + 1
		if old > BUDGET then
			expect.eq(now.match.log, NULL, at .. ": dropped past the budget")
			stats.drops[#stats.drops + 1] = a.seq
		else
			stats.maxKept = math.max(stats.maxKept, old)
			stats.lastKept = old
		end
	end
	return now
end

local total = { commits = 0, measured = 0 }
local function begin(name)
	stats = { name = name, commits = 0, measured = 0, drops = {}, maxKept = 0 }
	return stats
end
local function finish()
	total.commits, total.measured = total.commits + stats.commits, total.measured + stats.measured
	local s = stats
	stats = nil
	return s
end

-- ---------- matches ----------

-- A match against the computer (side B) where side A's throws are the computer's too
-- (made from the snapshot as if A were the computer), raising and punishment by the
-- computer's default. `scale` multiplies every throw's speed: 0.3 lands every baton
-- short, nothing falls, and the turn limit ends the match (about six actions a turn).
local function play(seed, maxTurns, scale)
	local s = session.new { mode = "match", seed = seed, cpu = "B", start = START, raising = "hand",
		maxTurns = maxTurns, wind = ({ "off", "light", "strong" })[seed % 3 + 1],
		surface = ({ "grass", "sand", "snow" })[seed % 3 + 1],
		teams = { A = { name = "Ada", players = { { name = "Ada", level = "beginner", key = "m1" } } },
			B = { name = "Computer", players = { { name = "Computer", level = "beginner" } } } } }
	local start = s:snapshot()
	local log = {}
	while s:need().kind ~= "over" do
		assert(#log < 5000, "the match ends")
		local n = s:need()
		local a
		if n.kind == "throw" then
			local d = json.decode(s:snapshot())
			d.opts.cpu = { "A", "B" }
			a = session.restore(json.encode(d), replay.NOBODY):cpuAction()
			if scale then a.launch.speed = a.launch.speed * scale end
		elseif n.kind == "raise" then
			a = { type = "raise" }
		else
			a = { type = "punish", x = n.cursor.x, y = n.cursor.y }
		end
		local r = s:apply(a)
		assert(r.ok ~= false, "the action applies")
		log[#log + 1] = { a = json.decode(json.encode(a)) }
	end
	return start, log
end

-- The match replayed with its document (session/replay.lua passes its sizes), every
-- commit checked.
local function replayed(name, seed, maxTurns, scale)
	local start, log = play(seed, maxTurns, scale)
	begin(name)
	local r = replay.new { start = start, log = log, document = true }
	local info = r:finish()
	expect.eq(info.differs, false, name .. ": the replay keeps step")
	expect.eq(info.over, true, name .. ": over")
	local doc = assert(r:document())
	local s = finish()
	expect.eq(s.commits, #log, name .. ": every action committed")
	return s, doc, #log
end

test("natural matches: the measure is 0.7.2's at every action", function()
	for _, seed in ipairs { 8, 11 } do
		local s, doc, n = replayed("natural " .. seed, seed, 200)
		expect.eq(s.measured, n, "every action measured")
		expect.eq(#s.drops, 0)
		expect.truthy(lobby.replayOf(doc.match), "the replay kept")
	end
end)

test("a match that ends just under LOG_BUDGET keeps its log, measured exactly", function()
	local s, doc, n = replayed("just under", 5, 95, 0.3)
	expect.truthy(n > 500, "a long match: " .. n)
	expect.eq(s.measured, n, "every action measured")
	expect.eq(#s.drops, 0, "never dropped")
	expect.truthy(s.maxKept > 0.97 * BUDGET, "just under: " .. s.maxKept .. " of " .. BUDGET)
	expect.eq(#doc.match.log, n, "the whole log kept")
	expect.truthy(lobby.replayOf(doc.match), "the replay kept")
end)

test("a match that crosses LOG_BUDGET drops its log at the same action as 0.7.2", function()
	local s, doc, n = replayed("crossing", 5, 100, 0.3)
	expect.eq(#s.drops, 1, "dropped once")
	local at = s.drops[1]
	expect.eq(s.measured, at, "measured up to the drop, never after")
	expect.truthy(at < n, "actions after the drop: " .. at .. " of " .. n)
	expect.truthy(s.lastKept > 0.99 * BUDGET, "the action before was just under: " .. tostring(s.lastKept))
	expect.eq(doc.match.log, NULL, "no log")
	expect.eq(lobby.replayOf(doc.match), nil, "no replay")
end)

test("the pitch's vectors: every commitAction with sizes is 0.7.2's", function()
	local DIR = "tests/pitch/vectors/"
	local function read(path)
		local f = assert(io.open(path, "rb"))
		local t = f:read("a")
		f:close()
		return t
	end
	local function subst(v, doc)
		if v == "$doc" then return doc end
		if v == "$match" then return (js.isTable(doc) and doc.match) or NULL end
		if v == "$engine" then return tw.engine.version end
		if type(v) ~= "table" or rawequal(v, NULL) then return v end
		local out = setmetatable({}, getmetatable(v))
		for k, x in pairs(v) do out[k] = subst(x, doc) end
		return out
	end
	local index = json.decode(read(DIR .. "index.json"), true)
	local commits = 0
	for _, file in ipairs(index.scenarios) do
		local sc = json.decode(read(DIR .. file), true)
		local doc = sc.start
		local sizes = {}
		begin(file)
		for _, step in ipairs(sc.steps) do
			local args = subst(step.args, doc)
			local res = json.decode(kubbCall("pitch." .. step.call, json.encode(args)), true)
			if step.call == "commitAction" then
				lobby.commitAction(args.doc, { n = args.n, seq = args.seq, snap = args.snap, hash = args.hash,
					action = args.action, over = args.over }, sizes)
			end
			if step.keep and not rawequal(res.value, NULL) then doc = res.value end
		end
		commits = commits + finish().commits
	end
	expect.truthy(commits > 40, "commit steps checked: " .. commits)
end)

test("docSize without sizes, or for a log that is not an array, is js.asciiSize", function()
	local l = lobby.lobbyOf(nil)
	l.match = json.object { log = json.object { x = "\u{e9}" }, snap = "s" }
	expect.eq(realSize(l, {}), js.asciiSize(l))
	l.match.log = { json.object { a = json.object { t = "caf\u{e9}" }, h = "h1" }, NULL, "x" }
	local sizes = {}
	expect.eq(realSize(l, sizes), js.asciiSize(l))
	-- a different log under the same sizes: measured afresh past the first change
	l.match.log = { l.match.log[1], json.object { a = json.object { t = "\u{1f600}" }, h = "h2" } }
	expect.eq(realSize(l, sizes), js.asciiSize(l))
	l.match.log = {}
	expect.eq(realSize(l, sizes), js.asciiSize(l))
	expect.eq(realSize(l, nil), js.asciiSize(l))
end)

test("the checks ran", function()
	expect.truthy(total.measured > 1500, "actions measured both ways: " .. total.measured)
	print(string.format("      log budget: %d commits checked, %d measured both ways", total.commits, total.measured))
end)
