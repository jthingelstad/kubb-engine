# The computer player

How the engine decides what to do with a kubb or a baton, at each level, and what it asks
of a game surface. A design, written 2026-11-21 for engine 0.11.0; the sections say which
parts exist. Since 0.11.1 three of the four parts do (Read, Choose, Throw, with the plays
table); Value does not yet. Since 0.12.0 Choose also raises, by level, and carries out
two attacking plays, `field.line` and `inkast.depth`. Read `docs/reference/README.md` first: the plays this design
carries out live there, each with the players who said it.

## The aim

Jamie, 2026-11-21: the engine should play kubb the way an amazing player does, and work
for beginners, club players and pros (`docs/reference/observations/owner-2026-11-21.md`).
The engine is the brains and the strategy. A game surface (the Playdate, the web, the
iPhone) is the experience: it shows the pitch, takes a person's inputs and hands them
over. So the engine says what inputs it needs, and a surface works out how to collect
them.

## Where 0.11.0 stands

`core/autothrow.lua` made four choices, the same at every level (since 0.11.1
`core/cpu.lua` makes them, unchanged):

1. which corner to inkast to: the one with more field kubbs near it;
2. where each kubb should rest: at the basket (beginner) or in a row beside the last
   (club and pro);
3. which field kubb to throw at: the one with the most kubbs straight behind it;
4. where to stand: straight behind the target, as far forward as allowed.

The levels differ in the hand, not the head: how steady the swing is and how far a
release scatters. It never throws deep, never aims at a line for the rethrow, never moves
along the throwing line to line two kubbs up, never chooses how a baton should meet a
kubb, and never weighs one choice against another. Raising takes the end farthest from
the nearest kubb; a punishment kubb goes deep and away from the others.

Against real play (Gym, 300 matches a level, 2026-11-21) the pro computer is short where
groups are taken: 4.9% of its field batons take three or more against 12 to 18% for the
top third of tournament teams, it clears 77% of its fields against 87 to 94%, and its
games run 12 turns against 6 to 10. The inkast is not the main gap. The baton at a group
is.

## Four parts

The computer player is four parts, each a module in `core/`, pure Lua like the rest.

| Part | Module | Answers | Exists |
| --- | --- | --- | --- |
| Read | `core/read.lua` | What is the situation? | 0.11.1, what 0.11.0 read |
| Value | `core/value.lua` | What is a position worth, in batons? | not yet |
| Choose | `core/cpu.lua` | Which play, and why? | 0.11.1, the choices 0.11.0 made; raising by level, 0.12.0 |
| Throw | `core/autothrow.lua` | What does the hand do with that intent? | yes |

0.11.1 cut them out of `autothrow.choose` with no change in play: `test_cpu_regression`
holds `autothrow.choose` to 0.11.0's results over 480 setups, field for field, and the
golden hashes held. What exists of each:

