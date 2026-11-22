# Plays: the king

The throw that ends the game. One piece of geometry by Josh Feathers (`ko-2012-king`),
which he says he has not dared use in a tournament, and the roles piece.

Every `Levels` line is a proposal of ours, not a source's.

## king.corner: The king from the corner

- **When:** king, the shot from the baseline, with a baton to spare.
- **Play:** Throw from the corner of the baseline on the throwing-arm side, not from the
  middle.
- **Why:** By his geometry the corner shot is about 18% longer (4.7 m against 4 m) and
  shows about 41% more of the king, since the king is seen across its diagonal. The feet
  must be in bounds but the release may be outside the pitch, which widens the view
  further. A throw off by the same amount glances the king from the corner where it would
  miss altogether from the middle.
- **Says who:** ko-2012-king#p1.7, ko-2012-king#p1.9, ko-2012-king#p1.10,
  ko-2012-king#p1.13, ko-2012-king#p1.15, ko-2012-king#p1.19 (Josh Feathers). The rules
  behind his point: the king is thrown at from behind the baseline, and only the
  thrower's feet (supporting areas) must stay behind it and between the sidelines
  (web-us-rules-v4#p12.1, web-us-rules-v4#p5.3; in the 2011 rules the sidelines run on
  to the horizon, web-us-rules-v2#p5.2).
- **Basis:** player
- **Against:** his own practice. Every tournament king shot he has seen was head-on,
  his included; he has seen corner shots glance the king and spin it without toppling it;
  and he allows his sums or his guess about force may be wrong (ko-2012-king#p1.1,
  ko-2012-king#p1.18, ko-2012-king#p1.20, ko-2012-king#p1.21). Geometry with no result
  behind it.
- **Levels:** Proposed: none, until the Gym shows it topples the king more often.
- **Engine:** not modelled (0.11.0). The king is thrown at from straight in front, from
  the middle of the baseline.
- **Gym:** `g.kingHit`, corner against middle. The physics can answer this where the
  author could not.

## king.spare: Keep two batons for the king

- **When:** king, deciding whether to throw at the last base kubb or hold a baton.
- **Play:** A thrower who misses the king often wants two batons left for it.
- **Why:** He missed it twice in one match and it cost his team a place in the last
  four. Teams give the shot to one player who is sure of it and calm under pressure.
- **Says who:** ko-2012-king#p1.4 (Josh Feathers); ko-2017-roles#p1.8 (Christopher
  Jones)
- **Basis:** player
- **Against:** nothing found. `levels.value` prices the king at 1.2 batons across all
  competitive players (ko-2014-advantage2#p1.10), so on average one baton is not quite
  enough.
- **Levels:** Proposed: a matter of each level's own king rate. PLAY.md's targets are
  40 to 60% for a beginner, 62 to 75% at club and 84 to 96% at pro.
- **Engine:** not modelled (0.11.0). The computer throws at whatever the rules allow
  next and never weighs the batons it has left.
- **Gym:** `g.kingHit`, and games lost with the king standing.
