# Plays: the inkast

Where the thrown kubbs should rest, and how they are thrown. The first plays, drawn from
the two sources observed so far: fifteen inkastare interviewed in 2011
(`kn-drill-2012`) and one coach's lesson (`yt-Io-rxbSB3Ns`). Both are about the drilled
inkast and neither is recent, so read every play here with Q10 in mind.

Every `Levels` line is a proposal of ours, not a source's, until Jamie settles it.

## inkast.corner: Build in the basket

- **When:** inkast, two or more kubbs in hand.
- **Play:** Put the group in the basket: the corner where the centre line meets a
  sideline. A right-hander uses the right corner.
- **Why:** Four reasons, from different players. A kubb on a line can only be raised
  into the pitch, so the defender loses the choice of end and the group stays tight. The
  corner is the furthest short spot from the king. A kubb that gets away from there goes
  out and is thrown again. And a right-hander's natural cut runs left to right into the
  sideline, with the baton thrower then able to throw down the line of kubbs.
- **Says who:** kn-drill-2012#p2.2 (Niklas Ahlgren); kn-drill-2012#p3.6,
  kn-drill-2012#p3.7, kn-drill-2012#p3.8 (Josh Feathers); kn-drill-2012#p6.8 (Simon
  Pettersson); kn-drill-2012#p3.20 (Scott Forster); yt-Io-rxbSB3Ns#0:35,
  yt-Io-rxbSB3Ns#1:04, yt-Io-rxbSB3Ns#1:30 (Eric Anderson); pk-drilling#p1.5,
  pk-drilling#p1.6, pk-drilling#p1.7, pk-drilling#p1.8 (Garrick van Buren);
  ko-2018-practice#p1.4 (Kyle Weakland). The rule behind the first reason: a kubb that
  can be raised in bounds must be, and half in is in (web-us-rules-v4#p7.5,
  web-us-rules-v4#p7.2). The German and Belgian rules ask for a kubb wholly inside
  once raised (web-dkb-rules-2025#p4.1, web-kf-rules-2026#p20.2), which narrows the
  margin on a line (Q10).
- **Basis:** player, coach
- **Against:** nothing found for two or more kubbs on where the group goes. Where the
  inkastare stands to build it is another choice (`inkast.stance`, Q17). For one kubb see
  `inkast.single`.
- **Levels:** Proposed: pro and club always. Beginner and kid do not aim for a corner.
- **Engine:** modelled in part (`cpu.basket`; `autothrow.basket` until 0.11.1). It picks the
  corner that already holds more field kubbs and flips a coin on a tie. It does not know
  the thrower's hand, and it stays 0.6 m inside the sideline (`basketX`) and, from 1.2.0,
  0.45 m past the centre line at club and 0.3 m at pro (`inkast.<level>.basketY`; 0.75 m
  before, and still at beginner), so its kubbs do not lie on a line. A kubb out for now
  does not count for a corner (`read.inNow`, 1.2.0).
- **Gym:** needs a row: thrown kubbs resting on a line.

## inkast.stance: Work along the baseline as the group grows

- **When:** inkast, a group already lies in the basket and has grown in from the
  sideline, so a kubb thrown from by the sideline must be cut back across the body.
- **Play:** Move along the baseline toward the middle, a metre or so, and as far as level
  with the king, then throw at the open side of the group and let the natural cut (left
  to right for a right-hander) bring the kubb in.
- **Why:** From by the sideline the easy cut runs toward the sideline, and gets harder
  the further the group reaches into the field; a kubb thrown across the body and cut is
  hard to bring back, and sticks out from the group or goes out. From further along the
  line the same cut runs into the group. The coach has worked on standing as far in as
  the king for a couple of years. No two groups are alike: look, weigh the risk, then go.
- **Says who:** yt-993xiTqXtYw#0:08, yt-993xiTqXtYw#0:16, yt-993xiTqXtYw#0:28,
  yt-993xiTqXtYw#0:47, yt-993xiTqXtYw#1:02, yt-993xiTqXtYw#1:27, yt-993xiTqXtYw#2:02
  (Eric Anderson). The rules fix only that the inkastare's feet stay behind the baseline
  and between the sidelines (web-us-rules-v4#p6.4). Nothing is thrown in the video:
  every cut is his word and a kubb rolled by hand (yt-993xiTqXtYw#1:30), and his feet
  are never shown.
- **Basis:** coach
- **Against:** Q17. The same coach's earlier lesson has a right-hander inkast from near
  the right sideline (yt-Io-rxbSB3Ns#0:35, yt-Io-rxbSB3Ns#0:43).
- **Levels:** Proposed: pro. Club inkasts from where it started.
- **Engine:** modelled in part, by accident (0.13.0). The computer's inkastare stands
  straight behind each spot it aims at (`plan.stance` from `autothrow`), so as the spot
  moves in from the sideline the stance moves with it, and it never throws across the
  body. It never stands further in than the spot to throw across at it, and its cut is
  always one tap toward the sideline (`inkast.steer`).
- **Gym:** needs a row: how far the later kubbs of a group rest from their marks, by how
  far the group reaches in from the sideline.

## inkast.single: One kubb does not go to the corner

- **When:** inkast, one kubb in hand (two, by the situation).
- **Play:** Aim midway between the king and the centre line's pin: about a metre in
  from the sideline, not on it.
- **Why:** Two sources, two reasons. The player: there is a small chance it settles
  behind the pin, which then shields it from a baton; with two or more the corner is
  worth its risk. The coach: a kubb thrown right down the sideline leaves a straight
  shot, and one about a metre in has "both sides to play with", which we read as batons
  having to come at it from an angle either way (the reading is ours, his gesture
  only). He teaches it to kids and new players, especially for a single kubb.
- **Says who:** kn-drill-2012#p3.11 (Josh Feathers); yt-KnLTnKVVPMg#0:33,
  yt-KnLTnKVVPMg#0:48, yt-KnLTnKVVPMg#1:29, yt-KnLTnKVVPMg#2:27, yt-KnLTnKVVPMg#2:37 (an
  unnamed coach in a Team Kubboom vest) That the two places agree is our arithmetic:
  midway between the king and the pin on a 5 m pitch is 1.25 m in, against his round
  metre. Neither source measured it.
- **Basis:** player, coach, estimate
- **Against:** nothing found. The coach's own demonstration kubb came to rest by a stake
  touching nothing (yt-KnLTnKVVPMg#0:57), and the reasons the two give are different.
- **Levels:** Proposed: club and pro. The coach teaches it to beginners, so a beginner
  may aim there too, though not reliably.
- **Engine:** not modelled (0.13.0). One kubb goes to the basket like any other, which
  sits 0.6 m inside the sideline and, from 1.2.0, 0.45 m (club) or 0.3 m (pro) past the
  centre line (`basketX`, `inkast.<level>.basketY`): already off the line, but nearer it
  than either source.
- **Gym:** needs a row: first-baton hits on a lone field kubb, by where it stands.

## inkast.first: The first kubb is the marker

- **When:** inkast, three or more kubbs in hand, the first kubb.
- **Play:** Drill the first kubb to stop where it lands, with no roll, on or beside the
  line. Throw the rest off it.
- **Why:** It marks the spot for every later throw and is the cushion that stops kubbs
  which would otherwise roll out. A kubb on the line is forced in bounds. One player uses
  a different throw for it: very little spin, stable flight.
- **Says who:** kn-drill-2012#p3.12, kn-drill-2012#p3.14 (Josh Feathers);
  kn-drill-2012#p3.21 (Scott Forster); kn-drill-2012#p4.8 (Björn Görlitz);
  kn-drill-2012#p2.3 (Niklas Ahlgren); yt-Io-rxbSB3Ns#8:04 (Eric Anderson)
- **Basis:** player, coach
- **Against:** on the spin only. Görlitz gives the first kubb very little; Phil Dickinson
  spins the first few harder and the later ones less (ko-2017-dickinson#p1.8). And the
  coach's own lone first kubb, thrown with his lean, ran on about half a kubb-length
  after landing (yt-Io-rxbSB3Ns#8:32): no dead stop in the one throw shown.
- **Levels:** Proposed: pro. Club tries and lands it less often.
- **Engine:** modelled in part (0.11.0). Later kubbs are aimed off the innermost kubb
  already lying by the basket (`cpu.spot`, `read.innermostLying`). The first kubb is
  thrown like the others, with the same spin: there is no dead first drill.
- **Gym:** needs a row: how far the first kubb rests from its marker.

## inkast.roll: Later kubbs roll into the ones already down

- **When:** inkast, a kubb already lies in the basket.
- **Play:** Land just short of or beside the group and let the kubb kick or roll into
  it, so each kubb is stopped by the last. Most of the time a light cut, not a big one.
- **Why:** Each kubb is stopped by the ones before it, so the group ends close together
  and the kubbs do not run out of bounds. In the coach's thrown demonstrations a kubb
  spinning nose down lands just short of the group on the thrower's side and hops on
  half to one kubb-length into it, mostly along its line and a little to one side,
  ending beside or nearly against a kubb already down; no throw shown kicks far
  sideways.
- **Says who:** kn-drill-2012#p2.10 (Josef Björklund); kn-drill-2012#p3.21 (Scott
  Forster); kn-drill-2012#p4.9 (Björn Görlitz); kn-drill-2012#p5.1, kn-drill-2012#p5.2
  (Marcus Hansson); kn-drill-2012#p5.15 (Samuel Hufschmid); yt-Io-rxbSB3Ns#1:13,
  yt-Io-rxbSB3Ns#5:07, yt-Io-rxbSB3Ns#7:09, yt-Io-rxbSB3Ns#7:10, yt-Io-rxbSB3Ns#8:35
  (Eric Anderson); the run on after landing also yt-Io-rxbSB3Ns#4:59. That a thrown kubb
  knocking another leaves both where they rest is the rule (web-us-rules-v4#p6.5).
- **Basis:** player, coach
- **Against:** Q12. Two players prefer a kubb that lands and stays: kn-drill-2012#p3.1
  (Terry Ekelöf), kn-drill-2012#p4.2 (Eric Goplin).
- **Levels:** Proposed: pro and club. A beginner's kubb has no spin and is not aimed at
  another.
- **Engine:** modelled (0.11.0): club and pro spin one tap toward the sideline and the
  plan aims short of the spot by the roll (`drill.rollFor`, `autothrow.tune.inkast`).
- **Gym:** needs a row: thrown kubbs that come to rest touching another.

## inkast.steer: Roll it either way

- **When:** inkast, the group has a gap, or lies on the wrong side of where the kubb can
  land.
- **Play:** Choose the direction of the roll: toward the sideline as usual, or back
  toward the middle to fill a gap between the kubbs and the sideline, or just behind
  kubbs already lying.
- **Why:** The group can then be built from either side. The players steer by the angle
  of the kubb in the hand, held through the throw. The coach says the roll against the
  hand does not come naturally.
- **Says who:** kn-drill-2012#p2.12, kn-drill-2012#p2.13, kn-drill-2012#p2.14 (Joakim
  Ekelöf); kn-drill-2012#p5.3 (Marcus Hansson); kn-drill-2012#p5.9 (Jens Haraldsson);
  kn-drill-2012#p4.10 (Björn Görlitz); yt-Io-rxbSB3Ns#6:24 (Eric Anderson)
- **Basis:** player, coach
- **Against:** kn-drill-2012#p6.1 (Johan Lundin) has never needed it. It is a refinement,
  not a requirement.
- **Levels:** Proposed: pro only.
- **Engine:** not modelled (0.11.0). The spin is always toward the sideline, one tap.
- **Gym:** nothing yet.

## inkast.chase: Sooner out than short

- **When:** inkast, first try at a kubb (not a rethrow), aiming at a line.
- **Play:** Aim so that a miss goes out of bounds, not so that it stays in play away
  from the group.
- **Why:** A kubb that goes out is thrown again. A kubb that skips away in play comes to
  rest around 6 m and, left standing, gives the other team a line 2 m forward. One player
  rates a punishment kubb as only slightly worse than a stray.
- **Says who:** kn-drill-2012#p3.8, kn-drill-2012#p3.9, kn-drill-2012#p3.10 (Josh
  Feathers); kn-drill-2012#p5.15, kn-drill-2012#p5.16 (Samuel Hufschmid);
  pk-drilling#p1.7 (Garrick van Buren)
- **Basis:** player, measured
- **Against:** Q1. It depends on the rule that a kubb may be thrown twice, which one
  player wanted changed (kn-drill-2012#p5.17); see Q10.
- **Levels:** Proposed: pro. PLAY.md measures the top third of teams rethrowing 15.8% of
  kubbs, more than weaker teams (150 scored games, `tools/realtiers.mjs`).
- **Engine:** not modelled (0.11.0). The basket sits inside both lines and the computer
  never aims at one; 0.10.0 measured about 2% rethrown at pro.
- **Gym:** `g.rethrown`, `g.punish`.

## inkast.deep: Throw deep what you cannot clear

- **When:** inkast, more field kubbs to face this turn than the team's clear count.
- **Play:** Throw short only as many kubbs as the team is sure to topple with its six
  batons. The rest go to the far baseline, in a cluster.
- **Why:** A deep kubb left standing gives the other team almost no advantage line. The
  player who states it calls it very important with teammates who hit poorly, and says
  his own team normally throws everything short. The exception he gives: against a very
  good team you sometimes have to play above your level.
- **Says who:** kn-drill-2012#p2.16, kn-drill-2012#p2.17, kn-drill-2012#p2.18 (Joakim
  Ekelöf); pk-deep#p1.3 (Garrick van Buren)
- **Basis:** player
- **Against:** Q4. A deep kubb has a second use this play does not cover: to set up a
  double with a base kubb (pk-deep#p1.2).
- **Levels:** Proposed: every level that drills, each with its own clear count. It would
  matter most at club, where the measured clear rate falls from 75% at four or five
  field kubbs to 34% at six or seven (PLAY.md).
- **Engine:** not modelled (0.11.0). Every kubb goes to the basket.
- **Gym:** `g.advTurns` and `g.cleared`; needs the clear count by level.

## inkast.depth: Depth, not only closeness

- **When:** inkast, four or more kubbs in hand.
- **Play:** Place kubbs one behind another along the baton's path, not only side by side
  along the centre line.
- **Why:** A baton takes two when one kubb stands behind another. Two players say a
  fence along the centre line leaves no doubles. One calls a kubb in front with the rest
  behind it perfect.
- **Says who:** kn-drill-2012#p3.13 (Josh Feathers); kn-drill-2012#p5.13 (Jens
  Haraldsson); kn-drill-2012#p4.13 (Björn Görlitz)
- **Basis:** player
- **Against:** Q6. Others aim for kubbs so close the raiser has no choice
  (kn-drill-2012#p6.9, kn-drill-2012#p2.10), which may be the same goal or a different
  one.
- **Levels:** Proposed: pro. Since 0.12.0 the pro computer lays columns; club does not.
  It wins at club too, but it made the club computer stronger and moved it away from
  real play (longer games, more doubles), and club is to be retuned as a whole against
  its new target (owner-2026-11-21#s6), so club lays the row as in 0.11.2 (Jamie's
  decision of 2026-11-21).
- **Engine:** modelled at pro (0.12.0, `core/cpu` depthSpot; `cpu.tune.depth`, `club = 0`).
  The kubbs lie end to end in a column down the baton's path: the first in the basket,
  each later one aimed to rest 4 cm in front of the column's front kubb, with the row's
  dead landing and roll (one tap toward the sideline, the plan aiming short by the run on
  and aside by the roll), so one that runs on is stopped by the kubb behind it. Four to a
  column (they fill the computer's 0.6 m lane), none nearer the centre line than 4.35 m;
  then the next column starts flank to flank with the innermost column's back kubb and
  grows forward beside it. A drill lies along its throw, and a defender raises a lying
  kubb only along its length, so a column stands in one lane whichever ends are chosen:
  `raise.par` counts its pairs as exposed every way (a pair lying 0.17 m apart scores 1.0 to
  2.0, a row stood level 0.47). In the Gym the pro computer's drills rest 0.06 m from
  their marks laying columns against 0.07 m laying the row, and with the column it beats
  the pro computer laying the row 74.5% on seeds 1 and 2 alike (at club, switched on by
  hand, 58.8% and 62.0%). Until 0.12.0 club and pro laid a row (`row = 1`), which wins
  only while the defender staggers it (Q6); club, which does not know `inkast.depth`,
  still does. Held
  to 4.35 m because the baskets face each other: two columns grown to the centre line
  stand a hand apart, and a baton at one touches the other team's column in the
  thrower's own half (II.B.11, web-us-rules-v4#p6.3). A column grown to 4.05 m wins
  55.4% against one held
  back, but with both teams doing it 3.6% of pro batons are forfeit, against none in real
  games. A wall along the sideline (the column 0.3 m nearer the
  sideline, `depth.x = 2.2`) did no better than at the basket (49.8%, before the hold).
- **Gym:** first-baton take by field size (`firstBaton.*`), `g.btc`; compare `row = 1`
  with `row = 0`.

## inkast.options: Leave the raiser nothing to choose

- **When:** inkast, judging where a kubb should rest, and judging the inkast afterward.
- **Play:** Prefer a resting place where the kubb can be raised only one way. Count a
  good inkast by how few kubbs the defender got to choose an end for, and by whether one
  baton could take them all.
- **Why:** Choosing the end is the defender's only defence against a group. One player
  counts the choices his opponent had and finds his team topples more the fewer there
  were.
- **Says who:** kn-drill-2012#p3.17, kn-drill-2012#p3.18 (Josh Feathers);
  kn-drill-2012#p4.12 (Björn Görlitz); kn-drill-2012#p6.9 (Simon Pettersson);
  kn-drill-2012#p2.8 (Niklas Ahlgren)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: a measure for every level, and a goal for pro.
- **Engine:** not modelled (0.11.0), but countable today: `raising.options` returns
  `"choice"` or `"forced"` for each kubb. Nothing reads it when placing a kubb.
- **Gym:** needs a row: options left, per inkast.

## inkast.adapt: The plan changes with the pitch and the last kubb

- **When:** inkast, after a kubb has come to rest somewhere unplanned, or on ground that
  plays differently.
- **Play:** Do not repeat the routine. Look again: build from the other side, change the
  corner when a punishment kubb sits on the usual one, and on hard dry ground throw
  lower and softer.
- **Why:** The players name habit as the top inkastare's weakness, and cleaning up after
  a kubb that went wrong as the mark of a good one.
- **Says who:** kn-drill-2012#p3.15, kn-drill-2012#p3.16 (Josh Feathers);
  kn-drill-2012#p6.4, kn-drill-2012#p6.2 (Johan Lundin); kn-drill-2012#p5.10 (Jens
  Haraldsson); kn-drill-2012#p2.11 (Josef Björklund)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: pro adapts; club keeps to the plan too long (PLAY.md, coach).
- **Engine:** modelled in part (0.11.0). The spot is worked out again before every kubb
  from where the kubbs lie. The corner follows the field kubbs already there. The arc is
  the same on every surface, though the aim allows for how far a kubb runs on each. A
  stray within 1.5 m of the basket can become the row's anchor.
- **Gym:** nothing yet.

## inkast.rescue: Knock a badly placed kubb out to throw it again

- **When:** inkast, a field kubb from an earlier turn stands very near a sideline or on
  the far baseline, and getting it back would swing the game or win it this turn.
- **Play:** Throw a kubb at it on a heavy angle from the sideline so that both go out of
  bounds. Both are then thrown again: the struck kubb as if not yet thrown, with two
  tries, and the thrown kubb with its one remaining.
- **Why:** The rule sends a field kubb knocked out by a thrown kubb back to the attacker.
  A kubb that stood deep can then be thrown short with the group. Knocking one out while
  the thrown kubb stays in gains nothing, and a miss can leave more kubbs badly placed
  than before. Punishment kubbs on the baseline are the usual ones rescued.
- **Says who:** ko-2012-rescue#p1.4, ko-2012-rescue#p1.8, ko-2012-rescue#p1.9,
  ko-2012-rescue#p1.11, ko-2012-rescue#p1.18 (Josh Feathers); pk-strategy#p1.16,
  pk-strategy#p1.19, pk-strategy#p1.20 (Planet Kubb wiki). The rule:
  web-us-rules-v4#p7.1.
- **Basis:** player
- **Against:** it is rare. He had never seen one tried in a tournament
  (ko-2012-rescue#p1.21), and PLAY.md counts 3 in 5,270 kubbs.
- **Levels:** Proposed: pro only, and only when the count says it pays (`levels.value`).
- **Engine:** the rules allow it (a rescued kubb is judged at the final position,
  docs/notes/rules-engine.md). The computer never tries it (0.11.0).
- **Gym:** nothing yet; needs rescues tried and rescues made as rows.

