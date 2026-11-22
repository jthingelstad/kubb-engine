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

- **Status:** answered for the computer (0.12.0): pro lays kubbs in depth, in columns
  down the baton's path (`inkast.depth`); club keeps the row until it is retuned
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
  Then, on engine 0.11.2, with both teams raising by the attacker's batons
  (`raising.policies.par`): the row lost to the line, 47.0% (43.2 to 50.8) on seed 1 and
  43.3% (40.0 to 46.6) on seed 2. `par` keeps the row a fence, which takes away the
  stagger the row won by (docs/notes/gym.md, "Raising by the attacker's batons").
  Then, on 0.12.0, `inkast.depth`, built with the row's dead landing and roll: the kubbs
  end to end in columns of four down the baton's path, which no choice of ends can take
  out of one lane. Its drills rest 0.06 m from their marks at pro (the row's 0.07), and it
  beats the row 74.5% at pro on seeds 1 and 2 (defender `par`) and 58.8% and 62.0% at
  club (defender `apart`). The sideline wall in its simplest form (the column 0.3 m
  nearer the sideline, thrown down from straight behind) did no better than the column at
  the basket (49.8%); `field.line` lets the thrower stand wherever a column's kubbs line
  up (docs/notes/gym.md, "The attacker's plays"). Club was left out of the release
  (Jamie, 2026-11-21): the column made the club computer stronger and moved it away from
  real play (turns a game 15.5 to 17.8, took two 13.1% to 15.6%, both above the range),
  and club is to be retuned as a whole against its new target (owner-2026-11-21#s6).
  One clip since (2026-11-21) shows a baton meeting a row of ten kubbs standing side by
  side across its path, touching or nearly, and neighbours falling with the struck kubb
  (yt-KcvzNzU7ZS8#1:30). It is one throw with a kubb already tilting, so it is carried
  in Q16, not here; it does not touch the answer for the inkast shape.
- **Recommendation:** The players were right, and so was the first Gym run: both results
  are the same fact seen against two defenders. Depth beats a fence once the defender
  defends. Done in 0.12.0 for pro (`inkast.depth`); club, which wins with it too, takes
  it or not when it is retuned as a whole. Left: a wall right on the
  sideline (a kubb on the line can only be raised into the pitch, `inkast.corner`), which
  needs a computer that aims at a line (`inkast.chase`), and `inkast.first`.
- **Settle by:** done for the shape; the sideline wall waits for a computer that aims at
  a line.
- **Touches:** inkast.depth, inkast.corner, raise.across

## Q7: Raise kubbs apart, or as a tight fence?

- **Status:** answered for the policy (0.12.0): pro raises by `raise.par`, club `apart`,
  beginner `first`, a person's automatic raising `par` at every level
  (owner-2026-11-21#s5; docs/notes/computer-player.md, "The order of work";
  docs/notes/gym.md, "Raising by level")
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
  Then `raise.par` was built (0.11.2, `raising.policies.par`, used by no level yet) and
  played, 300 seeds each way, two seeds. At pro against the row it beats `apart` 76.8%
  (73.8 to 79.9) and is level with `together` (49.5%) and a little ahead of the same-end
  policy (54.9%). Against the line it is level with `apart` (54.0%, 50.8 to 57.2) and
  beats the same-end policy 65.6%. At club it beats all three against the row (57 to 60%)
  and is level with `apart` against the line. It met every bar set for it.
- **Recommendation:** Switch it on. Pro raises by the attacker's batons; club keeps
  `apart`, which is what a club player does; a beginner stands kubbs anyhow. A person's
  automatic raising, and the end offered first when raising by hand, should be the
  engine's best advice, `par`. One caution stands: part of the result is the computer's
  own blind spot at a fence, so the raising has to be played again whenever the baton at
  a group improves (Q16).
- **Settle by:** done for the policy, and switched on by level in 0.12.0 with the
  scorecard beside it (docs/notes/gym.md, "Raising by level"). Played again against
  0.12.0's attacker (`inkast.depth`, `field.line`): `par` and `apart` are level at pro
  (50.3% and 51.8%), and `par` beats the same-end policies 55 to 57; at club (measured
  with the column, which club does not ship) it leads `apart` 53.5% and 56.3%. So `par`
  stays, as the policy that never loses (docs/notes/gym.md, "The attacker's plays"). A
  person's kubbs raised by the engine take it at every level, the engine's best advice
  (owner-2026-11-21#s5): against the club computer the human thrower wins about 16 games
  in 100 (15.7%, 16.8%) where it won 12.3 on 0.11.2. Still open: a beginner's random end,
  which waits for Choose's own random stream, and club's own raising when club is retuned.
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
- **So far:** The rule texts, read 2026-11-21, agree on the U.S. engine's freedom only
  in the U.S.: anywhere in the defenders' half, a baton length from the king and every
  stake (web-us-rules-v4#p8.4, web-us-rules-v2#p9.3). The 2003 World Championship
  booklet says anywhere on the pitch, as printed (web-vm-rules-2003#p3.3). The Belgian
  rules keep it a baton length from the back line, so the baseline is not allowed
  (web-kf-rules-2026#p18.2). The German rules do not place it at all: a defender throws
  it into his own half from the attacker's baseline (web-dkb-rules-2025#p3.3).
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
  The current rule texts, read 2026-11-21: the U.S. rules still give a kubb a second
  throw and call a kubb half in, in (web-us-rules-v4#p7.2), and still make a kubb that
  can be raised in bounds be raised in bounds (web-us-rules-v4#p7.5), so the corner and
  the chase keep their reasons in the game the engine plays. The German and Belgian
  rules keep the second throw but ask for a kubb wholly inside once stood
  (web-dkb-rules-2025#p4.1, web-kf-rules-2026#p20.2), which shrinks what a line forces in;
  the German rules have punishment kubbs thrown, not placed (web-dkb-rules-2025#p3.3),
  and both have a kubb lying on others placed by the throwing team
  (web-dkb-rules-2025#p6.1, web-kf-rules-2026#p7.1). None of the predicted changes (one
  try per kubb, a longer pitch) is in any of them.
- **Settle by:** done for the U.S. rule text; video of recent finals with commentary for
  how the best play under it, once something can watch them.
- **Touches:** every inkast play

## Q11: A Kid level

- **Status:** answered: decided by Jamie (2026-11-21), built in 0.15.0 (docs/notes/kid-mode.md):
  a gentle mode, not a weaker computer (`owner-2026-11-21#s7`). The two sources below are
  still to be observed against what was built.
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
  (docs/notes/rules-engine.md; the rule, web-us-rules-v4#p6.5). The computer never
  tries it.
- **Settle by:** a second source that describes the same throw. Then a play, at pro.
- **Touches:** a play not yet written

## Q14: Where should a baton meet the front kubb of a group?

- **Status:** open: measured in the Gym; the engine's physics disagrees with the player
- **Asks:** PLAY.md has the half-turn throw arriving low, a kubb hit low and hard, and top
  hits one in twenty or thirty (owner). Kyle Weakland aims at the top front corner with
  the baton halfway between upright and flat, so that it tumbles over and into the group,
  and calls a low square hit the fault that stops the baton dead (ko-2017-blasting#p1.13,
  ko-2017-blasting#p1.14, ko-2017-blasting#p1.22). Phil Dickinson trains a full turn with
  the head striking square, and hits high, low or on an edge by the reaction he wants
  (ko-2017-dickinson#p1.10, ko-2017-dickinson#p1.11).
- **So far:** The Gym, 2026-11-21, engine 0.11.0, the computer at club and pro, 300
  matches a setting. In this physics the answer is no. At pro, a baton that first meets
  a group on the kubb's body and near upright takes two or more 68% of the time; one that
  clips the top edge 50%, falling to 20% as the baton leans to half turned; one that
  comes down on top 3.5%. Making the computer hit as the player describes (aim at 0.6 of
  the height, a tumble that arrives half turned) cut three-or-more at groups from 10.1%
  to 4.7%. A low square hit does not stop the baton dead here: it keeps a third of its
  speed and takes the most. And the engine's baton does not arrive low: about 60% of
  first touches on a group at pro are within 1 cm of the top. What did help was a flatter,
  harder throw: `plan.tune.arcFarDeg` at 15 lifted pro's three-or-more from 4.9% to 6.8%
  and its base kubbs from 8 m from 34.7% to 42.0%, into the target. Nothing swept comes
  near real top teams' 12 to 18% for three or more.
  A lesson observed since (2026-11-21), on the 8 m baton rather than the group: top
  players throw half a turn or a whole one, a little over-rotated still lands on the
  kubb, and a little under-rotated sticks or pops over it with a much lower hit rate
  (yt-Rl8PNnjDidQ#0:32, yt-Rl8PNnjDidQ#2:18, yt-Rl8PNnjDidQ#2:33, yt-Rl8PNnjDidQ#2:41;
  `baseline.rotation`). That allows both the half turn and Dickinson's full turn, and
  his under-rotated baton may be Weakland's baton that stops dead. Nothing is thrown in
  it, so it is the coach's word.
- **Recommendation:** Do not build `field.corner` as written. Two things follow instead.
  The arc is a lever worth playing side against side, level by level. And the gap that
  remains is too large for any aim to close, so the next question is the physics: whether
  a baton going through a standing group loses too much, or the engine's groups stand
  too loose, compared with wood. The Gym measures the engine, not the pitch, and one
  player's account against one simulator settles neither.
  Before any of that, one cheap check: whether the engine's baton, like the coach's,
  forgives over-rotation more than under-rotation at 8 m. If it does not, the half-turn
  plan with an even spread is aiming at the wrong side of its own error.
- **Settle by:** `gym versus` on the arc; the reference engine (docs/notes/reference-engine.md)
  on a baton through a standing group; the Gym's base-kubb hits from 8 m by turns at first
  touch, under against over; and video of top blasters, once something can watch it.
- **Touches:** field.corner, field.sure, baseline.rotation

## Q15: May the defender turn a kubb when standing it up?

- **Status:** answered (2026-11-21) by the rule text: no. The U.S. rules v4.0 raise a kubb
  exact: "upon one end while keeping two corners on the ground" (II.D.1,
  web-us-rules-v4#p7.3), and exact: "Twisting a kubb is never allowed" (II.D.9.a,
  web-us-rules-v4#p8.2; a penalty under III.C.5, web-us-rules-v4#p11.1). The 2011 rules
  these pieces were written under have the same raising sentence (II.D.1,
  web-us-rules-v2#p7.3) and allow a twist only where uneven ground requires it (II.D.7,
  web-us-rules-v2#p9.2).
- **Asks:** Josh Feathers and Chris Hodges both treat a kubb's facing as something the
  defender sets: a corner toward the attacker on the front kubb of a double, a flat face
  when nothing else differs (ko-2012-doubles#p1.16, ko-2013-fence#p1.15). The engine
  raises a kubb by tipping it onto one end about that end's bottom edge (U.S. rules
  II.D.1 as the engine reads them), which fixes its facing by how it lay. Were they
  choosing a facing, or choosing which kubb to stand where?
- **Recommendation:** Go by the rule text the engine plays. If it fixes the facing, then
  facing is something the inkastare and the bounce decide, and the defender only reads
  it. The physics already makes it matter.
- **So far:** Read side by side on 2026-11-21. The other rule sets agree: the German
  rules tip a kubb over a short edge without turning or shifting it
  (web-dkb-rules-2025#p5.1), and the Belgian forbid turning or rotating it so as to
  change the way it would stand (web-kf-rules-2026#p19.1). The 2003 World Championship
  booklet says only that a kubb is raised where it lies in the direction of the
  defenders' choice (web-vm-rules-2003#p4.1), which reads as the choice of end in the
  light of the detailed rules adapted from it, but does not say so. The Belgian rules
  also set base kubbs flat face to the opponent, never a corner
  (web-kf-rules-2026#p10.1): facing matters enough to be ruled on. So Feathers and Hodges
  were reading facings they could not set, or writing loosely; the engine's raising
  (tip about the bottom edge of the chosen end) is the rule.
- **Settle by:** done: the current U.S. rules and the 2011 rules, read side by side
  (above).
- **Touches:** raise.facing, raise.square (both now say so); inkast.single and
  field.angle, where facing is the inkast's and the attacker's, not the defender's

## Q16: Why does the pro computer take three kubbs so rarely?

- **Status:** open: investigated in the Gym and against the reference engine; three causes;
  0.12.0's plays take the pro to 6.8% (the target is 12 to 18)
- **Asks:** The top third of tournament teams take three or more kubbs with 12 to 18% of
  their field batons. The pro computer does with 4.9%, and no aim closes the gap (Q14).
- **So far:** 2026-11-21, engine 0.11.0. One reading first: the turn's first baton at a
  fresh group of three or more already takes three or more 12.8% of the time. The figure
  per baton is low because of what is left for the later batons. Then three causes, in
  order of size.
  1. **The groups, about 5 to 6 points.** Lying, the pro computer's kubbs touch (median
     8.7 cm to the nearest). Standing, they do not (18.4 cm; one kubb in twenty has
     another in front of it within a kubb's height), because `apart` spreads them. A
     hand-made touching pile stood up by the same policy doubles the figure, to about 10%.
  2. **The throw, about 1.5 points on today's groups and 5 on tight ones.** The flattest
     throw the plan allows (`plan.tune.arcFarDeg` 15: loft 7 degrees, 10.5 m/s, a
     backswing a person can make) takes 16.3% from tight piles against 11.3% as shipped,
     and clears six in 4.2 batons, the real top teams' figure. Played side against side it
     wins 68.4% at pro (65.0 to 71.9) and 72.0% at club (68.4 to 75.6), much of it from
     base kubbs at 8 m, which rise to 40.9% at pro, inside the real range. Its costs: a
     short 8 m baton runs on 6.5 m where it now runs 2.7, and a baton that touches a kubb
     leaves it standing 4.5% of the time against 11.4%, further from the recorded throws'
     23.5% (people's throws played on the engines of their day, 0.2 to 0.7: not a real
     rate, docs/notes/gym.md "The recorded-throw bank").
  3. **Kubb knocking kubb, about 1 to 2 points, more as groups tighten.** Against MuJoCo
     with the same sizes, masses, friction and bounce (1,337 hand-made group cases), the
     two engines agree on what the baton keeps and where it goes, and on fences and loose
     lines. They differ on a blow passing from kubb to kubb: a line of three struck clean
     has 0.54 kubbs felled by another kubb in ours against 0.88 to 1.08, and a touching
     column of six is far too stable (0.10 toppled against 0.62 to 0.74 under pro's
     nerves). MuJoCo's own variants disagree on deep piles, so this is a lead, not a
     verdict.
  Then 0.12.0: the raising by level (`par` at pro) and two attacking plays,
  `inkast.depth` and `field.line`. `par` alone took the pro's three or more down to 1.8%;
  with the plays it is 6.8% (0.11.2: 4.9%), took two 22.2% (in range), turns cleared
  78.5% and turns a game 12.3, where 0.11.2 had them and still short of real play (87 to
  94% cleared, 6 to 10 turns). The standing groups are tighter (30% of kubbs touching
  another, 4% on 0.11.2; the owner's range 60 to 90), so cause 1 is partly met; causes 2
  and 3 are untouched (docs/notes/gym.md, "The attacker's plays"). The plays are the pro
  computer's only: the club computer throws as on 0.11.2 (1.9% three or more, against 3
  to 7) until it is retuned.
  A clip observed since (2026-11-21) bears on cause 3 from the side: a baton meets a row
  of ten kubbs standing side by side across the throw, touching or nearly, and the
  struck kubb's neighbours fall with it (yt-KcvzNzU7ZS8#1:04, yt-KcvzNzU7ZS8#1:30).
  Against it, Chris Hodges reasons that kubbs side by side do not fall together
  (ko-2013-fence#p1.11), the reason behind `raise.across` and `par`. One throw, its
  release cut, a kubb already tilting before impact, and a touching row where a raised
  fence stands 10 cm apart: it settles nothing, but it says the sideways transfer
  through touching kubbs is worth a case of its own.
- **Recommendation:** Take them in the order the plays allow. The raising comes first and
  will change how groups stand, so measure again after `raise.par` (done, with the plays
  that answer it: 6.8%). The flatter throw is now the cheapest real gain and has an owner's word behind it (a baton at 5 m is thrown
  "fairly low", `core/throwplan.lua`); make it the computer's choice by level, not the
  plan's default, so a person's aim does not move. The kubb-to-kubb transfer is a physics
  change that moves every golden hash: do it last, and only with a measurement of real
  wood to aim at.
- **Settle by:** `gym versus` after each; for the physics, a filmed baton into a touching
  column or pile, and into a touching row across the throw; the reference engine on the
  same row (docs/notes/reference-engine.md), which costs no hash.
- **Touches:** field.sure, field.power, inkast.depth, raise.across, the physics

## Q17: Where does the inkastare stand?

- **Status:** open
- **Asks:** One coach in two lessons. In the earlier one a right-hander inkasts from the
  right side, near the sideline, so the kubbs land where they can be forced in
  (yt-Io-rxbSB3Ns#0:35, yt-Io-rxbSB3Ns#0:43). In the later one, staying there is the
  habit to break: as the group reaches into the field the left-to-right cut from the
  sideline gets harder, so move along the baseline, a metre or as far as level with the
  king, and let the natural cut run into the group (yt-993xiTqXtYw#0:16,
  yt-993xiTqXtYw#0:28, yt-993xiTqXtYw#1:02, yt-993xiTqXtYw#1:27). It is about where the
  thrower stands, not where the group goes: `inkast.corner` is untouched.
- **So far:** The rules fix only that the inkastare throws from behind the baseline with
  both feet between the sidelines (web-us-rules-v4#p6.4). The computer stands straight
  behind each spot it aims at, so its stance follows the group in and it never throws
  across the body; it never stands further in to throw across at the group, and its cut
  is always toward the sideline (`inkast.stance`, `inkast.steer`).
- **Recommendation:** Read them as one coach's teaching in two steps, not a contradiction:
  start by the sideline for the first kubbs, and move in as the group grows. The later
  video is his account of what he changed, so where they differ it wins. It needs no
  new cut: thrown from further in, the computer's one tap toward the sideline is the
  natural cut he describes running into the group.
- **Settle by:** the Gym: the pro computer standing in, by the group's reach from the
  sideline, against straight behind each spot, on how far later kubbs rest from their
  marks and on the attacker's take at the group; and a match video of a top inkastare
  showing where they stand.
- **Touches:** inkast.stance, inkast.corner, inkast.steer

## Q18: Does a field kubb's default arc go by the target, or only by the distance?

- **Status:** answered (0.16.0): one line by distance for every target, lowered
- **Asks:** On 2026-11-20 Jamie set a baton's default release by the distance alone: "The
  closer you are to the target the lower you throw", and "arc based on target is just
  obviously wrong" (docs/notes/throw.md, plan.tune "A baton's default release"). On
  2026-11-22, of a baton on that default from the advantage line 1.4 m from a group: "A
  real player would throw hard at a tight group this close" (owner-2026-11-22#s2). Kyle
  Weakland throws light to medium at a group so as not to miss (ko-2017-blasting#p1.6,
  ko-2017-blasting#p1.23), and says a tight group needs power (ko-2017-blasting#p1.5).
- **So far:** A first build of 0.16.0 gave field kubbs a lowered line of their own and
  kept the old one for base kubbs, the king and empty spots. The ruling of 2026-11-20
  stands, so the simpler answer was measured first: the lowered line for every target.
  Outside field kubbs under 8 m it reaches the king from the baseline (4 m), a Kid match's
  base kubbs from the Kid line (6 m) and its king, and an empty spot. A lone king at 4 m:
  a perfect swing 100% on both, the recorded hand 87% before and 89% after, a newcomer 54%
  and 62%. The Gym's king shots 88.4 / 84.0 / 85.3% before and 94.2 / 83.6 / 88.6% after
  (beginner, club, pro hands; n about 300 to 350 each); games lost to an early king 3.0 /
  0.3 / 0.3% and 2.7 / 0.3 / 0.3%. On the Kid meter a lone base kubb at 6 m 54% and 56% for
  a small child's hand, the king at 4 m 83% and 86%; in Kid matches the king 96.2 / 99.7 /
  96.5% and 96.2 / 98.7 / 96.8%. Every row holds within its interval or rises
  (docs/notes/throw.md "The drive", "What else it reaches").
- **Recommendation:** Done: one line by distance, lowered (`plan.tune.arcLine`), for every
  target; `plan.arcFor` takes no target. The line before is `plan.sharedArcFor`, the
  computer's until its drive is switched on.
- **Settle by:** done.
- **Touches:** field.drive, field.power

## Q19: Should a typical player on the meter throw like a club player, or like the people who have played so far?

- **Status:** open: for the owner
- **Asks:** The person's meter (0.13) was tuned so that the recorded hand of the time (fit 1,
  418 throws on engine 0.7.1, before the meter) fells a lone kubb as the club rows of
  `docs/reference/play-levels.json` say. Refitted from people on the meter itself (fit 2,
  2026-11-22), the recorded hand fells an 8 m base kubb 43% of the time against the club
  row's 19 to 27% (real games, all teams: 32.7%), lands a thrown kubb dead 78% of the time
  (the club computer 56%), and beats the club computer in 86 games of 100. Should the bars
  narrow until a typical player throws like a club player, or stay where the people who
  have played so far find them?
- **So far:** Fit 2 rests on 212 throws (133 batons, 79 thrown kubbs) from 6 matches and 4
  players, one match 35% of them, all on engine 0.13.1 and its wider kubb bars
  (docs/notes/gym.md "Fitting the human thrower"). The owner said on 2026-11-22 that people
  now drill too well (owner-2026-11-22#s4); 0.16.0 narrowed a thrown kubb's bars to a
  baton's for that. Nothing has been narrowed on fit 2.
- **Recommendation:** Wait for the evidence before narrowing: about 200 throws a cell from
  10 or more matches and 5 or more players. What narrowing would take is measured in
  docs/notes/throw.md "Bars that bring the recorded hand to club": the release bar does
  it, the power bar hardly matters.
- **Settle by:** the owner's word on who the meter is for, then the recorded matches above,
  then the Gym against the chosen rows.
- **Touches:** none

## Q20: How long does a real 8 m throw take, and on what line?

- **Status:** open: for the owner (Q19 is the meter's question, on another branch)
- **Asks:** The owner, 2026-11-22: "I think the physics of our baton throw may just be too
  slow." A throw's speed is set by its line: to carry 8 m from the hand (0.6 m up) to a
  kubb's aim height, with the air's drag, a baton needs (`flight.speedForCarry`):

  | launch loft | release speed | flight time | speed at the kubb | coming down at |
  | --- | --- | --- | --- | --- |
  | 10 | 13.7 m/s | 0.62 s | 12.8 m/s | 17 degrees |
  | 15 | 11.8 m/s | 0.74 s | 11.2 m/s | 22 degrees |
  | 22 (the default at 8 m) | 10.3 m/s | 0.88 s | 9.9 m/s | 28 degrees |
  | 30 | 9.4 m/s | 1.03 s | 9.1 m/s | 36 degrees |

  Does a real 8 m throw take about 0.9 s and peak about a metre above the hand (the
  default), or 0.6 to 0.7 s on a flatter line (a quarter to a third faster at the kubb)?
- **So far:** The engine's flight matches the ballistics (MuJoCo and `flight.carry` agree to
  millimetres), so a throw is not slow for its line; only the line can be. No source in
  `docs/reference/observations/` times a flight. What makes hits soft in play is measured
  apart: a baton that meets the turf before the kubb (about half of a person's 8 m touches)
  reaches it at about 5.7 m/s instead of 9.8 (`lua5.4 tools/groundfirst.lua`).
- **Recommendation:** Time one: a lesson or match clip with a baton seen from release to
  touch, frame by frame. Until then the default line stands; it is the owner's rule by
  distance (plan.tune.arcLine).
- **Settle by:** a timed clip, then the owner's word on the line.
- **Touches:** none

## Q21: What does a real baton do when it clips the top of a standing kubb?

- **Status:** open: for the owner (a filmed test)
- **Asks:** A baton at throwing speed that clips only the top centimetre of a standing
  kubb, its lowest point a few millimetres under the top edge: does the kubb fall, and how
  often? The engine fells 94 to 100% of such grazes, MuJoCo 40 to 65%, and in the engine a
  fast glance at a top corner falls or stands by where the 240 Hz step falls
  (docs/notes/physics.md, "A glance at a top corner").
- **So far:** No source in `docs/reference/observations/` shows a graze close enough to
  count. MuJoCo is no referee here: its friction creeps near the cone's edge.
- **Recommendation:** Film it. A kubb standing on grass, a baton thrown or swung at 8 to
  10 m/s so that it clips the top 1 cm of the kubb (its lowest point under the top edge,
  coming down about 20 degrees), at least 20 tries, filmed from the side at 120 fps or
  more; count the tries that touched only the top centimetre and how many of those fell.
- **What each answer decides:** most fall (above 80%): the engine is right to fell them;
  the built fix (`at-touch`, the touch met at its moment) ships with the baton's rounding
  cut from 1 cm to 2 or 3 mm, which keeps them falling and makes the outcome the same in
  every step phase. About half or fewer fall: the engine over-fells grazes; the fix is
  left out, and a compliant edge contact is the work, not the phase.
- **Settle by:** the filmed count.
- **Touches:** `core/world.lua` (`atTouch`), `core/collide.lua` (`batonRound`)
