# Open questions

Where sources disagree, and what only Jamie can answer. A question is not settled by
picking a side here: Jamie's answer is recorded as an observation in his words
(`observations/owner-<date>.md`), the question's status becomes `answered` with a pointer
to it, and the plays it touches are updated.

Q1 to Q5 came from PLAY.md. The rest came from the first two observations and from the
source census of 2026-11-21.

## Q1: Should the pro computer go out of bounds on purpose?

- **Status:** open
- **Asks:** The best third of tournament teams rethrows 16% of its kubbs, more than
  weaker teams. Is that risk taken on purpose, and should the pro computer take it?
- **So far:** Two interviewees say yes, on purpose: a kubb that goes out is thrown again,
  and a kubb that strays in play is worse (kn-drill-2012#p3.10, Josh Feathers;
  kn-drill-2012#p5.15, Samuel Hufschmid). See the play `inkast.chase`.
  0.10.0 measured about 2% rethrown at pro.
- **Touches:** inkast.chase

## Q2: Is the low third of tournament teams "club"?

- **Status:** open
- **Asks:** Or does club sit below any tournament team, with the measured numbers too
  kind to it?
- **So far:** web-kubbsh-levels (not yet observed) is one player's ladder of six levels,
  and puts players who enter the occasional local tournament at its fourth.
- **Touches:** play-levels.json

## Q3: Which beginner numbers look wrong from the pitch?

- **Status:** open
- **Asks:** Every beginner number is an estimate. The census found no measured data on
  beginners anywhere.
- **Touches:** play-levels.json

## Q4: Should the weaker computer levels throw deep kubbs?

- **Status:** open
- **Asks:** A team that cannot clear what it holds can throw the kubbs it will not reach
  to the far baseline.
- **So far:** Joakim Ekelöf states it as a rule, with the number of kubbs thrown short
  tied to what the team can clear, and says his own team, Team Ekeby, normally throws
  everything short (kn-drill-2012#p2.16, kn-drill-2012#p2.17, kn-drill-2012#p2.18). See
  `inkast.deep`. Is the baseline cluster he describes the same play as PLAY.md's deep
  kubbs at 7 or 8 m?
- **Touches:** inkast.deep

## Q5: How good is a pro from an advantage line?

- **Status:** open
- **Asks:** Measured 58% over 72 batons; the computer's 80% read "just right" to Jamie.
  The target range keeps both. Narrow it?
- **Touches:** play-levels.json

## Q6: A row across, or kubbs in depth?

- **Status:** open
- **Asks:** Since 0.11.0 the club and pro computer lay their kubbs flank to flank in a
  row (`autothrow.tune.inkast`, `row = 1`). Two interviewees say depth matters more than
  closeness, because kubbs one behind another give doubles and a fence along the centre
  line gives none (kn-drill-2012#p3.13, Josh Feathers; kn-drill-2012#p5.13, Jens
  Haraldsson). Others want kubbs so close the raiser has no choice (kn-drill-2012#p6.9,
  kn-drill-2012#p2.10). Is that one goal or two? And is the engine's row the fence they
  warn against, or the wall the coach describes (yt-Io-rxbSB3Ns#1:13)?
- **So far:** Not measured. The Gym can compare `row = 1` with `row = 0` (0.10's
  placement) on first-baton take and batons to clear.
- **Touches:** inkast.depth

## Q7: Raise kubbs apart, or as a tight fence?

- **Status:** open
- **Asks:** The engine's raise policy is `apart`: each kubb stands on the end furthest
  from its neighbours (owner and coach, PLAY.md). ko-2013-fence (not yet observed) argues
  for counting the attacker's batons, and says a tight fence across can beat kubbs spread
  in depth.
- **Touches:** the raise phase; no plays yet

## Q8: Where does a punishment kubb go?

- **Status:** open
- **Asks:** The engine places it deep and away from other kubbs. ko-2011-punishment (not
  yet observed) places it by the score: on the baseline when well behind, by a sideline
  when even, behind the king when ahead. Josh Feathers says most teams put it on their
  baseline, and plans his own inkast around that (kn-drill-2012#p3.9).
- **Touches:** the punish phase; no plays yet

## Q9: Does throwing first decide the game?

- **Status:** open
- **Asks:** One club's count has the first team winning about three games in four. A
  larger count has 55 to 45, against 65 to 35 in the same author's simulator
  (ko-2012-baseline, ko-2014-advantage1, ko-2014-advantage3; none yet observed). What do the
  150 scored games say, and what does the Gym say at each level?
- **Touches:** the opening; no plays yet

## Q10: Is the 2011 picture of the inkast still how the best play?

- **Status:** open
- **Asks:** kn-drill-2012 is fifteen top inkastare in 2011. Several expected the rules to
  change because drilling had become too strong: one try per kubb in place of two
  (kn-drill-2012#p5.17), or a longer pitch with more kubbs (kn-drill-2012#p4.15). What
  has changed since, in the rules and in how the best throw?
- **Touches:** every inkast play

## Q11: A Kid level

- **Status:** open
- **Asks:** Jamie, 2026-11-21: a fourth level below beginner, with a mode for children to
  have fun in. What makes it a kid's game: a shorter pitch, fewer kubbs, more forgiving
  throws, or all three? Kubbnation's 2014 Kid edition (kn-2014-kid) and the U.S.
  championship's Kid Kubb finals are the sources found so far.
- **Touches:** levels

## Q12: Bounce into the group, or land and stay?

- **Status:** open
- **Asks:** Most of the 2011 interviewees roll or bounce each kubb against the ones
  already down. Two prefer a kubb that lands where it is meant to and stays: a higher arc
  onto a spot (kn-drill-2012#p4.2, Eric Goplin), or no bounce at all where the ground
  allows (kn-drill-2012#p3.1, kn-drill-2012#p3.2, Terry Ekelöf). Johan Lundin says it
  depends on the field (kn-drill-2012#p6.2). Which is the pro inkast today?
- **So far:** Since 0.11.0 the engine has one way: a spun drill that lands dead and rolls.
- **Touches:** inkast.roll, inkast.first

## Q13: What did Johan Lundin mean by a kubb "not over line"?

- **Status:** open
- **Asks:** He says he is good at knocking such a kubb with the one he throws so that both
  end well placed and over the line (kn-drill-2012#p6.5). A kubb short of the centre
  line, one outside a sideline, or a standing field kubb (PLAY.md's rescue)?
- **Touches:** a play not yet written
