-- core/namegen and core/namewords: generated names (docs/NAMES.md).
import "core/namegen"
import "core/namewords"
local namegen, words = tw.namegen, tw.namewords

local here = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "tests/lua"

local function readBlocklist()
	local f = assert(io.open(here .. "/../names/blocklist.txt"))
	local rules = { word = {}, phrase = {}, run = {} }
	for line in f:lines() do
		local kind, text = line:match("^(%a+) (.+)$")
		if kind and not line:match("^#") then
			assert(rules[kind], "blocklist: unknown rule " .. kind)
			rules[kind][#rules[kind] + 1] = text
		end
	end
	f:close()
	return rules
end

test("namewords: every word is one capitalised word of letters, once per list", function()
	for _, list in ipairs { "adjectives", "woods", "teams" } do
		local seen = {}
		for _, w in ipairs(words[list]) do
			expect.truthy(w:match("^%u%l+$"), list .. ": " .. w)
			expect.eq(seen[w], nil, list .. ": twice: " .. w)
			seen[w] = true
		end
	end
end)

test("namewords: every never-pair is a name the lists could otherwise make", function()
	for _, s in ipairs(words.never) do
		local a, b = s:match("^(%u%l+) (%u%l+)$")
		expect.truthy(a, "never: two words: " .. s)
		local inList = function(list, w)
			for _, x in ipairs(words[list]) do if x == w then return true end end
		end
		local made = (inList("adjectives", a) or inList("woods", a))
			and (inList("woods", b) or inList("teams", b))
		expect.truthy(made, "never: not a name the lists make: " .. s)
	end
end)

test("namewords: no word is in two lists, so a name parses one way", function()
	local where = {}
	for _, list in ipairs { "adjectives", "woods", "teams" } do
		for _, w in ipairs(words[list]) do
			expect.eq(where[w], nil, w .. " is in " .. tostring(where[w]) .. " and " .. list)
			where[w] = list
		end
	end
	expect.eq(where.The, nil, "The is the team prefix")
end)

test("namegen: every name parses back to itself, within the length", function()
	for _, kind in ipairs(namegen.KINDS) do
		local all = namegen.all(kind)
		expect.truthy(#all > 1000, kind .. ": enough names for a lobby")
		for _, s in ipairs(all) do
			local parts = namegen.parse(kind, s)
			expect.truthy(parts, kind .. ": parses: " .. s)
			expect.eq(namegen.make(kind, parts), s)
			expect.truthy(#s <= namegen.max[kind], s)
		end
	end
end)

test("namegen: no name holds anything on the blocklist", function()
	local rules, hits = readBlocklist(), {}
	for _, kind in ipairs(namegen.KINDS) do
		for _, s in ipairs(namegen.all(kind)) do
			local low = s:lower()
			local spaced = " " .. low .. " "
			local run = low:gsub(" ", "")
			for _, w in ipairs(rules.word) do
				if spaced:find(" " .. w .. " ", 1, true) then hits[#hits + 1] = s .. " (word " .. w .. ")" end
			end
			for _, p in ipairs(rules.phrase) do
				if spaced:find(" " .. p .. " ", 1, true) then hits[#hits + 1] = s .. " (phrase " .. p .. ")" end
			end
			for _, r in ipairs(rules.run) do
				if run:find(r, 1, true) then hits[#hits + 1] = s .. " (run " .. r .. ")" end
			end
		end
	end
	expect.eq(#hits, 0, table.concat(hits, ", ", 1, math.min(#hits, 30)))
end)

test("namegen: text that is not a name is refused", function()
	expect.truthy(namegen.valid("player", "Mighty Maple"))
	expect.truthy(namegen.valid("team", "The Lumberjacks"))
	expect.truthy(namegen.valid("team", "Birch Batons"))
	expect.truthy(namegen.valid("team", "Wobbly Towers"))
	expect.eq(namegen.valid("player", "mighty maple"), false, "capitals are the words'")
	expect.eq(namegen.valid("player", "Mighty  Maple"), false, "one space")
	expect.eq(namegen.valid("player", " Mighty Maple"), false)
	expect.eq(namegen.valid("player", "Mighty Batons"), false, "a team noun is not a wood")
	expect.eq(namegen.valid("team", "Mighty Maple"), false, "a wood is not a team noun")
	expect.eq(namegen.valid("player", "Kim"), false, "typed names are not generated")
	expect.eq(namegen.valid("team", "The"), false)
	expect.eq(namegen.valid("player", "Magnificent Mahogany"), false, "too long")
	expect.eq(select(2, namegen.make("player", { shape = "adj", "Magnificent", "Mahogany" })), "long")
	expect.eq(namegen.valid("player", nil), false)
	expect.eq(namegen.valid("player", "Salty Walnut"), false, "a pair in namewords.never")
	expect.eq(select(2, namegen.make("player", { shape = "adj", "Salty", "Walnut" })), "never")
	expect.truthy(namegen.valid("player", "Salty Maple"), "each word alone is fine")
	expect.eq(select(2, namegen.make("team", { shape = "wood", "Pine", "Pinecones" })), "repeat")
	expect.eq(namegen.valid("team", "Pine Pinecones"), false)
	expect.truthy(namegen.valid("team", "Pine Batons"))
	expect.eq(namegen.valid("coach", "Mighty Maple"), false)
end)

-- A fixed draw: the same numbers every run, like a client's seeded generator.
local function draws(seed)
	local x = seed
	return function(n)
		x = (x * 1103515245 + 12345) % 2147483648
		return x % n + 1
	end
end

test("namegen: roll is the client's draw, the same draw the same name", function()
	for _, kind in ipairs(namegen.KINDS) do
		local a, b = draws(7), draws(7)
		for _ = 1, 200 do
			local s, parts = namegen.roll(kind, a)
			expect.eq(namegen.roll(kind, b), s)
			expect.truthy(namegen.valid(kind, s), s)
			expect.eq(namegen.make(kind, parts), s)
		end
	end
end)

test("namegen: player names alliterate more often than chance", function()
	local rand, same = draws(3), 0
	for _ = 1, 1000 do
		local s = namegen.roll("player", rand)
		local a, w = s:match("^(%a)%a* (%a)")
		if a == w then same = same + 1 end
	end
	expect.truthy(same > 400, "alliterative: " .. same .. " of 1000")
end)

test("namegen: roll keeps a locked slot, step scrolls one", function()
	local rand = draws(11)
	for _ = 1, 50 do
		local s, parts = namegen.roll("team", rand, { shape = "adj", nil, "Lumberjacks" })
		expect.eq(parts.shape, "adj")
		expect.eq(parts[2], "Lumberjacks")
		expect.truthy(s:match(" Lumberjacks$"), s)
	end
	local s, parts = namegen.step("player", { shape = "adj", "Mighty", "Maple" }, 2, 1)
	expect.truthy(namegen.valid("player", s))
	expect.eq(parts[1], "Mighty")
	expect.truthy(parts[2] ~= "Maple")
	local back = namegen.step("player", parts, 2, -1)
	expect.eq(back, "Mighty Maple")
	-- A long adjective skips the woods that would not fit.
	local long = namegen.step("player", { shape = "adj", "Magnificent", "Oak" }, 2, 1)
	expect.truthy(long and #long <= namegen.max.player, tostring(long))
end)
