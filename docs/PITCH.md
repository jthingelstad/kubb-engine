# The pitch

`pitch/` is the logic of a shared pitch: the lobby document and the reducers that write
it, who acts in a shared match, and which engine a match runs on when clients carry
several. It is pure: no clock, no randomness, no network. The host passes its seed and
start time in. The pitch server (the web repository's `docs/PITCH-SERVER.md`, its wire in
`backend/pitch-server/PROTOCOL.md`) carries the document and the match's log; it runs no
engine and knows none of these rules.

The Lua is the source of truth. It began as the web game's `src/net/lobby.js`, `seats.js`
and `sync.js` in Lua (the commit in `engine.json`'s `pitchFrom`), with the same function
names. Since engine 0.3 those files are thin wrappers over these calls, so there is no
second implementation to keep in step: a change to who acts or to the document is made
here, and the web and the iPhone app take it with the tag.

Before 0.13 this was `room/`, its calls `room.<name>` and its tables `tw.room.*`. The old
spelling still works (below, "The old spelling").

## Files

| Path                | What                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------- |
| `pitch/lobby.lua`   | `tw.pitch.lobby`: the document's reducers, and the engine check for START.                    |
| `pitch/seats.lua`   | `tw.pitch.seats`: who may act for what the match needs now.                                   |
| `pitch/engines.lua` | `tw.pitch.engines`: the pitch's engine when clients carry several (since 0.8.1).              |
| `pitch/sync.lua`    | `tw.pitch.sync`: how a client stayed in step through the shared document (no longer used live). |
| `pitch/js.lua`      | `tw.pitch.js`: the JavaScript rules these follow (truthiness, `===`, `JSON.stringify`, sizes). |
| `pitch/api.lua`     | `tw.pitch.api`: the calls behind `kubbCall("pitch.<name>")`.                                  |

`session/api.lua` imports `pitch/api`, so loading the session as usual (docs/SESSION.md
"Loading") loads the pitch too. The pitch's calls need no `useTune`, `new` or match: a
client may make them before or without one.

## Calling

```
kubbCall("pitch.<name>", argsJson) -> resultJson
```

- The argument is one JSON object of named fields (the tables below). An absent field is
  JavaScript's `undefined`; `null` is `null`. They are not the same to every call.
- The result is always `{"value": ...}`. `value` is `null` where the call has nothing to
  give: for a reducer that means "change nothing, write nothing". Wrapping it means a
  document that happens to hold a key `error` is never mistaken for a failure.
- A failure (an unknown call, an argument that is not an object, a Lua error) is
  `{"error": "..."}`, as for every engine call. It names the call as it was made
  (`unknown call pitch.nope`, `room.lobbyOf: the argument is not an object`).
- Arguments are read with `json.decode(text, true)`: an empty object stays `{}`, an
  empty array stays `[]`, `null` stays `null`. Results are written by the engine's
  deterministic encoder: keys sorted, integers without a point, floats with one (`3.0`)
  or an exponent. The same inputs give the same bytes on every client.
- Strings are UTF-8. Member ids are strings.

Swift, for instance:

```swift
let out = kubbCall("pitch.joinTeam", #"{"doc":\#(docText),"id":"\#(me)","side":"A"}"#)
// {"value":{...the new document...}} or {"value":null}: nothing to write
```

### The old spelling

`room.<name>` reaches the same call as `pitch.<name>`, with the same bytes back, and
`tw.room` is the same table as `tw.pitch`. A client that carries older engines (0.7 to
0.9 know only `room.`) can keep one bridge that says `room.` for all of them, and move to
`pitch.` when it stops carrying them. New code says `pitch.`.

## The document

The pitch server holds one lobby document per pitch, written with compare-and-set (its
`set` and `start`). It is `null` until someone writes it; every reducer reads `null`, `{}`
or junk as a fresh lobby.

```
{
  v: 1,
  teams:    { A: [memberId, ...], B: [...] },   in throwing order, 0 to 6 each
  options:  { surface, opening, raising, wind, set },
  settings: { computer?, scene? },   since 0.9, only when the host set one (difference 9)
  open:     false | true,     true lists the pitch under Open games
  started:  false | true,
  n:        0,                matches started on this pitch
  match:    null | {          the header only, as the pitch server carries it
    n,                        the match number (doc.n when it started)
    players: { A: [{ id, name }], B: [...] },  who plays, frozen at START
    cpu:     "A" | "B" | null,                 the computer's side
    host,                     who started it
    engine,                   the engine's major.minor that started it ("0.13")
  }
  ...                         any other top-level key: kept as it is (a newer client's)
}
```

The match itself is not in the document. The pitch server keeps its number, the actions
committed, the hash after the last, its log of actions, the newest snapshot and the
host's `meta` (what a replay needs besides the log), and sends them beside the document.

- `options` keys and values: `MATCH_OPTIONS` below. Unknown ones are dropped; missing
  ones take `OPTION_DEFAULTS`. The engine's own options (`computer`, `scene`) are not in
  `options` but in `settings` (difference 9). Read every option, defaults filled in,
  with `optionsOf`.
- The reducers keep `match` as they find it, so a header reads, writes and survives
  `lobbyOf`, `joinTeam` and the rest unchanged; `backToLobby` drops it.

### The full match

`startMatch` builds more than the header. Its value's `match` is the whole match the
retired rooms server stored in the document:

```
match: {
  n, players, cpu, host, engine,   the header
  seq:   0,                        actions committed
  snap,                            the engine's snapshot, text exactly as it gave it
  hash,                            the engine's hash of that snapshot
  setup, h0, log: [],              only when the host passed `setup`: the newMatch
                                   options, the hash at the start, the log
  over:  true,                     set by commitAction on the action that ends it
}
```

A live client writes only the header to the pitch (the web keeps `n, players, cpu, host,
engine` and drops the rest) and sends `snap`, `hash` and `meta` beside it in the
server's `start`. The web builds `meta` from the full match: `{ v: 1, setup, engine,
version, players, cpu }`.

The full match is also what a replay's document is. The session's `replayLoad({ ...,
document: true })`, `replayFinish()` and `replayDocument()` (docs/SESSION.md "The score
sheet and replays") run `joinTeam`, `setOptions`, `startMatch` and `commitAction` over a
finished match and give the document a pitch would have written with its full match,
byte for byte as `json.encode` gives it, so `replayOf(document.match)` is that match's
replay. The web's highlight reels check a share this way (its `backend/reels/check.mjs`).

- `snap` is opaque text. Never parse it and write it back: that turns `3.0` into `3` and
  changes the hash. The calls carry it as a JSON string and never look inside.
- `setup`, `h0` and `log` are absent when `setup` was not passed. `over` is absent until
  the match ends. Absent, `null` and empty are different here and each survives every
  call.
- A full match with a log stays under `LOG_BUDGET` (248 KB, counting every character
  above U+007E as 6, the retired rooms server's rule): the commit that would pass it
  drops the log. `replayDocument` keeps each log entry's size from commit to commit
  (`lobby.docSize`) instead of encoding the whole document on every action: the same
  number, so the log goes at the same action.

### Values used by the calls

- **lineup** `{ players: { A: [{ id, name, level }], B: [...] }, cpu: "A" | "B" | null }`
- **members** the pitch's members in joined order: `[{ id, connected, me }]`, where `me`
  is what the member told the pitch about themselves: `{ name, level, engine }`. `engine`
  is the member's engine version (`engineVersion`). Other member fields (the server's
  `role`, `joined`, `since`) are ignored.
- **ctx** (who acts) `{ players, cpu, host, connected: [memberId, ...] }`: the match's
  players and computer side, the pitch's host now, and the ids connected now.
- **need** what the engine's session says it needs (`view.need`): `{ kind: "throw" |
"raise" | "punish" | "over", side, cpu, practice, setup: { thrower: { key } } }`.

## The calls

Each is `pitch.<name>`; the fields are the argument object's. "nothing" is `value: null`.

### The lobby and START

| Call           | Fields                                                         | Value                                                                                                                                                                                                                           |
| -------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lobbyOf`      | `doc`                                                          | The document as it stands, cleaned (teams to strings, options to known values, `n` to an integer, `match` to an object or null), or a fresh lobby. Unknown top-level keys are kept.                                             |
| `sideOf`       | `doc, id`                                                      | `"A"`, `"B"` or null (watching).                                                                                                                                                                                                |
| `joinTeam`     | `doc, id, side`                                                | Put `id` on `side` (`"A"`, `"B"`), or take them off both (`side: null`: sit out). Nothing while a match runs, for another side, when already there, or when the side holds six.                                                 |
| `setOptions`   | `doc, options`                                                 | The host's options merged in (unknown values ignored); `computer` and `scene` go to `settings`. Nothing while a match runs or when nothing changes.                                                                             |
| `setAccess`    | `doc, open`                                                    | Open (listed) or invite only. Nothing when unchanged.                                                                                                                                                                           |
| `openListing`  | `doc, members, over`                                           | What the host lists for an open pitch: `{ players, seats, state: "waiting" \| "playing" \| "over" }`, or null while invite only. The pitch server counts players itself; the web sends `seats` and `state`.                     |
| `pruneTeams`   | `doc, present`                                                 | Forget members no longer on the pitch (`present`: their ids). Between matches only; nothing when nobody went.                                                                                                                   |
| `lineup`       | `doc, members`                                                 | Who plays: the teams with each member's cleaned name (`Player n` when none) and level, the computer on an empty side. Null when nobody is on a team.                                                                            |
| `cleanName`    | `name`                                                         | Whitespace collapsed, trimmed, at most 16 UTF-16 units. `""` for a non-string.                                                                                                                                                  |
| `cleanOptions` | `options`                                                      | Known keys with known values; the rest the defaults.                                                                                                                                                                            |
| `optionsOf`    | `doc`                                                          | Every match option the pitch holds, defaults filled in: `options`' five and `computer` and `scene` from `settings`. The one place a client reads them all. Since 0.9.                                                            |
| `optionLabel`  | `key, value`                                                   | The label shown for an option's value, or the value as text.                                                                                                                                                                    |
| `matchOptions` | `doc, lineup, seed, start`                                     | The engine's `newMatch` options for the lineup: each player's `key` is their member id, `cpu: []` when both sides are human. The host passes its own `seed` and `start` (`{ year, month, day, hour, min }`).                    |
| `startCheck`   | `players, members, host, lenient`                              | May START go ahead? `{ ok, engine, differ: [ids], unknown: [ids] }` (below).                                                                                                                                                    |
| `startMatch`   | `doc, snap, hash, players, cpu, host, setup, members, lenient` | START: the document with `started`, `n + 1` and the full match (above), stamped with `engine`. Nothing when a match runs or `startCheck` refuses. A live client writes the header only.                                        |
| `backToLobby`  | `doc, n`                                                       | REMATCH: the same teams, the match dropped. Nothing unless a match runs (and is match `n`, when `n` is given).                                                                                                                  |
| `mayPlay`      | `engine, match, lenient`                                       | May a member whose engine is `engine` play `match` (a header will do)? `{ ok, why: null \| "unknown" \| "differs", engine, match }`.                                                                                            |
| `engineFor`    | `doc, members, host, me, carries`                              | The engine the next match runs on (below): `{ engine, missing: [ids], unknown: [ids] }`, `engine` null when none is carried by all. `me` (a member id) and `carries` (what `me` carries) are optional. Since 0.8.1.            |
| `carried`      | `me`                                                           | The major.minors a member's presence (`me`) says it carries, newest first. Since 0.8.1.                                                                                                                                         |
| `announce`     | `carries, engine`                                              | The presence fields a client carrying several engines sends while the pitch's engine is `engine`: `{ engine: "<engine>+engines", engines: [...] }`. Since 0.8.1.                                                               |
| `speakAs`      | `members, engine`                                              | The members with `me.engine` set to `engine` for each that carries it, for a host passing them to `engine`'s own `startMatch`. Since 0.8.1.                                                                                     |
| `compareEngines` | `a, b`                                                       | -1, 0 or 1 as major.minor `a` is older than, equal to or newer than `b`; null when either is not a version. Since 0.8.1.                                                                                                       |
| `constants`    |                                                                | `DOC_VERSION, TEAM_MAX, SEATS, SIDES, NAME_MAX, LEVELS, OPTION_DEFAULTS, MATCH_OPTIONS, LOG_BUDGET, REPLAY_VERSION`, sync's `CLIENT` and `WITH_BYTES` (4096), and `ENGINE` (this engine's major.minor).                       |

