-- The vectors (docs/PITCH.md "The vectors") under desktop Lua: every step of
-- tests/pitch/vectors/, a frozen corpus recorded from the web's JavaScript at the commit
-- engine.json's pitchFrom names, run through kubbCall("pitch.<name>") and compared with what
-- the JavaScript returned.
-- tests/node/pitch.test.mjs runs the same vectors under wasmoon.
import "session/api"
import "session/json"
import "pitch/js"
local json, js, NULL = tw.web.json, tw.shared.js, tw.web.json.null

local DIR = "tests/pitch/vectors/"

local function readFile(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("a")
	f:close()
	return s
end

local function fnv(s)
	local h = 0x811c9dc5
	for i = 1, #s do
		h = h ~ s:byte(i)
		h = (h * 0x01000193) & 0xffffffff
	end
	return string.format("%08x", h)
end

-- A copy of v with the scenario's placeholders put in (empty objects stay objects).
local function subst(v, doc, engine)
	if v == "$doc" then return doc end
	if v == "$match" then return (type(doc) == "table" and not rawequal(doc, NULL) and doc.match) or NULL end
	if v == "$engine" then return engine end
	if type(v) ~= "table" or rawequal(v, NULL) then return v end
	local out = setmetatable({}, getmetatable(v))
	for k, x in pairs(v) do out[k] = subst(x, doc, engine) end
	return out
end

-- Take out what the Lua adds on purpose: a match's (it has seq) or a replay's (v and
-- log) engine. Returns the copy and the engines found.
local function normalise(v, found)
	if type(v) ~= "table" or rawequal(v, NULL) then return v end
	local strip = v.seq ~= nil or (v.v ~= nil and v.log ~= nil)
	local out = setmetatable({}, getmetatable(v))
	for k, x in pairs(v) do
		if strip and k == "engine" then found[#found + 1] = x else out[k] = normalise(x, found) end
	end
	return out
end

local function matches(got, want)
	local text = js.text(got)
	if type(want) == "table" and not rawequal(want, NULL) and want["$fnv"] ~= nil then
		return fnv(text) == want["$fnv"] and #text == want["$bytes"], text
	end
	return text == js.text(want), text
end

local index = json.decode(readFile(DIR .. "index.json"), true)
local ENGINE = tw.engine.version
local MM = tw.shared.lobby.ENGINE

test("the vectors were recorded from the web commit engine.json names", function()
	local manifest = json.decode(readFile("engine.json"))
	expect.eq(manifest.pitchFrom and manifest.pitchFrom.commit, index.web, "engine.json pitchFrom.commit")
end)

local total = 0
for _, file in ipairs(index.scenarios) do
	test("vectors " .. file, function()
		local sc = json.decode(readFile(DIR .. file), true)
		local doc = sc.start
		for i, step in ipairs(sc.steps) do
			local args = subst(step.args, doc, ENGINE)
			local argText = json.encode(args)
			local outText = kubbCall("pitch." .. step.call, argText)
			local res = json.decode(outText, true)
			if res.error then error(string.format("%s step %d %s: %s", file, i, step.call, res.error), 0) end
			-- byte stable: the engine's own output decodes and encodes to the same text
			expect.eq(json.encode(res), outText, "re-encoding step " .. i)
			local found = {}
			local ok, text = matches(normalise(res.value, found), step.out)
			if not ok then
				error(string.format("%s step %d %s(%s)\n  lua: %s\n  js:  %s", file, i, step.call,
					argText:sub(1, 300), text:sub(1, 600), js.text(step.out):sub(1, 600)), 0)
			end
			for _, e in ipairs(found) do expect.eq(e, MM, "the engine stamped at step " .. i) end
			if step.keep and not rawequal(res.value, NULL) then doc = res.value end
			total = total + 1
		end
	end)
end

test("every vector step ran", function()
	expect.eq(total, index.steps, "steps")
end)
