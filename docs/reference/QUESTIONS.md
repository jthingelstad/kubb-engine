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

- **Status:** open: played side against side; the answer depends on the defender
- **Asks:** Since 0.11.0 the club and pro computer lay their kubbs flank to flank in a
  row (`autothrow.tune.inkast`, `row = 1`). Two interviewees say depth matters more than
  closeness, because kubbs one behind another give doubles and a fence along the centre
  line gives none (kn-drill-2012#p3.13, Josh Feathers; kn-drill-2012#p5.13, Jens
  Haraldsson). Others want kubbs so close the raiser has no choice (kn-drill-2012#p6.9,
  kn-drill-2012#p2.10). The coach builds "a wall along the side" (yt-Io-rxbSB3Ns#1:13)
  and has the baton thrower throw down it (yt-Io-rxbSB3Ns#1:30).
- **So far:** The Gym, 2026-11-21, engine 0.11.0, the computer at pro, 300 seeds played
  both ways round (`gym versus`). The row against 0.10's line and cluster (`row = 0`):

  | The row's kubbs are raised | The line's kubbs are raised | The row wins |
  | --- | --- | --- |
  | apart | apart | 67.6% (64.2 to 71.0) |
  | apart | kept across | 55.2% (51.8 to 58.5) |
  | kept across | apart | 44.5% (41.1 to 47.9) |
  | kept across | kept across | 36.6% (33.2 to 39.9) |

  The row wins only while the defender stands its kubbs `apart`, which staggers a row
  lying across the pitch into depth. Against a defender who keeps it a fence, the row
  loses to the line 37 to 63. At club the two shapes are level (50.7%, 47.1 to 54.3). One
  caution carried over: on 0.11's physics the line's drills land less accurately than the
  row's, so the line is being judged at a handicap.
- **Recommendation:** The players were right, and so was the first Gym run: both results
  are the same fact seen against two defenders. Depth beats a fence once the defender
  defends. So the inkast cannot be settled before the raising is (Q7). When the computer
  raises by the attacker's batons, play the shapes again and build the one that wins
  against it. A wall in depth along the sideline, thrown down from that sideline, is
  still untested: nothing builds it.
- **Settle by:** `gym versus`, after `raise.par` exists: row, line and a sideline wall,
  each against a defender who raises by the attacker's batons.
- **Touches:** inkast.depth, inkast.corner, raise.across

## Q7: Raise kubbs apart, or as a tight fence?

- **Status:** open: played side against side; `apart` lost
- **Asks:** The engine's raise policy is `apart`: each kubb stands on the end furthest
  from its neighbours (owner and coach, PLAY.md). Chris Hodges argues for counting the
  attacker's batons, and says space across the pitch is worth much more than space along
  it (ko-2013-fence#p1.4, ko-2013-fence#p1.11). The Planet Kubb wiki has defenders
  standing kubbs to minimise depth (pk-strategy#p1.10).
- **So far:** The Gym, 2026-11-21, engine 0.11.0, both teams the pro computer throwing
  the shipped row, 300 seeds played both ways round. The team raising `apart` won 23.8%
  against one raising `together`, 27.5% against `first`, and 27.3% and 24.4% against two
  Gym policies that stand every kubb with a choice on the same end. Every interval is
  clear of 50; the four are not different from one another. Why: kept as a fence, six
  kubbs stand side by side about 10 cm apart, and the computer takes them one baton each.
  Its aim counts only kubbs straight behind the front one, and never joins two standing
  flank to flank. Staggered by `apart`, the same kubbs give it doubles. But against the
  line, raising `apart` did better than keeping kubbs on one end (the first two rows of
  Q6's table: 67.6 against 55.2 for the team raising the line's kubbs). So no fixed
  policy is right: across beats apart against a row, and apart beats across against a
  line.
- **Recommendation:** Build `raise.par`: for each kubb with a choice, the end that leaves
  the attacker the fewest kubbs one behind another on a baton's path. It should choose
  the fence against a row and the spread against a line without being told which it
  faces. Then make it the computer's policy and the automatic one, if it beats `apart`
  and is no worse than the fixed policies against both shapes. One caution: part of this
  result is the computer's own blind spot at a fence. A thrower who could take a tight
  row would change the sum, so the raising has to be played again whenever the baton at a
  group improves (Q14).
- **Settle by:** `gym versus`: `par` against `apart` and against the same-end policies,
  facing the row and facing the line, at pro and at club.
- **Touches:** raise.par, raise.across

## Q8: Where does a punishment kubb go?

- **Status:** open: recommendation accepted
- **Asks:** The engine places it deep and away from other kubbs. Chris Hodges places it
  by the score: on the baseline when well behind, by a sideline when even, behind the
  king when ahead (ko-2011-punishment#p1.6, ko-2011-punishment#p1.7,
  ko-2011-punishment#p1.10). He turns a flat face to the thrower and notes that others
  turn an edge (ko-2011-punishment#p1.19, ko-2011-punishment#p1.20). The Planet Kubb wiki
  adds a fourth place: on the centre line, far from the group, when the attacker will
  need all six batons for the group anyway (pk-strategy#p1.13). Josh Feathers says most teams put it on their
  baseline, and plans his own inkast around that (kn-drill-2012#p3.9).
- **Recommendation:** The engine's default is what most teams do; leave it. Placement by
  the score is a pro refinement worth little: punishment kubbs are about one kubb in a
  hundred at tournament level.
- **Settle by:** nothing yet. No Gym work until the larger plays are in.
- **Touches:** punish.baseline, punish.sideline, punish.king, punish.safe

## Q9: Does throwing first decide the game?

- **Status:** open: recommendation accepted
- **Asks:** One club's footage has the first team winning 75% of games between similar
  teams, with no count given (ko-2012-baseline#p1.13). Two years later the same analyst,
  from about 100 scored games, has 55 to 45, against 65 to 35 in his own simulator
  (ko-2014-advantage1#p1.10, ko-2014-advantage1#p1.11).
- **So far:** In the Gym at pro, with both teams playing alike under the default opening,
  the team that opened won 163 of 299 decided games, about 54.5%. That is the larger
  count's figure, not the club's.
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

## Q15: May the defender turn a kubb when standing it up?

- **Status:** open
- **Asks:** Josh Feathers and Chris Hodges both treat a kubb's facing as something the
  defender sets: a corner toward the attacker on the front kubb of a double, a flat face
  when nothing else differs (ko-2012-doubles#p1.16, ko-2013-fence#p1.15). The engine
  raises a kubb by tipping it onto one end about that end's bottom edge (U.S. rules
  II.D.1 as the engine reads them), which fixes its facing by how it lay. Were they
  choosing a facing, or choosing which kubb to stand where?
- **Recommendation:** Go by the rule text the engine plays. If it fixes the facing, then
  facing is something the inkastare and the bounce decide, and the defender only reads
  it. The physics already makes it matter.
- **Settle by:** the current U.S. rules and the 2012 rules these pieces were written
  under, read side by side.
- **Touches:** raise.facing, raise.square