- **Read** has what `autothrow` worked out about the pitch: the field kubbs near each
  basket (`read.basketCounts`), the lying kubbs near one and their middle
  (`read.lyingNear`), the innermost of them (`read.innermostLying`), the clear spot test
  (`read.spotClear`) and a front kubb's lane (`read.lane`); since 0.12.0 also the lane
  along the true line from any stance (`read.lineLane`, for `field.line`: the kubbs in
  it, the same lane weighed as `raise.par` weighs a pair, and whether the king, a kubb in
  front or a kubb of the thrower's own half rules the stance out). Its tune numbers stay
  in `autothrow.tune`, where the Gym and the session's tune files set them.
- **Choose** is `cpu.decide(s, r, level)`: the basket (`cpu.basket`), the spot
  (`cpu.spot`), the spin, the field target by lane, the stance line and the arc, with
  `why`. It draws from the throw's stream only for the basket's coin on a tie, as 0.11.0
  did. 0.12.0 changes play, but neither of its plays draws (a level knows a play or does
  not), so Choose still has no stream of its own: it comes with the first play a level
  uses only some of the time, or a beginner's random raise. `cpu.last` holds the last
  decision: the session exposing it to a client is a later step.
- **Choose's plays** (0.12.0) sit in `cpu.tune`, each switched by level and off entirely
  (`on = 0`), with its numbers beside its switches, so the Gym reaches them
  (`--set cpu.tune.line.pro=0`). `field.line` (pro): for each standing field kubb, the
  stance straight behind it and, for each kubb beyond it, the point on the throwing line
  that puts the two one behind the other (and a step or two along the line when straight
  behind is no good); each scored by its lane times the chance of hitting the front kubb
  from there. `inkast.depth` (pro): the kubbs end to end in columns down the baton's path,
  four to a column, held 4.35 m from the baseline. Club knows neither and, but for
  `field.drive` (0.18.0), plays as in 0.11.2 (Jamie, 2026-11-21: it is to be retuned as a whole against its new target).
- **Choose raises** (0.12.0): `cpu.raising` is the level table (pro `par`, club `apart`,
  beginner `first`) and `cpu.raise(dec, ctx, level)` the decision, kept in `cpu.last`
  with `kind = "raise"` and, at pro, `why.play = "raise.par"` (facts: the level, the
  policy, the ends, how much each leaves in line, whether it was a tie). `cpu.advice`
  (`par`) is a person's side. Which side is which is the match's:
  `match.raisePolicy(m, side)` (docs/notes/rules-engine.md). A beginner's `first` stands
  in for a random end, which needs Choose's own stream.
- **The plays table** (`core/plays.lua`) holds the three plays 0.11.0 carries out:
  `inkast.corner`, `inkast.roll` and `field.roles`, and since 0.12.0 `raise.par`,
  `field.line` and `inkast.depth`, and since 0.18.0 `field.drive`. A baton at a base kubb and the king
  shot carry out no play in the reference, so their `why` has facts and no play.
- **Throw** is `autothrow.choose`: Choose, then the stance, the solve, the swing and the
  launch.

**Read** turns a match setup into the quantities `docs/reference/SITUATIONS.md` names:
kubbs in hand, field kubbs and the groups they form, the lines a baton could take through
them from any stance, which thrown kubbs lie on a line, how many the defender will have a
choice on (`raising.options`), batons left, the score. It decides nothing.

**Value** is the yardstick (`levels.value`): the average batons a team at a level needs
to finish a position. A table per level, counted from that level's own Gym games with
`tools/batonvalue.mjs`, and checked against the table counted from the scored tournament
games. Choose compares two options by what each leaves to be done.

**Choose** holds the plays. For the action in front of it, it lists the candidate
intents the level knows, scores each with Read and Value, and picks one. It returns the
intent and the reason.

**Throw** is what `autothrow` already does well: stand, solve the plan for the intent,
and make a swing with the level's mistakes in it. It stops deciding.

`autothrow.choose(setup, rng, scale, level)` keeps its signature and its meaning, since
the Playdate and the session call it: it is Choose then Throw (0.11.1). Its result does
not carry `why`: that table goes into the session's aim, its actions and its checks, so
the reason is kept beside it, on `cpu.last`.

## A decision

Choose returns one table:

    { kind = "toss",                       -- or "baton", "raise", "punish"
      intent = { ... },                    -- the inputs below
      why = { play = "inkast.deep",        -- an id from docs/reference/plays
              facts = { inHand = 7, clearCount = 5 },
              over = "inkast.corner" } }   -- what it chose against, when it weighed two

`why` is data, not prose. `core/plays.lua` holds each play's id, phase, the levels that
know it and one plain sentence a surface can show as it is ("Threw deep: seven kubbs to
face and five it could clear."). A surface with an on-device language model may put
that into its own words for a coach or a review. The model only rephrases facts the
engine gave it; it never chooses a throw, because a throw has to be the same on every
client and repeatable from a seed.

`make refcheck` holds the two ends together: every play id in `core/plays.lua` is a play
in `docs/reference/plays/` (0.11.1). The other end, that a play whose `Engine` line says
it is modelled is in `core/plays.lua`, is still to come: several plays are modelled in
part by choices that have no entry of their own yet.

## Levels

A level is three things.

- **The hand** (exists): swing mistakes, release scatter, nerves, tumble. `plan.levels`,
  `autothrow.tune`.
- **What it knows:** for each play, how often the level uses it when the situation comes
  up, from 0 to 1. A beginner knows almost none. Club knows the common ones and applies
  them unevenly. Pro knows them all.
- **How well it judges:** the error in its reading of a position. A club player's count
  of the batons a group needs is rougher than a pro's.

Kid is a fourth level, below beginner (0.15.0; Jamie, 2026-11-21: "kid level is for kids to
have fun with kubb"). Choosing it makes a Kid match (docs/notes/kid-mode.md). The Kid
computer has the hand (`plan.levels.kid`: `nervesDeg` 1.8, `swingScale.kid` 1.5,
`drillScatter` 2.5), a beginner's inkast with no spin (`inkast.kid`) and a beginner's
raising (`first`); it knows no play (`field.line`, `inkast.depth`, the row are pro's and
club's), never raises `apart` or `par`, and places no punishment kubb (the Kid rules have
none). Its tune is set in the Gym so a child (the human thrower on the Kid meter, hand x3)
wins about 75 games in 100 (docs/notes/kid-mode.md "The Kid computer").

A level's numbers are not chosen by feel. Each is set so the level's Gym scorecard sits
in its range in `docs/reference/play-levels.json`, and so a level beats the one below it
by a margin we state.

## The inputs

An intent is what a thrower means to do. A person's surface and the computer produce the
same table; the hand then adds the mistakes. Every field has a default, so a simple
surface may send only a target.

| Action | Field | Meaning | Today |
| --- | --- | --- | --- |
| toss | `spot` | where the kubb should rest | the circle (`setTarget`) |
| toss | `roll` | which way and how far it rolls after landing | `setSpin`, in taps |
| toss | `arc` | how high it flies | `setArc` |
| toss | `stance` | where along the baseline the thrower stands | `setStance` |
| baton | `target` | the piece or point aimed at | the circle |
| baton | `stance` | where along the throwing line | `setStance` |
| baton | `arc` | how flat and so how hard | `setArc` |
| baton | `tilt` | the spin plane tipped | `setTilt` |
| baton | `height` | how high on the piece the baton should meet it | fixed at 0.3 of the height |
| baton | `turn` | how far the baton has turned when it arrives | fixed by the level |
| raise | `end` | which end, for a kubb with a choice | the `raise` action's choice |
| punish | `spot` | where it stands | the `punish` action |
| punish | `facing` | which way it is turned | fixed, square to the pitch |
| any throw | `hand` | right or left | none: the thrower has no hands |

So most of what the plays need can already be said by a person. The computer does not
say it. Four inputs are new: a baton's `height` and `turn` (`field.corner`, Q14), a
punishment kubb's `facing` (`punish.safe`) and the thrower's `hand`, which decides the
corner (`inkast.corner`), where the arm is over the line (`field.line`) and which side is
the off side (`punish.king`).

A new input reaches a surface through the session (`docs/SESSION.md`) and goes by
`docs/VERSIONING.md`: fields a client may leave out go with a minor version; a format an
older client cannot read is a major one. Each client moves to the tag when its own work
is scheduled.

## Rules this design keeps

- **Same seed, same game.** Choose draws from its own random stream, never the throw's,
  so adding a decision cannot shift a throw that did not change.
- **Bounded work.** A decision may run on a Playdate. Candidates are few (a dozen stances
  by the front kubbs; the raise looks ahead a set depth), and no decision allocates per
  physics step. `core/world` and `core/collide` are not touched.
- **No play without a source.** A choice in `core/cpu.lua` names a play, and the play
  cites its observations.
- **No play without a result.** A play is switched on for a level only after the Gym has
  played it side against side and it won, or moved the level toward real play without
  losing.

## How a play gets in

1. The play is in `docs/reference/plays/` with its sources.
2. The Gym has the row that measures it.
3. It is built in Choose, switched off at every level. Nothing a seeded match does
   changes, the golden hashes hold, and it ships as a patch.
4. `gym versus` plays the level with it against the level without.
5. If it earns its place it is switched on at the levels that know it: a minor version,
   `make golden`, the play's `Engine` line and the scorecard in the pull request.

## The order of work

First the split itself, with no change in play: Read, Choose and Throw cut out of
`autothrow.choose`, `why` returned, every golden hash as recorded. Done in 0.11.1.

Then plays, by what `gym versus` shows matters most. Its first results (2026-11-21,
0.11.0, docs/notes/gym.md "Versus") reordered this list:

1. **Raising by the attacker's batons** (`raise.par`, `raise.across`). The largest effect
   measured so far: the engine's `apart` policy loses about three games in four to any
   policy that keeps a row a row. It comes first because every inkast result depends on
   it (Q6 and Q7 are one contest). Built switched off in 0.11.2
   (`raising.policies.par`) and proven side against side: it beats `apart` 77 to 23
   against the row and matches it against the line (docs/notes/gym.md, "Raising by the
   attacker's batons"). Switched on by level in 0.12.0: pro `par`, club `apart`, beginner
   `first`, a person's automatic raising and by-hand default `par`; `match.settle` raises
   with the defender's policy (`match.raisePolicy`). Done; the scorecard is in
   docs/notes/gym.md, "Raising by level". Played again against 0.12.0's attacker: `par`
   and `apart` are now level at pro (the 77 to 23 was the old attacker's blind spot), and
   `par` beats the same-end policies 55 to 57, so it stays. What it leaves: a beginner's
   random end (Choose's own stream).
2. **The baton at a group** (`field.line`, Q14). The reason `apart` loses is a blind spot
   in the attacker: the computer cannot take two kubbs standing flank to flank, and takes
   a tight fence one baton a kubb. This is also where the pro computer is furthest from
   real play. The Gym has ruled one idea out: hitting the top front corner with the baton
   half turned (`field.corner`) takes fewer kubbs in this physics, not more. And it has
   found three causes of the gap (Q16): the groups stand too loose once `apart` has
   spread them; the computer throws softer and higher than the flattest throw a person
   can make, which wins about two games in three side against side; and a blow passes
   from kubb to kubb less readily than in the reference engine. `field.line` is built and
   on at pro in 0.12.0: it wins 54.8% and 56.9% alone and 59.5% and 61.4% on top of
   `inkast.depth`; at club it adds nothing, and club knows neither play. Left: the flatter
   throw by level, and the kubb-to-kubb transfer.
3. **The inkast's shape, played again** against a defender who raises well: row, line and
   a wall in depth along the sideline. Against `par` the 0.10 line beat the row, about 55
   to 45; `inkast.depth`, columns down the baton's path landed with the row's dead landing
   and roll, beats the row 74.5% at pro and 59 to 62% at club. It is on at pro only in
   0.12.0: at club it moved the computer away from real play (longer games, more doubles)
   and further from the owner's new target for club (a typical online player wins about
   four in ten; owner-2026-11-21#s6), so club plays as in 0.11.2 until it is retuned as a
   whole (Jamie, 2026-11-21). With both plays the pro computer is back where 0.11.2 had it
   on took two, turns cleared and turns a game, and ahead on three or more (6.8% against
   4.9%), still short of real play on cleared turns (78.5% against 87 to 94) and game
   length (12.3 turns against 6 to 10); it beats 0.11.2's pro 79 and 81 games in 100
   (docs/notes/gym.md, "The attacker's plays"). The wall right on the
   sideline waits for a computer that aims at a line.
4. **Club, retuned as a whole** against its target: a typical online player wins about
   four games in ten against it (0.12.0: about 16 in 100). `inkast.deep` at club and
   `inkast.chase` at pro.
5. `inkast.first` and `inkast.steer`.
   `field.drive`, built switched off in 0.16.0 and on at club and pro in 0.18.0: every
   baton but the king shot on a person's default line; the king shot by level
   (`autothrow.tune.kingScale`, into every level's king row). The Gym's person at club
   wins 61.3% against the club computer (68.8% on 0.16.0, 48.5% on 0.15.1): open,
   docs/notes/gym.md "Where 0.18.0 stands".
6. The punishment plays, and `king.corner` as a Gym experiment.

The levels are far apart: pro beats club 97 games in 100 and club beats beginner 94
(0.12.0, seeds 1 and 2). The owner's targets (owner-2026-11-21#s6): a new player wins
about two games in three against beginner, a typical online player about four in ten
against club, and pro is left hard, with no extra level yet. In 0.12.0 the human thrower (the Gym's
person, at the same level) wins about 98 in 100 against beginner, 16 against club and
none against pro.
Whether a level should beat the one below it that often is a product question (Q11 and
the levels) and is not settled here.

## The row's depth (1.3.0)

From a played online game (the owner, 2026-11-26): the club computer's drilled kubbs
rested 1.2 to 2.2 m past the centre line, where real players drill near it. In one turn
the rests went 5.21, 5.43, 5.77 and 6.23 m from the baseline. The cause was the row
(`cpu.spot`): the first kubb aims at the basket and runs on a little, and each later kubb
was aimed beside the innermost kubb lying at that kubb's depth, so every overshoot added to
the last. 1.2.0 moved only where the row starts.

The play is `inkast.first` with `inkast.roll`: the first kubb is the marker the rest are
thrown off, and a later kubb lands just short of the group and rolls into it, so the kubb
already down is the backstop, not a depth to copy. With
`autothrow.tune.inkast.<level>.rowCap = 1` a later row kubb is aimed beside the innermost
lying kubb as before, but no deeper than `rowPast` (0.15 m, about a kubb's width and a
gap) past the level's basket (`core/cpu` rowDepth). A kubb lying short of that is still
laid level with. A pro column is laid deep on purpose and grows forward toward the
line, so the cap does not reach it; a beginner throws every kubb at the basket.

Built switched off, then proven in the Gym (grass, 300 seeds each played both ways
round, turn limit 40):

| team A | team B | B's score (95%) |
| --- | --- | --- |
| club | club, rowCap 1, rowPast 0 | 61.8% (58.4 to 65.3) |
| club | club, rowCap 1, rowPast 0.15 | 60.6% (57.3 to 63.8) |
| club | club, rowCap 1, rowPast 0.3 | 57.1% (53.8 to 60.4) |
| club, rowCap 1 (seed 2) | club, rowCap 0 | 35.8% (32.7 to 39.0) |

Where the club computer's drilled kubbs rest past the centre line (kubbs in the far half
only; `gym run --out`, 300 matches of the computer against itself, read from each drill's
`restY` in the throw lines, as the Gym has no row for it yet; the versus runs agree):

| | median | 90th percentile | over 1 m |
| --- | --- | --- | --- |
| club, 1.2 (every kubb) | 0.54 m | 1.25 m | 18.7% |
| club, 1.2 (the last of an inkast of 3 or more) | 0.69 m | 1.47 m | 28.4% |
| club, rowPast 0.15 (every kubb) | 0.51 m | 0.86 m | 5.6% |
| club, rowPast 0.15 (the last of 3 or more) | 0.55 m | 0.87 m | 5.2% |
| pro (columns; unchanged) | 0.45 m | 0.72 m | 1.3% |
| beginner (the basket; unchanged) | 0.49 m | 1.23 m | 17.0% |

The median stays where the basket puts it (club 4.45 m, 1.2.0); what goes is the tail
that grew kubb by kubb. The groups do not fall apart (versus, without the cap against
with it): lying kubbs touching another after an inkast of three or more 0.42 against 0.41
(inside the noise; 0.43 against 0.41 at rowPast 0, just past it), three or more touching
in a chain 29.0% against 27.1%, kubbs rethrown 0.9% against 1.0%, kubbs resting outside
the far half 1.3% against 1.4%. The group is tighter: its farthest two kubbs 1.02 m apart
against 0.82. rowPast 0 puts the kubbs nearer still (median 0.44 m, p90 0.78) but loses a
little touching, so 0.15 is the one switched on, at club (and pro, where only a pro with
`inkast.depth` off lays a row).

What it costs: the club computer is stronger, and its games against itself are longer
(17.3 turns against 15.3; real club games 8 to 14). The owner's target has a typical
online player winning about four in ten against club, so club's strength wants measuring
against the Gym's person again with the rest of 1.3. It was: "Club against a typical player (1.3.0)" below.

## Club against a typical player (1.3.0)

The owner's target (approved 2026-11-26): "the computer levels retuned so a typical player
wins about 4 in 10 against club". The typical player is the Gym's human thrower (the
recorded people, fit 2, hand x1) on the honest Standard meter. Measured first, with 1.3's
meter and the aim by the baton's turn in (docs/notes/throw.md "The bars' corners"): it won
20.3% (17.3 to 23.4) against club. Club's field batons missed 18% (club's measured row is 30
to 40) and it cleared 80% of its fields against the person's 54%: the gap was club's close
throws, not its base kubbs (26% from 8 m, the person 27%).

Each lever alone, the person against club with one number changed (150 seeds unless said;
the person's score, paired by seed, with its 95% interval):

| club's change | person's score | club's field batons missed | base kubbs from 8 m | illegal |
| --- | --- | --- | --- | --- |
| none (300 seeds) | 20.3% (17.3 to 23.4) | 17.8 | 26.3 | 2.6 |
| `nervesDeg` 0.8 | 25.2% (20.1 to 30.2) | | | |
| `nervesDeg` 1.1 | 37.7% (31.9 to 43.4) | 19.4 | 14.2 | 2.0 |
| `nervesLen` 0.05 | 23.2% (18.5 to 27.9) | | | |
| `tumbleSd` 0.1 | 24.7% (20.1 to 29.3) | 19.2 | 26.0 | 2.4 |
| `kingScale.club` 2.2 | 22.8% (18.6 to 27.1) | 17.2 | 25.8 | 4.4 |
| `inkast.club.hand` 0.45 | 19.3% (15.2 to 23.5) | 18.6 | 25.5 | 2.4 |
| `swingScale.club` 1.4 | 33.5% (28.5 to 38.5) | 20.5 | 23.8 | 2.7 |
| `swingScale.club` 1.5 | 38.0% (32.3 to 43.7) | 23.5 | 23.0 | 3.5 |
| `swingScale.club` 1.8 | 87.7% (84.2 to 91.2) | 33.2 | 19.2 | 19.1 |
| `swingScale.club` 2.2 | 96.7% (94.7 to 98.7) | | | |

The nerves grow with the throw's effort, so they barely reach a field throw: 1.1 took the
base kubbs from 8 m to 14% (club's row is 19 to 27) before the person reached 40. The swing
scale reaches the close throws, but past 1.5 it is a cliff: a steady swing's shake (up to
`shakeMax` 0.22 times the scale) passes 0.33, a 30-degree tilt (`legalTiltDeg`), and the
batons helicopter (19% of them illegal at 1.8). So the swing scale goes to 1.5, the edge,
and the tumble's spread makes up the rest:

| club | person's score, seed 1 (300) | seed 2 (300) |
| --- | --- | --- |
| 1.2 and the first 1.3 draft: `swingScale` 1.3, `tumbleSd` 0.06 | 20.3% (17.3 to 23.4) | |
| `swingScale` 1.5 | 38.5% (34.5 to 42.5) | |
| `swingScale` 1.5, `nervesDeg` 0.65 | 41.7% (37.8 to 45.5) | |
| **`swingScale` 1.5, `tumbleSd` 0.08 (shipped)** | **40.3% (36.6 to 44.1)** | **43.6% (39.7 to 47.5)** |

The nerves row also lands but takes club's base kubbs from 8 m to 19.9%, the bottom of its
row, so the tumble is the one shipped. Beginner, pro and Kid are not touched.

Every matchup, before (club 1.3 / 0.06) and after (grass, 300 seeds both ways round;
the first team's score):

| team A | team B | before | after |
| --- | --- | --- | --- |
| person, Standard | club | 20.3% (17.3 to 23.4) | 40.3% (36.6 to 44.1) |
| person, Easy | club | 91.3% (89.1 to 93.6) | 95.6% (94.0 to 97.1) |
| person, Hard | club | 5.8% (4.0 to 7.6) | 12.5% (10.0 to 15.0) |
| person, hand x2 (a newcomer) | beginner | 57.8% (54.3 to 61.4) | the same |
| person, hand x1 | beginner | 98.2% (97.1 to 99.2) | the same |
| person, hand x1 | pro | 2.6% (1.3 to 3.8) | the same |
| person, hand x0.5 (a master) | pro | 62.3% (58.5 to 66.1) | the same |
| club | beginner | 100.0% | 100.0% |
| pro | club | 97.0% (95.7 to 98.3) | 98.8% (97.9 to 99.6) |

The ladder holds. The aim by the baton's turn is neutral for the computer: club with it
against club without, 51.1% (49.8 to 52.4); pro 48.9% (47.2 to 50.6).

Club's scorecard against the real games (`gym run --full --levels club`, 300 matches of the
computer against itself; club's row from `docs/reference/play-levels.json`):

| row | before | after | club's row | all real games |
| --- | --- | --- | --- | --- |
| turns a game | 17.6 | 18.7 | 8 to 14 | 8.9 |
| field batons: missed | 18.4 | 21.8 | 30 to 40 | 24.7 |
| field batons: took two | 17.2 | 15.7 | 8 to 13 | 16.0 |
| turns with field kubbs: cleared them | 71.0 | 66.3 | 68 to 80 | 83.4 |
| turns from an advantage line | 25.8 | 29.9 | 15 to 22 | 14.4 |
| base kubb from the baseline (8 m) | 25.0 | 23.6 | 19 to 27 | 32.7 |
| base kubb from an advantage line | 69.0 | 63.2 | 33 to 45 | 51.7 |
| king shots that toppled it | 71.1 | 63.2 | 62 to 75 | 83.8 |
| illegal throws, of batons | 2.1 | 3.5 | | |
| kubbs rethrown, of kubbs thrown in | 0.9 | 0.9 | 11 to 18 | 14.1 |

Field misses and base kubbs from the advantage line move toward club's row; turns a game
move away from it (17.6 to 18.7). None of the levers measured shortened club's games: each
makes club weaker, and a weaker club leaves more standing and takes longer to finish. What
else is off in the rows (not measured as causes): club clears its fields less often than
real club players (66% against 68 to 80), throws from an advantage line twice as often (30%
against 15 to 22) and almost never rethrows a kubb (0.9% against 11 to 18). Those belong to
the inkast's and the field's plays, a change of how club plays rather than of its hand, for
the play reference and the Gym in their own pull request.

## Computer players in teams (0.17.0)

Since 0.17.0 the computer is a player, not only a side: a team may hold people and
computers together, each computer at its own level (docs/SESSION.md "Computer players").
Nothing in Choose or the hand changed: autothrow.choose already threw at the thrower's
level, and a computer player's throw is that, in the team's throwing order (core/order).
What is new is who decides what the rules give the team: a team with a person on it by its
people, a team of computers at its strongest player's level (`match.strongestLevel`, then
`cpu.raising` of that level). That is a choice of which level's existing play applies, not
a new play, so it did not go through "How a play gets in". One change to the order: in a
team with a computer player the kubbs go round the team turn by turn (core/order
`rotateInk`), because the deal opens every turn of six batons with the same player in a
team of 1, 2, 3 or 6, and a computer cannot be handed the kubbs by the `thrower` action. The Gym plays such teams with
`gym versus --a "team=club+club+pro"` (docs/notes/gym.md "Versus").

## Not decided here

When each client takes a new tag. (The Kid level and mode were decided and built in 0.15.0:
docs/notes/kid-mode.md.) Whether a surface uses a
language model, and for what.