### Who acts

| Call          | Fields          | Value                                                                                                                                                                                                                                                                                                                   |
| ------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `actorsFor`   | `need, ctx`     | The members who may act now. A throw is its owner's (`need.setup.thrower.key`); if they are not connected, the first connected team-mate in throwing order takes it; failing that, the host. A raise or punishment kubb: any connected defender, else the host. The computer's: the host. Practice and the end: nobody. |
| `mayAct`      | `need, ctx, me` | May `me` act? Never for the computer's throw (the host's engine throws it by itself).                                                                                                                                                                                                                                   |
| `shownActor`  | `need, ctx`     | Who to show as acting: the first who may, `"cpu"`, or null.                                                                                                                                                                                                                                                             |
| `controlFor`  | `ctx, me`       | This client's `setControl` argument: `{ sides, cpu }`, its own team's side, every human side for the host, and the computer for the host.                                                                                                                                                                               |
| `sameControl` | `a, b`          | Are two controls the same (so `setControl` need not be called again)?                                                                                                                                                                                                                                                   |
| `playingSide` | `ctx, me`       | The side `me` plays for, or null (watching).                                                                                                                                                                                                                                                                            |
| `teamIds`     | `ctx, side`     | The side's member ids in throwing order.                                                                                                                                                                                                                                                                                |

