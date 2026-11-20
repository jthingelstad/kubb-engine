-- The computer's target label (a play-test match: four batons of one turn
-- named kubb a4 while they were aimed at a3). Its circle moves to the kubb
-- autothrow.choose aims at; the label must name that kubb, not the one the
-- circle was on before (throw.showAim).
import "session/session"
import "session/json"
import "core/autothrow"
tw.web.session.useTune("pointer")
local session = tw.web.session

local START = { year = 2026, month = 11, day = 20, hour = 10, min = 0 }

test("every computer baton names the piece it is aimed at", function()
	local batons, wrong, onLane = 0, 0, 0
	for _, seed in ipairs { 3, 7, 11, 19 } do
		local s = session.new { mode = "match", cpu = "both", seed = seed, start = START, maxTurns = 30 }
		local guard = 0
		while s:need().kind ~= "over" and guard < 2000 do
			guard = guard + 1
			-- the set-up the computer chose from: the one in force when its aim
			-- first showed
			local pos, kind
			local o
			for _ = 1, 600 do
				if not pos and s.ts.mode == "aim" then
					pos, kind = {}, s.setup.kind
					for _, p in ipairs(s.setup.pieces) do pos[p.id] = p end
				end
				o = s:frame { dt = 1 / 60 }
				if o.action then break end
			end
			assert(o and o.action, "the computer did not throw")
			local a = o.action
			if kind ~= "toss" and a.how == "baton" then
				batons = batons + 1
				local p = a.target.on and pos[a.target.on]
				if not (p and p.y == a.target.y) then
					wrong = wrong + 1
					if wrong <= 3 then
						print(string.format("      seed %d throw %d: on %s at y %s, aimed at y %.3f", seed, a.seq,
							tostring(a.target.on), p and string.format("%.3f", p.y) or "-", a.target.y))
					end
				elseif a.target.x ~= p.x then
					onLane = onLane + 1   -- aimed across the middle of a lane of kubbs
				end
			end
		end
	end
	expect.truthy(batons > 100, "batons thrown: " .. batons)
	expect.eq(wrong, 0, "batons whose label names another piece")
	print(string.format("      %d batons, every label right (%d aimed across a lane)", batons, onLane))
end)
