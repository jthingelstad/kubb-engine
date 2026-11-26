-- Scenes (0.14, core/scenes): a scene decides the surface and the kubb set a match may
-- have, wherever a client sets options (kubbCall "new", the pitch's setOptions, optionsOf
-- and matchOptions); the card shows only what the scene leaves to the player
-- (pitch.optionRows); a match or a document from before 0.14 (no scene, or any scene with
-- any surface and set) loads and plays exactly as it was recorded. And the ground
-- impacts a renderer may ask for (setImpacts), which never reach a snapshot or a hash.
import "session/api"
import "session/session"
import "session/json"
import "session/replay"
import "session/wide"
import "session/namecheck"
import "pitch/lobby"
import "core/scenes"
tw.web.session.useTune("pointer")
local api, session, json, replay, lobby, scenes = tw.web.api, tw.web.session, tw.web.json, tw.web.replay,
	tw.shared.lobby, tw.scenes
local NULL = json.null

local START = { year = 2026, month = 11, day = 22, hour = 12, min = 0 }

local function call(method, a)
	local r = json.decode(api.call(method, a and json.encode(a) or nil))
	assert(type(r) ~= "table" or not r.error, type(r) == "table" and r.error)
	return r
end

local function pitch(name, args)
	local out = json.decode(kubbCall("pitch." .. name, json.encode(args)), true)
	if out.error then error("pitch." .. name .. ": " .. out.error, 2) end
	local v = out.value
	if rawequal(v, NULL) then return nil end
	return v
end

local function snapOpts() return json.decode(kubbCall("snapshot", "")).opts end

local function newMatch(o)
	local m = { mode = "match", seed = 7, cpu = "both", start = START, maxTurns = 4 }
	for k, v in pairs(o or {}) do m[k] = v end
	call("new", m)
	return snapOpts()
end

