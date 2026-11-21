# Open questions

Where sources disagree, or the engine and the sources do, and how each is to be settled.

A question is settled by the strongest of these that applies: the rules text; a count
from scored games; a comparison in the Gym; the weight of the sources, the more recent and
more accomplished first. Jamie decides what the game should be: its levels, its modes and
what goes in. He is not asked to referee technique between top players
(`owner-2026-11-21#s3`).

Each question carries a recommendation. On 2026-11-21 Jamie accepted them as the working
answers, to be proven in simulated play (`owner-2026-11-21#s4`). A recommendation is not a
result: the question stays open until what `Settle by` names has been done.

Q1 to Q5 came from PLAY.md. The rest came from the first observations and from the source
census of 2026-11-21.

## Q1: Should the pro computer go out of bounds on purpose?

- **Status:** open: recommendation accepted, to be proven in the Gym
- **Asks:** The best third of tournament teams rethrows 16% of its kubbs, more than
  weaker teams. Is that risk taken on purpose, and should the pro computer take it?
- **So far:** Two interviewees say yes, on purpose: a kubb that goes out is thrown again,
  and a kubb that strays in play is worse (kn-drill-2012#p3.10, Josh Feathers;
  kn-drill-2012#p5.15, Samuel Hufschmid). 0.10.0 measured about 2% rethrown at pro.
- **Recommendation:** Yes, at pro, on the first try only. Aim the first try so that a miss
  goes out, and play a rethrow safely inside. The target is the measured range, 8 to 17%
  of kubbs rethrown, with punishment kubbs held at or under 1.5%.
- **Settle by:** the Gym: a pro that aims at the lines against one that does not, on
  `g.rethrown`, `g.punish`, `g.cleared` and games won.
- **Touches:** inkast.chase, inkast.corner

## Q2: Is the low third of tournament teams "club"?

- **Status:** open: recommendation accepted
- **Asks:** Or does club sit below any tournament team, with the measured numbers too
  kind to it?
- **So far:** web-kubbsh-levels (not yet observed) is one player's ladder of six levels.
  Its fourth, players who enter the occasional local tournament, hits more than 15% at
  8 m; the measured low third hits 23%.
- **Recommendation:** Treat the low third as the top of club, not its middle, and let the
  club ranges reach lower. Keep the numbers as they are until a real club sample exists.
- **Settle by:** scoring club play. The Madison Kubb League films its weekly games from
  overhead (yt--7i2_EFdZUA and yt-j9LEzlQftjo are its finals); a dozen of those in Planet
  Kubb Notation would be the first measured club data.
- **Touches:** play-levels.json

## Q3: Which beginner numbers are right?

- **Status:** open: recommendation accepted
- **Asks:** Every beginner number is an estimate. The census found no measured data on
  beginners anywhere.
- **Recommendation:** Stop treating beginner as a thing to measure from tournaments. Set
  it by what it is for: a person new to the game should beat the beginner computer about
  half the time, in a game short enough to finish. The people who play online are the
  nearest thing to beginner data there is, and the Gym already fits a human thrower from
  their recorded swings.
- **Settle by:** the recorded matches (private; `gym fit`, `gym bank`): what new players
  hit, how far their kubbs scatter and how long their games run. Then the Gym: the fitted
  human against the beginner computer.
- **Touches:** play-levels.json

## Q4: Should the weaker computer levels throw deep kubbs?

- **Status:** open: recommendation accepted, to be proven in the Gym
- **Asks:** A team that cannot clear what it holds can throw the kubbs it will not reach
  to the far baseline.
- **So far:** Joakim Ekelöf states it as a rule, with the number of kubbs thrown short
  tied to what the team can clear, and says his own team, Team Ekeby, normally throws
  everything short (kn-drill-2012#p2.16, kn-drill-2012#p2.17, kn-drill-2012#p2.18).
- **Recommendation:** Yes at club, where it should matter most: the measured clear rate
  falls from 75% at four or five field kubbs to 34% at six or seven. At pro only when the
  field passes what pro clears, which is rare. Not at beginner, who does not place kubbs.
  Each level gets a clear count from its own Gym results: throw short while the chance of
  clearing stays good, and the rest deep in a cluster.
- **Settle by:** the Gym: club with the play against club without, on `g.advTurns`,
  `g.cleared` and games won.
- **Touches:** inkast.deep

## Q5: How good is a pro from an advantage line?

- **Status:** open: recommendation accepted
- **Asks:** Measured 58% over 72 batons; the computer's 80% read "just right" to Jamie.
  The target range keeps both. Narrow it?
- **Recommendation:** Leave the range alone. Seventy-two batons cannot separate 58% from
  70%, and one number hides the distance: a line 2 m from a base kubb is not a line 6 m
  from it. Score it by distance when there is more to count.
- **Settle by:** more scored games at the top level.
- **Touches:** play-levels.json

## Q6: A row across, or kubbs in depth?

- **Status:** open: the first comparison is in, and it went against our reading
- **Asks:** Since 0.11.0 the club and pro computer lay their kubbs flank to flank in a
  row (`autothrow.tune.inkast`, `row = 1`). Two interviewees say depth matters more than
  closeness, because kubbs one behind another give doubles and a fence along the centre
  line gives none (kn-drill-2012#p3.13, Josh Feathers; kn-drill-2012#p5.13, Jens
  Haraldsson). Others want kubbs so close the raiser has no choice (kn-drill-2012#p6.9,
  kn-drill-2012#p2.10). The coach builds "a wall along the side" (yt-Io-rxbSB3Ns#1:13)
  and has the baton thrower throw down it (yt-Io-rxbSB3Ns#1:30).
- **So far:** The Gym, 2026-11-21, engine 0.11.0, the computer at club and pro, 300
  matches each, seed 1: the row as shipped against `row = 0` (0.10's line for two or
  three kubbs and cluster for more) and against `row = 0` with `clusterFrom = 99` (always
  a line along the throw). The row won on every row that bears on doubles. At pro, field
  batons that took two: 22.2% against 17.1% and 15.9%; three or more: 4.9% against 3.0%
  and 2.1%; turns that cleared: 77.0% against 72.8% and 71.2%; batons to clear: 3.70
  against 4.08 and 4.14. Club moved the same way by less. Why: the row lies as a fence,
  but the defender's `apart` policy then stands neighbours on opposite ends, which
  staggers it 15 cm in depth. Standing, it has as much depth on the baton's path as the
  line, and it is tighter (spread 0.23 m against 0.32 and 0.36 at pro). Two cautions.
  The line variants also land their drills worse on 0.11's physics (0.17 m from the mark
  against 0.06), so shape and accuracy are mixed. And each variant played itself, so
  there is no win rate.
- **Recommendation:** Keep the row. Our reading that it is the fence the players warn
  against was wrong for the game as the engine plays it. What the result does show is
  that the worth of an inkast shape depends on how the defender raises: the row works
  because `apart` staggers it. A defender who kept it a fence, as `raise.across` advises,
  might undo that. So Q6 and Q7 are one contest and have to be played as one.
- **Settle by:** the Gym, attacker against defender: the row against the line, each under
  `apart` and under a raise that keeps kubbs across. That needs matches where the two
  sides play differently, which the Gym cannot yet do. A wall in depth along the
  sideline, thrown down from that sideline, is still untested: nothing builds it.
- **Touches:** inkast.depth, inkast.corner, raise.across

## Q7: Raise kubbs apart, or as a tight fence?

- **Status:** open: recommendation accepted
- **Asks:** The engine's raise policy is `apart`: each kubb stands on the end furthest
  from its neighbours (owner and coach, PLAY.md). Chris Hodges argues for counting the
  attacker's batons, and says space across the pitch is worth much more than space along
  it (ko-2013-fence#p1.4, ko-2013-fence#p1.11).
- **Recommendation:** Keep `apart` for now. The better rule is the one both sides are
  reaching for: stand each kubb where the attacker needs the most batons. The engine can
  count that with the same lane test its own batons aim by.
- **Settle by:** the Gym: a `par` policy against `apart` on the attacker's `g.btc` and
  `g.cleared`.
- **Touches:** raise.par, raise.across

## Q8: Where does a punishment kubb go?

- **Status:** open: recommendation accepted
- **Asks:** The engine places it deep and away from other kubbs. Chris Hodges places it
  by the score: on the baseline when well behind, by a sideline when even, behind the
  king when ahead (ko-2011-punishment#p1.6, ko-2011-punishment#p1.7,
  ko-2011-punishment#p1.10). He turns a flat face to the thrower and notes that others
  turn an edge (ko-2011-punishment#p1.19, ko-2011-punishment#p1.20). Josh Feathers says most teams put it on their
  baseline, and plans his own inkast around that (kn-drill-2012#p3.9).
- **Recommendation:** The engine's default is what most teams do; leave it. Placement by
  the score is a pro refinement worth little: punishment kubbs are about one kubb in a
  hundred at tournament level.
- **Settle by:** nothing yet. No Gym work until the larger plays are in.
- **Touches:** punish.baseline, punish.sideline, punish.king, punish.safe

## Q9: Does throwing first decide the game?

- **Status:** open: recommendation accepted
- **Asks:** One club's count has the first team winning about three games in four. A
  larger count has 55 to 45, against 65 to 35 in the same author's simulator
  (ko-2012-baseline, ko-2014-advantage1, ko-2014-advantage3; none yet observed).
- **Recommendation:** Count it, do not argue it. The engine already offers both openings
  (2-4-6 and six batons). If the first team wins much more than 55% in the Gym at pro
  under one of them, that opening is the wrong default for pro play.
- **Settle by:** a count over the 150 scored games, and the Gym by level and opening.
- **Touches:** the opening; no plays yet

## Q10: Is the 2011 picture of the inkast still how the best play?

- **Status:** open: recommendation accepted
- **Asks:** kn-drill-2012 is fifteen top inkastare in 2011. Several expected the rules to
  change because drilling had become too strong: one try per kubb in place of two
  (kn-drill-2012#p5.17), or a longer pitch with more kubbs (kn-drill-2012#p4.15).
- **Recommendation:** Use it. The engine plays the U.S. rules, under which a kubb is still
  thrown twice and a kubb on a line is still raised into the pitch, so the reasons these
  players give still hold in the game we are building. The 2020 lesson and Kubb On's 2017
  and 2018 pieces teach the same drill. Where a newer source differs, the newer one wins.
- **So far:** ko-2025-worlds, the newest written source, turned out to say nothing direct
  on the corner, the roll, going out on purpose or deep kubbs. Planet Kubb's 2017
  glossary repeats the corner, the rethrow and deep as the safe choice (pk-drilling#p1.7,
  pk-deep#p1.3), and Kyle Weakland in 2018 has the sideline forcing kubbs together
  (ko-2018-practice#p1.4). So the written evidence runs to 2018.
- **Settle by:** the current rule texts, and video: recent finals with commentary, once
  something can watch them.
- **Touches:** every inkast play

## Q11: A Kid level

- **Status:** open: Jamie's to decide
- **Asks:** Jamie wants a fourth level below beginner, with a mode for children to have
  fun in (`owner-2026-11-21#s2`). What makes it a kid's game?
- **Recommendation:** Make it a different game, not a weaker beginner: a shorter pitch,
  fewer base kubbs so a game ends soon, no punishment kubbs and no illegal-throw calls,
  and a computer that tosses the way a child does. Read Kubbnation's 2014 Kid edition
  (kn-2014-kid) and watch the U.S. championship's Kid Kubb finals before fixing any
  number.
- **Settle by:** Jamie, once those two sources are observed.
- **Touches:** levels, the match options

## Q12: Bounce into the group, or land and stay?

- **Status:** open: recommendation accepted
- **Asks:** Most of the 2011 interviewees roll or bounce each kubb against the ones
  already down. Two prefer a kubb that lands where it is meant to and stays: a higher arc
  onto a spot (kn-drill-2012#p4.2, Eric Goplin), or no bounce at all where the ground
  allows (kn-drill-2012#p3.1, kn-drill-2012#p3.2, Terry Ekelöf). Johan Lundin says it
  depends on the field (kn-drill-2012#p6.2).
- **Recommendation:** Both, by the kubb. The first kubb is the one that should land and
  stay (`inkast.first`); the rest roll into it (`inkast.roll`), which is what the engine
  does since 0.11.0. Land-and-stay for every kubb is a soft-ground throw and can wait for
  the surfaces.
- **Settle by:** the Gym: a dead first kubb against the same throw for every kubb, on how
  tight the group ends.
- **Touches:** inkast.roll, inkast.first

## Q13: What did Johan Lundin mean by a kubb "not over line"?

- **Status:** open: recommendation accepted
- **Asks:** He says he is good at knocking such a kubb with the one he throws so that both
  end well placed and over the line (kn-drill-2012#p6.5).
- **Recommendation:** Read it as a thrown kubb lying short of the centre line. The next
  kubb is thrown into it so both end in the half. The engine allows this already: a kubb
  is judged where it lies once every kubb is thrown, not when it stops
  (docs/notes/rules-engine.md). The computer never tries it.
- **Settle by:** a second source that describes the same throw. Then a play, at pro.
- **Touches:** a play not yet written

## Q14: Where should a baton meet the front kubb of a group?

- **Status:** open
- **Asks:** PLAY.md has the half-turn throw arriving low, a kubb hit low and hard, and top
  hits one in twenty or thirty (owner). Kyle Weakland aims at the top front corner with
  the baton halfway between upright and flat, so that it tumbles over and into the group,
  and calls a low square hit the fault that stops the baton dead (ko-2017-blasting#p1.13,
  ko-2017-blasting#p1.14, ko-2017-blasting#p1.22). Phil Dickinson trains a full turn with
  the head striking square, and hits high, low or on an edge by the reaction he wants
  (ko-2017-dickinson#p1.10, ko-2017-dickinson#p1.11).
- **Recommendation:** Both can be true: low and hard for a single kubb, where only that
  kubb has to fall, and high with a turning baton for a group, where the baton has to go
  on. If so, the computer needs a hit height and a tumble chosen by the shot, not one
  setting per level.
- **Settle by:** the Gym. Its forensics already record how each baton arrives at a kubb;
  split kubbs taken per baton by arrival height and baton angle, singles and groups
  apart.
- **Touches:** field.corner, field.sure

