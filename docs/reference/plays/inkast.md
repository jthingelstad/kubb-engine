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
  ko-2018-practice#p1.4 (Kyle Weakland)
- **Basis:** player, coach
- **Against:** nothing found for two or more kubbs. For one kubb see `inkast.single`.
- **Levels:** Proposed: pro and club always. Beginner and kid do not aim for a corner.
- **Engine:** modelled in part (`autothrow.basket`, 0.11.0 and before). It picks the
  corner that already holds more field kubbs and flips a coin on a tie. It does not know
  the thrower's hand, and it stays 0.6 m inside the sideline and 0.75 m past the centre
  line (`basketX`, `basketY`), so its kubbs do not lie on a line.
- **Gym:** needs a row: thrown kubbs resting on a line.

## inkast.single: One kubb does not go to the corner

- **When:** inkast, one kubb in hand (two, by the situation).
- **Play:** Aim midway between the king and the centre line's pin.
- **Why:** There is a small chance it settles behind the pin, which then shields it from
  a baton. With two or more the corner is worth its risk.
- **Says who:** kn-drill-2012#p3.11 (Josh Feathers)
- **Basis:** player
- **Against:** nothing found. One player only.
- **Levels:** Proposed: pro only, and not before a second source agrees.
- **Engine:** not modelled (0.11.0). One kubb goes to the basket like any other.
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
  spins the first few harder and the later ones less (ko-2017-dickinson#p1.8).
- **Levels:** Proposed: pro. Club tries and lands it less often.
- **Engine:** modelled in part (0.11.0). Later kubbs are aimed off the innermost kubb
  already lying by the basket (`autothrow.spot`). The first kubb is thrown like the
  others, with the same spin: there is no dead first drill.
- **Gym:** needs a row: how far the first kubb rests from its marker.

## inkast.roll: Later kubbs roll into the ones already down

- **When:** inkast, a kubb already lies in the basket.
- **Play:** Land beside the group and let the kubb kick or roll into it, so each kubb is
  stopped by the last. Most of the time a light cut, not a big one.
- **Why:** Each kubb is stopped by the ones before it, so the group ends close together
  and the kubbs do not run out of bounds.
- **Says who:** kn-drill-2012#p2.10 (Josef Björklund); kn-drill-2012#p3.21 (Scott
  Forster); kn-drill-2012#p4.9 (Björn Görlitz); kn-drill-2012#p5.1, kn-drill-2012#p5.2
  (Marcus Hansson); kn-drill-2012#p5.15 (Samuel Hufschmid); yt-Io-rxbSB3Ns#1:13,
  yt-Io-rxbSB3Ns#5:07, yt-Io-rxbSB3Ns#7:09 (Eric Anderson)
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
- **Levels:** Proposed: pro.
- **Engine:** modelled another way (0.11.0). Club and pro lay a row, each kubb flank to
  flank with the innermost one lying (`row = 1`, `rowStep`). It lies as a fence, and the
  defender's `apart` raise staggers it into depth. In the Gym it gave more doubles and
  triples than 0.10's line or cluster (Q6).
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
  pk-strategy#p1.19, pk-strategy#p1.20 (Planet Kubb wiki)
- **Basis:** player
- **Against:** it is rare. He had never seen one tried in a tournament
  (ko-2012-rescue#p1.21), and PLAY.md counts 3 in 5,270 kubbs.
- **Levels:** Proposed: pro only, and only when the count says it pays (`levels.value`).
- **Engine:** the rules allow it (a rescued kubb is judged at the final position,
  docs/notes/rules-engine.md). The computer never tries it (0.11.0).
- **Gym:** nothing yet; needs rescues tried and rescues made as rows.

