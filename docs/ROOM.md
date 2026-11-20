# The room

`room/` is the logic of a shared pitch: the room's document and the reducers that write
it, who acts in a shared match, and how a client keeps its match in step with the room.
It is the web game's `src/net/lobby.js`, `seats.js` and `sync.js` (kubb.thingelstad.xyz)
in Lua, at the commit in `engine.json` (`roomFrom`), with the same function names, so the
web and the iPhone app write the document the same way. It is pure: no clock, no
randomness, no network. The host passes its seed and start time in; a client's room
socket (the web's `src/net/room.js`, the app's own) carries the document, and is not
here.

Everything a client needs is on this page. The web's `docs/MULTIPLAYER.md` and
`docs/ROOMS.md` say how its room server works; references to them below are the web
repository's.

## Files

| Path             | What                                                                                          |
| ---------------- | --------------------------------------------------------------------------------------------- |
| `room/lobby.lua` | `tw.room.lobby`: the document's reducers (lobby.js), and the engine check for START.          |
| `room/seats.lua` | `tw.room.seats`: who may act for what the match needs now (seats.js).                         |
| `room/sync.lua`  | `tw.room.sync`: what to do with a document version that arrived, and the action's rider.      |
| `room/js.lua`    | `tw.room.js`: the JavaScript rules these follow (truthiness, `===`, `JSON.stringify`, sizes). |
| `room/api.lua`   | `tw.room.api`: the calls behind `kubbCall("room.<name>")`.                                    |

`session/api.lua` imports `room/api`, so loading the session as usual (docs/SESSION.md
"Loading") loads the room too. The room's calls need no `useTune`, `new` or match: a
client may make them before or without one.

## Calling

```
kubbCall("room.<name>", argsJson) -> resultJson
```

- The argument is one JSON object of named fields (the table below). An absent field is
  JavaScript's `undefined`; `null` is `null`. They are not the same to every call.
- The result is always `{"value": ...}`. `value` is `null` where the JavaScript returns
  `undefined` or `null`: for a reducer that means "change nothing, write nothing".
  Wrapping it means a document that happens to hold a key `error` is never mistaken for
  a failure.
- A failure (an unknown call, an argument that is not an object, a Lua error) is
  `{"error": "..."}`, as for every engine call.
- Arguments are read with `json.decode(text, true)`: an empty object stays `{}`, an
  empty array stays `[]`, `null` stays `null`. Results are written by the engine's
  deterministic encoder: keys sorted, integers without a point, floats with one (`3.0`)
  or an exponent. The same inputs give the same bytes on every client.
- Strings are UTF-8. Member ids are strings.

Swift, for instance:

```swift
let out = kubbCall("room.joinTeam", #"{"doc":\#(docText),"id":"\#(me)","side":"A"}"#)
// {"value":{...the new document...}} or {"value":null}: nothing to write
```

## The document

The room holds one JSON document per pitch. It is `null` until someone writes it (and
an expired room comes back empty); every reducer reads `null`, `{}` or junk as a fresh
lobby.

```
{
  v: 1,
  teams:   { A: [memberId, ...], B: [...] },   in throwing order, 0 to 6 each
  options: { surface, opening, raising, wind, set },
  open:    false | true,     true lists the pitch under OPEN GAMES on the home page
  started: false | true,
  n:       0,                matches started on this pitch
  match:   null | {
    n,                       the match number (doc.n when it started)
    seq,                     actions committed (0 at the start)
    snap,                    the engine's snapshot, text exactly as it gave it
    hash,                    the engine's hash of that snapshot
    players: { A: [{ id, name }], B: [...] },  who plays, frozen at START
    cpu:     "A" | "B" | null,                 the computer's side
    host,                    who started it
    engine,                  the engine's major.minor that started it ("0.3")
    setup,                   the engine's newMatch options (the replay sets out from them)
    h0,                      the engine's hash at the start
    log:   [{ a, h }],       every action committed with the hash after it: the replay's.
                             One an action (length == seq) while whole; null once not
                             (a commit without its action, or the document too big)
    over:  true,             the match has ended (set by the action that ended it)
  }
  ...                        any other top-level key: kept as it is (a newer client's)
}
```

- `snap` is opaque text. Never parse it and write it back: that turns `3.0` into `3` and
  changes the hash. The calls carry it as a JSON string and never look inside.
- `setup`, `h0` and `log` are there only when the host passed `setup` at START (a match
  from an older client has none, and no replay). `over` is absent until the match ends.
  Absent, `null` and empty are different here and each survives every call.
- `options` keys and values: `MATCH_OPTIONS` below. Unknown ones are dropped; missing
  ones take `OPTION_DEFAULTS`.
