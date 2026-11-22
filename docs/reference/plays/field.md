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
  Görlitz). The rules let a thrower stand anywhere along the throwing line between the
  sidelines (web-us-rules-v4#p5.3, web-us-rules-v2#p11.1, web-vm-rules-2003#p5.1).
- **Basis:** player, coach
- **Against:** nothing found. At a lone kubb the engine's default stance, straight
  behind it, is what `field.angle` argues against.
- **Levels:** Proposed: club and pro. It is the difference between a group and a double.
  Since 0.12.0 the pro computer knows it; club does not (the Gym found no gain there,
  and club plays as in 0.11.2 until it is retuned as a whole: owner-2026-11-21#s6).
- **Engine:** modelled at pro only (0.12.0, `core/cpu` lineChoice; `cpu.tune.line`). For each
  standing field kubb the computer tries the stance straight behind it and, for each kubb
  beyond it within 1.2 m, the point on its throwing line (the baseline or the advantage
  line, inside the stakes) that puts the two one behind the other. It reads the lane along
  that true line (`read.lineLane`: within 7 cm across, to 0.6 m beyond), weighs the kubbs
  behind the front one as `raise.par` weighs a pair, and scores the stance by that times
  the chance of hitting the front kubb from there (the nerves and the swing's pull at that
  range), never a line through the king, past a kubb in front, or within 0.3 m of a field
  kubb in its own half (II.B.11, web-us-rules-v4#p6.3: touching one forfeits the baton);
  when straight behind
  is no good it steps along the line. At ten field kubbs a decision makes at most 55 lane
  tests, and four more for each kubb whose straight stance is no good. In the Gym (300
  seeds, seeds 1 and 2) it wins 54.8% and 56.9% alone at pro and 59.5% and 61.4% on top
  of `inkast.depth`; at club it adds nothing (52.0% and 50.5% on top of `inkast.depth`,
  53.1% and 50.6% alone), so club does not know it. The second half of the play (hit
  the front kubb on the side that sends the baton on) is not modelled.
- **Gym:** `g.field2`, `g.field3`, first-baton take by field size.

## field.angle: Step aside to see a lone kubb corner-on

- **When:** field, a single kubb with no other in line behind it, standing square to the
  pitch or at a slight angle.
- **Play:** Step along the throwing line, about a metre at a field kubb 4 m out, until the
  kubb is seen across a corner rather than face-on, and throw from there.
- **Why:** A kubb seen corner-on is a wider target than one seen face-on (his example: 9 cm
  against 7 cm, about 30% more), and the step adds little length: a metre aside at
  4.25 m makes the throw 4.36 m, 11 cm longer. Kids want to throw straight at what they
  see; he tells them to come over and find the wider view, above all at a single kubb.
- **Says who:** yt-KnLTnKVVPMg#0:18, yt-KnLTnKVVPMg#0:21, yt-KnLTnKVVPMg#1:06,
  yt-KnLTnKVVPMg#1:29 (an unnamed coach in a Team Kubboom vest). The rules allow any
  stance along the line between the sidelines (web-us-rules-v4#p5.3). Every number is
  his arithmetic, worked aloud; none is measured on the pitch, and no throw from either
  place is shown. Our own check: a square kubb seen from a metre aside at 4.25 m is
  turned about 13 degrees and shows about 8.4 cm, some 20% more than face-on (his 9 cm
  needs about 20 degrees); at 8 m, 2 m aside gives about 14 degrees and 21%, close to
  his 15 to 20% (yt-KnLTnKVVPMg#1:50, yt-KnLTnKVVPMg#2:09). A wider target is not by
  itself a surer topple.
- **Basis:** coach, estimate
- **Against:** nothing found. The engine's straight-behind stance (`field.line`'s Engine
  line, `field.roles`) is the default this argues against. Raised kubbs keep the facing
  they lay with (Q15, answered), so how square a lone kubb stands is set by the inkast's
  bounce, not by the defender.
- **Levels:** Proposed: club and pro; the coach teaches it to beginners. The same step
  at a base kubb from 8 m is `baseline.angle`.
- **Engine:** not modelled (0.13.0). At a single kubb the computer stands straight behind
  it (`plan.stance`); `field.line` moves the stance only to line two kubbs up. The
  physics has the kubb as a box, so a corner and a face already meet a baton
  differently.
- **Gym:** needs a row: first-baton hits on a lone field kubb, by the angle the kubb is
  seen at from the stance (the same row `inkast.single` needs).

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

## field.drive: Low and hard into a close group

- **When:** field, a baton at the front kubb of a group (another standing field kubb within
  about 45 cm of it), the front kubb within about 5 m of the stance: from the advantage
  line above all, and at a group 4 to 5 m out from the baseline.
- **Play:** Throw low and hard, flat or a little down, the baton straight out of the hand
  without a flip, into the front kubb's face, so the struck kubb is driven into the ones
  behind it and the baton carries on into the group.
- **Why:** A tight group passes a blow on; the harder and lower the baton meets the front
  kubb, the more it carries into the next. At a group close in a soft lob meets one kubb
  and stops. The owner's two reports are of the default arc failing exactly there.
- **Says who:** owner-2026-11-22#s1, owner-2026-11-22#s2, owner-2026-11-22#s3 (Jamie);
  ko-2017-blasting#p1.5 (Kyle Weakland: power matters most against a tight group);
  ko-2017-roles#p1.5 (a blaster photographed crouched low in his follow-through)
- **Basis:** owner, player
- **Against:** ko-2017-blasting#p1.6, ko-2017-blasting#p1.23: Weakland throws at light to
  medium power because he cannot throw hard and still hit, and a miss is the worst result
  (`field.sure`). ko-2017-blasting#p1.3: his damage comes from the baton whipping round
  after contact, not from one kubb driven into another. `field.corner` and `field.power`
  are the finesse half of the same choice. Q18 (closed: one line for every target,
  lowered).
- **Levels:** club and pro for the computer from 0.17.0 (`cpu.tune.drive`), not beginner
  or kid. A person gets it as the default close in from 0.16.0 (one line for every
  target), at every level.
- **Engine:** the person's throw from 0.16.0 (docs/notes/throw.md "The drive": ARC under
  half past 5, the floor, no flip, the lowered default line). The computer's from 0.17.0 at
  club and pro (`core/cpu` decideBaton, `cpu.tune.drive`): every baton but the king shot on a
  person's default line (`plan.arcFor`) instead of the line before (`plan.sharedArcFor`),
  named `field.drive` when the arc at a field kubb is a drive. Built in 0.16.0 for a close
  group only; the whole line beat that. On two hand-written positions after the owner's
  reports (`tools/driveprobe.lua`, 300 jittered throws) the drive fells 1.93 and 1.95 kubbs
  a baton against 1.60 and 1.67 on the old default; the MuJoCo reference agrees on what
  such throws fell (docs/notes/throw.md "The force carried into a group").
- **Gym:** `gym versus`, 300 seeds both ways round, grass. 0.16.0 (the group drive,
  switched off): club with it against club without 62.1% (58.8 to 65.4), pro 60.3% (57.1 to
  63.4). 0.17.0: the line for every baton against the group drive, both teams driving,
  56.0% (52.7 to 59.3) at club and 55.0% (51.9 to 58.1) at pro. Switched on (with the king
  shot by level): club's three or more 1.9% to 3.7% (3 to 7), cleared 70.9% to 74.7%; pro's
  three or more 6.8% to 9.9% (12 to 18), turns 12.3 to 10.7, cleared 78.5% to 84.5%;
  club's two 16.7% (8 to 13) stays over its row. The recorded hand beats club 61.3%:
  open (docs/notes/gym.md "Where 0.17.0 stands").

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