Two clients acting at once are settled by the pitch server: it takes an action only as
the next sequence, and the other is refused.

### Replays and reels

| Call           | Fields                                  | Value                                                                                                                                                              |
| -------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `commitAction` | `doc, n, seq, snap, hash, action, over` | Action `seq` of match `n` committed to a full match with the snapshot after it. Nothing unless it follows the match's last action. `replayDocument` runs it.       |
| `replayOf`     | `match`                                 | A full match's replay `{ v, n, setup, h0, log, snap, hash, players, cpu, engine }` once it is over with its log whole, or null. A header alone gives null.          |
| `isReplay`     | `replay`                                | Is this (a kept replay, from the api or an embed) a replay the engine can play?                                                                                    |

### Calls live play no longer makes

These belonged to the retired rooms server, where every action rewrote the shared
document. They stay, because what clients call only grows (docs/VERSIONING.md "Carrying
several engines"), and their behaviour is unchanged:

| Call        | Fields                                  | Value                                                                                                                                                                                                                                         |
| ----------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `decide`    | `local, doc, with, mine`                | What to do with a document version that arrived: `{ kind: "lobby" }`, `{ kind: "start", match }`, `{ kind: "same", match }`, `{ kind: "old" }`, `{ kind: "apply", match, action }`, `{ kind: "adopt", match, why: "own" \| "gap" \| "no-action" }`. |
| `rider`     | `n, seq, action, bytes, client, engine` | The `with` for a commit, or null when it would not fit `bytes` (default 4096) less 64, counted as `asciiSize`. `client` defaults to `"web"`; `engine`, when given, rides as `e`.                                                             |
| `asciiSize` | `value`                                 | The characters of `JSON.stringify(value)`, each above U+007E counted as 6.                                                                                                                                                                    |
| `nextHost`  | `members, host`                         | When the host has gone, the earliest-joined connected member; null while the host is here. The pitch server now picks the host itself.                                                                                                        |

## Live play through the calls

1. The lobby: members `joinTeam`, the host `setOptions` and `setAccess`; each reducer's
   value, when not null, is what the client writes (the server's `set`, compare-and-set).
   `openListing` gives the host what to list while the pitch is open.
2. START, on the host, on the pitch's engine (`engineFor`): `lineup(doc, members)`,
   `startCheck`, `matchOptions(doc, lineup, seed, start)`, then the engine's `new` with
   those options, its `snapshot` and `hash`, then `startMatch(doc, { snap, hash, players,
   cpu, host, setup, members })`. The document with the header goes in the server's
   `start`, the snapshot, hash and `meta` beside it.
3. Every client: `mayPlay(myEngine, doc.match)` before taking part; `controlFor(ctx, me)`
   gives `setControl`; `mayAct(view.need, ctx, me)` says whether this client takes the
   input now, `shownActor` who to show.
4. Actions go through the server (`act`), never through these calls. A client that
   receives one applies it and compares the hash; a gap or a hash that differs asks for
   the whole pitch and restores its snapshot.
5. The end: the server builds the kept replay from `meta` and its log. `backToLobby(doc,
   n)` for a rematch.

## Engines in one match

A match belongs to the engine major.minor it was started on, for its whole life: its
play, its replay, its embed, its highlight reel, a share's check and its score sheet.
Two clients share it only when both carry that engine (docs/VERSIONING.md "Playing
together"). A client may carry one engine (every release before 0.8.1 does) or several
(docs/VERSIONING.md "Carrying several engines").

What every release since 0.3 does, unchanged:

- START writes `match.engine`, the starting engine's major.minor (`lobby.ENGINE`).
- `startMatch` refuses while any player's engine (their `me.engine` in `members`, read
  as major.minor) differs from the starting engine's (`startCheck`'s `differ`). The host
  is not checked: it runs that engine. Watchers are not checked: only the lineup's
  players are (`lineup`: the teams' members still on the pitch, away or not).
- A player who names no engine (a web client from before 0.3) counts as `unknown`. By
  default START is refused for them too; the host may pass `lenient: true` to let them
  play. `lenient` never lets a different engine in.
- A client joining a running match calls `mayPlay(myEngineVersion, match)`. A match
  with no `engine` (started by an older client) is `unknown`: refused unless `lenient`.

### The pitch's engine

When clients carry several engines, the next match runs on the **pitch's engine**: the
newest major.minor that the host and every player in the lineup carry
(`engineFor(doc, members, host)`). It is a function of the pitch's presence and its
teams and nothing else, so every client works out the same one from the same pitch.
Watchers do not count, so a watcher on an older engine never pulls a match down; they
count once they take a seat. When no engine is carried by all, `engine` is null and
`missing` names the players to tell (those without the engine most of them share).

What a member carries is read from its presence (`carried`):

- A client carrying several sends `engines`, every major.minor it carries, and writes its
  `engine` as the pitch's engine followed by `+engines` (`"0.7+engines"`; `announce`).
  Older engines read `engine` through `majorMinor`, which stops at the minor, so they
  see `"0.7"`.
- `engines` is believed only while `engine` carries the mark and is among them. The pitch
  server merges `me` field by field, so an older client rejoining under the same member
  id overwrites `engine` and leaves a stale `engines` behind; the missing mark says so.
- Otherwise a member carries its lone `engine` (`"0.7.4"` and `"0.7"` both read as
  `0.7`), or nothing.

`engineFor` reads each member's `engines`, never a new client's own `engine`, so a
client changing its announcement cannot change the answer: there is no loop to swing.

### Speaking down

A client that carries several engines keeps every client that carries one in agreement
without any change to them:

1. It works out the pitch's engine counting itself (`engineFor` with `me`, and
   `carries` while its own presence has not come back), and announces it (`announce`
   then the server's `me` message) whenever the answer changes: when a member joins,
   leaves or takes or gives up a seat, and when the host changes. Before it knows the
   pitch it announces its newest.
2. It runs the lobby, START and the match on that engine's own pitch and session calls
   (`room.*` on an engine before 0.13), so the rules it applies are exactly an older
   client's. As host it starts on that engine, passing `speakAs(members, engine)` as
   `members` so a player whose new announcement is still on its way is not refused for
   it. Its `match.engine` is then that engine's.
3. An older host reads the new client's `engine` as the pitch's and its START passes.
   An older player's lobby check of the host (`mayPlay` against the host's `engine`)
   passes. An older client's `mayPlay` on the match passes.
4. In a running match a client plays or watches only on `match.engine`, through that
   engine's `mayPlay`; a client that does not carry it is refused.

An announcement takes one round trip. While it is on its way an older host may refuse
START once and an older player may see its version card for a moment. Nothing is
written in that time.

The document, its reducers and the rules of who acts are the same code in every engine
a client carries today (`room/` was the same in 0.7.4 and 0.8.0, 0.8.1 added the engine
calls, 0.9 `settings`, and 0.13 only renames it). Running the lobby on the pitch's engine
keeps clients agreeing if they ever differ; the document must still only grow
(docs/VERSIONING.md "Carrying several engines"), because a watcher on another engine
writes its own seat.

## Differences from the JavaScript

The vectors were recorded from the web's JavaScript before it became a wrapper. These
are where the Lua decides otherwise, each deliberate and tested
(`tests/lua/pitch/test_pitch.lua`, "the engine's own"):

1. **`lobbyOf` keeps unknown top-level keys.** The JavaScript rebuilt the document from
   the keys it knew and dropped the rest; here any other top-level key goes through
   every reducer as it was, so a newer client's fields survive an older client's write.
2. **`startMatch` writes `match.engine`** and refuses on an engine mismatch
   (`members`, `lenient`; above). The JavaScript took neither argument.
3. **`replayOf` carries `engine`** when the match has one, so a replay knows which
   engine reproduces it.
4. **`startCheck` and `mayPlay`** are new, and so are `engineFor`, `carried`,
   `announce`, `speakAs` and `compareEngines` (since 0.8.1).
5. **`rider` takes `client` and `engine`** instead of the JavaScript's `size` function
   (always `asciiSize` here). With neither given it is the JavaScript's rider exactly.
6. **`cleanName` never leaves half a character.** Where the JavaScript's 16-unit cut
   splits a character beyond U+FFFF (an emoji), the whole character goes; the
   JavaScript left a lone surrogate.
7. **`ctx.connected` is a list**, not a `Set`.
8. **Results are wrapped** in `{"value": ...}`, and `undefined` comes back as `null`.
9. **The engine's own options** (since 0.9) live in a top-level `settings` object, not
   in `options`: `{ computer?, scene? }`, each present only when a host set a valid
   value, and `settings` only when one is. An older engine's `lobbyOf` (0.8.2 and before)
   rebuilds `options` from the five keys it knows but keeps a top-level key it does not
   know, so a 0.8 client's `joinTeam` or `setAccess` in a shared lobby leaves them as the
   host set them (`tests/lua/pitch/test_settings.lua` proves it with 0.8.2's own
   reducers, `tests/fixtures/room-0.8.2/`). Inside `options` they would be dropped. A
   document without `settings` reads and writes exactly as before.
   - `computer`, the computer's level (`beginner`, `club` or `pro`; Jamie, 2026-11-20:
     "yes this should be a real per game setting"). It is in `MATCH_OPTIONS` (label
     "Computer") and `OPTION_DEFAULTS` (`club`). A person's own level stays theirs
     (`me.level`); the option is the computer's only.
   - `scene`, the look the match is drawn in: in `OPTION_DEFAULTS` (`day`) but not in
     `MATCH_OPTIONS`, since the engine does not list the scenes. Any id of lowercase
     letters, digits and hyphens, 1 to 24 characters, is taken (`isScene`), so a client
     adds a scene without an engine release and labels it itself. `set` stays a fixed
     list, as the JavaScript had it (vector 017 refuses `"mars"`).
   - The host sets them with `setOptions`, in the same `options` object as the rest.
     `optionsOf` reads all seven with defaults filled in. `matchOptions` passes each on
     only when the pitch has it, so a pitch that never set one starts the match it always
     did. `cleanOptions` is the JavaScript's: it knows only the five.