- A document with a log stays under `LOG_BUDGET` (248 KB, counting every character
  above U+007E as 6, as the room does): the commit that would pass it drops the log.
  A replay that commits a whole match in one pass (`replayLoad` with `document`) keeps
  each log entry's size from commit to commit (`lobby.docSize`) instead of encoding the
  whole document on every action: the same number, so the log goes at the same action.

### Values used by the calls

- **lineup** `{ players: { A: [{ id, name, level }], B: [...] }, cpu: "A" | "B" | null }`
- **members** the room's members in joined order: `[{ id, connected, me }]`, where `me`
  is what the member told the room about themselves: `{ name, level, engine }`. `engine`
  is the member's engine version (`engineVersion`); a web client from before 0.3 sends
  none.
- **ctx** (who acts) `{ players, cpu, host, connected: [memberId, ...] }`: the match's
  players and computer side, the room's host now, and the ids connected now (a `Set` in
  the JavaScript, a list here).
- **need** what the engine's session says it needs (`view.need`): `{ kind: "throw" |
"raise" | "punish" | "over", side, cpu, practice, setup: { thrower: { key } } }`.
- **local** (staying in step) `{ n, seq }`: the match number and the last action number
  this client holds, applied or queued.
- **rider** (`with`) `{ n, seq, a, c, e? }`: the action riding along with a commit, the
  client that made it (`c`, `"web"` or `"ios"`) and, when given, the engine's version
  (`e`).

## The calls

Each is `room.<name>`; the fields are the argument object's. "nothing" is `value: null`.

### The document (lobby.js)

| Call           | Fields                                                         | Value                                                                                                                                                                                                                           |
| -------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lobbyOf`      | `doc`                                                          | The document as it stands, cleaned (teams to strings, options to known values, `n` to an integer, `match` to an object or null), or a fresh lobby. Unknown top-level keys are kept.                                             |
| `sideOf`       | `doc, id`                                                      | `"A"`, `"B"` or null (watching).                                                                                                                                                                                                |
| `joinTeam`     | `doc, id, side`                                                | Put `id` on `side` (`"A"`, `"B"`), or take them off both (`side: null`: sit out). Nothing while a match runs, for another side, when already there, or when the side holds six.                                                 |
| `setOptions`   | `doc, options`                                                 | The host's options merged in (unknown values ignored). Nothing while a match runs or when nothing changes.                                                                                                                      |
| `setAccess`    | `doc, open`                                                    | Open (listed) or invite only. Nothing when unchanged.                                                                                                                                                                           |
| `openListing`  | `doc, members, over`                                           | What the host tells the room server about an open pitch: `{ players, seats, state: "waiting" \| "playing" \| "over" }`, or null while invite only.                                                                              |
| `pruneTeams`   | `doc, present`                                                 | Forget members no longer in the room (`present`: their ids). Between matches only; nothing when nobody went.                                                                                                                    |
| `lineup`       | `doc, members`                                                 | Who plays: the teams with each member's cleaned name (`Player n` when none) and level, the computer on an empty side. Null when nobody is on a team.                                                                            |
| `cleanName`    | `name`                                                         | Whitespace collapsed, trimmed, at most 16 UTF-16 units. `""` for a non-string.                                                                                                                                                  |
| `cleanOptions` | `options`                                                      | Known keys with known values; the rest the defaults.                                                                                                                                                                            |
| `optionLabel`  | `key, value`                                                   | The label shown for an option's value, or the value as text.                                                                                                                                                                    |
| `matchOptions` | `doc, lineup, seed, start`                                     | The engine's `newMatch` options for the lineup: each player's `key` is their member id, `cpu: []` when both sides are human. The host passes its own `seed` and `start` (`{ year, month, day, hour, min }`).                    |
| `startCheck`   | `players, members, host, lenient`                              | May START go ahead? `{ ok, engine, differ: [ids], unknown: [ids] }` (below).                                                                                                                                                    |
| `startMatch`   | `doc, snap, hash, players, cpu, host, setup, members, lenient` | START: the match from the host's first snapshot, stamped with `engine`. Nothing when a match runs or `startCheck` refuses.                                                                                                      |
| `commitAction` | `doc, n, seq, snap, hash, action, over`                        | Action `seq` of match `n` committed with the snapshot after it. Nothing unless it follows the document's last action (the compare-and-set's loser adopts instead).                                                              |
| `replayOf`     | `match`                                                        | The ended match's replay `{ v, n, setup, h0, log, snap, hash, players, cpu, engine }`, or null (not over, or its log is not whole).                                                                                             |
| `isReplay`     | `replay`                                                       | Is this (from the room's kept copy) a replay the engine can play?                                                                                                                                                               |
| `backToLobby`  | `doc, n`                                                       | REMATCH: the same teams, the match dropped. Nothing unless a match runs (and is match `n`, when `n` is given).                                                                                                                  |
| `mayPlay`      | `engine, match, lenient`                                       | May a member whose engine is `engine` play `match`? `{ ok, why: null \| "unknown" \| "differs", engine, match }`.                                                                                                               |
| `constants`    |                                                                | `DOC_VERSION, TEAM_MAX, SEATS, SIDES, NAME_MAX, LEVELS, OPTION_DEFAULTS, MATCH_OPTIONS, LOG_BUDGET, REPLAY_VERSION` as lobby.js exports them, sync.js's `CLIENT`, `WITH_BYTES` (4096) and `ENGINE` (this engine's major.minor). |