test("the scenes call: the catalogue, its surfaces and sets", function()
	local c = call("scenes")
	expect.eq(c.default, "day")
	local ids = {}
	for i, e in ipairs(c.scenes) do ids[i] = e.id end
	expect.eq(table.concat(ids, ","), "day,beach,night,neon,minnesota,tournament,bw")
	local byId = {}
	for _, e in ipairs(c.scenes) do byId[e.id] = e end
	expect.eq(byId.day.name, "Park")
	expect.eq(byId.night.name, "Camping")
	expect.eq(byId.neon.name, "Techno")
	expect.eq(byId.bw.name, "Black & White")
	expect.eq(byId.neon.surface, "grid")
	expect.eq(byId.neon.ring, true)
	expect.eq(byId.neon.dark, true)
	expect.eq(byId.bw.mono, true)
	expect.eq(byId.tournament.set, "usa")
	expect.eq(byId.minnesota.surface, "snow")
	expect.eq(byId.minnesota.set, "minnesota")
	expect.eq(table.concat(byId.bw.choices, ","), "surface", "Black & White leaves the surface to the player")
	for _, e in ipairs(c.scenes) do
		if e.id ~= "bw" then expect.eq(#e.choices, 0, e.id .. " leaves nothing") end
	end
	local sf = {}
	for i, s in ipairs(c.surfaces) do sf[i] = s.id end
	expect.eq(table.concat(sf, ","), "grass,sand,snow,grid")
	expect.eq(#c.sets, 5, "every set the engine takes, sweden and wisconsin too")
end)

test("new: the scene decides the surface and the set", function()
	local o = newMatch { scene = "beach", surface = "grass" }
	expect.eq(o.scene, "beach"); expect.eq(o.surface, "sand"); expect.eq(o.set, "classic")
	o = newMatch { scene = "bw", surface = "snow" }
	expect.eq(o.scene, "bw"); expect.eq(o.surface, "snow")
	o = newMatch { scene = "bw", surface = "grid" }
	expect.eq(o.surface, "grass", "Black & White has no grid: its default")
	o = newMatch { scene = "tournament", set = "classic" }
	expect.eq(o.surface, "grass"); expect.eq(o.set, "usa")
	o = newMatch { scene = "neon", surface = "sand", set = "sweden" }
	expect.eq(o.surface, "grid"); expect.eq(o.set, "classic")
	o = newMatch { scene = "minnesota" }
	expect.eq(o.surface, "snow"); expect.eq(o.set, "minnesota")
	-- Park is the default and is not written; an id the catalogue does not have is Park
	o = newMatch { scene = "day", surface = "snow", set = "usa" }
	expect.eq(o.scene, nil); expect.eq(o.surface, "grass"); expect.eq(o.set, "classic")
	o = newMatch { scene = "dusk", surface = "snow" }
	expect.eq(o.scene, nil, "unknown: Park"); expect.eq(o.surface, "grass")
	-- the match's game file names the surface
	call("new", { mode = "match", seed = 7, cpu = "both", start = START, scene = "neon" })
	expect.eq(json.decode(kubbCall("snapshot", "")).save.game.surface, "Grid")
	expect.eq(call("view").surface, "grid")
	expect.eq(call("view").scene, "neon")
end)

test("new with no scene is as before 0.14: any surface and set, the start unchanged", function()
	local plain = { mode = "match", seed = 9, cpu = "both", start = START, surface = "sand", set = "sweden", maxTurns = 3 }
	local o = newMatch(plain)
	expect.eq(o.surface, "sand"); expect.eq(o.set, "sweden"); expect.eq(o.scene, nil)
	local direct = session.new(plain):snapshot()
	call("new", plain)
	expect.eq(kubbCall("snapshot", ""), direct, "the door adds nothing when no scene is named")
end)

-- A match kept before 0.14 could name any scene with any surface and set (0.13 took any
-- well formed id): it restores, checks and replays exactly as it was.
test("a match from before 0.14 (a scene with any surface and set) loads and plays as recorded", function()
	local old = { mode = "match", seed = 4, cpu = "both", start = START, raising = "auto", maxTurns = 3,
		scene = "night", surface = "sand", set = "wisconsin" }
	local s = session.new(old)   -- the path a restore, a replay and checkStart take
	local start = s:snapshot()
	expect.truthy(start:find('"scene":"night"', 1, true) and start:find('"surface":"sand"', 1, true))
	expect.eq((session.startCheck(start)), true, "checkStart")
	local r = session.restore(start)
	expect.eq(r:snapshot(), start, "restore")
	local log = {}
	for _ = 1, 300 do
		if s:need().kind == "over" then break end
		local a
		for _ = 1, 3000 do
			local f = s:frame { dt = 1 / 30 }
			if f.action then a = f.action break end
		end
		if not a then break end
		log[#log + 1] = { a = json.decode(json.encode(a)), h = s:hash() }
	end
	expect.truthy(#log > 5, "it played")
	local fin = replay.new({ start = start, log = log }):finish()
	expect.eq(fin.differs, false, "replayed from its start, hash for hash")
	expect.eq(replay.new({ setup = session.setupOf(start), log = log }):finish().differs, false,
		"replayed from its setup")
	-- an old game file's surface still reads (namecheck holds sets to every set the engine takes)
	local rep = tw.web.namecheck.snapshot(json.decode(start))
	expect.truthy(rep.allowed, "an honest 0.13 match with a listed scene and the wisconsin set is allowed")
end)

test("practice: a scene holds setSurface to the surfaces it allows", function()
	call("new", { mode = "practice", scene = "bw" })
	expect.eq(call("setSurface", { surface = "snow" }).surface, "snow")
	expect.eq(call("setSurface", { surface = "grid" }).surface, "snow", "not a Black & White surface: unchanged")
	call("new", { mode = "practice", scene = "neon" })
	expect.eq(call("view").surface, "grid")
	expect.eq(call("setSurface", { surface = "grass" }).surface, "grid")
	call("new", { mode = "practice" })
	expect.eq(call("setSurface", { surface = "sand" }).surface, "sand", "no scene: as before")
end)

test("the pitch: a named scene decides; a document without one is as written", function()
	local doc = pitch("joinTeam", { doc = NULL, id = "m1", side = "A" })
	-- no scene: as before 0.14
	local legacy = pitch("setOptions", { doc = doc, options = { surface = "snow", set = "sweden" } })
	expect.eq(legacy.options.surface, "snow"); expect.eq(legacy.options.set, "sweden")
	local all = pitch("optionsOf", { doc = legacy })
	expect.eq(all.scene, "day"); expect.eq(all.surface, "snow")
	-- choosing a scene brings its surface and set
	local d = pitch("setOptions", { doc = legacy, options = { scene = "beach" } })
	expect.eq(d.settings.scene, "beach"); expect.eq(d.options.surface, "sand"); expect.eq(d.options.set, "classic")
	expect.eq(pitch("setOptions", { doc = d, options = { surface = "grass" } }), nil, "Beach is sand: no change")
	d = pitch("setOptions", { doc = d, options = { scene = "bw", surface = "snow" } })
	expect.eq(d.options.surface, "snow")
	d = pitch("setOptions", { doc = d, options = { surface = "sand" } })
	expect.eq(d.options.surface, "sand", "Black & White leaves the surface to the player")
	d = pitch("setOptions", { doc = d, options = { scene = "tournament" } })
	expect.eq(d.options.surface, "grass"); expect.eq(d.options.set, "usa")
	local lu = pitch("lineup", { doc = d, members = { { id = "m1", me = { name = "Ada" } } } })
	local o = pitch("matchOptions", { doc = d, lineup = lu, seed = 5, start = START })
	expect.eq(o.scene, "tournament"); expect.eq(o.set, "usa"); expect.eq(o.surface, "grass")
	-- a write that left the scene's values (an older engine's lobbyOf cleans grid to grass)
	-- is read through the scene again
	local techno = pitch("setOptions", { doc = d, options = { scene = "neon" } })
	expect.eq(techno.options.surface, "grid")
	techno.options.surface = "grass"
	expect.eq(pitch("optionsOf", { doc = techno }).surface, "grid")
	local mo = pitch("matchOptions", { doc = techno, lineup = lu, seed = 5, start = START })
	expect.eq(mo.surface, "grid")
	-- a well formed id a newer engine wrote is kept, and read as Park
	local newer = pitch("lobbyOf", { doc = { v = 1, teams = { A = { "m1" }, B = {} }, settings = { scene = "desert" },
		options = { surface = "sand" } } })
	expect.eq(newer.settings.scene, "desert")
	local no = pitch("optionsOf", { doc = newer })
	expect.eq(no.scene, "day"); expect.eq(no.surface, "grass")
end)

test("pitch.optionRows: the card a scene leaves; the Scene row first, no Kubbs row", function()
	local function keys(r)
		local out = {}
		for i, row in ipairs(r.rows) do out[i] = row[1] end
		return table.concat(out, ",")
	end
	local park = pitch("optionRows", { scene = "day" })
	expect.eq(park.scene, "day")
	expect.eq(keys(park), "scene,opening,raising,wind,togo,computer", "Throw to go (1.4.0) before Computer")
	expect.eq(#park.rows[1][3], #scenes.list, "every scene on the Scene row")
	expect.eq(park.rows[1][3][1][2], "Park")
	local bw = pitch("optionRows", { scene = "bw" })
	expect.eq(keys(bw), "scene,surface,opening,raising,wind,togo,computer")
	local vs = {}
	for i, c in ipairs(bw.rows[2][3]) do vs[i] = c[1] end
	expect.eq(table.concat(vs, ","), "grass,sand,snow", "only its surfaces")
	for _, id in ipairs { "beach", "night", "neon", "minnesota", "tournament" } do
		expect.eq(keys(pitch("optionRows", { scene = id })), "scene,opening,raising,wind,togo,computer", id)
	end
	local t = pitch("optionRows", { scene = "tournament" })
	expect.eq(t.defaults.set, "usa"); expect.eq(t.defaults.surface, "grass")
	expect.eq(pitch("optionRows", { scene = "nope" }).scene, "day")
	expect.eq(pitch("optionLabel", { key = "scene", value = "neon" }), "Techno")
	expect.eq(pitch("optionLabel", { key = "surface", value = "grid" }), "Grid")
end)

test("names.check: a scene and a set the engine lists", function()
	call("new", { mode = "match", seed = 7, cpu = "both", start = START, scene = "neon" })
	local d = json.decode(kubbCall("snapshot", ""))
	expect.truthy(tw.web.namecheck.snapshot(d).allowed, "a Techno match on the grid")
	d.opts.scene = "dusk"
	local rep = tw.web.namecheck.snapshot(d)
	expect.eq(rep.allowed, false, "a scene the engine does not list")
	d.opts.scene, d.opts.set = "neon", "sweden"
	expect.truthy(tw.web.namecheck.snapshot(d).allowed, "sweden is in no scene but still a set the engine takes")
	d.opts.set = "denmark"
	expect.eq(tw.web.namecheck.snapshot(d).allowed, false)
end)

-- Plays a computer match through the door until `n` throws, gathering recordings.
local function recordings(n, o)
	local m = { mode = "match", seed = 21, cpu = "both", start = START, maxTurns = 6 }
	for k, v in pairs(o or {}) do m[k] = v end
	call("new", m)
	local recs, hashes = {}, {}
	for _ = 1, 200 do
		local f
		for _ = 1, 3000 do
			f = call("frame", { dt = 1 / 30 })
			if f.action then break end
		end
		if not f.action then break end
		if f.recording then recs[#recs + 1] = f.recording end
		hashes[#hashes + 1] = call("hash").hash
		if #recs >= n then break end
	end
	return recs, hashes
end

test("ground impacts: only when asked, where and when pieces met the ground, never hashed", function()
	expect.eq(call("setImpacts", {}).on, false)
	local off, h0 = recordings(6, { scene = "neon" })
	for _, r in ipairs(off) do expect.eq(r.timeline.impacts, nil, "off: none gathered") end
	expect.eq(call("setImpacts", { on = true }).on, true)
	local on, h1 = recordings(6, { scene = "neon" })
	expect.eq(table.concat(h1, ","), table.concat(h0, ","), "the same match, hash for hash")
	local n, kinds, thrown = 0, {}, 0
	for i, r in ipairs(on) do
		local list = r.timeline.impacts
		expect.truthy(list, "on: the timeline carries impacts")
		local last = -1
		for _, e in ipairs(list) do
			n = n + 1
			kinds[e.with] = true
			if e.thrown then thrown = thrown + 1 end
			expect.truthy(e.t >= last, "in time order")
			last = e.t
			expect.truthy(e.t >= 0 and e.t <= r.duration + 1e-9, "on the recording's clock")
			expect.truthy(e.speed >= tw.web.throw.tune.impactSpeed, "hard enough")
			expect.truthy(e.strength > 0 and e.strength <= 1, "a strength")
			expect.truthy(type(e.x) == "number" and type(e.y) == "number" and type(e.id) == "string")
			expect.truthy(e.with == "baton" or e.with == "kubb" or e.with == "king", e.with)
		end
		-- one impact per piece per strike
		for a = 1, #list do
			for b = a + 1, #list do
				if list[a].id == list[b].id then
					expect.truthy(list[b].t - list[a].t > tw.web.throw.tune.impactGap, "merged within the gap")
				end
			end
		end
		expect.eq(json.encode(r.items), json.encode(off[i].items), "the same throw")
	end
	expect.truthy(n > 6 and kinds.baton and kinds.kubb, "batons and kubbs met the ground")
	expect.truthy(thrown > 0, "the thrown piece's landing is marked")
	call("setImpacts", { on = false })
end)

test("ground impacts in the wide view are un-turned like the other points", function()
	local rec = { timeline = { impacts = { { t = 0.5, x = 1, y = 2, id = "a1", with = "kubb", speed = 2, strength = 0.1 } } } }
	local out = tw.web.wide.recording("B", rec)
	local fx, fy = tw.frame.point("B", 1, 2)
	expect.eq(out.timeline.impacts[1].x, fx)
	expect.eq(out.timeline.impacts[1].y, fy)
	expect.eq(rec.timeline.impacts[1].x, 1, "the session's recording is left alone")
end)
