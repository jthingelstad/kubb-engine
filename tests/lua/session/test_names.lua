-- Generated names through the session's door (docs/SESSION.md "Names", docs/NAMES.md
-- section 8 step 1): kubbCall("names.<name>"). tests/node/names.test.mjs runs the same
-- calls under wasmoon and checks the same fingerprint, so a seed gives one name on both.
import "session/api"
import "session/json"
import "core/namegen"
import "core/namewords"
local json, namegen, words = tw.web.json, tw.namegen, tw.namewords

local function call(method, a)
	local out = json.decode(_G.kubbCall(method, a and json.encode(a) or ""))
	if type(out) == "table" and out.error then error(method .. ": " .. out.error, 2) end
	return out
end
local function refused(method, a)
	local out = json.decode(_G.kubbCall(method, a and json.encode(a) or ""))
	return type(out) == "table" and out.error
end

local function fnv(text)
	local h = 0x811c9dc5
	for i = 1, #text do h = ((h ~ text:byte(i)) * 0x01000193) & 0xffffffff end
	return string.format("%08x", h)
end

-- The names seeds 1 to 300 roll, one a line, hashed: the same in tests/node/names.test.mjs.
-- (Player names repeat more than team names: the alliteration narrows the draw, as
-- namegen.roll with any generator does.)
local FINGERPRINT = { player = "07a20e20", team = "6a91fa87" }

