-- raising.policies.par (raise.par, raise.across): hand-made cases with a known answer,
-- legality, and the default policy unchanged. Team B defends (y 4 to 8); Team A throws
-- from y = 0 toward +y.
import "core/raising"
import "core/rules"
local raising, pitch = tw.raising, tw.pitch

local KING = { x = 0, y = 4, standing = true, angle = 0 }
local ALONG = math.pi / 2   -- a kubb lying along the throw

local function lying(x, y, a) return { x = x, y = y, standing = false, angle = a or 0 } end
local function standing(x, y) return { x = x, y = y, standing = true, angle = 0 } end

local function ctxFor(kubbs, except)
	local others = {}
	for i, p in ipairs(kubbs) do
		if i ~= except then others[#others + 1] = { id = "k" .. i, pose = p, kind = p.kind or "field" } end
	end
	return { half = "B", king = KING, others = others }
end

-- Raise every lying kubb in list order (as core/rules does, by id) with `policy`;
-- returns the list, now standing, and the choice made for each.
local function raiseAll(kubbs, policy)
	local made = {}
	for i, p in ipairs(kubbs) do
		if not p.standing then
			local ctx = ctxFor(kubbs, i)
			local dec = raising.options(p, ctx)
			local c = dec.choices[raising.choose(dec, ctx, policy)]
			kubbs[i] = { x = c.pose.x, y = c.pose.y, standing = true, angle = c.pose.angle }
			made[i] = c.which
		end
	end
	return kubbs, made
end

-- The field's exposure as par counts it: every pair, both views.
local function exposure(kubbs)
	local e = 0
	for i = 1, #kubbs do
		for j = i + 1, #kubbs do
			e = e + raising.parExposure(kubbs[i].x, kubbs[i].y, kubbs[j].x, kubbs[j].y, 1, 0, raising.tune)
		end
	end
	return e
end

test("par: a row lying flank to flank is kept a fence", function()
	local row = {}
	for i = 0, 4 do row[#row + 1] = lying(0.4 + 0.10 * i, 6.0, ALONG) end
	local up = raiseAll(row, "par")
	for i = 2, #up do expect.near(up[i].y, up[1].y, 1e-9, "kubb " .. i .. " level with the first") end
	-- apart staggers the same row into depth
	local row2 = {}
	for i = 0, 4 do row2[#row2 + 1] = lying(0.4 + 0.10 * i, 6.0, ALONG) end
	local ap = raiseAll(row2, "apart")
	local staggered = false
	for i = 2, #ap do if math.abs(ap[i].y - ap[1].y) > 0.1 then staggered = true end end
	expect.truthy(staggered, "apart staggers it")
	expect.truthy(exposure(up) < exposure(ap), "par leaves less exposure than apart")
end)

test("par: kubbs lying in a line along the throw are spread", function()
	local line = { lying(1, 5.0, ALONG), lying(1, 5.2, ALONG) }
	local up = raiseAll(line, "par")
	expect.near(up[1].y, 4.89, 1e-9, "the near one on its near end")
	expect.near(up[2].y, 5.31, 1e-9, "the far one on its far end")
	-- three in a line, 25 cm apart: the outer two go outward
	local three = raiseAll({ lying(-1, 5.0, ALONG), lying(-1, 5.25, ALONG), lying(-1, 5.5, ALONG) }, "par")
	expect.near(three[1].y, 4.89, 1e-9)
	expect.near(three[3].y, 5.61, 1e-9)
end)

test("par: a kubb that can step out of another's line does, where apart would not", function()
	-- standing kubbs at (1, 5.5) and (1.4, 5.2); the lying kubb's ends are (1.04, 5.2), in
	-- front of the first and 30 cm short of it, and (1.26, 5.2), level with the second
	local kubbs = { standing(1, 5.5), standing(1.4, 5.2), lying(1.15, 5.2, 0) }
	local ctx = ctxFor(kubbs, 3)
	local dec = raising.options(kubbs[3], ctx)
	expect.eq(dec.mode, "choice")
	expect.eq(dec.choices[raising.choose(dec, ctx, "apart")].which, 2, "apart: farther from the nearest")
	expect.eq(dec.choices[raising.choose(dec, ctx, "par")].which, 1, "par: out of the line")
end)

test("par: the inside double (ko-2013-fence p1.8 to p1.10)", function()
	-- four kubbs lying in an X about (0.8, 6), each 15 cm out along a diagonal. All four
	-- stood outward make two columns of two, each a double down the pitch. Hodges stands
	-- two toward the middle: one easy double, two kubbs alone, a baton more. Here par
	-- stands one inward, which breaks one column the same way (one double, two alone)
	-- with the double farther apart.
	local r = 0.15
	local function x4()
		local out = {}
		for _, a in ipairs { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 } do
			out[#out + 1] = lying(0.8 + r * math.cos(a), 6 + r * math.sin(a), a)
		end
		return out
	end
	-- pairs one baton could take (exposure past a half), counted greedily
	local function doubles(k)
		local used, n = {}, 0
		for i = 1, #k do
			for j = i + 1, #k do
				if not used[i] and not used[j]
					and raising.parExposure(k[i].x, k[i].y, k[j].x, k[j].y, 1, 0, raising.tune) > 0.5 then
					used[i], used[j], n = true, true, n + 1
				end
			end
		end
		return n
	end
	local outward = raiseAll(x4(), function() return 1 end)
	expect.eq(doubles(outward), 2, "all outward: two doubles, two batons")
	local up = raiseAll(x4(), "par")
	expect.eq(doubles(up), 1, "par: one double and two kubbs alone, three batons")
	expect.truthy(exposure(up) < exposure(outward), "less exposure than all outward: "
		.. exposure(up) .. " against " .. exposure(outward))
end)

test("par: a base kubb and kubbs of the other half do not count", function()
	-- a base kubb on the baseline right behind one end would be a pair if it counted
	local kubbs = { { x = 1, y = 8, standing = true, angle = 0, kind = "base" }, lying(1.11, 7.6, 0) }
	local ctx = ctxFor(kubbs, 2)
	local dec = raising.options(kubbs[2], ctx)
	expect.eq(raising.choose(dec, ctx, "par"), raising.choose(dec, ctx, "apart"), "a tie, so apart's")
end)

test("par never returns an illegal choice", function()
	-- a fixed pseudo-random stream (no math.random in the engine's tests either)
	local seed = 12345
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local asked = 0
	for _ = 1, 300 do
		local kubbs = {}
		local n = 2 + math.floor(rnd() * 9)
		local cx, cy = (rnd() - 0.5) * 4.6, 4.1 + rnd() * 3.8
		for i = 1, n do
			local p = lying(cx + (rnd() - 0.5) * 0.8, cy + (rnd() - 0.5) * 0.8, rnd() * 2 * math.pi)
			if rnd() < 0.3 then p.standing = true end
			kubbs[i] = p
		end
		for i, p in ipairs(kubbs) do
			if not p.standing then
				local ctx = ctxFor(kubbs, i)
				local dec = raising.options(p, ctx)
				if #dec.choices > 0 then
					local k = raising.choose(dec, ctx, "par")
					expect.truthy(math.type(k) == "integer" and k >= 1 and k <= #dec.choices,
						"choice " .. tostring(k) .. " of " .. #dec.choices)
					asked = asked + 1
					local c = dec.choices[k]
					kubbs[i] = { x = c.pose.x, y = c.pose.y, standing = true, angle = c.pose.angle }
				end
			end
		end
	end
	expect.truthy(asked > 300, "asked " .. asked)
end)

test("par: the default policy is still apart", function()
	expect.eq(tw.rules.new({}).raisePolicy, "apart")
	local kubbs = { standing(1, 5.5), standing(1.4, 5.2), lying(1.15, 5.2, 0) }
	local ctx = ctxFor(kubbs, 3)
	local dec = raising.options(kubbs[3], ctx)
	expect.eq(raising.choose(dec, ctx), raising.choose(dec, ctx, "apart"))
	expect.eq(raising.choose(dec, ctx), 2)
end)
