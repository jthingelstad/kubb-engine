-- A straight stroke is spatial: one rail length is 180 backswing degrees.
-- The host supplies ordered positions in rail lengths, relative to the grip.
-- Interpolate where the stroke crossed its starting line, even if the next
-- sample is far into the follow-through. Speed and display rate are immaterial.
import "core/swing"
local straight = {}
local function rounded(x) return math.floor(x * 1024 + 0.5) / 1024 end

function straight.frame(s, points)
	local event
	for _, p in ipairs(points) do
		if p.phase == "down" then
			tw.swing.reset(s.swing)
			s.straight = { x = 0, y = 0, peak = 0 }
			event = nil
		elseif s.straight then
			local g = s.straight
			if p.phase ~= "cancel" then
				local x, y = p.x, p.y
				g.peak = math.max(g.peak, math.min(180, rounded(y * 180)))
				if g.peak >= tw.swing.tune.startBackDeg and g.y > 0 and y <= 0 then
					local cross = rounded(g.x + (x - g.x) * g.y / (g.y - y))
					local offset = math.min(6, math.max(0, math.abs(cross) - 0.08) * 8)
					s.strokeResult = { back = g.peak, releaseAngle = s.release, flickFrac = 1,
						smoothness = 1, shake = 0, pull = 1, how = "straight",
						lineDeg = cross < 0 and -offset or offset }
					s.straight = nil
					return "release"
				end
				if s.swing.onArm then s.swing.onArm(-math.max(0, g.y) * 180, -math.max(0, y) * 180) end
				g.x, g.y = x, y
				s.swing.back, s.swing.arm = g.peak, -y * 180
				s.swing.phase = g.peak >= tw.swing.tune.startBackDeg and "winding" or "idle"
			end
			if p.phase == "cancel" or p.phase == "up" then
				s.straight = nil
				tw.swing.reset(s.swing)
				s.swing.back = 0
				event = "letdown"
			end
		end
	end
	return event
end
tw.web = tw.web or {}
tw.web.straight = straight
