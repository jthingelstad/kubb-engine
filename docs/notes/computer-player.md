# The computer player

How the engine decides what to do with a kubb or a baton, at each level, and what it asks
of a game surface. A design, written 2026-11-21 for engine 0.11.0; the sections say which
parts exist. Read `docs/reference/README.md` first: the plays this design carries out
live there, each with the players who said it.

## The aim

Jamie, 2026-11-21: the engine should play kubb the way an amazing player does, and work
for beginners, club players and pros (`docs/reference/observations/owner-2026-11-21.md`).
The engine is the brains and the strategy. A game surface (the Playdate, the web, the
iPhone) is the experience: it shows the pitch, takes a person's inputs and hands them
over. So the engine says what inputs it needs, and a surface works out how to collect
them.

## Where 0.11.0 stands

`core/autothrow.lua` makes four choices, the same at every level:

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

| Part | Module | Answers |
| --- | --- | --- |
| Read | `core/read.lua` | What is the situation? |
| Value | `core/value.lua` | What is a position worth, in batons? |
| Choose | `core/cpu.lua` | Which play, and why? |
| Throw | `core/autothrow.lua` | What does the hand do with that intent? |

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
the Playdate and the session call it: it becomes Choose then Throw.

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

`make refcheck` will hold the two ends together: every play id in `core/plays.lua` is a
play in `docs/reference/plays/`, and a play whose `Engine` line says it is modelled is in
`core/plays.lua`.

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
`autothrow.choose`, `why` returned, every golden hash as recorded.

Then plays, largest measured gap first:

1. `field.line`: stand where kubbs line up. The lane test from any stance, not only
   straight on.
2. `field.corner` and Q14: how the baton meets the front kubb of a group.
3. Raising by the attacker's batons (`raise.par`, `raise.across`), played against the
   inkast shapes (Q6 and Q7 are one contest).
4. `inkast.deep` at club and `inkast.chase` at pro.
5. `inkast.first` and `inkast.steer`.
6. The punishment plays, and `king.corner` as a Gym experiment.

The order will move as `gym versus` reports. It is recorded here when it does.

## Not decided here

The Kid level and mode (Q11). When each client takes a new tag. Whether a surface uses a
language model, and for what.
