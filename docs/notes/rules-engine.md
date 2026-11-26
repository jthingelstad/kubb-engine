# Rules engine, notation and throwing order

Subsystem notes moved out of `AGENTS.md` (2026-11-17). The hard rules are also in
`AGENTS.md`; this file keeps the detail and the history. Paths are from the repo root.

## Rules engine

`core/rules.lua` (`tw.rules`) is Rules V4.0 as a pure state machine. It knows nothing
about physics: it asks for the next action and takes resolved throws (the outcome records
below) and the defender's choices. Helpers: `core/pitch.lua` (dimensions, halves, stakes,
`advantageMeters`), `core/rect.lua` (oriented rectangles), `core/raising.lua` (II.D raising
and II.D.11 punishment geometry), `core/notation.lua` (score sheet and game file).

```lua
local g = tw.rules.new{ teams = { A = { name = "Jamie", players = { { name = "Jamie" } } },
                                  B = { name = "Playdate", players = { { name = "Club" } } } },
                        surface = "Grass", opening = "2-4-6" --[[ or "six" ]], first = "A",
                        raisePolicy = "apart" }
local n = g:need()
```

- Pieces: kubbs have permanent ids `a1`..`a5` (Team A's base kubbs at x = -2..2, y = 0) and
  `b1`..`b5` (y = 8); the king is `king`. `g.kubbs[id]` = `{ id, kind = "base"|"field",
  half = "A"|"B", where = "pitch"|"hand"|"out"|"punish", pose, thrown, established, fouled }`.
  `half` is the half a field kubb belongs to (where it was thrown), not recomputed from y: a
  kubb thrown this turn is a field kubb of the target half on the pitch wherever it lies
  until its round is judged. `where = "out"` means picked up for a rethrow. `fouled` marks a
  thrown kubb that touched the thrower's own half (II.C.4b) until it is judged.
  `g.king.pose`. `g:census()` counts kubbs by `where` (always 10). `g:liesNow(id)` says
  `"in"` or `"out"` for where a thrown kubb lies before it is judged; `g.judgment` is what
  the last judgment did (`thrown, rethrow, punish, rescue, lowered, lifted`), nil after a
  toss that did not end a round.
- State: `g.turn`, `g.attacker`, `g.defender`, `g.phase` (`toss`, `rethrow`, `raise`,
  `punish`, `batons`, `over`), `g.batonsLeft`, `g.advantageY`, `g.winner`, `g.how`,
  `g.sheet` (the notation score sheet).
- `g:need()` returns one of:
  - `{ kind = "toss", side, kubb, rethrow, throwY, half, left }`: the attacker throws kubb
    `kubb` from its baseline `throwY` into `half`. First throws come before rethrows (II.C.6).
    `left` counts this throw and the rest of its round (see "Judged at the final position").
  - `{ kind = "raise", side, kubb, pose, decision }`: the defender raises a lying kubb.
    `decision = { mode, choices, ends }` from `tw.raising.options`; mode is `choice` (both
    footprints clear and in bounds), `forced` (one), `displaced` (none clear: touching the
    obstruction, II.D.5; the defender may still pick the end when both qualify).
    Since 1.4.0 it also has `lying`: the ids of every field kubb of the half still lying,
    in id order (`kubb` is the first). Any of them may be raised next.
  - `{ kind = "punish", side, kubb, half }`: the defender places a punishment kubb.
  - `{ kind = "baton", side, n, of, left, kingShot, throwY, advantageY, targets }`: `throwY`
    is the advantage line when there is one and this is not a king shot, else the baseline.
    `targets` are the standing field kubbs, else the base kubbs, else `{ "king" }`.
  - `{ kind = "over", winner, how }`.
- Actions: `g:toss(outcome, player)`, `g:raise(choiceIndex | nil, policy, id?)` (nil = automatic; `id`
  since 1.4.0: any id of `need().lying`, the index then into that kubb's own decision),
  `g:raiseKubb(id, which, policy)` (1.4.0: by the end's `which`, nil the policy's),
  `g:raiseAll(policy)`, `g:placePunishment(pose)` (returns false and a reason when invalid),
  `g:autoPunishment(policy)`, `g:throwBaton(outcome, player)`, `g:resign(side, player)` (only
  on the resigning team's own turn). `player` is an id or name; it defaults to the team's
  first player. Calling an action out of phase raises an error.
- Raising policies (`tw.raising.policies`): `apart` (the game's default,
  `g.raisePolicy`: the end farthest from other kubbs), `par` (since 0.11.2: the end that
  leaves the attacker's batons the fewest kubbs one behind another, its numbers
  `raising.tune.par*`), `together`, `first`, or any `function(decision, ctx) -> index`.
  `g:context` gives each other kubb's `kind`, so a policy can leave base kubbs out.
- Which side raises how (0.12.0) is not the rules' but the match's: `match.settle` raises
  each kubb with the defender's policy, `match.raisePolicy(m, side)`. The computer
  raises by its level (`core/cpu.raising`: pro `par`, club `apart`, beginner `first`, a
  stand-in for a random end) and keeps its reason in `cpu.last`; a person's side, raised
  automatically, by the engine's advice (`cpu.advice`, `par`), which is also the end a
  client offers first by hand. The match knows the computer's sides from `match.new`'s
  `cpu` (the session passes it) or, failing that, from the mode `Vs Playdate` (Team B);
  `match.new`'s `raising = { A, B }` names a side's policy outright. A match that says
  neither raises every kubb with `g.raisePolicy`, as before 0.12. The punishment
  policy is a `function(candidates, ctx) -> pose`; the default puts it deep in the half and
  away from other kubbs.

### Poses

`{ x, y, standing, angle, onTop }` in world meters. `standing` = upright on an end; `angle`
is the long axis direction for a lying kubb (radians from +x) and the yaw of the square for a
standing one; `onTop` is the id of a kubb it rests on. A lying kubb raised on an end stands on
a 7 x 7 footprint centered 11 cm out along its axis (it pivots on that end's bottom edge).

### Baton outcome

What physics must report for one baton, after everything is at rest:

| Field | Meaning |
|---|---|
| `illegal` | true for an illegal throw (helicopter, II.B.1) |
| `toppled` | ids of every piece whose long axis came within a few degrees of horizontal at any point (II.B.10: one that ends standing on an end is still toppled). May include `"king"`. |
| `kingToppled` | true if the king was toppled (same as `"king"` in `toppled`) |
| `moved` | `{ [id] = pose }`: rest pose of every piece that moved, toppled or not (the king too) |
| `ownHalfHit` | ids of field kubbs in the thrower's own half that the baton touched, even if they did not move (II.B.11) |

The engine also treats any toppled or moved field kubb in the attacker's half as II.B.11.
What it does with them: illegal or II.B.11 throws put everything back and write `Z`; a king
toppled before every kubb is down loses (`E`, also after an illegal throw); toppled field
kubbs go to the defender's hand; a toppled base kubb with a field kubb still standing after
the throw is raised where it was (II.B.4a); a piece moved without toppling stays at its rest
pose unless its center left the pitch (II.B.7: put back). It stays as the throw left it, not
stood up straight: core/debris carries its exact body pose ("Debris" below).

### Kubb-toss outcome

| Field | Meaning |
|---|---|
| `rest` | rest pose of the thrown kubb: lying (with `angle`), standing on an end, or `onTop = id` when it rests on another kubb |
| `moved` | `{ [id] = pose }`: rest pose of every other piece it moved (field kubbs, base kubbs, the king) |
| `kingToppled` | true if it toppled the king (the throwing team loses) |
| `ownHalfHit` | optional ids of pieces in the thrower's own half it touched (II.C.4b) |

In bounds is the center of the standing kubb against the defender's half (lines are in). A
lying kubb is in if either footprint is. Struck field kubbs stay where they come to rest and
are raised there (II.C.4). Base kubbs a toss moves are stood back where they were. The king
toppled by a thrown kubb ends the game at once (`E`). Everything else waits for the
judgment below.

### Judged at the final position

The ruling (Jamie, 2026-11-13): whether a thrown kubb is in or out is not judged when it
stops. If a kubb is out and a later kubb moves it in, there is no rethrow; the rethrows go
by where every kubb lies once they are all thrown, and they come last.

- **Rounds.** A round is every kubb queued when it starts: the first throws (rescued kubbs
  among them) before the rethrows (II.C.6). While a round has throws left, every thrown kubb
  stays a piece on the engine's pitch at its rest pose (in, out of bounds, short of the
  middle line, in the thrower's own half), a field kubb of the target half, and later kubbs
  can move it. Nothing is judged.
- **The judgment** (`Game:_judge`, when the round's last throw is at rest), on every field
  kubb of the target half as it lies then, established ones included:
  1. a kubb resting on another is lowered beside it (II.D.6, `N`), unless the kubb under it
     is out (it is picked up: the upper kubb lies where it is, no `N`);
  2. an established field kubb that cannot be raised in bounds is rescued (II.C.5a, `Q`):
     back to the attacker as a kubb not yet thrown, thrown in the next round;
  3. a kubb thrown once that cannot be raised in bounds is picked up and rethrown in the
     next round (II.C.5b, II.C.6); so is one thrown once that a rethrow knocked out;
  4. a kubb thrown twice that is still out is a punishment kubb (II.C.5c, II.D.11, `P`).
  Out kubbs leave the pitch at the judgment, all at once. Rounds go on until nothing is left
  to throw; then the defender raises and places punishment kubbs as before.
- **II.C.4b at the final position.** A thrown kubb that touches a field kubb in the
  thrower's own half fouls at once: that kubb is put back (nothing in the own half is
  applied), the note is written, and the thrown kubb is out at the judgment wherever it
  lies by then (it stays on the pitch until then, a piece later kubbs can hit). A thrown kubb
  lying in the thrower's own half at the end without having touched anything is simply out
  (not in bounds). Moving a kubb thrown this turn is never II.C.4b, wherever it lies.
- **A rescue is judged at the end too:** an established kubb knocked out and knocked back in
  before the round ends stays where it lies, no `Q`.

### Raising in any order (1.4.0)

The rules say nothing about the order in which a team stands up its kubbs. Before 1.4 the
engine raised them in id order. Now `g:lyingKubbs()` lists every field kubb of the half
still lying, and `g:raiseOptions(id)` gives a kubb's decision as it lies now: the same
`raising.options` that `need().decision` gives, read from the pitch at that moment, since
a kubb already stood up can block another's end. `g:canRaise(id, which)` says whether a
raise would be taken, and why not: `"not raising"`, `"not lying"`, `"no end"` or `"that
end"`. Nothing is written on the sheet for the order: the turn line records where each
kubb stands, whatever order it went up in.

### The throw to go (1.4.0)

Who throws first, thrown for before turn 1 (core/togo). Each team throws one baton from the middle of its own baseline
at the king, both thrown blind, on their own worlds, so neither baton moves the other.
The verdict (`togo.decide`):

- The baton at rest nearest the king, with the king left standing, wins.
- Touching the king is fine (a gap of 0).
- A team that topples the king loses: the other team throws first.
- If both topple it, or the gaps are equal to the millimetre (`togo.mm`), both throw
  again.

The gap (`togo.gap`) is measured from the baton's axis segment, less its radius, to the
king's centre less half the king's side, wherever the baton rests (off the pitch too). It
is never below 0. A helicopter counts: neither is a rule of the throw to go, only of a
turn's.

It is not part of `tw.rules`: the game starts after it. `match.setFirst(m, side, text)`
makes the game again with that side first (no throw has happened) and keeps the text as
`g.firstBy`. The game file writes it as `[Engine:first "throw to go: Team A 0.42 m,
Team B 0.88 m"]`, beside the standard `[First]`. It is a writer-owned header key, so
pk-kubb-score's reader keeps it and nothing else changes. No to-go in Kid matches. The
session runs the phase (docs/SESSION.md "The throw to go").

The distance thrown at, a person's circle and the computer's aim (`togo.tune`): a person's
circle starts 1.4 m short of the king's centre, on the ground, on the lob `togo.arc()`.
The computer aims 1.25 m short at beginner and club and 1.4 m at pro, on its level's swing
and nerves. These were chosen so the computer topples the king no more often than a person
of its standing (the Gym's recorded hand, scaled x2, x1 and x0.5 for Easy, Standard and
Hard). Over 300 batons: the person toppled 1%, 1% and 0%, the computer 1%, 1% and 0%
(beginner, club and pro). The median gap was 0.61, 0.60 and 0.56 m for the person and
0.88, 0.70 and 0.70 m for the computer. A circle nearer the king (0.45 to 1.1 m short)
toppled it 40 to 100% of the time even for a steady swing inside both bars, since a
baton's lob runs on after it lands. A person may still put the circle there.

### The Kid rules (0.15.0)

A game made with `rules = "kid"` (`rules.new`, `match.new`; kept as `g.rules`, so a save
keeps it; absent in every game before 0.15) plays the Kid rules, `rules.kid`
(docs/notes/kid-mode.md has the owner's decision and every choice):

- Three base kubbs a side, `a1`..`a3` and `b1`..`b3` at `rules.kid.baseX` (x = -1, 0, 1);
  `rules.baseXFor(g.rules)` gives a game's spots (core/cards draws its slots from it).
  `g:census().total` is 6.
- `need()`'s `throwY` for a toss is the Kid line (`g:kidLineY(side)`: `rules.kid.line`, 2 m,
  in front of the attacker's baseline), and for a baton at a kubb `g:kidThrowY(side)`: the
  Kid line or the advantage line, whichever is further from the baseline. The king shot's
  is the baseline. `match.setup` gives `s.kid = true`, `s.kidY` (the Kid line, view frame)
  and `s.forwardY` from `throwY` for every kubb and every baton but the king shot. The
  sheet's advantage (`A`) is written exactly as in a standard game.
- `throwBaton` ignores `illegal` (a note `bN helicopter; counted (kid rules)`), and a king
  toppled before every kubb is down is stood back up where it was (its `moved` pose is not
  applied) with a note `bN knocked the king down early; stood back up (kid rules)`; the
  rest of the throw is ruled as if it had stood, so its token has no `E` and the game goes
  on. `toss` does the same for a kubb thrown in that topples the king (`a kubb thrown in
  knocked the king down; stood back up (kid rules)`).
- A kubb out twice joins the punishment queue as before, but `P` is not inked and the
  punish phase places each at once (`Game:_placeFair`: `raising.fairSpot`, else the
  standard automatic spot if no fair spot is free), with a note and `t.placed` on the
  sheet's turn; `need()` never asks for a punishment kubb. `g.judgment.punish` still counts
  them (match.resolve says "out twice: stood at the fair spot", code `placed`).
- The rest of the rules (II.B.4a, II.B.7, II.B.11, II.C.4b, rescues, rethrows, raising) are
  the standard ones.

## Notation conventions

`core/notation.lua` keeps the score sheet as the engine runs and renders the game file
(DESIGN.md section 7). `tw.notation.render(game, { start, finish, version, mode })` gives the
text, in Planet Kubb Notation 2's canonical form (pk-kubb-score's `docs/notation-2.md`,
edition 2026.11, release `v2-2026.11`; the grammar's `CanonicalGame`): `[Notation "2"]`
first, then the headers the notation defines in its order (`Event`, `Location`, `Start`,
`End`, `Duration`, `Surface`, `Rules`, `Base kubbs "5"`, `Batons "6"`, `Opening "2-4-6"` or
`"6"`, the teams and players, `First`, `Win`, `Scored by`), then the engine's own (`Mode`,
`Throw Levels`) by code point, a blank line, and each turn line followed by its position
lines (since the release after 0.13.0; files before wrote notation 1 with positions as
`(@ x,y)` comments in a corner frame, which nothing writes now and `core/gamefile` still
reads). pk-kubb-score owns the notation; the engine owns its writer, the rules and its
statistics, and depends on pk-kubb-score one way. Times are `{ year, month, day, hour, min }` tables passed in (no `os.time` in core);
`tw.notation.filename(start, teamA, teamB)` gives `YYYY-MM-DD-HHMM-<a>-v-<b>.txt`.

- **A Kid game** (0.15.0): `[Rules "Kid rules, 2-4-6: three base kubbs; ..."]` (or "six
  from the start") and `[Base kubbs "3"]`; no `E` for a king stood back up, no `P` for a
  kubb stood at the fair spot (and no pitch line that turn: `t.placed`), a helicopter
  written as what it did; notes say each (docs/notes/kid-mode.md "What the game file
  says").
- **`[Throw Levels]`** (since 0.13.2) names the computer's players only, each with the
  level it throws at: `[Throw Levels "computer pro"]` against a person, every player
  computer against computer (`"k pro, m club, playdate beginner"`), and no header when no
  computer plays (pass and play, online with people only) or the match does not say
  which side is the computer (no `cpu` and not "Vs Playdate"). `match.fileLevels` builds
  it from `match.cpuSides` and `cpu.levelName`; `notation.render` writes whatever
  `meta.levels` it is given and leaves the header out when that is empty. A level is the
  computer's standard; a person's changes nothing in their throw (0.13.0,
  docs/notes/throw.md "The person's meter"), so a person is not listed. Files from 0.13.1
  and before list every player. Nothing reads the header back: `gamefile.parse` keeps it
  in `headers`, and the canonical form puts it after `Mode` by code point when present.

- Player ids: lowercased name, spaces and hyphens to `_`, everything else but letters
  dropped; a taken id gets `_b`, `_c`, ... Names in headers lose quotes and brackets; player
  names also lose commas and parentheses (kubb.js splits on them).
- **What the file writes for a player** (engine 0.7.1; Jamie, 2026-11-19: "player names in
  the turns isn't ever needed unless a team has more than 1 player. And if so, it should use
  an initial not the full name"). `notation.fileIds` decides it when the file is rendered;
  the game, its saves, snapshots and the Playdate's history keep the full ids. A throw by a
  team of one carries no prefix (`2. I - - - -`). A team of more writes the player's
  initial, the first letter of their id (`4. l:3I l:- d:F s:-`); players whose prefixes are
  written (both teams together, as kubb.js keys its players by id alone) and share one get
  the shortest start of their id that tells them apart (Kim and Karl: `ki`, `ka`), never
  ending on `_`. An id assignIds made unique keeps its suffix after its stem's prefix (two
  Danas: `d`, `d_b`). The header names each player with the id the turn lines use
  (`[Team B Players "Sam (s), Lee (l), Dana (d)"]`); a one-player team keeps its full id
  there (`"Alex (alex)"`), because gamefile counts a team's players by its `(id)` entries
  and kubb.js reads a name only with one, and no prefix may equal it (a prefix that would
  falls back to the player's full id). `[Throw Levels]` uses the header's ids. Files from
  before 0.7.1 prefix every throw with the full id; `gamefile.parse` reads both, and its
  `throws` give each throw's player (an unprefixed one is its team's only player).
- Inkast token per player, in order of first toss: `I` = every first throw this turn
  (rescued kubbs included, so I = kubbs knocked last turn + Q), `R` = every rethrow made,
  `P` = punishment kubbs (also in R), `Q` = rescues, `N` = kubbs that came to rest on another
  (capped at 5, the grammar's limit), `E` = king toppled by a thrown kubb. The rules engine
  never writes `Y` (a failed rescue is intent it cannot see); record mode does
  (docs/RECORD.md), and `inkastBody` places it after `P` since 1.1.0. No inkast token when there was nothing to throw. `I` and `R` are inked when the
  kubb is thrown; `P`, `Q` and `N` when the round is judged, to the player who made its last
  throw (the grammar takes the letters in any order; the token always writes `IRPYQN`, as the canonical form orders them).
- When the game ends before the inkast is done (king toppled by a kubb, or a resign), the
  token still counts every kubb that was due, so kubb.js's inkast check holds.
- `A` follows the inkast when the attacker throws from an advantage line: bare, as the
  canonical form has it. The sheet keeps the whole metres from the attacker's own baseline
  (`t.advantage`, 0 to 4, rounded down); Notation 2 says where the line runs only through
  the pitch line of the thrower's own half, which the file does not write (below).
  (Notation 1 files wrote `nA`; `core/gamefile` reads both.)
- Batons: `-`, `F`/`nF`, `B`/`nB`, `FB`, `K`, `=`, `Z`, `E` or `nFE`/`BE`, `G`, then `X`
  for each baton left once the game is over (after `K`, `E`, `G` or an inkast `E`).
- Notes (`# a; b`) say what the tokens cannot: `bN toppled a base kubb early; raised
  (II.B.4a)`, `bN hit a field kubb in the thrower's own half; all put back (II.B.11)`,
  `bN pushed a kubb out without toppling; put back (II.B.7)`, `a kubb hit a field kubb in the
  thrower's own half (II.C.4b)`, `bN toppled the king early`, `king toppled by a thrown
  kubb`, `resigned during the inkast`. `bN` is the turn's Nth baton.
- `[Rules "U.S. Championship 4.0, 2-4-6"]` or `"..., six from the start"`, with
  `[Opening "2-4-6"]` or `[Opening "6"]` beside it for readers (kubb.js reads the batons a
  turn may have from `Opening` and `Batons`). A turn with nothing thrown in has no inkast
  token; `0I` is what `inkastBody` writes for an empty count, which the engine never has.
- **Positions** (2026-11-16, Jamie: "the biggest limitation of the scoresheet system I
  created is it doesn't note pitch position for anything"; Notation 2's position lines
  since the release after 0.13.0). The sheet keeps them as data in the engine's frame
  (`t.inkastAt[pid]` and a baton's `at`, through `Sheet:inkAt` and
  `Sheet:baton(pid, token, at)`), exactly as before; only the file's way of writing them
  changed, so no golden hash moved and every save loads as it did.
  - **The frame**, converted in one place (`notation.toPitch`, back with
    `notation.fromPitch`): the origin is the centre-line stake on Team A's left as Team A
    stands on its baseline facing the king (engine x = -2.5, y = 4). Across is x + 2.5,
    0 to 5 (the king at 2.50; the left sideline as someone on Team A's baseline facing
    Team B sees it is x = -2.5, which `test_positions` proves with the aim camera); depth is
    4 - y in half `a` and y - 4 in half `b`, 0 to 4 (both baselines at 4.00). The half is
    the one the piece is in play for, never read off y. `notation.point` writes a point
    with two decimals, rounded to the centimetre with exact halves to even (`%.2f`), never
    `-0.00`, and gives nil for a point outside its half (a pitch or felled line has no
    minus sign).
  - What the sheet keeps. A baton: where each kubb its token counts stood before the
    throw, its F kubbs then its B (each in id order); also for `nFE`/`BE`. None for `-`,
    `Z`, `E` alone, `K`, `=`, `G`, `X`, nor for a base kubb toppled early and raised
    (II.B.4a: not in the token). An inkast: kept once, as the batons begin
    (`Game:_inkastPositions`), when every kubb is raised and every punishment kubb placed
    (afresh if `match.settleStanding` moves one before the first baton): each kubb thrown
    this turn that is in play, where it stands, in the order of its last throw, per player
    (`k.inkBy`, `k.tossSeq`); a punishment kubb with the player whose token counts its P.
    A rescued kubb (Q) has the place it was thrown back in to; a kubb lowered from on top
    of another (N) where it was raised after; a kubb out of play has none. A game that ends
    during the inkast (an inkast `E`, a resign before the batons) keeps none for it.
  - What the file writes (`notation.positionLines`), for the half under attack only, in
    points, in the canonical order:
    - `@a`/`@b`, the pitch line, every entry unmarked (thrown in this turn), when it can be
      the whole half: no field kubb stands there from an earlier turn (counted from the
      sheet as kubb.js counts, less the rescues), no punishment kubb was placed (the sheet
      does not say which kubb is the `p`), and the sheet has a place for every kubb thrown
      in. Otherwise none: the notation's pitch line "is the whole half or it is left out".
    - `*a`/`*b`, the felled line, a word a baton: its kubbs where they stood, field then
      base, each by across and depth, joined by `+`; `-` for a baton that felled none, one
      the sheet has no places for (an old save), one whose kubb stood outside the half, and
      one whose field kubb is not where the pitch line has it (an earlier baton moved it:
      kubb.js finds every felled field kubb on the pitch line, so the word is left out
      rather than warned on). No line when every word is `-`.
    - Not written: the thrower's own half (its kubbs are `s`, and the sheet does not keep
      where the kubbs left from earlier turns stand), `~` (where each kubb lay before it was
      raised, and which end it was raised on) and `^` (where each baton was thrown from:
      the engine's outcomes carry no stance). Each needs new data in the sheet, which moves
      every golden hash: a minor version (docs/VERSIONING.md).
  - `make games` reads every written point back with pk-kubb-score's grammar and finds it
    among the places the sheet kept, within half a centimetre (`tools/sheetplaces.lua`
    writes them beside each game; `tests/node/notation-gate.mjs`, "The round trip"). In
    the 500 headless games, pitch lines for about 70% of the turns with kubbs thrown in and
    felled words for nearly every baton that felled one.
  - A save from before positions loads (no `inkastAt`, `at`, `inkBy`, `tossSeq`): its
    turns render without position lines, and a turn in progress gives its kubbs to its one
    inkaster (none when it had several).
  - Reading: `core/gamefile.parse` skips position lines (`gamefile.isPosition`) and leaves
    them out of `lines`; it drops comments in parentheses before it counts tokens, so a
    notation 1 file an older client wrote reads as it always did. On screen the position
    lines are left out (they would fill the 400 px screen; the file keeps them): the
    session's `sheet().shown` and `gamefile.parse`'s `lines` have none, and
    `gamefile.shown` gives `""` for one, so a screen that splits the file's text itself
    (the Playdate's `scenes/sheet` from `scenes/match` and `scenes/players`) should skip
    the lines `gamefile.isPosition` names.

## Throwing order

Teams of one to six (docs/PLAYERS.md, the plan for saved players and team pass and play;
step 1 is built). `core/order.lua` (`tw.order`, pure, `test_order.lua`) decides who throws
every baton and kubb before the throw, within Rules V4.0 as far as a team's size allows:

- **II.B.5**: a player throws at most `order.cap(n, batons)` = max(2, ceil(batons / n))
  batons a turn (one player all six, two three each, three to six two each).
- **II.A.4**: the opening's two batons by two different players and its four by at least
  three (`order.distinct`, fewer for a smaller team).
- **Blocks**: each team has a rotation (its players in order); a turn's batons are dealt
  from it as evenly as possible over as many players as there are batons
  (`order.split`: 2, 2, 1, 1 for four players), a player's batons in a row, so the
  Playdate changes hands as few times as the rules allow. The next turn starts past the
  players who threw an extra baton (past everyone dealt when all threw the same): the
  doubles go round the team, and in the opening whoever did not throw opens the team's
  next turn.
- **The inkast**: one inkaster a turn (first throws and rethrows), by default the turn's
  first baton thrower (`o.inkaster`).
- **Changes**: `order.change(o, n, pid, thrown)` gives baton n to another player, swapping
  with that player's first later baton, refused (`team`, `cap`, `distinct`, `thrown`) if
  the turn would break a rule; `order.setInkaster(o, pid)`.
- `order.thrower(o, g)` deals the engine's turn when it is new (`order.sync`) and says who
  throws what `g:need()` asks for (the next baton's thrower also while the defender
  raises). The state is plain tables (`o.A`, `o.B` = `{ ids, start }`, `o.turn`, `o.deal`,
  `o.inkaster`), so `core/save` keeps it as `m.order`; a match saved without one starts a
  fresh order.
- `order.checkSheet(g)`: every turn of a finished sheet against both rules and the teams
  (`kubb.js` checks neither); `test_games`, `make games` and `tools/physmatch.lua` run it.