Beyond these the calls decide exactly as the JavaScript did on the same JSON, odd input
included: `===` (so `"3"` is not `3`), JavaScript truthiness (`0`, `""` and `null` are
false; `[]` and `{}` are true), `Number.isInteger`, and sizes counted on
`JSON.stringify`'s text.

## The vectors

`tests/pitch/vectors/` is a frozen corpus: every call and its value as the web's
JavaScript gave them at the commit `engine.json`'s `pitchFrom` names, recorded before
those modules became wrappers. Scripted scenarios (odd documents, a full pitch of sixteen
with six a side, options, names, sizes and riders, every path of `decide`, a log past the
budget) and a seeded pitch's life each for 30 seeds (joins, leaves, team changes,
options, START, commits with riders, compare-and-set losers, gaps and missed versions,
the host going and a new one, rematches, a disconnected member's throw taken by a
team-mate). Values over 400 bytes are kept as an FNV-1a hash and length of their
sorted-key text.

They cannot be made again: the web's modules now call the engine, so recording through
them would compare the engine with itself. Never edit them. A deliberate change to a
call's behaviour is a new difference above, with the vector steps it changes said in
the pull request.

- `make test-pitch` runs every vector under desktop Lua and `make test-wasm`
  (`tests/node/pitch.test.mjs`) under wasmoon, comparing each value after taking out
  `engine` (differences 2 and 3) and checking it is this engine's. The wasmoon run also
  checks that `room.<name>` gives the same bytes as `pitch.<name>`.
- `tests/lua/session/test_logsize.lua` checks every `commitAction` step's size measure
  against them.
