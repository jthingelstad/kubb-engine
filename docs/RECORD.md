# Record mode

Since 1.1.0. Record mode scores a real game of kubb throw by throw. It is built for Kubb:
Pitchside, the iPhone app for scorers. The host says what was seen: a kubb thrown in landed
in or out, a baton felled two field kubbs, the king fell, a team resigned. The engine keeps
the game's state under the rules (U.S. Championship 4.0) and writes the game as Planet Kubb
Notation 2 in its canonical form (pk-kubb-score's `docs/notation-2.md`).

It is not `tw.rules`. The rules engine judges the poses the physics gives it. A scorer has
no poses, only what they saw, and records what happened instead of enforcing the rules.
When a game breaks a rule, the engine warns. An event is never an error. Record mode counts
kubbs the way pk-kubb-score's `kubb.js` counts them, so every finished file it writes reads
back with no warnings.

- `core/record.lua` (`tw.record`): the game: `new`, `apply`, `build`, `state`, `render`,
  `rows`.
- `session/record.lua` (`tw.web.record`): the door, `kubbCall("record.<name>", argsJson)`,
  which `session/api.lua` dispatches like `names.<name>`. It holds one recorded game for
  each Lua state, with its event log. It never touches a match the session runs.

There are no Kid rules. Record mode does not use the physics, the tune, the random seed or
the clock, so it needs no `useTune` or `new` first.

## The idea: a log of events

The host keeps the game as its setup and a list of events, and so does the engine. Every
event is plain JSON. An edit or an undo is a rebuild: the host sends the list as it now
stands (`record.rebuild`), and the engine plays it again from the setup. A rebuild is cheap:
the counts, a few cells, no physics. The worked example's 38 events rebuild in about 0.15 ms
on desktop Lua, with the file written. The same setup and events always give the same game, the same
file and the same warnings.

Store the setup and the events, not the state or the file. Both can be made again.

## Calls

`argsJson` is a JSON object. Each call returns JSON. A call that cannot be made returns
`{"error": "record: ..."}`, as every call through the door does.

| Call | Arguments | Returns |
|---|---|---|
| `record.options` | none | `{ format, surfaces, openings, winds, switches, events }` |
| `record.new` | `{ game, want? }` | a result. A new game with an empty log. |
| `record.add` | `{ event, want? }` | a result, plus `added = { index, warnings }` |
| `record.rebuild` | `{ events, game?, want? }` | a result. The log replaced and the game rebuilt (with the held setup when `game` is left out). |
| `record.undo` | `{ want? }` | a result. The last event dropped and the game rebuilt. With no events, the same game. |
| `record.view` | `{ want? }` | a result |
| `record.events` | none | `{ events }`: the held log |
| `record.build` | `{ game, events, want? }` | a result. Touches nothing held: for a saved game, a preview or a server. |

The result is `{ state, warnings, notation?, sheet? }`:

- `state` is "State" below.
- `warnings` lists every warning in the game so far, in order (below, "Warnings").
- `want = { notation = true }` adds `notation = { text, name }`: the file and a file name
  (`2026-11-24-1000-ringers-v-stakes.txt` once a start time is known, `kubb-game.txt` before).
- `want = { sheet = true }` adds `sheet = { rows }`: the score sheet, a row for each turn
  (below, "The score sheet").
- `added.index` is the new event's place in the log (0-based). `added.warnings` lists the
  warnings this event raised, so the screen can show them beside the throw.

Errors:

- "record: no game; call record.new first": `add`, `undo`, `view`, `events` or `rebuild`
  with no `game` before a game exists.
- "unknown call record.<name>".
- "record: new: ...": a setup that cannot be a game (below). `new`, `rebuild` with a `game`
  and `build` all check it.

## The game (setup)

```json
{
  "teams": {
    "A": { "name": "Ringers", "players": [ "Kim", { "name": "Dana" }, { "name": "Ole", "id": "ole" } ] },
    "B": { "name": "Stakes",  "players": [ "Sam", "Lee" ] }
  },
  "first": "A",
  "opening": "2-4-6",
  "surface": "grass",
  "wind": "light",
  "event": "Fall Open, pool 2",
  "location": "Riverside Park, Pitch 4",
  "client": "0.1 (1.1.0)",
  "start": { "year": 2026, "month": 11, "day": 24, "hour": 10, "min": 0 },
  "capture": { "players": true, "pitch": true, "stance": true }
}
```

| Field | Values | Left out |
|---|---|---|
| `teams.A`, `teams.B` | `{ name, players }`: 1 to 6 players, each a name, or `{ name, id? }` | required |
| `teams.X.name` | text, at most 60 bytes | `"Team A"`, `"Team B"` |
| a player's `name` | text, at most 60 bytes | `"Player 1"`, ... |
| a player's `id` | the id events name the player by (below) | made from the name |
| `first` | `"A"` or `"B"`: the team that throws first | `"A"` |
| `opening` | `"2-4-6"` (2, 4, then 6 batons) or `"six"` (6 from the start) | `"2-4-6"` |
| `surface` | `"grass"`, `"sand"`, `"snow"` | `"grass"` |
| `wind` | `"off"`, `"light"`, `"strong"`: a label in the file, nothing more | `"off"` |
| `rules` | `"standard"` only. `"kid"` is refused: record mode has no Kid rules. | standard |
| `event`, `location` | text, at most 120 bytes. Commas are kept. | not written |
| `client` | the app's version label, 1 to 40 letters, digits, spaces, `.`, `-`, `+`, `(`, `)` | not written |
| `start` | `{ year, month, day, hour, min }`, local time | the first event's `time` |
| `capture` | the switches for the first turn (below, "Capture") | all off |

Names are cleaned as the session cleans typed names (`notation.cleanName`): quotes,
backslashes, square brackets and line breaks go. A player's name also loses commas and parentheses, which the
players header uses. Team names, `event` and `location` keep their commas.

**Player ids.** Each player gets an id: the `id` given, or one made from the name
(`notation.assignIds`: lowercase ASCII letters, digits and `_`, with a suffix when two would
be the same). `state.sides.X.players[i].id` gives it. Events name a thrower by this id
(`by`). The file writes a shorter one (`players[i].file`): no prefix for a team of one,
initials for larger teams (`k`, `d`, `o`), as the engine's other files do. Letters outside
ASCII drop out of a made id ("Åsa" makes `sa`). Pass `id` to choose one.

## Capture

What a game records besides the turn line is a set of switches. They are independent and
can change between turns with a `capture` event. A switch is either on or off for a whole
turn. A turn takes the switches as they are at its first event, and a `capture` event in
a turn that has begun applies from the next turn.

| Switch | Records | Writes |
|---|---|---|
| (always) | the inkast, the advantage line, each baton's outcome | the turn line: `5. 3I A 3F B B B = K` |
| `players` | who threw each kubb and baton (`by`) | player prefixes: `5. k:3I A k:3F d:B ...` |
| `pitch` | where field kubbs stand, and where each felled kubb stood (`at`) | `@a`/`@b` lines, and a `*` line for the half under attack |
| `lay` | how kubbs lie (reserved) | nothing (below, "What the file writes") |
| `stance` | where each baton was thrown from (`stance`) | a `^` line for the attacker |

With `players` off, or with a `by` left out, the token has no prefix. With `pitch` off, no
position is asked for or written. Positions given while a switch is off are ignored.
Positions are never needed to move the game on.

The file's own header `[Pitchside:capture "players pitch stance"]` names every switch
that was on for any turn it writes (`lay` left out), or `"turns"` with all off.

## Positions

Positions are in the notation's pitch frame (notation-2.md "The pitch frame"), for the half
the kubb is in:

- `across`: 0 to 5 metres along the centre line. Seen from that team's baseline, 0 is its
  left.
- `depth`: 0 at the centre line to 4 at the baseline.

The host sends a point: `{ "across": 2.6, "depth": 1.3 }` or `[2.6, 1.3]`. The engine keeps
and writes field kubb positions as the one-metre cell the point falls in (`2,1`): the far
edges belong to the last cell, so base kubbs at depth 4 are in row 3. A stance is written
as a point to the centimetre: across 0 to 5, depth 0 to 9.99 (a thrower may stand behind
the baseline). A position outside these ranges is left out with a `position` warning.

The base kubbs start known: one in each cell along row 3 (`0,3` to `4,3`). A base kubb
felled with its `at` is taken from its cell. One felled without `at` makes the side's base
positions unknown (`baseComplete = false`) until none stand.

## Events

An event is `{ "type": ..., ... }`. Every event also takes:

- `time`: `{ year, month, day, hour, min }`, local time. The first `time` is the game's
  start when the setup has none. The time of the event that ends the game is the file's
  `End`, and `Duration` follows from the two.
- `id`: anything the host likes. Warnings this event raises carry it back.

An unknown `type`, or an event that is not an object, is skipped with an `event` warning.
It keeps its place in the log: `record.events` gives a `null` (or anything not an object)
back as `false`, and a rebuild skips it again with the same warning at the same index.

### toss: a kubb thrown in

```json
{ "type": "toss", "by": "sam", "result": "in", "at": { "across": 1.2, "depth": 2.4 } }
```

| Field | Meaning |
|---|---|
| `result` | `"in"` or `"out"`. Anything else is taken as in, with a warning. |
| `by` | the thrower's id (`players` capture) |
| `at` | where it stands, in the half it was thrown into (`pitch` capture) |
| `onTop` | `true`: it came to rest on another kubb (`N`) |
| `rescueAttempt` | `true`: the thrower tried to knock out a field kubb left from an earlier turn |
| `rescued` | how many such kubbs it knocked out (`Q`). Each must be thrown in again, so the kubbs due grow by as many. |
| `rescuedAt` | the cells they stood in, `[ {across, depth}, ... ]`. Without them the half's positions become unknown. |
| `king` | `true`: it knocked the king over. The throwing team loses (`E`). |

The engine knows whether a toss is a first throw or a rethrow: first throws come first
(II.C.6). A first throw is `I`, or `Y` when `rescueAttempt` is set and nothing was rescued.
A first throw that lands out earns a rethrow (`R`). A rethrow that lands out again is a
punishment kubb (`P`): the defending team places it, and it stands as a field kubb. A rescue
attempt on a rethrow is written as `R`, with a `rescue` warning.

A toss when no kubbs are due is not recorded (`phase` warning).

### punish: where a punishment kubb was placed

```json
{ "type": "punish", "at": { "across": 2.5, "depth": 3.5 } }
```

Only before the turn's first baton, and only while a punishment kubb waits to be placed
(`state.inkast.punish` against `punishPlaced`). It only records the position: the kubb is
counted when the rethrow lands out.

### pitch: the field kubbs in a half, as they stand now

```json
{ "type": "pitch", "half": "A", "at": [ { "across": 3.2, "depth": 1.1, "mark": "s" } ] }
```

Replaces what the engine knows of where `half`'s field kubbs stand. Use it to correct
positions, or to give them all at once instead of with each toss. It is recorded only when
`at` holds exactly as many entries as field kubbs stand in that half
(`state.sides.X.field`). `mark: "s"` says the kubb stood from an earlier turn. Every kubb
in the attacker's own half is such a kubb. `mark: "p"` says it is this turn's punishment
kubb.

### advantage: the advantage line as seen

```json
{ "type": "advantage", "applies": true, "meters": 2 }
```

Whether the batons go from an advantage line follows from the count: they do when a field
kubb stands in the attacker's own half (`state.advantage.applies`). This event records what
the scorer saw. When the two differ, the engine warns (`advantage`) and adds a note to the
turn. The file follows the count, because `kubb.js` checks `A` against it. `meters` is kept
in the state and not written.

### baton

```json
{ "type": "baton", "by": "kim", "field": 3, "base": 0,
  "at": [ {"across": 1.4, "depth": 1.6}, {"across": 2.3, "depth": 1.2}, {"across": 2.6, "depth": 1.7} ],
  "stance": { "across": 2.6, "depth": 1.3 } }
```

| Field | Meaning |
|---|---|
| `field`, `base` | how many field and base kubbs it felled. Left out: 0. Both 0: a miss. |
| `king` | `true`: the king fell |
| `illegal` | `true`: an illegal throw (`Z`). Its kubbs are put back. With `king`, and kubbs standing, the throwing team loses (`E`). |
| `by` | the thrower's id (`players` capture) |
| `at` | where each felled kubb stood: the field kubbs first, then the base kubbs (`pitch` capture) |
| `stance` | where it was thrown from (`stance` capture) |

The engine writes the token:

- `-`: a miss.
- `F`, `2F`, `B`, `FB`: kubbs felled.
- `K`: the king, with no kubb standing. The throwing team wins.
- `=`: a throw at the king that missed.
- `E` or `2FE`: the king with kubbs standing. The throwing team loses.
- `Z`: an illegal throw.

When a baton gives more than the count allows, the engine records what the rules allow and
warns:

- More field or base kubbs felled than stand: counted as many as stand (`count`).
- A base kubb felled while a field kubb still stands: the base kubb is stood back up
  (II.B.4a) and a note is added (`rule`).
- Felled kubbs given when nothing stands: it is the king shot, and they are left out
  (`count`).

A baton thrown during the inkast ends it. Every kubb still due counts as thrown in
(`inkast` warning, "taken as in"). If no toss was recorded at all, the turn's inkast is
"not recorded", as the notation allows (no inkast token).

With `players` on and every baton's `by` given, the engine checks the throwing order. A
player throwing more than their share (II.B.5) or a turn with too few different players
(II.A.4) is recorded as thrown, with one `order` warning a turn.

The turn ends with its last baton (2, 4, then 6 in a 2-4-6 opening; always 6 with `six`).
The other team's turn then begins: it throws in the kubbs this turn felled.

### resign

```json
{ "type": "resign", "side": "B" }
```

`side` resigns (left out: the team throwing). The other team wins. The file writes `G` on
the resigning team's own line, because the notation writes `G` and `W` for the throwing
team only:

- the current turn's, if `side` is throwing: `2. - - G X` (the batons left are `X`);
- the turn before, if the other team is throwing and has not thrown yet: `1. - - G`;
- otherwise, a line of its own after the current turn: `3. G X X X X X`.

### call: the game called for a team

```json
{ "type": "call", "winner": "A" }
```

An umpire or the time limit ends the game for `winner`. The file writes `W` as `resign`
writes `G`: `4. 3IYQ F - W X X X`, or `3. A W X X X X X` on the winner's own line.

### capture: change the switches

```json
{ "type": "capture", "players": false, "stance": true }
```

Sets the switches named and leaves the others. It applies to the current turn if nothing
has happened in it yet, and otherwise from the next turn.

### note

```json
{ "type": "note", "text": "rain delay, 10 minutes" }
```

A note on the current turn's line, after `#`.

## State

```json
{
  "format": 1, "engine": "1.1.0",
  "turn": 4, "phase": "batons", "over": false, "events": 22,
  "attacker": "B", "defender": "A",
  "capture": { "players": true, "pitch": true, "lay": false, "stance": true },
  "king": "standing",
  "sides": {
    "A": { "name": "Ringers",
           "players": [ { "id": "kim", "name": "Kim", "file": "k" }, ... ],
           "base": 3, "field": 4,
           "fieldPositions": [ { "across": 0, "depth": 0 }, { "across": 3, "depth": 1, "mark": "s" }, ... ],
           "fieldComplete": true,
           "basePositions": [ { "across": 1, "depth": 3 }, ... ], "baseComplete": true },
    "B": { ... }
  },
  "inkast": { "due": 0, "rethrows": 0, "left": 0, "dueAtStart": 4,
              "punish": 0, "punishPlaced": 0, "rescuable": 0 },
  "batons": { "total": 6, "thrown": 0, "left": 6 },
  "advantage": { "applies": false, "observed": null, "meters": null },
  "throwers": { "batons": [ { "id": "sam", "batons": 0 }, { "id": "lee", "batons": 0 } ], "cap": 3, "distinct": 1 },
  "next": { "kind": "baton", "n": 1, "of": 6, "kingShot": false, "targets": "field", "field": 4, "base": 3 },
  "allowed": [ "baton", "pitch", "advantage", "resign", "call", "capture", "note" ]
}
```

A field left out of the JSON is nil (the door writes no `null`). Above, `observed` and
`meters` would not be there.

| Field | Meaning |
|---|---|
| `format` | the version of the events and the state (`record.FORMAT`). It only grows: fields are added, never changed. |
| `engine` | the engine's version |
| `turn` | the current turn's number (1-based) |
| `phase` | `"inkast"` (kubbs to throw in), `"batons"` or `"over"` |
| `events` | events applied, counting skipped ones |
| `winner`, `how` | when over: `"A"`/`"B"`, and `"king"`, `"king toppled early"`, `"king toppled by a thrown kubb"`, `"resigned"` or `"called"` |
| `king` | `"down"` when the game ended with the king felled, else `"standing"` |
| `sides.X.base`, `.field` | that team's base kubbs standing, and field kubbs standing in its half |
| `sides.X.fieldPositions` | the cells known for those field kubbs. `mark` is `"s"` for one from an earlier turn, `"p"` for this turn's punishment kubb, and missing for one thrown in this turn. |
| `sides.X.fieldComplete` | every field kubb has a cell |
| `sides.X.basePositions`, `.baseComplete` | the base kubbs' cells, while known |
| `attacker`, `defender` | while not over |
| `inkast.due`, `.rethrows`, `.left` | first throws still due, rethrows owed, and both |
| `inkast.dueAtStart` | kubbs the turn had to throw in |
| `inkast.punish`, `.punishPlaced` | punishment kubbs this turn, and how many have a position |
| `inkast.rescuable` | field kubbs from earlier turns in the half being thrown into |
| `batons.total`, `.thrown`, `.left` | this turn's batons |
| `advantage.applies` | the batons go from the advantage line (by the count) |
| `advantage.observed`, `.meters` | what an `advantage` event said |
| `throwers.batons` | batons each of the attacker's players has thrown this turn |
| `throwers.cap`, `.distinct` | most batons one player may throw this turn (II.B.5), and the different players the turn needs (II.A.4) |
| `next` | what the screen asks for next: `{ kind: "toss", rethrow, left }`, `{ kind: "baton", n, of, kingShot, targets, field, base }` (`targets`: `"field"`, `"base"` or `"king"`) or `{ kind: "over", winner, how }` |
| `allowed` | the event types that do something now. `"punish"` is listed while a punishment kubb waits. Over: only `"capture"`. |

## Warnings

```json
{ "event": 11, "turn": 2, "code": "rule", "text": "baton 2 felled a base kubb with a field kubb still standing; it is stood back up (II.B.4a)", "id": "the event's id" }
```

`event` is the event's place in the log (0-based). `turn` is the turn it fell in. `id` is
there when the event had one. `text` is plain English for the screen. Codes:

| Code | When |
|---|---|
| `rule` | a rule was broken and the engine applied the rules' outcome (II.B.4a, the king early) |
| `order` | the throwing order broke II.B.5 or II.A.4; recorded as thrown |
| `count` | more felled than stood, rescued more than stood, or felled kubbs on a king shot; counted as the rules allow |
| `advantage` | the advantage line as seen differs from the count |
| `inkast` | kubbs due but not recorded before the batons, or the end; taken as in |
| `phase` | an event that does nothing now (a toss after the inkast, a baton after the end) |
| `position` | a position out of range or not matching the count; left out |
| `thrower` | a `by` naming nobody, or a player of the other team; written with no prefix |
| `rescue` | a rescue attempt on a rethrow |
| `result`, `pitch`, `punish`, `resign`, `call`, `time`, `event` | an event's field is not one of its values |

## The score sheet

`sheet.rows` has a row for each turn the file writes:

```json
{ "turn": 5, "side": "A", "line": "5. k:3I A k:3F d:B o:B k:B d:= o:K",
  "lines": [ "@a 3,1s", "@b 1,1 2x2,1", "^a 2.60,1.30 ...", "*b 1,1+2x2,1 0,3 2,3 3,3 - -" ],
  "inkastRecorded": true, "inkast": { "I": 3, "R": 0, "P": 0, "Y": 0, "Q": 0, "N": 0, "E": false },
  "advantage": true,
  "batons": [ { "token": "3F", "by": "kim", "stance": "2.60,1.30" }, ... ],
  "notes": [], "capture": { "players": true, "pitch": true, "lay": false, "stance": true } }
```

A turn waiting for its first event is left out. `by` is the player's id, not the file's
prefix.

## What the file writes

The headers, in the canonical order:

- `Notation`;
- `Event` and `Location` when given;
- `Start`, then `End` and `Duration` once the game is over (when times are known);
- `Surface`;
- `Rules`: "U.S. Championship 4.0, 2-4-6" or "U.S. Championship 4.0, six from the start";
- `Base kubbs` 5, `Batons` 6, `Opening`;
- the teams and their players, `First`;
- `Win` once the game is over;
- `Scored by`: "Kubb: Pitchside" and the client label;
- the writer's own keys: `Pitchside:capture` and, unless off, `Pitchside:wind`.

Then a turn line for each turn and the position lines under it, in the order `@a @b ^a *b`:

- `@a`/`@b`: a half's field kubbs as the first baton is thrown. Each half is written when
  every field kubb in it has a cell and the cells agree with the count (`s` marks, `p`
  marks), as the canonical form checks.
- `^a`: the attacker's stances, `-` for a baton with none. Written when any baton has one.
- `*b`: what each baton felled, cell by cell. Field kubbs come first, then base kubbs,
  joined by `+`. `-` for a baton with no cells, or with cells the pitch line does not
  hold. Written when any baton has cells.

The `~` lay line is never written. The notation writes it only beside a pitch line in
points, and record mode writes cells (below, "Notation changes needed").

A file is a whole game once `state.over` is true. Before then it is a draft. It has no
`Win`, and while kubbs are still being thrown in, its inkast token counts only the tosses
so far.

Every file the tests write passes the engine's notation gate: pk-kubb-score's grammar, its
canonical writer (the file is unchanged by it), and `kubb.js` with no warnings and the same
winner (`make test-node`, `tools/recordgames.lua`).

## Notation changes needed (pk-kubb-score)

These are what a scorer can record that Planet Kubb Notation 2 cannot write. The engine
does not invent syntax for them. They are raised for pk-kubb-score:

1. **A lay line beside cells.** `~a`/`~b` needs its pitch line in points, so a scorer who
   taps cells cannot write how kubbs lie. The `lay` switch is taken and nothing is written
   until the grammar allows a lay line beside a pitch line in cells, or one with a cell for
   each entry.
2. **An approximate position.** A tap is a guess within a metre or so, and the grammar has
   no mark for an estimated position. Record mode writes cells, which are honest about
   that, but a point a scorer is sure of cannot be told apart from one they guessed.
3. **The advantage line's distance.** The canonical form reads where the line runs from
   the pitch line. With cells, or no pitch line, the distance the scorer saw (`meters`) has
   nowhere to go. The lenient form's `2A` reads it but is not canonical.
4. **A result before any throw.** `G` and `W` belong to the throwing team's line. A game
   that ends before Team B has thrown, resigned or called for B, cannot be written. A
   header-only result, or `G`/`W` allowed as a turn of its own, would cover it. Today it is
   refused with a `phase` warning.
5. **An advantage line used when the count says none.** `A` must match the count, so a
   breach the scorer saw goes in a note.
6. **More than five kubbs on others in one token.** `N` is capped at 5. More is written as
   5, with a note.
7. **Wind and what was captured.** Neither has a standard header. Record mode uses its own
   keys, `Pitchside:wind` and `Pitchside:capture`. A shared key would let other readers use
   them.
8. **Pictures of the pitch.** No reference to a photo of a position. Not asked for yet;
   noted for later.

## Tests

- `tests/lua/session/test_record.lua` (desktop Lua, through `kubbCall`) checks the games of
  `tests/fixtures/record/games.lua`:
  - each game's lines, winner and warnings;
  - a game added event by event equals the game rebuilt from its log, and its build;
  - every undo back to the start equals a build of the shorter log;
  - the state mid-turn and mid-inkast;
  - rethrows and a punishment kubb;
  - the refusals (Kid rules among them);
  - bad events;
  - options and names.
- `tests/node/record.test.mjs` builds the same games under wasmoon from the bundle and
  checks that they write the same files, byte for byte.
- `make test-node` writes the games' files and gates them.

The games:

| Game | What it shows |
|---|---|
| `example` | the worked example: five turns, players, pitch and stance on, the king |
| `bare` | the same game with every switch off |
| `switching` | switches changed between turns, `lay` asked for |
| `breach` | II.B.5, II.B.4a, an advantage line the count denies, too many felled, the king early (`E`) |
| `called` | rethrows, a punishment kubb and its place, `N`, a rescue (`Q`) and a failed one (`Y`), `W` for the throwing team |
| `calledOther` | `W` for the team not throwing, on a line of its own |
| `inkastKing` | a thrown kubb fells the king |
| `resign`, `resignOther`, `resignWaiting` | `G` on the team's own turn, on a line of its own, and on its turn before |
| `skipped` | an inkast not recorded at all, and one cut short |
