-- The Kubb Gym's two teams (docs/notes/gym.md "Versus"): each team of a match plays
-- with its own level, thrower, raising policy and tune settings. A measuring tool: it
-- changes nothing in the engine's files; while a match is played it puts a team's
-- numbers in the engine's tune tables only while that team acts.
--
-- A spec is "level=pro;thrower=cpu;raise=apart;autothrow.tune.inkast.pro.row=0" (parts
-- split by ';' or ','; tune paths are --set's: a number reachable from tw by its path).
-- raise= left out (or raise=default) is the engine's own for that team
-- (versus.defaultRaise).
--
-- How a team's numbers are switched: every set key is taken out of its table (rawset to
-- nil) and served by the table's __index, which returns the value of the team acting
-- now (versus.use) or the shipped value when no team acts or the acting team does not
-- set it. So one team's number cannot be read while the other acts, whatever module
-- holds the table. Each read is counted by team: a key nothing reads while its team acts
-- (a module copied it into a local at import, or that team never reaches it) is how the
-- Gym tells a setting that changes nothing.
--
--   local versus = dofile("tools/gym/versus.lua")
--   local spec = versus.parse("level=pro;raise=apart", "A")
--   local v = versus.install({ A = specA, B = specB }, LEVEL_TO_CPU)
--   versus.use("A") ... versus.use(nil)
--   versus.policy(spec)   -- the raising policy, a name or a Gym-only function
local versus = {}

local pitch = tw.pitch
local huge = math.huge

versus.LEVELS = { beginner = true, club = true, pro = true }
versus.THROWERS = { cpu = true, human = true }

