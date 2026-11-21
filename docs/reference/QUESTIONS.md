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

- **Status:** open: recommendation accepted, to be proven in the Gym
- **Asks:** Since 0.11.0 the club and pro computer lay their kubbs flank to flank in a
  row (`autothrow.tune.inkast`, `row = 1`). Two interviewees say depth matters more than
  closeness, because kubbs one behind another give doubles and a fence along the centre
  line gives none (kn-drill-2012#p3.13, Josh Feathers; kn-drill-2012#p5.13, Jens
  Haraldsson). Others want kubbs so close the raiser has no choice (kn-drill-2012#p6.9,
  kn-drill-2012#p2.10). The coach builds "a wall along the side" (yt-Io-rxbSB3Ns#1:13)
  and has the baton thrower throw down it (yt-Io-rxbSB3Ns#1:30).
- **Recommendation:** Our reading is that these agree. The wall runs along the sideline,
  into the half, so the kubbs stand one behind another on the path of a baton thrown from
  that sideline. The engine's row runs the other way, across the pitch at one depth, which
  is the fence the players warn against. If the Gym bears that out, build in depth along
  the sideline and stand the baton thrower on that sideline.
- **Settle by:** the Gym, in two steps. First `row = 1` against `row = 0` (0.10's line and
  cluster) on first-baton take, `g.field2`, `g.field3` and `g.btc`. Then a wall in depth
  along the sideline against both.
- **Touches:** inkast.depth, inkast.corner

## Q7: Raise kubbs apart, or as a tight fence?

- **Status:** open: recommendation accepted
- **Asks:** The engine's raise policy is `apart`: each kubb stands on the end furthest
  from its neighbours (owner and coach, PLAY.md). ko-2013-fence (not yet observed) argues
  for counting the attacker's batons, and says a tight fence across can beat kubbs spread
  in depth.
- **Recommendation:** Keep `apart` for now. The better rule is the one both sides are
  reaching for: stand each kubb where the attacker needs the most batons. The engine can
  count that with the same lane test its own batons aim by.
- **Settle by:** observing ko-2013-fence and ko-2012-doubles, then the Gym: a `par` policy
  against `apart` on the attacker's `g.btc` and `g.cleared`.
- **Touches:** the raise phase; no plays yet

## Q8: Where does a punishment kubb go?

- **Status:** open: recommendation accepted
- **Asks:** The engine places it deep and away from other kubbs. ko-2011-punishment (not
  yet observed) places it by the score: on the baseline when well behind, by a sideline
  when even, behind the king when ahead. Josh Feathers says most teams put it on their
  baseline, and plans his own inkast around that (kn-drill-2012#p3.9).
- **Recommendation:** The engine's default is what most teams do; leave it. Placement by
  the score is a pro refinement worth little: punishment kubbs are about one kubb in a
  hundred at tournament level.
- **Settle by:** observing ko-2011-punishment. No Gym work until the larger plays are in.
- **Touches:** the punish phase; no plays yet

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
- **Settle by:** observing ko-2025-worlds (the 2025 U.S. 1v1 champions on drilling and
  risk) and the current rule texts.
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
