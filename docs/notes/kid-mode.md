# Kid mode

Since 0.15.0 the engine has a Kid match: gentler rules for both sides, a wider meter for a
person and a Kid computer a child beats about three games in four. This note keeps the
owner's decision, the design and the choices made inside it, the measurements, and where
the design did not survive contact with the code. The rules as code are in
docs/notes/rules-engine.md ("The Kid rules"), the meter in docs/notes/throw.md ("The Kid
meter"), the computer in docs/notes/computer-player.md, the session's fields in
docs/SESSION.md and the pitch's in docs/PITCH.md.

## The owner's decision (Jamie, 2026-11-21)

- "'Kid' would be a super good level to add: Kid, Beginner, Club, Pro… then we can make a
  mode for kids to have fun with."
- Asked whether Kid is its own gentle mode and not just a weaker computer: "yes, kid level
  is for kids to have fun with kubb" (`docs/reference/observations/owner-2026-11-21.md`
  `s7`).
- He accepted the proposal this release builds: every baton from a line 2 m in front of the
  baseline; three base kubbs a side; a king knocked down early stood back up instead of
  losing; no punishment kubbs; no illegal-throw calls; the widest meter; a Kid computer a
  child beats about three games in four.

No published source prescribes kid rules, so every detail below is design judgement, the
engine owner's where the proposal left it open: the kinder choice for a small child that
still leaves a game worth winning.

## One switch

A client offers Kid as one more segment of its Computer row, first: Kid, Beginner, Club,
Pro. Choosing the Kid computer makes the match a Kid match: the Kid rules for both sides,
the Kid meter for every person, the Kid computer. Inside the engine the three stay
separate, so pass and play with two children can have the Kid rules later without a
computer:

| part | where | value |
| --- | --- | --- |
| the rules | `match.new`'s and `rules.new`'s `rules`, the game's `g.rules` | `"kid"`; absent: the standard rules |
| the meter | `plan.meters.kid`, the throw state's `meter` (`throw.meterFor`) | `"kid"`; absent: `plan.tune.meter` |
| the computer | `plan.levels.kid`, `autothrow.tune` (`swingScale.kid`, `inkast.kid`), `cpu.raising.kid` | the level `kid` |

The session sets `opts.rules = "kid"` when the match's computer is `kid` and the computer
plays a side, or when a caller asks for `rules = "kid"` outright; it is kept in the
snapshot only then, so every other match has the snapshot it always had, and a match, save,
replay or document with no rules plays exactly as before. The pitch has no rules setting of
its own: its Computer setting reaches the session as `computer`, and the session decides.
The Playdate's `core/matchopts` sets `opts.rules` with `opts.computer` (its client passes it
on).

## The rules as built