### Who acts (seats.js)

| Call          | Fields          | Value                                                                                                                                                                                                                                                                                                                   |
| ------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `actorsFor`   | `need, ctx`     | The members who may act now. A throw is its owner's (`need.setup.thrower.key`); if they are not connected, the first connected team-mate in throwing order takes it; failing that, the host. A raise or punishment kubb: any connected defender, else the host. The computer's: the host. Practice and the end: nobody. |
| `mayAct`      | `need, ctx, me` | May `me` act? Never for the computer's throw (the host's engine throws it by itself).                                                                                                                                                                                                                                   |
| `shownActor`  | `need, ctx`     | Who to show as acting: the first who may, `"cpu"`, or null.                                                                                                                                                                                                                                                             |
| `controlFor`  | `ctx, me`       | This client's `setControl` argument: `{ sides, cpu }`, its own team's side, every human side for the host, and the computer for the host.                                                                                                                                                                               |
| `sameControl` | `a, b`          | Are two controls the same (so `setControl` need not be called again)?                                                                                                                                                                                                                                                   |
| `playingSide` | `ctx, me`       | The side `me` plays for, or null (watching).                                                                                                                                                                                                                                                                            |
| `teamIds`     | `ctx, side`     | The side's member ids in throwing order.                                                                                                                                                                                                                                                                                |
| `nextHost`    | `members, host` | When the host has gone, the earliest-joined connected member (the only one the room lets claim); null while the host is here.                                                                                                                                                                                           |

### Staying in step (sync.js)

| Call        | Fields                                  | Value                                                                                                                                                                                                                                                                                                                                                |
| ----------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `decide`    | `local, doc, with, mine`                | What to do with a document version that arrived: `{ kind: "lobby" }`, `{ kind: "start", match }` (another match: restore it), `{ kind: "same", match }` (compare hashes), `{ kind: "old" }`, `{ kind: "apply", match, action }` (apply, then check the hash), `{ kind: "adopt", match, why: "own" \| "gap" \| "no-action" }` (restore the snapshot). |
| `rider`     | `n, seq, action, bytes, client, engine` | The `with` for a commit, or null when it would not fit `bytes` (default 4096) less 64, counted as `asciiSize`: then the others adopt the snapshot. `client` defaults to `"web"`; `engine`, when given, rides as `e`.                                                                                                                                 |
| `asciiSize` | `value`                                 | The characters of `JSON.stringify(value)`, each above U+007E counted as 6: the room's size rule.                                                                                                                                                                                                                                                     |

The web's `aimKey` (a cast throttle for the aim the others see) is not here: it is how
the web paces its socket, not shared state.

## A match through the calls

1. The lobby: members `joinTeam`, the host `setOptions` and `setAccess`; each reducer's
   value, when not null, is what the client writes to the room (compare-and-set).
2. START, on the host: `lineup(doc, members)`, `matchOptions(doc, lineup, seed, start)`,
   then the engine's `new` with those options, its `snapshot` and `hash`, then
   `startMatch(doc, { snap, hash, players, cpu, host, setup, members })` and write it.
3. Every client, on every document version: `decide(local, doc, with, mine)`, then
   `restore(match.snap)` for start and adopt, `apply(action)` then `hash` for
   apply. `controlFor(ctx, me)` gives `setControl`; `mayAct(view.need, ctx, me)` says
   whether this client takes the input now.
4. The client that acted: `rider(n, seq, action)`, then `commitAction(doc, ...)` with
   the snapshot after the action, written with the rider. A null value means another
   client's commit came first: adopt that one.
5. The end: the action that ends the match commits with `over: true`; `replayOf(match)`
   is what the room keeps. `backToLobby(doc, n)` for a rematch.

