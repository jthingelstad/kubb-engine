# The computer player

How the engine decides what to do with a kubb or a baton, at each level, and what it asks
of a game surface. A design, written 2026-11-21 for engine 0.11.0; the sections say which
parts exist. Since 0.11.1 three of the four parts do (Read, Choose, Throw, with the plays
table); Value does not yet. Since 0.11.3 Choose also has the raising by level and two
attacking plays, `field.line` and `inkast.depth`, built switched off: no level uses any of
them yet. Read `docs/reference/README.md` first: the plays this design
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
| Choose | `core/cpu.lua` | Which play, and why? | 0.11.1, the choices 0.11.0 made; raising by level and two plays built switched off, 0.11.3 |
| Throw | `core/autothrow.lua` | What does the hand do with that intent? | yes |

0.11.1 cut them out of `autothrow.choose` with no change in play: `test_cpu_regression`
holds `autothrow.choose` to 0.11.0's results over 480 setups, field for field, and the
golden hashes held. What exists of each:

- **Read** has what `autothrow` worked out about the pitch: the field kubbs near each
  basket (`read.basketCounts`), the lying kubbs near one and their middle
  (`read.lyingNear`), the innermost of them (`read.innermostLying`), the clear spot test
  (`read.spotClear`) and a front kubb's lane (`read.lane`); since 0.11.3 also the lane
  along the true line from any stance (`read.lineLane`, for `field.line`: the kubbs in
  it, the same lane weighed as `raise.par` weighs a pair, and whether the king, a kubb in
  front or a kubb of the thrower's own half rules the stance out). Its tune numbers stay
  in `autothrow.tune`, where the Gym and the session's tune files set them.
- **Choose** is `cpu.decide(s, r, level)`: the basket (`cpu.basket`), the spot
  (`cpu.spot`), the spin, the field target by lane, the stance line and the arc, with
  `why`. It draws from the throw's stream only for the basket's coin on a tie, as 0.11.0
  did. Neither play 0.11.3 builds draws (a level knows a play or does not), so its own
  stream comes with the first play a level uses only some of the time, or a beginner's
  random raise. `cpu.last` holds the last decision: the session exposing it to a client
  is a later step.
- **Choose's plays** (0.11.3, switched off) sit in `cpu.tune`, each switched by level and
  off entirely (`on = 0`), with its numbers beside its switches, so the Gym reaches them
  (`--set cpu.tune.line.pro=1`). `field.line`: for each standing field kubb, the stance
  straight behind it and, for each kubb beyond it, the point on the throwing line that
  puts the two one behind the other (and a step or two along the line when straight
  behind is no good); each scored by its lane times the chance of hitting the front kubb
  from there. `inkast.depth`: the kubbs end to end in columns down the baton's path, four
  to a column, held 4.35 m from the baseline. No level knows either yet.
- **Choose raises** (0.11.3, switched off): `cpu.raising` is the level table and
  `cpu.raise(dec, ctx, level)` the decision, kept in `cpu.last` with `kind = "raise"`
  and, for a level that raises `par`, `why.play = "raise.par"` (facts: the level, the
  policy, the ends, how much each leaves in line, whether it was a tie). `cpu.advice` is
  a person's side. Which side is which is the match's: `match.raisePolicy(m, side)`
  (docs/notes/rules-engine.md). Every level and the advice are `apart`, so every side
  raises as before.
- **The plays table** (`core/plays.lua`) holds the three plays 0.11.0 carries out:
  `inkast.corner`, `inkast.roll` and `field.roles`, and since 0.11.3 `raise.par`,
  `field.line` and `inkast.depth`, built and with no levels: no level uses them yet. A baton at a base kubb and the king
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

Kid is a fourth level, below beginner, and a product decision still open (Q11).

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
   attacker's batons"). 0.11.3 builds the raising by side, switched off: `match.settle`
   raises with the defender's policy (`match.raisePolicy`), the computer's by its level
   (`cpu.raising`) and a person's by the engine's advice (`cpu.advice`), every one `apart`
   for now. Switched on in the Gym as Jamie decided (pro `par`, club `apart`, beginner
   `first`, a person `par`: owner-2026-11-21#s5), it is measured in docs/notes/gym.md,
   "Raising by level"; against the attacker below, `par` and `apart` are level at pro and
   `par` beats the same-end policies 55 to 57, so `par` is still the one to enable.
2. **The baton at a group** (`field.line`, Q14). The reason `apart` loses is a blind spot
   in the attacker: the computer cannot take two kubbs standing flank to flank, and takes
   a tight fence one baton a kubb. This is also where the pro computer is furthest from
   real play. The Gym has ruled one idea out: hitting the top front corner with the baton
   half turned (`field.corner`) takes fewer kubbs in this physics, not more. And it has
   found three causes of the gap (Q16): the groups stand too loose once `apart` has
   spread them; the computer throws softer and higher than the flattest throw a person
   can make, which wins about two games in three side against side; and a blow passes
   from kubb to kubb less readily than in the reference engine. `field.line` is built
   switched off in 0.11.3: switched on at pro it wins 54.8% and 56.9% alone and 59.5% and
   61.4% on top of `inkast.depth`; at club it adds nothing (docs/notes/gym.md, "The
   attacker's plays").
3. **The inkast's shape, played again** against a defender who raises well: row, line and
   a wall in depth along the sideline. Against `par` the 0.10 line beat the row, about 55
   to 45. `inkast.depth` (built switched off in 0.11.3), columns down the baton's path
   landed with the row's dead landing and roll, beats the row 74.5% at pro and 59 to 62%
   at club when switched on; at club it also moved the computer away from real play and
   from the owner's new target for club (owner-2026-11-21#s6), so it is to be switched on
   at pro only (Jamie, 2026-11-21; docs/notes/gym.md, "The attacker's plays").
4. `inkast.deep` at club and `inkast.chase` at pro.
5. `inkast.first` and `inkast.steer`.
6. The punishment plays, and `king.corner` as a Gym experiment.

The levels are far apart: pro beats club 96 games in 100 and club beats beginner 94.
Whether a level should beat the one below it that often is a product question (Q11 and
the levels) and is not settled here.

## Not decided here

The Kid level and mode (Q11; for kids to have fun with kubb, owner-2026-11-21#s7). When each client takes a new tag. Whether a surface uses a
language model, and for what.