- **Three base kubbs a side** (`rules.kid.baseX`): `a1`..`a3` and `b1`..`b3` at x = -1, 0,
  1 on each baseline, the middle three of the standard five spots (across 1.50, 2.50 and
  3.50 in the notation's frame). Nearer the middle, a throw that misses wide stays on the
  pitch; and a standard set's spacing, so a sheet or a drawing of the base kubbs needs
  nothing new but fewer of them.
- **The opening** follows the match's option, as in the standard game. With three base
  kubbs, 2-4-6 means the first team's two batons can take at most two of three, and the
  second team's four must clear the kubbs thrown in and then three base kubbs before the
  king, so nobody can win in the first two turns. Six from the start is not kinder: the
  team that opens could take all three base kubbs and the king in its first turn, and a
  child should never lose before throwing. 2-4-6 stays the default; nothing forces it.
- **The Kid line** (`rules.kid.line`, 2 m). Every kubb thrown in and every baton at a kubb,
  field or base, by either side, is thrown from 2 m in front of the thrower's own baseline,
  or from the advantage line when that is nearer the middle (`Game:kidThrowY`, the same
  comparison of distances from the baseline the advantage line itself uses). The pitch is
  unchanged: a base kubb is 6 m away, a field kubb just past the middle 3 m. The stance's
  allowed ground moves with it: the thrower stands from `backMax` behind the baseline up to
  the line (the setup's `forwardY`), as with an advantage line.
  - **Kubbs thrown in from the Kid line too.** The proposal leaned that way; it is the
    hardest throw for a small arm, and from the baseline a child's kubb often does not
    reach the middle (a kubb that stays in the thrower's own half is out). From the line
    the far half is 2 to 6 m away.
  - **The king shot stays on the baseline,** as the standard rules have it even with an
    advantage line. The owner named field and base batons; from the Kid line the king
    would be 2 m away, which would make the last throw nearly certain and the game's end
    an anticlimax. From the baseline it is 4 m, nearer than any base kubb, and a child
    fells it about four times in five in the Gym.
- **An early king stood back up.** The king knocked down by a baton before the thrower's
  side has cleared the other side's kubbs is stood back up where it was; the throw counts
  otherwise (its field kubbs go to the hand, a base kubb hit early is raised as the
  standard rules raise it) and the turn's remaining batons go on. The same for a kubb
  thrown in that knocks the king down: stood back up, the inkast goes on. The king knocked
  down when it may be is a win as ever.
- **No punishment kubbs.** A kubb out twice is stood by the engine at the fair spot
  (`raising.fairSpot`) and nobody is asked: the session never asks for a punishment kubb in
  a Kid match. The fair spot is the valid spot (in the half, a baton length from the king
  and the stakes, on no kubb) nearest either of two points 1 m either side of the middle and
  1 m past the centre line (`raising.tune.fairAcross`, `fairDepth`): where a good kubb
  thrown in lands, 3 m from the Kid line. Not the middle of the half, the obvious place: the
  king stands on that line, between the thrower and the kubb. On a tie the left point as
  Team A sees it.
- **No illegal throws.** A helicopter counts as thrown: what it knocks down is down, and
  the file notes it.
- **What stays.** Everything else: a field kubb left standing gives the other side its
  advantage line (a consequence, not a punishment); II.B.4a (a base kubb hit while field
  kubbs stand is raised); II.B.7 (a kubb pushed out is put back); II.B.11 and II.C.4b (a
  throw that hits the thrower's own half's field kubbs is put back and forfeit; with the Kid
  line in front of a child's own field kubbs this rarely comes up); rethrows; rescues;
  raising.

## The Kid meter

`plan.meters.kid` (docs/notes/throw.md "The Kid meter"). The bars are about five times the
standard's at 6 m and three times at 3 m: half widths 17.6 / 48 degrees at 6 m (standard
3.8 / 14.2), 27.5 / 75 at 3 m and under, 11 / 30 at 8 m (`powerHalf8` 11, `releaseHalf8` 30,
`widen` 0.3). The honest rule stands: inside both bars and steady, the throw goes where it
was aimed. A wider bar with the standard's in-bar gain (0.1) let a tenth of a far larger
error through, and a child's swings inside the bars missed one in five at 6 m; at 0.02
(`inGain`) they hit as the standard meter's do. Past the bars it is gentler: the release's
pull 0.08 degrees a degree (0.15), the shake past STEADY counting 0.5 (0.75), a kubb's
scatter past a bar half (`roughGain` 3), and a soft flick's shortfall a third
(`flickIn` 0.3, new, the Kid meter's only): the flick that counts is `1 - 0.3 x (1 -
flick)`, everywhere the flick counts (the speed, the power verdict, the tumble), so the
verdict still reads what the throw got. The check of a person's throw
(`session/check.lua`) takes the match's meter and the forgiven flick.

Measured with `lua5.4 tools/meterprobe.lua --meter kid --n 400 --ranges 2,3,4,6,8 --parts
perfect,honest,hand --hands 3,2,1` (seed 1, a lone standing kubb on grass, turned 0 to 90
degrees; the Kid meter counts a helicopter as thrown). The child is the Gym's recorded hand
(the club baton part) with its misses tripled (`human.scale` 3).

| | 2 m | 3 m | 4 m | 6 m | 8 m |
|---|---|---|---|---|---|
| bars (half widths, power / release) | 27.5 / 75 | 27.5 / 75 | 24.2 / 66 | 17.6 / 48 | 11 / 30 |
| a perfect swing, fell | 100% | 100% | 100% | 100% | 100% |
| steady swings evenly inside both bars, fell | 100% | 100% | 100% | 100% | 99% |
| a child (the recorded hand x3), fell | 82% | **80%** (target 80) | 75% | **54%** (target 50) | 29% |
| a newcomer (x2), fell | 88% | 88% | 87% | 75% | 47% |
| the recorded people (x1), fell | 96% | 96% | 95% | 92% | 84% |

On the standard meter the same child fells 31% at 3 m and 10% at 6 m. A drilled kubb on the
Kid meter (`--parts drill`): the recorded hand rests a median 3 cm from the spot, 97% within
0.3 m (8 cm and 74% on the standard meter).

## The Kid computer

Gentle and a little clumsy, never cruel. It throws on the same Kid line (the setup's), on
pro's gauge as every level does, with:

- the hand: `swingScale.kid` 1.5 (a beginner's 2.2: a large swing scale makes the computer's
  shaky swings helicopters, about 40% of its batons at 2.6; at 1.5 about 3%), `nervesDeg`
  1.8 (beginner 1.6), `nervesLen` 0.08, `tumbleSd` 0.12, `drillScatter` 2.5: it misses
  mostly by a line that drifts, as a child does, not by flinging the baton;
- the inkast (`inkast.kid`): tossed out at the basket with no spin, no grouping and no
  row, the hand 0.6 of a baton's;
- raising: `first` (`cpu.raising.kid`), the simplest, as a beginner.

What it does not do, removed or never given to it: `field.line` (moving along the line to
take two kubbs at once) and `inkast.depth` (columns down the baton's path), pro's; the row
and the grouped inkast, club's and pro's; raising `apart` (club: spreads a child's kubbs
on purpose) and `par` (pro: stands them where they line up worst for the child's batons);
and a punishment kubb placed to hurt (no punishment kubbs at all). It never leaves a kubb
standing to gain a line: no level does, and Kid knows no play that would. A person's own
side is raised by the engine's advice (`par`) as in every match, which favours the child.

**The Gym** (`node tools/gym.mjs versus --a "thrower=human;hand=3;level=club" --b
"level=kid" --rules kid --n 300 --jobs 4`; grass, each seed played both ways round, turn
limit 40): the child is the human thrower on the Kid meter with its misses tripled, its
target and stance the club computer's, its kubbs raised by the engine's advice.

| seed | child won / Kid computer / turn limit | the child's score, paired 95% | turns a match |
| --- | --- | --- | --- |
| 1 | 431 / 169 / 0 of 600 | 71.8% (68.2 to 75.5) | 4.7 |
| 2 | 464 / 136 / 0 of 600 | 77.3% (74.1 to 80.6) | 4.8 |

Together 895 games of 1200, 74.6 in 100.
Tuned on `nervesDeg` (200 seeds, seed 1, before the computer's kubbs moved to the Kid line):
2.0 gave 77.5%, 1.6 gave 72.0%; shipped 1.8. The child wins more when it opens (81 and 86%)
than when the computer does (63 and 68%). Each side's own rows (seeds 1 and 2): the child
fells a base kubb from the Kid line 55% of the time, a field kubb 79 to 81%, the king 80 to
84%, and rethrows 8 to 11% of its kubbs; the Kid computer 31 to 33%, 80 to 82% and 78 to
84%, and rethrows under 1%. No game reached the turn limit.

A Kid match lasts about five turns (4.7 and 4.8: two or three each), well under the ten the owner set as
the most. If it should last longer the levers are the base kubbs (four, at -1.5, -0.5, 0.5,
1.5), the king shot's line (it is already the baseline) or six batons a turn becoming
four; none is needed for the "should not drag" limit.

## What the game file says

The engine writes Planet Kubb Notation 2 (pk-kubb-score's `docs/notation-2.md`, edition
2026.11, vendored `v2-2026.11`), and a Kid match passes the notation gate (`make games`:
every fourth headless game and five physics matches are Kid matches; canonical form, no
warnings, the same winner, positions read back).

- `[Base kubbs "3"]`: the notation's own header, and `kubb.js` counts with it (its
  `readRules`), so a king shot with three base kubbs down draws no warning.
- `[Rules "Kid rules, 2-4-6: three base kubbs; kubbs and batons from 2 m in front of the
  baseline; an early king stood back up; no punishment kubbs; helicopters count"]`: the
  rest, in words, as the `Rules` header is "the rule set, in words".
- **The king stood back up** has no token. The notation's `E` is "the baton knocked the king
  over too early: the throwing team loses", and `kubb.js` ends the game on it, so the turn
  line writes the baton's token as if the king had stood (`F`, `-`, ...) and a note: `# b3
  knocked the king down early; stood back up (kid rules)`; for a kubb thrown in, `# a kubb
  thrown in knocked the king down; stood back up (kid rules)` and no inkast `E`.
- **No punishment kubbs.** The notation's `P` is "punishment kubbs: thrown out twice and
  placed by the other team", and a pitch line's `p` is "placed this turn as a punishment
  kubb". Neither is true of the fair spot, so the kubb counts in `R` (it was thrown twice)
  and not in `P`, the note says `a kubb out twice was stood at the fair spot, no punishment
  kubb (kid rules)`, and the turn has no pitch line (the kubb does not stand where it was
  thrown, and the line "is the whole half or it is left out").
- **The Kid line** cannot be written. `A` is "the batons were thrown from an advantage
  line", and `kubb.js` warns when it is marked with no field kubbs left standing, so the
  file marks `A` exactly when the standard rules would (field kubbs were left), whichever
  line was nearer. The stance line (`^`, "Where was each baton thrown from?", depth 0 to
  9.99 with the baseline at 4.00) could carry each baton's stance, but the engine writes no
  stance lines (its outcomes carry none), and nothing in the notation says where kubbs
  thrown in were thrown from.
- **A helicopter that counts** is written as what it did (`F`, `-`), never `Z` ("an illegal
  throw"), with a note: `# b2 helicopter; counted (kid rules)`.
- `[Throw Levels "computer kid"]` names the Kid computer.

What the notation lacks, to raise upstream: a way to say a turn was played by other rules
than the header's defaults beyond free words (a Kid or handicap line: where batons and kubbs
are thrown from, per side); a token or mark for a king knocked down and stood back up (a
house rule many casual games play); and a placed kubb that is not a punishment (a `P`-like
count and a pitch-line mark for "placed, no penalty"). None is worked around here: the
reader is not forked, and the gate passes as the notation stands.

## Where the design did not survive contact with the code

- **"The centre of the legal half" for a kubb out twice** puts it straight behind the king
  from where the child throws (x = 0). The fair spot is 1 m to either side, 1 m past the
  centre line.
- **"The widest meter" alone did not make a child's throws go in.** Widening the bars with
  the standard's in-bar gain made a swing inside them less accurate (a tenth of a larger
  error), so the Kid meter's in-bar gain is 0.02; and a child's soft flicks (the hand x3
  triples the shortfall) went short inside the bars, which the new `flickIn` forgives a
  share of. Both are the Kid meter's only; the standard meter and every golden hash are
  unchanged.
- **The king shot from the Kid line** was not in the proposal's list (field and base); it
  stays on the baseline.
- **The Kid computer's clumsiness by swing scale** turned into helicopters (about 40% of
  its batons at a scale of 2.6), which count in a Kid match but look wrong; its misses come
  from its nerves instead.
- **The Playdate's option table stores the computer's level as an index**, so Kid is its
  fourth value (a choice kept before 0.15 keeps its level) and `order` steps it first.
- **The cpu fixtures used "kid" as the name of a level the engine does not know**
  (`tests/lua/cpucases.lua`). That case is now "toddler" and the fixtures' 51 case headers
  say so; every result in them is as recorded.
- **`plan.LEVELS`** (four now) is also what `checkThrow` lists as the levels a person's
  throw fits: it lists `kid` too.