test("names.roll: the same seed gives the same name, a valid one, with its parts", function()
	for _, kind in ipairs(namegen.KINDS) do
		local seen, lines = {}, {}
		for seed = 1, 300 do
			local r = call("names.roll", { kind = kind, seed = seed })
			expect.eq(call("names.roll", { kind = kind, seed = seed }).text, r.text, "same seed")
			expect.truthy(namegen.valid(kind, r.text), kind .. ": " .. r.text)
			expect.eq(call("names.make", { kind = kind, parts = r.parts }).text, r.text, "parts make the text")
			seen[r.text] = true
			lines[#lines + 1] = r.text
		end
		local n = 0
		for _ in pairs(seen) do n = n + 1 end
		expect.truthy(n > 200, kind .. ": seeds give different names (" .. n .. " of 300)")
		expect.eq(fnv(table.concat(lines, "\n")), FINGERPRINT[kind], kind .. " fingerprint")
	end
	expect.eq(call("names.roll", { kind = "player", seed = 42 }).text, "Midsummer Myrtle")
	expect.eq(call("names.roll", { kind = "team", seed = 42 }).text, "Lively Carvers")
	-- a seed is any whole number a client's generator gives, negative or large too
	expect.truthy(call("names.roll", { kind = "team", seed = -5 }).text)
	expect.truthy(call("names.roll", { kind = "team", seed = 2 ^ 40 }).text)
end)

test("names.roll: locked slots are kept, the open ones drawn", function()
	for seed = 1, 100 do
		local r = call("names.roll", { kind = "team", seed = seed, keep = { shape = "adj", words = { json.null, "Lumberjacks" } } })
		expect.eq(r.parts.shape, "adj")
		expect.eq(r.parts.words[2], "Lumberjacks")
		expect.truthy(namegen.valid("team", r.text), r.text)
		local p = call("names.roll", { kind = "player", seed = seed, keep = { shape = "adj", words = { "Lucky" } } })
		expect.eq(p.parts.words[1], "Lucky", "the first slot locked")
		local w = call("names.roll", { kind = "team", seed = seed, keep = { shape = "wood" } })
		expect.eq(w.parts.shape, "wood", "a shape alone keeps the shape")
	end
	-- both slots locked: the name itself
	expect.eq(call("names.roll", { kind = "player", seed = 9, keep = { shape = "adj", words = { "Mighty", "Maple" } } }).text,
		"Mighty Maple")
	-- a kept word not in its list (a word taken out, or a typo) is drawn again
	local r = call("names.roll", { kind = "player", seed = 3, keep = { shape = "adj", words = { "Sassy", "Maple" } } })
	expect.eq(r.parts.words[2], "Maple")
	expect.truthy(r.parts.words[1] ~= "Sassy" and namegen.valid("player", r.text), r.text)
	-- kept words that make no name: text and parts null, not an error
	local none = call("names.roll", { kind = "player", seed = 3, keep = { shape = "adj", words = { "Salty", "Walnut" } } })
	expect.eq(none.text, nil)
	expect.eq(none.parts, nil)
	expect.truthy(refused("names.roll", { kind = "team", seed = 1, keep = { shape = "nope" } }), "an unknown shape")
end)

test("names.step: round a slot through exactly the words names.choices gives, both ways", function()
	local start = { shape = "adj", words = { "Mighty", "Maple" } }
	for slot = 0, 1 do
		local choices = call("names.choices", { kind = "player", parts = start, slot = slot }).words
		local p, visited = start, {}
		for _ = 1, #choices do
			local r = call("names.step", { kind = "player", parts = p, slot = slot })
			expect.truthy(r.moved)
			expect.truthy(namegen.valid("player", r.text), r.text)
			visited[#visited + 1] = r.parts.words[slot + 1]
			-- the other slot never moves
			expect.eq(r.parts.words[2 - slot], start.words[2 - slot])
			p = r.parts
		end
		expect.eq(p.words[slot + 1], start.words[slot + 1], "back where it started after a full turn")
		local at
		for i, w in ipairs(choices) do if w == start.words[slot + 1] then at = i end end
		for k = 1, #choices do
			expect.eq(visited[k], choices[(at - 1 + k) % #choices + 1], "step's order is the list's")
		end
		local fwd = call("names.step", { kind = "player", parts = start, slot = slot })
		local back = call("names.step", { kind = "player", parts = fwd.parts, slot = slot, dir = -1 })
		expect.eq(back.text, "Mighty Maple", "dir -1 undoes dir 1")
	end
	-- only one word fits: moved false, the name as it was
	local only = { shape = "adj", words = { "Magnificent", "Owls" } }
	expect.eq(#call("names.choices", { kind = "team", parts = only, slot = 1 }).words, 1)
	local r = call("names.step", { kind = "team", parts = only, slot = 1 })
	expect.eq(r.moved, false)
	expect.eq(r.text, "Magnificent Owls")
	-- the slots of "The <noun>": one
	expect.truthy(call("names.step", { kind = "team", parts = { shape = "the", words = { "Owls" } }, slot = 0 }).moved)
	expect.truthy(refused("names.step", { kind = "team", parts = { shape = "the", words = { "Owls" } }, slot = 1 }), "slot out of range")
	expect.truthy(refused("names.step", { kind = "player", parts = { shape = "adj", words = { "Mighty" } }, slot = 0 }), "a word missing")
	expect.truthy(refused("names.step", { kind = "player", parts = start, slot = 0, dir = 2 }), "dir")
end)

test("names.choices: every word that fits the slot, each making a valid name", function()
	local c = call("names.choices", { kind = "player", parts = { shape = "adj", words = { "Magnificent", "Maple" } }, slot = 1 }).words
	expect.eq(table.concat(c, ","), "Ash,Elm,Fir,Oak,Pear,Pine,Plum,Teak")
	local s = call("names.choices", { kind = "player", parts = { shape = "adj", words = { "Salty", "Maple" } }, slot = 1 }).words
	for _, w in ipairs(s) do
		expect.truthy(w ~= "Walnut" and w ~= "Chestnut", "never pairs are not offered")
	end
end)

test("names.make: the text, or null and why", function()
	expect.eq(call("names.make", { kind = "team", parts = { shape = "the", words = { "Lumberjacks" } } }).text, "The Lumberjacks")
	local function why(kind, shape, ws) return call("names.make", { kind = kind, parts = { shape = shape, words = ws } }).why end
	expect.eq(why("player", "adj", { "Salty", "Walnut" }), "never")
	expect.eq(why("player", "adj", { "Magnificent", "Mahogany" }), "long")
	expect.eq(why("team", "wood", { "Pine", "Pinecones" }), "repeat")
	expect.eq(why("player", "adj", { "Mighty", "Batons" }), "word")
	expect.eq(why("player", "adj", { "Mighty" }), "word")
end)

test("names.valid: generated names pass, typed ones do not, and the engine's defaults are marked", function()
	local v = call("names.valid", { kind = "player", text = "Mighty Maple" })
	expect.eq(v.ok, true)
	expect.eq(v.default, false)
	expect.eq(v.parts.shape, "adj")
	expect.eq(table.concat(v.parts.words, " "), "Mighty Maple")
	expect.eq(call("names.valid", { kind = "team", text = "The Lumberjacks" }).parts.words[1], "Lumberjacks")
	for _, bad in ipairs { "mighty maple", "Mighty  Maple", " Mighty Maple", "Mighty Maple ", "Kim", "Salty Walnut",
		"Magnificent Mahogany", "Pine Pinecones", "Mighty Batons", "The", "" } do
		local r = call("names.valid", { kind = "player", text = bad })
		expect.eq(r.ok, false, bad)
		expect.eq(r.parts, nil, bad)
	end
	expect.eq(call("names.valid", { kind = "team", text = "Mighty Maple" }).ok, false, "a player name is not a team name")
	expect.eq(call("names.valid", { kind = "player", text = 7 }).ok, false, "not a string")
	expect.eq(call("names.valid", { kind = "player" }).ok, false, "no text")
	for _, d in ipairs { "Computer", "Team A", "Team B", "Player 1", "Player 6" } do
		local r = call("names.valid", { kind = "team", text = d })
		expect.eq(r.ok, false, d .. " is not generated")
		expect.eq(r.default, true, d .. " is the engine's own")
	end
	expect.eq(call("names.valid", { kind = "player", text = "Player 7" }).default, false, "six a side")
	expect.truthy(refused("names.valid", { kind = "coach", text = "Mighty Maple" }), "an unknown kind")
end)

test("names.words: the lists, shapes and rules as namegen holds them, hashed", function()
	local w = call("names.words")
	expect.eq(w.version, words.version)
	expect.eq(w.rules, 1)
	expect.eq(w.max.player, namegen.max.player)
	expect.eq(w.max.team, namegen.max.team)
	for _, list in ipairs { "adjectives", "woods", "teams", "never" } do
		local got = list == "never" and w.never or w.lists[list]
		expect.eq(table.concat(got, ","), table.concat(words[list], ","), list)
	end
	expect.eq(#w.shapes.team, 3)
	expect.eq(w.shapes.team[2].prefix, "The")
	expect.eq(#w.defaults, 9)
	-- the hash is of the canonical JSON of every other field
	local text = _G.kubbCall("names.words", "")
	local without = text:gsub('"hash":"%x+",', "")
	expect.eq(fnv(without), w.hash)
	expect.eq(_G.kubbCall("names.words", "{}"), text, "the same bytes every call")
end)

test("names.all: every name, as tests/names holds them", function()
	local here = arg[0]:match("^(.*)/[^/]*$") or "."
	for _, kind in ipairs(namegen.KINDS) do
		local all = call("names.all", { kind = kind }).names
		local f = assert(io.open(here .. "/../names/" .. kind .. ".txt"))
		local file = f:read("a")
		f:close()
		expect.eq(table.concat(all, "\n") .. "\n", file, kind)
	end
end)

test("names calls need no session or tune, and errors come back as other calls' do", function()
	expect.truthy(refused("names.nope", {}):match("unknown call names%.nope"))
	expect.eq(refused("names.roll", { kind = "player", seed = 1.5 }), "names.roll: seed is a whole number")
	expect.eq(refused("names.roll", { kind = "player" }), "names.roll: seed is a whole number")
	expect.truthy(refused("names.roll", { kind = "coach", seed = 1 }))
end)