-- Gym-only raising policies (the engine's are tw.raising.policies). Each keeps a row
-- across the pitch a row: every kubb with a choice goes up on the same end, so kubbs
-- that lay side by side stand side by side. `away` raises each on the end away from the
-- centre line (deeper in the defender's half), `toward` on the end toward it. A kubb with
-- one choice (forced, or displaced with one end clear) goes where the rules put it.
versus.policies = {
	away = function(dec, ctx)
		local best, bestD = 1, huge
		for i, c in ipairs(dec.choices) do
			local d = pitch.fromBaseline(ctx.half, c.pose.y)
			if d < bestD - 1e-12 then best, bestD = i, d end
		end
		return best
	end,
	toward = function(dec, ctx)
		local best, bestD = 1, -huge
		for i, c in ipairs(dec.choices) do
			local d = pitch.fromBaseline(ctx.half, c.pose.y)
			if d > bestD + 1e-12 then best, bestD = i, d end
		end
		return best
	end,
}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- A spec string into { label, level, thrower, raise, sets = { { path, value } } }.
function versus.parse(str, label)
	local spec = { label = label, level = "club", thrower = "cpu", raise = "default", sets = {} }
	local seen = {}
	for part in (str or ""):gmatch("[^,;]+") do
		part = trim(part)
		if part ~= "" then
			local k, v = part:match("^([%w_%.]+)%s*=%s*(.-)$")
			if not k then error("versus: team " .. label .. ": not key=value: " .. part, 0) end
			if seen[k] then error("versus: team " .. label .. ": " .. k .. " given twice", 0) end
			seen[k] = true
			if k == "level" then
				if not versus.LEVELS[v] then error("versus: team " .. label .. ": level beginner, club or pro, got " .. v, 0) end
				spec.level = v
			elseif k == "thrower" then
				if not versus.THROWERS[v] then error("versus: team " .. label .. ": thrower cpu or human, got " .. v, 0) end
				spec.thrower = v
			elseif k == "raise" then
				if v ~= "default" and not (tw.raising.policies[v] or versus.policies[v]) then
					local names = {}
					for n in pairs(tw.raising.policies) do names[#names + 1] = n end
					for n in pairs(versus.policies) do names[#names + 1] = n .. " (gym)" end
					table.sort(names)
					error("versus: team " .. label .. ": no raising policy " .. v .. " (" .. table.concat(names, ", ") .. ")", 0)
				end
				spec.raise = v
			elseif k:find(".", 1, true) then
				local n = tonumber(v)
				if not n then error("versus: team " .. label .. ": " .. k .. " is not set to a number: " .. v, 0) end
				spec.sets[#spec.sets + 1] = { path = k, value = n }
			else
				error("versus: team " .. label .. ": unknown part " .. k .. " (level, thrower, raise or a tune path)", 0)
			end
		end
	end
	if spec.raise == "default" then spec.raise, spec.raiseDefault = versus.defaultRaise(spec.level, spec.thrower), true end
	return spec
end

-- A team's raising when its spec does not name one: what the engine does for such a
-- side (since 0.11.3, core/cpu.raising): the computer by its level, the human thrower
-- (a person whose kubbs the engine raises) by the engine's advice (cpu.advice); in
-- 0.11.3 both are apart at every level. An engine from before 0.11.3 (gym compare's
-- older ref, --engine) has no such table and raised every side apart, so its teams do.
function versus.defaultRaise(level, thrower)
	local cpu = tw.cpu
	if not (cpu and cpu.raising) then return "apart" end
	if thrower == "human" then return cpu.advice end
	return cpu.raisePolicy(level)
end

-- The raising policy the engine is given for this team: a name of tw.raising.policies,
-- or a Gym-only function.
function versus.policy(spec)
	return versus.policies[spec.raise] or spec.raise
end

local state = { current = nil }
versus.state = state

-- Which team's numbers the tune tables serve from now on: a team label, or nil (shipped).
function versus.use(label) state.current = label end

local function resolve(path)
	local keys = {}
	for k in path:gmatch("[^%.]+") do keys[#keys + 1] = k end
	local t = tw
	for k = 1, #keys - 1 do
		t = t[keys[k]]
		if type(t) ~= "table" then error("versus: " .. path .. ": no table at " .. table.concat(keys, ".", 1, k), 0) end
	end
	local last = keys[#keys]
	if type(t[last]) ~= "number" then error("versus: " .. path .. " is not a number in the engine", 0) end
	return t, last, keys
end

-- Puts both teams' numbers in the tune tables, switched by versus.use. levelToCpu: the
-- plan.levels keys the computer copies into its own level table (autothrow.cpuLevel),
-- served there too. Returns the entries: { [path] = { base, val = { A, B }, reads = { A, B, none } } }.
function versus.install(teams, levelToCpu)
	local entries, order = {}, {}
	local byTable = {}
	for _, lab in ipairs { "A", "B" } do
		for _, s in ipairs(teams[lab].sets) do
			local e = entries[s.path]
			if not e then
				local t, key, keys = resolve(s.path)
				e = { path = s.path, key = key, base = t[key], val = {}, reads = { A = 0, B = 0, none = 0 }, tables = { t } }
				if keys[1] == "plan" and keys[2] == "levels" and #keys == 4 and levelToCpu and levelToCpu[key] then
					local c = tw.autothrow.cpuLevel(keys[3])
					if c ~= t and type(c[key]) == "number" then e.tables[2] = c end
				end
				entries[s.path] = e
				order[#order + 1] = s.path
			end
			e.val[lab] = s.value
			if s.value == e.base then
				error(("versus: team %s sets %s to %s, the value it already has: that changes nothing"):format(lab, s.path, tostring(s.value)), 0)
			end
		end
	end
	for _, path in ipairs(order) do
		local e = entries[path]
		for _, t in ipairs(e.tables) do
			local map = byTable[t]
			if not map then
				if getmetatable(t) ~= nil then
					error("versus: " .. path .. ": its table has a metatable already; its numbers cannot be switched by team", 0)
				end
				map = {}
				byTable[t] = map
				setmetatable(t, {
					__index = function(_, k)
						local x = map[k]
						if not x then return nil end
						local who = state.current
						x.e.reads[who or "none"] = x.e.reads[who or "none"] + 1
						local v = who and x.e.val[who]
						if v == nil then v = x.base end
						return v
					end,
					__newindex = function(tt, k, v)
						local x = map[k]
						if x then x.base = v else rawset(tt, k, v) end
					end,
					__pairs = function(tt)
						local list = {}
						for k, v in next, tt do list[#list + 1] = { k, v } end
						for k in pairs(map) do list[#list + 1] = { k, tt[k] } end
						local i = 0
						return function()
							i = i + 1
							if list[i] then return list[i][1], list[i][2] end
						end, tt, nil
					end,
				})
			end
			map[e.key] = { e = e, base = t[e.key] }
			rawset(t, e.key, nil)
		end
	end
	return entries, order
end

return versus
