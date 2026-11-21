# Plays: batons at the field kubbs

Which kubb, from where, and how the baton should meet it. Mostly from Kyle Weakland's
piece on blasting (`ko-2017-blasting`), with the roles piece and the inkastare who place
kubbs for these throws. Several of his points rest on video clips nobody has watched yet.

Every `Levels` line is a proposal of ours, not a source's.

## field.sure: One sure kubb before three hoped for

- **When:** field, any baton at a group.
- **Play:** Throw at the power you can hit with. Take the kubb you are sure of before
  the throw that might take three.
- **Why:** A complete miss is the worst result of a baton: it costs the kubb, unsettles
  the next throw and spreads to the team. He throws at light to medium power and accepts
  leaving a kubb a harder throw would have taken. A baton has a value that depends on the
  kubbs in play, and none should be thrown away.
- **Says who:** ko-2017-blasting#p1.6, ko-2017-blasting#p1.7, ko-2017-blasting#p1.8,
  ko-2017-blasting#p1.9, ko-2017-blasting#p1.23 (Kyle Weakland)
- **Basis:** player
- **Against:** nothing found. `levels.value` puts numbers on what a baton is worth.
- **Levels:** Proposed: club and pro. A beginner throws as hard at one kubb as at five.
- **Engine:** not modelled (0.11.0). The computer aims at the lane with the most kubbs
  and has no measure of the chance it misses everything.
- **Gym:** `g.fieldMiss`.

## field.line: Stand where the kubbs line up

- **When:** field, two or more kubbs that could stand one behind another from somewhere
  along the throwing line.
- **Play:** Move along the line until they are straight ahead, then throw through the
  front one. If no stance lines them up, hit the front kubb on the side that sends the
  baton on toward the next.
- **Why:** The baton carries on along its line, over or off the first kubb and into the
  one behind. The inkastare builds for this throw: a wall along the sideline that the
  baton thrower throws down.
- **Says who:** ko-2017-blasting#p1.17, ko-2017-blasting#p1.18, ko-2017-blasting#p1.20
  (Kyle Weakland); yt-Io-rxbSB3Ns#1:30 (Eric Anderson); kn-drill-2012#p4.13 (Björn
  Görlitz)
- **Basis:** player, coach
- **Against:** nothing found.
- **Levels:** Proposed: club and pro. It is the difference between a group and a double.
- **Engine:** built, switched off (0.11.3, `core/cpu` lineChoice; `cpu.tune.line`, no level
  knows it). In play the stance is still straight behind the target, clamped to the line's
  ends (`plan.stance`), and a lane counts only kubbs within 7 cm across and 0.6 m behind
  the front one as seen from straight on (`laneHalf`, `laneDeep`): two kubbs on a
  diagonal are two singles to the computer. Switched on, for each standing field kubb the
  computer tries the stance straight behind it and, for each kubb beyond it within 1.2 m,
  the point on its throwing line (the baseline or the advantage line, inside the stakes)
  that puts the two one behind the other. It reads the lane along that true line
  (`read.lineLane`: within 7 cm across, to 0.6 m beyond), weighs the kubbs behind the
  front one as `raise.par` weighs a pair, and scores the stance by that times the chance
  of hitting the front kubb from there (the nerves and the swing's pull at that range),
  never a line through the king, past a kubb in front, or within 0.3 m of a field kubb in
  its own half (II.B.11: touching one forfeits the baton); when straight behind is no
  good it steps along the line. At ten field kubbs a decision makes at most 55 lane
  tests, and four more for each kubb whose straight stance is no good. In the Gym (300
  seeds, seeds 1 and 2), switched on, it wins 54.8% and 56.9% alone at pro and 59.5% and
  61.4% on top of `inkast.depth`; at club it adds nothing (52.0% and 50.5% on top of
  `inkast.depth`, 53.1% and 50.6% alone). The second half of the play (hit the front kubb
  on the side that sends the baton on) is not modelled.
- **Gym:** `g.field2`, `g.field3`, first-baton take by field size.

## field.corner: Meet the kubb high, with the baton half turned

- **When:** field, a baton at the front kubb of a group.
- **Play:** Hit the top front corner of the kubb with the baton about halfway between
  upright and flat.
- **Why:** The baton then tumbles over the top and whips round into the rest, and the
  kubb is driven back into the group. Hit square with the baton's end, or low, the baton
  stops dead and takes one kubb. The top is where a kubb is easiest to move.
- **Says who:** ko-2017-blasting#p1.3, ko-2017-blasting#p1.12, ko-2017-blasting#p1.13,
  ko-2017-blasting#p1.14, ko-2017-blasting#p1.15, ko-2017-blasting#p1.22 (Kyle Weakland);
  ko-2017-dickinson#p1.11 (Phil Dickinson)
- **Basis:** player
- **Against:** Q14. PLAY.md has the half-turn throw arriving low, with top hits one in
  twenty or thirty (owner). ko-2017-dickinson#p1.10 trains a full turn with the head
  striking square.
- **Levels:** Proposed: none. In the Gym this arrival took fewer kubbs at a group than
  the upright body hit the engine already makes (Q14). It stays here as what a strong
  player says, not as something to build until the physics has been checked.
- **Engine:** not modelled (0.11.0). The baton's centre is aimed through the kubb at 0.3
  of its height (`plan.tune.aimHeightShare`), the same for a single and a group, and the
  tumble is set by the level, not by the shot.
- **Gym:** the forensics already record how a baton arrives at a kubb (docs/notes/gym.md,
  "Arrival"); needs take-two-or-more by arrival height and baton angle.

## field.power: Hard at a tight group, soft at a loose one

- **When:** field, choosing how hard to throw at a group.
- **Play:** A tight group needs power. A loose one needs placement and a baton that
  turns into it.
- **Why:** Kubbs that touch pass the blow on. Kubbs apart have to be reached by the
  baton itself.
- **Says who:** ko-2017-blasting#p1.5 (Kyle Weakland)
- **Basis:** player
- **Against:** nothing found. One sentence from one player.
- **Levels:** Proposed: pro, and not before a second source.
- **Engine:** not modelled (0.11.0). The arc and speed come from the distance alone.
- **Gym:** nothing yet.

## field.roles: The group first, then the ones left

- **When:** field, a group and one or more single kubbs.
- **Play:** The first batons go at the group. The single kubbs left are taken after, one
  baton each, by the thrower who does not miss.
- **Why:** Teams divide the throws this way: a blaster who takes several at once, then a
  cleanup thrower for the must-hit singles, then the 8 m thrower. Groups of three or four
  come up more often than big ones, and taking one with a baton or two early saves the
  batons that decide a game.
- **Says who:** ko-2017-roles#p1.4, ko-2017-roles#p1.6, ko-2017-roles#p1.7 (Christopher
  Jones); ko-2018-practice#p1.3 (Kyle Weakland)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: every level.
- **Engine:** modelled in part (0.11.0). The lane with the most kubbs is thrown at
  first, with the nearest front kubb on a tie. Every thrower on a team throws alike:
  there are no roles.
- **Gym:** `g.btc`.