A finished match can also be turned into its document after the fact (since 0.7.2): the
session's `replayLoad({ ..., document: true })`, `replayFinish()` and
`replayDocument()` (docs/SESSION.md "The score sheet and replays") run these same
reducers, steps 1, 2, 4 and 5, over the replay. The document is the one a pitch that
played the match would have written, byte for byte as `json.encode` gives it, so
`replayOf(document.match)` gives the room's replay of it. `test_check.lua` compares one
with a real room flow.

## Engines in one match

Two clients share a match only when their engines' major.minor are equal
(docs/VERSIONING.md "Playing together"). The room enforces it at START:

- START writes `match.engine`, this engine's major.minor.
- `startMatch` refuses while any player's engine (their `me.engine` in `members`)
  differs from the host's (`startCheck`'s `differ`). The host is not checked: it runs
  this engine.
- A player who names no engine (a web client from before 0.3) counts as `unknown`. By
  default START is refused for them too; the host may pass `lenient: true` to let them
  play. `lenient` never lets a different engine in.
- A client joining a running match calls `mayPlay(myEngineVersion, match)`. A match
  with no `engine` (started by an older client) is `unknown`: refused unless `lenient`.

## Differences from the JavaScript

Every one is deliberate and tested (`tests/lua/room/test_room.lua`, "the engine's own"):

1. **`lobbyOf` keeps unknown top-level keys.** The JavaScript rebuilds the document from
   the keys it knows and drops the rest; here any other top-level key goes through every
   reducer as it was, so a newer client's fields survive an older client's write. Until
   the web adopts these calls, its own writes still drop them.
2. **`startMatch` writes `match.engine`** and refuses on an engine mismatch
   (`members`, `lenient`; above). The JavaScript takes neither argument.
3. **`replayOf` carries `engine`** when the match has one, so a replay knows which
   engine reproduces it.
4. **`startCheck` and `mayPlay`** are new.
5. **`rider` takes `client` and `engine`** instead of the JavaScript's `size` function
   (always `asciiSize` here). With neither given it is the JavaScript's rider exactly.
6. **`cleanName` never leaves half a character.** Where the JavaScript's 16-unit cut
   splits a character beyond U+FFFF (an emoji), the whole character goes; the
   JavaScript leaves a lone surrogate.
7. **`ctx.connected` is a list**, not a `Set`.
8. **Results are wrapped** in `{"value": ...}`, and `undefined` comes back as `null`.

Beyond these the calls decide exactly as the JavaScript does on the same JSON, odd input
included: `===` (so `"3"` is not `3`), JavaScript truthiness (`0`, `""` and `null` are
false; `[]` and `{}` are true), `Number.isInteger`, and sizes counted on
`JSON.stringify`'s text.

## Equivalence

- `tools/room-vectors.mjs` (`make room-vectors KUBB_WEB=<web checkout>`) plays
  scenarios (`tools/room-scenarios.mjs`) through the web's own modules and writes every
  call and its value to `tests/room/vectors/`: scripted ones (odd documents, a full
  room of sixteen with six a side, options, names, sizes and riders, every path of
  `decide`, a log past the budget) and a seeded room's life each for 30 seeds (joins,
  leaves, team changes, options, START, commits with riders, compare-and-set losers,
  gaps and missed versions, the host going and a new one, rematches, a disconnected
  member's throw taken by a team-mate). Values over 400 bytes are kept as an FNV-1a
  hash and length of their sorted-key text.
- `make test-room` runs every vector under desktop Lua and `make test-wasm`
  (`tests/node/room.test.mjs`) under wasmoon, comparing each value after taking out
  `engine` (difference 2 and 3) and checking it is this engine's. No vector has an
  unknown top-level key or a name a split character would change.
- When the web's modules are at hand (`KUBB_WEB`, or a sibling checkout at the commit
  in `engine.json`), `tests/node/room.test.mjs` also runs 60 more seeds live through
  both and checks the web's constants are the engine's.

## What the web changes to use these

- Load the engine at 0.3 or later and replace `src/net/lobby.js`, `seats.js` and
  `sync.js` with thin wrappers over `kubbCall("room.<name>", JSON.stringify(args))`,
  reading `.value` (and `?? undefined` where it tests for `undefined`).
- Pass the room's members to `startMatch` (`members`) and send `me.engine`
  (`engineVersion`) in each member's `me`. Decide whether to pass `lenient` while older
  clients are about; once every client sends its engine, drop it.
- Pass `connected` as an array in `ctx`.
- Call `mayPlay` before joining a running match.
- Optionally pass `engine` to `rider`, so the recorder sees which engine committed.
- Keep `aimKey` and the socket.
