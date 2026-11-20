# The session

`session/` is the engine's platform-neutral session: a practice pitch or a match behind
a few coarse calls, every argument and result JSON text. A client draws, listens and
talks to the network; every rule, plan, swing, flight, ruling and camera is Lua. It is
the web game's `lua/web/` (kubb.thingelstad.xyz), moved here at the commit in
`engine.json` (`sessionFrom`) with its behaviour kept, and this file is that
repository's `docs/ENGINE.md` for the parts that are now the engine's, still in the
web's words: where it says a browser, read any client, and its examples use the web's
`Engine` wrapper (`newMatch(opts)` is `kubbCall("new", { mode = "match", ... })`, and so
on). Code comments that cite `docs/CLIENT.md` mean the web repository's.

The Playdate's `source/scenes/match.lua`, `throw.lua` and `settle.lua` (in
`playdate-kubb`) are what `session/session.lua` and `session/throw.lua` follow, line for
line where they can; "Differences from the Playdate" says where they differ.

Everything returned is in **the thrower's view frame** (`core/frame`): the thrower
stands at y = 0 on their own baseline, looking up the pitch toward +y (the far baseline
at y = 8), x to the right, z up, metres. A client never flips the pitch. In a match the
frame is the throwing side's (the defending side's for raising and punishment).

## Files

| Path                  | What                                                                                                               |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `session/api.lua`     | The one door: the global `kubbCall(method, argJson) -> resultJson`, protected (`{"error": "..."}` on a Lua error). |
| `session/session.lua` | `tw.web.session`: practice and match sessions, actions, snapshot, restore, hash, the tune and the client label.    |
| `session/throw.lua`   | `tw.web.throw`: one throw: aim, dial, computer, launch, the recording, the playback camera.                        |
| `session/replay.lua`  | `tw.web.replay`: a finished match played again from its options and its log, read only.                            |
| `session/check.lua`   | `tw.web.check`: a shared match's throws checked: the computer's made again, a person's held to the dial.           |
| `session/wide.lua`    | `tw.web.wide`: the wide view, one camera for the whole pitch.                                                      |
| `session/json.lua`    | `tw.web.json`: deterministic JSON (sorted keys, shortest round-trip floats, integers kept apart from floats).      |
| `room/`               | The room's calls, `kubbCall("room.<name>")`: a shared pitch's document, who acts, staying in step (docs/ROOM.md).  |
| `tune/pointer.lua`    | `tw.tune.pointer`: a pointer's values for the core's tune tables, and the session's dial and throw tables.         |
| `version.lua`         | `tw.engine`: the engine's name and version (docs/VERSIONING.md).                                                   |

The tables keep the web's `tw.web.*` names, so the web adopts this with path changes
only. Modules are imported as `session/<name>`, `tune/<name>` and `version`.

## Loading

A client loads the engine from one artifact. `make bundle` writes
`build/kubb-engine-sources.json`, the module map `{ "core/world": "<source>",
"session/api": "<source>", "tune/pointer": "<source>", "version": "<source>", ... }`
(keys sorted, no whitespace, so the same sources give the same bytes), and its sha256
beside it (`kubb-engine-sources.json.sha256`; `bundle.sha256` in `engine.json` is the
same). Put an `import` shim over it that runs a module once, then
`import "session/api"`:

```lua
local imported = {}
function import(name)
  name = name:gsub("%.lua$", "")
  if imported[name] then return nil end
  imported[name] = true
  local s = __kubbSource(name) -- the host's lookup in the module map
  if not s then error("import: no module " .. name, 2) end
  return assert(load(s, "@" .. name))()
end
import "session/api"
```

`tests/node/wasm.mjs` does this under wasmoon, as the web's `src/engine/index.js` does.
Each Lua state holds one session.

## Starting

Before the first `new` or `restore`, a host makes these calls:

- `engineVersion()` returns `{ version }`: `version.lua`'s, to check against the
  release the host vendored and to compare with a peer's (docs/VERSIONING.md).
- `useTune({ name })` returns `{ tune }`. Required: `new` and `restore` refuse to run
  before it. It loads `tune/<name>.lua` and puts its values into the core's tables;
  `"pointer"` is a mouse or a finger on the web's dial. Once per Lua state: the same
  name again is fine, another is refused.
- `setClient({ label })` returns `{ client }`: the client label written into every game
  file the session makes (`[Scored by "Throwing Wood <label>"]`), like `"web 0.4.2"`.
  1 to 40 letters, digits, spaces, dots, hyphens or pluses, no space at either end.
  Default `"kubb-engine <version>"`. It can be called again; a file takes the label set
  when it is written. Since 0.7.2 it also takes `location`, the game file's
  `[Location "..."]` line (`"throwingwood.com"` for the web and the iPhone app, same
  rules as the label: a domain name passes); absent, the line is `"Playdate"` as before.
  Each call sets both, so a call without `location` puts `"Playdate"` back. It returns
  `{ client, location }`, the label and the Location line every file will now carry
  (since 0.7.4 `location` is `"Playdate"` when none was given; before, it was left out).
  The location reaches every file the session writes: the live `sheet()`, the over
  need's `file`, and a replay's sheet and over file (each written with the location set
  at the time, on the host that writes it).

The label and the location are not in the snapshot, the room document (`replayDocument`)
or any recording, so neither ever changes a hash, and two hosts with different
locations play one match in step. The tune can: it sets how
the computer's flick maps onto the swing, so peers in one online match load the same
tune (the golden hashes are recorded with `pointer`).

## The API

Every method below is `kubbCall(name, JSON.stringify(args))` behind a wrapper. Results
are plain objects. The room's calls (`room.<name>`) are in docs/ROOM.md. Angles are degrees unless named otherwise; times are seconds.

### Sessions

| Call                         | Returns           | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `newPractice(opts)`          | view              | `{ surface: "grass" \| "sand" \| "snow", level, set, drill }`. The practice pitch (scenes/drills.lua's free throw); `drill: true` throws kubbs at the circle.                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `newMatch(opts)`             | view              | `{ seed, teams, cpu, first, opening, raising, wind, surface, set, computer, scene, start, maxTurns, modeName }`. `teams: { A: { name, players: [{ name, level, key }] }, B: ... }`, 1 to 6 players a side (strings work as names). `cpu`: `"A"`, `"B"`, `"both"` or a list. `first: "A" \| "B"`. `opening: "2-4-6" \| "six"`. `raising: "hand" \| "auto"`. `wind: "off"` or a core/wind level (`"light"`, `"strong"`, ...). `start: { year, month, day, hour, min }`: the match clock's start (the game file's date; pass the host's local time). `maxTurns`: the side to throw at that turn resigns (tests, quick games). `computer` (since 0.9): the computer's level, `"beginner"`, `"club"` or `"pro"`, given to every player on a computer side whose entry names no level of its own; absent, unknown or `"club"` (the default) the option is not kept, so the start is the one a match always had, and the computer throws at club. A person's level is their entry's own. `scene` (since 0.9): the look to draw the pitch in, an id of lowercase letters, digits and hyphens, 1 to 24 characters (`room/lobby.isScene`); the engine keeps it in the start like `set` and never reads it otherwise. Absent, invalid or `"day"` (the default) it is not kept. The view's `scene` is the one to draw (`"day"` when none); a client draws a scene it does not know as `"day"`. Practice (`new` with `mode: "practice"`) takes `scene` too. |
| `restore(snapshotText)`      | view              | A match from a snapshot. Restored while raising, placing a punishment kubb or after the end, the view shows the match's pitch as it stands (pieces and debris, a king that ended the match lying down) in the last throw's frame, as live, until the next throw is set up. The restored session acts for every side and the computer until `setControl` says otherwise.                                                                                                                                                                                                                                   |
| `snapshot()`                 | text              | The whole match as JSON text. Opaque: store and send it as it is, byte for byte. Matches only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `hash()`                     | `{ hash, bytes }` | FNV-1a 32 of the snapshot text (8 hex digits) and its length. Equal hashes mean equal matches.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `setControl({ sides, cpu })` | need              | Which sides this browser plays (`sides: ["A"]`, `[]` for a spectator) and whether it throws for the computer (`cpu`, default true). One browser in a room has `cpu: true`.                                                                                                                                                                                                                                                                                                                                                                                                                                |

### Reading

| Call          | Returns                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `view()`      | `{ need, items, minimap, aim, camera, dial, surface, set }`: everything the screen needs when nothing plays back.                                                        |
| `frameView()` | The same view, in the thrower's view frame even while the wide view is on: what a report records (the web's `src/net/report.js`), so its replay compares like with like. |
| `need()`      | What happens next (below).                                                                                                                                               |
| `aim()`       | `{ aim, camera }`.                                                                                                                                                       |
| `reportThrow()` | Last throw’s result, sequence and final piece poses in its thrower frame, including its projectile. Empty before a throw or after a restore. |
| `recording()` | The last throw's recording (below), or `{}`.                                                                                                                             |

**need** is one of:

- `{ kind: "throw", side, setup, cpu, local, candidates?, wind, ... }`. `setup` is the
  throw (`kind`, `projectile` "baton" or "kubb", `n` of `of`, `label`, `kingShot`,
  `rethrow`, `lineY`, `forwardY`, `advY`, `targets`, `thrower { id, name, level, key }`;
  `key` is the lineup's key for that player, on a shared pitch the room member it
  belongs to).
  `cpu`: the computer throws. `local`: this browser acts for it. `candidates`: the team's
  players when a human team has more than one (for the `thrower` action). Practice:
  `{ kind: "throw", practice: true, drill, surface, level, set }`.
- `{ kind: "raise", side, kubb, pose, mode, choices, ends, default, others, king, n, of,
team, local }`: a kubb to raise by hand. `choices[i] = { which, pose, displaced,
crowded }`; `ends[i] = { which, pose, inBounds, obstructedBy, ok, why }` (`why`: "THAT
  END IS OUT" or "THAT END IS BLOCKED"); `default` is the index the computer would pick.
- `{ kind: "punish", side, kubb, cursor {x, y}, bounds {xMin, xMax, yMin, yMax}, keepOut
[{ kind, id, x, y, r }], others, n, of, team, local }`: a punishment kubb to place.
- `{ kind: "over", winner, how, file { text, name }, text, short }`: the match is over;
  `file` is the game file (match.file, `version` the client label, see "Starting").
  `short` is `text` as a few capital words (`session.short`): `"KING DOWN"`,
  `"KING TOO EARLY: GAME OVER"`, and `"RESIGNED"` for a resignation, whose `text`
  begins with the team's name (`"Riverside resigned: Oak wins"`; before 0.7.4 its
  `short` was the first 12 characters, `"RIVERSIDE RE"`). Words no rule knows are cut
  at a word, never inside one. Output only: not in the snapshot or any hash.

Every match need also carries `card` (informational: `{ kind: "settle" | "handoff" |
"pass", ... }`, the Playdate's cards; nothing waits on them), `turn`, `throws`, `teams`,
`standing`, `last { text, short }` (the last ruling) and `resignPending`.

**items** are the pieces as the renderer draws them: `{ id, kind, team, x, y, z, qw, qx,
qy, qz, toppled }`, kinds `kubb`, `king`, `baton`, `stake`. **camera** is core/camera's
table: position `px py pz`, unit `f*` forward, `r*` right and `u*` up, `lx ly lz` the
point looked at, focal length `f` with principal point `cx cy` for the Playdate's 400 x
240 screen (scale `f` by the canvas width over 400). **aim** is `{ marker { x, y, r, on,
set, kind, shown }, thrower { x, y, swivel, set }, plan { release, arcSet, tilt, spin,
level, speed, loft, swivel, dist, back, powerLo, powerHi, releaseLo, releaseHi }, arc
[{x, y, z}]?, projectile, drill, lineY, forwardY, advY, advText, halfWidth, backMax,
rail { name, kind, n, of, r1, r2 }, flag, restText, verdicts?, wind?, mix, watching }`.
**dial** is hud.clock's state: `{ phase, arm, crank, back, powerLo, powerHi, releaseLo,
releaseHi, deadDeg, overDeg, lastBack, lastStop, prompt }`. **minimap** is `{ pieces,
aim { x0, y0, x1, y1 }, advY, lineY, wind }`.

### Each frame

| Call           | Returns                                                                                                                   |
| -------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `frame(input)` | `{ dial, camera, aim, event?, action?, recording?, need? }`. `input = { dt, arm, plan, move: {dx, dy}, walk: {dx, dy} }`. |
| `showAt(t)`    | `{ t, done, speed, camera, items, burst, dial }`: the last throw at `t` seconds after the release.                        |

**The wide view** (the web's docs/CLIENT.md "The wide view"): `setWide(box)` with a box `{ left,
top, right, bottom }` in frame px fits one fixed camera to it and returns `{ camera, kind,
farPx }` (`kind` "side" or "end"; `farPx` the smallest base kubb's height in frame px).
From then on every call's `camera` is that camera, and what a call gives in Team B's view
frame (items, aim, minimap, a recording's bursts; since 0.7.2 also its `landing`,
`result.landX`/`landY` and `restX`/`restY`, and `timeline.firstContact` and `firstHit`)
comes un-turned into the world frame, with `wide` set to the kind. `setWide(null)` turns it off. The setting outlasts `new` and
`restore`.

`arm` is the pointer on the dial as **forward degrees from 6 o'clock** in (-180, 180]:
0 at the bottom, negative up the left side (the backswing: 7 o'clock is -30, 9 is -90,
12 is -180), positive up the right (the throw: 5 is +30, 3 is +90). Leave it out (or
null) while the pointer is not on the dial. `plan`: the plan view is held (the dial
does nothing, the camera eases to the overhead view). `move` and `walk`: the circle's
and the stance's keys, -1..1 per axis. `event` is `"letdown"` or `"release"`. On a
release that this browser acts for, `action` is the throw to send to the room,
`recording` is its recording, and `need` is what comes next (the throw has already been
applied here).

On a human input frame, optional `dial.crossings` lists `{band, edge}` in travel
order. The bands are `power` (backswing) and `release` (forward), the edges
`enter` and `exit`. Endpoints are inside. Fast samples can cross both edges in
one frame. Only measured arm motion while winding or swinging counts. A reset,
lift without motion, stationary frame, remote aim or computer animation emits
no crossing. Read once from the frame response, including a release frame.

### Touch pendulum

Send `frame({ dt, touch: [sample, ...] })` for a local human throw. Samples belong
to one contact, in order. Start with `{ phase: "down", x, y, t }`, send positions
while moving, and end with `{ phase: "up", x, y, t }` or `{ phase: "cancel" }`.
Use monotonic seconds and divide both coordinates by the same short edge of the
play area, with y increasing down. Keep that coordinate system for the contact.
Forward coalesced samples with their original timestamps. Frames without new
samples leave a held contact alone. The engine returns the usual dial, events,
action and recording. A cancelled or stale contact (over 30 seconds between
samples) lets down.

`session/touch.lua` linearly interpolates at 120 Hz starting at touchdown, then
projects onto the crank. A short edge is 600 degrees. Horizontal displacement
from the origin discounts vertical travel by half its magnitude, down to zero.
Angles round to 1/1024 degree. Winding back 30 degrees engages the core swing.
A 300 degree/s return starts a flick, 1200 degree/s delivers full power. The
existing swing measures speed and steadiness. A normal release waits for lift
and uses the farthest forward angle. A slow return lets down at six and crossing
180 degrees forward releases a sky ball even with the finger down.

Both `useTune("pointer")` and `useTune("touch")` share the pointer host's physics,
CPU calibration and dial. Either accepts both kinds of frame input. The touch
projection constants live in `tune/touch.lua`. A human action and its recording
carry an optional `input` field for tuning: `pointer` (the dial) or `touch`
(the pendulum). The core's on-device trace writer tags its lines `crank`.
Scripted throws and older records have no measured input. The tag is outside
the snapshot, scoring, seats and player-facing views.

### Aiming

All return `{ aim, camera }`, and do nothing unless this browser may aim now.

| Call                           | What                                                                                                                 |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| `setTarget(x, y, snap)`        | The circle at (x, y); `snap` puts it on the nearest piece within `snapRadius`.                                       |
| `nudgeTarget(dx, dy)`          | The circle moved by (dx, dy) metres.                                                                                 |
| `setStance(x, y)`              | The thrower stands there (behind the line, inside the pitch). `setStance()` lets the stance follow the target again. |
| `stepArc(step)`, `setArc(deg)` | The release angle (the plan's arc): a step of `arcStepDeg`, or any value, clamped (never rounded). |
| `stepSide(step)`               | A step: a baton's tilt by `tiltStepDeg`, a kubb's spin by one tap.                                  |
| `setTilt(deg)`, `setSpin(spin)` | Since 0.9: a baton's tilt (degrees) or a kubb's spin (taps, fractions too), any value, clamped to the range; each does nothing for the other projectile. |
| `freshPlan()`                  | Back to the plan's own release and arc.                                                                              |
| `setLevel(level)`              | The thrower's level (practice: the default level).                                                                   |

Practice also has `setDrill(on)`, `reset()` and `setSurface(name)`, which return a view.

**The controls** (since 0.9; Jamie, 2026-11-20: "more analog allow the slider to select
any value in a range"). `aim.controls` gives a slider its numbers from the engine:
`arc` always, `tilt` for a baton, `spin` for a kubb, each `{ min, max, default, value,
tick, step, unit, scope }` (`arc` also `set`, `spin` also `radPerTap` and `baseRad`).
`tick` is the fine move a held key slides by, one a frame (`plan.tune.arcTickDeg`,
`tiltTickDeg`, `spinTick`); `step` what a press jumps by (the step calls). `scope` is
`"throw"` or `"turn"` (below).

| Control | Range | Default | Tick | Step | Physically |
| ------- | ----- | ------- | ---- | ---- | ---------- |
| `arc` | 15 to 165 clock degrees (half past 5 to half past 12) | the plan's own: 90 at base kubbs, 75 the king, 60 field kubbs, 135 a drilled kubb | 5 | 15 | the release target; the loft is `plan.loftFor` of it, about 7 to 57 degrees |
| `tilt` | -20 to 20 degrees | 0 | 1 | 5 | the baton's spin plane tipped, before the shake's tilt; over 30 with the shake is a helicopter |
| `spin` | -3 to 3 taps | 0 | 0.25 | 1 | 22 rad/s a tap about the kubb's long axis, + clockwise from behind (rolls right), on top of the wrist's 3 rad/s spiral: -63 to +69 rad/s |

The value a client sends is applied as it is (clamped), and the throw's action carries
the launch it made, so a fractional value needs no wire precision of its own: every
client applies the action's numbers (JSON's shortest round-trip doubles), never a slider
position. The spin is linear in the physics (`drill.body`; the drill's solve does not
read it), so there is no step at a former tap.

**Turn and throw settings** (Jamie, 2026-11-20). The arc and a baton's tilt are throw
settings: every throw starts from the plan's own arc and no tilt. A kubb's spin is a turn
setting, "Keep between throws": the spin a person threw a kubb with is where the same
side's next kubb in the same inkast turn starts (rethrows included), as the circle is
kept; a side's batons, the other side's turn and a new match start from none. It is taken
from the action's `plan.spin` and kept in the snapshot's aim memory (`keptSpin`, absent
when none), so every client and a restore start the next kubb from the same value, and
`aim.plan.spin` shows it. `freshPlan` puts this throw's spin back to none. In practice
with KUBBS on the spin stays from throw to throw until `reset()` or `setDrill`.

### The score sheet and replays

`sheet()` is `{ text, name, shown, done }` for a match (`{}` in practice): `text` the game
file in Planet Kubb Notation as it stands (positions included), `shown` each line as a
screen shows it.

A finished match played again (`session/replay.lua`): `replayLoad({ setup, h0, log })`
(`setup` the match's options, or `start` its first snapshot; `log` `[{ a, h }]`, each
action and the hash after it) sets it out again; `replayStep()`, `replayBack()` (the start
of the previous turn), `replayRewind()`, `replayInfo()` and `replayEnd()`. Every result
carries `replay: { i, total, turn, thrown, throws, differs, done, over, refusedAt, ... }`.
While a replay is loaded every action from outside is refused; `new` or `restore` ends it.

Since 0.7.2:

- `replayStep()` also returns `standing: { before, after }`, the kubbs standing either
  side of the action: `{ king, A: { field, base }, B: { field, base } }` (`king` true
  while it stands). One action's `after` is the next one's `before`.
- `replayFinish()` plays every action left without recordings and returns the info.
  `refusedAt` is the 0-based index of the first action the match refused (then
  `differs` is true), `over` that the match has ended.
- `replayLoad` takes three options for a server (below, "What a server can prove"):
  `checkCpu: true` makes each of the computer's throws again and sets `forged`,
  `forgedAt` (0-based) and `forgedWhy` at the first that is not the same, or the first
  action on the computer's turn that is not its throw; `checkThrows: true` holds each
  person's throw to `checkThrow` and sets `outOfBounds`, `outOfBoundsAt` and
  `outOfBoundsWhy`; `document: true` (or `{ ids: { A: [...], B: [...] }, host }`) builds
  the room document as a pitch builds it. `cpuChecked` and `throwsChecked` count what
  was checked.
- `replayDocument()` returns `{ document, h0, hashes }` once the replay is finished:
  the room document (docs/ROOM.md "The document") with the teams joined, the options
  set, START with the first snapshot and every action committed with the snapshot and
  hash after it, `over` on the last; `hashes[i]` is the hash after action i. It refuses
  a replay not played to its end, one with a refused action, and a match of the
  computer against itself. Member ids are each player's `key`, else the side and number
  (`"A1"`); `match.engine` is this engine's major.minor.
- `checkThrow(action)` returns `{ ok, why, computer, levels, level, atLevel }`: could
  `action` be the next throw of the match as it stands now (`levels` the player levels
  that fit it).
- `checkStart({ start })` returns `{ ok, why }`: is `start` a match's first snapshot,
  exactly what `newMatch` makes from the options inside it?
- `renameStart({ start, names: { A: "Ann" }, log? })` returns `{ start, ids, log? }`: the same first
  snapshot with that side's names changed and nothing else. A string names the team
  and, on a one-player side, its player; `{ name, players: ["..", ..] }` names a team of
  more (one name each). Player keys stay. The names are in the snapshot, so every hash
  from `h0` on differs; the throws, rulings (save their words) and pieces do not.
  Players' ids come from their names, and a `thrower` action names a player by id (a
  solo side can carry one too, naming its only player), so the old log stops at the
  first one. `ids` maps each old id to its new one; pass the log and `log` comes back
  with every thrower action's id mapped (the hashes dropped): replay the renamed start
  with that log.

#### What a server can prove

A shared match against the computer arrives as its first snapshot (or setup) and its
log. A server (a highlight reel) can replay it in the engine and check this much:

- **The computer's throws are its own.** The computer's choice uses only the setup, the
  seed and the throw count (`autothrow.choose` on `rng(mix(seed, 1, throws))`), so
  `checkCpu` makes each one again from the snapshot before it and compares every field
  exactly (the host's `at` aside). A changed speed, aim or verdict, or a person's throw
  put in its turn, is `forged` at that action.
- **Every action is legal in order.** A refused action (out of step, a wrong side, a
  bad spot) stops the replay: `refusedAt`. The result (rulings, the winner, the game
  file) is what the engine makes of the log, never what the sender says.
- **A person's throw is one the dial could make.** It cannot be made again: the action
  keeps the swing's back and stop but not its flick, shake or pull, and the nerves' draws
  are seeded from them. `checkThrow` holds it to bounds worked out from the code that
  makes a throw (`session/check.lua` lists each with its source): the plan solved again
  for the stance and target with every release, tilt (or spin) and level a player can
  choose (since 0.9 any value in range, the action's `plan` tried first); the loft pinned by the stop (since 0.8.0, a baton planned under 2 m with the
  plan's flatter share of it and the heave of a swing past the power target, as
  `plan.launch` gives them); the tilt pinning the shake and the pull; the
  swivel, speed and tumble within the nerves' largest draw (and never under the floors
  the throw clamps to: a tumble under `tumbleMin`, a length draw under `lenMin`), `ZMAX` = sqrt(-2 ln 1e-12),
  about 7.43 sds (`plan.rng`'s normal floors u1 at 1e-12); the flick between
  `minFlickFrac` and 1 and matching the power verdict; a kubb's nose, spin and wobble
  exactly `drill.body`'s; the backswing 30 to 200 degrees; the stance on the ground the
  rules allow (an unset stance straight behind the target); the target in the marker's
  area or on a piece. Touch, the linear meter and STAND feed the same swing and
  `setStance`, so they need no bounds of their own.

What it cannot prove:

- **That a person threw it.** Any throw inside the bounds passes, whoever (or whatever)
  made it. A program can choose good throws inside them.
- **That the speed was likely.** The bounds are the largest the engine can give, not a
  likely spread. An overpowered full backswing at a near target multiplies the nerves:
  the bound for a legal baton is about 57 m/s, and an honest dial throw reaches 30 m/s
  about once in 300 such swings. A 30 m/s baton from a short or on-target swing is
  refused.
- **The match before the start.** `checkStart` proves the start is a fresh match made
  from its own options, but the options (names, seed, levels) are whatever the sender
  chose.
- **A match against a person.** Neither side's throws can be made again.

### Actions (a match among browsers)

| Call                | Returns                                                 |
| ------------------- | ------------------------------------------------------- |
| `apply(action)`     | `{ ok, recording?, need, why?, label? }`                |
| `checkPunish(x, y)` | `{ ok, why, label }` without placing.                   |
| `aimState()`        | This browser's aim, to send while aiming.               |
| `showAim(state)`    | Someone else's aim shown here: `{ aim, camera, dial }`. |

The actions:

- `{ type: "throw", seq, how, launch, stance, target, scripted, swing?, verdicts?, plan?, at? }`:
  what `frame` returned. `seq` is the number of throws before it; a throw out of step is
  an error, never applied. `target.on` is the id of the piece the circle is on, or null.
  For the computer's baton it is the piece `autothrow.choose` aimed at (`a.on`: the
  front kubb of the lane it aims across), since 0.9; before, the circle moved to the
  computer's aim and kept the label of the piece it was on before, so a turn's batons
  could name a kubb they were not thrown at.
  Since 0.9 a person's throw carries `plan`: `{ release, tilt }`
  for a baton, `{ release, spin }` for a kubb, the plan as the thrower set it (degrees,
  degrees, taps). Every client applies `launch`, never `plan`; the kubb's `spin` is what
  the side's next kubb starts from (below), and `checkThrow` holds the throw to it. The
  computer's throws and older actions have none.
- `{ type: "raise", choice }`: the index into `need.choices` (leave it out for the
  computer's default).
- `{ type: "punish", x, y }`: the spot in the defender's view frame. Refused spots come
  back `{ ok: false, why, label }` (label e.g. "TOO NEAR THE KING") and change nothing.
- `{ type: "resign", side, at? }`: waits for that side's own turn (the rules allow it
  only then), as on the Playdate.
- `{ type: "thrower", id }`: who throws next for the side to throw (`need.candidates`).

`at` (optional) is the finish time stamp the game file uses.

## The frame (per-frame call pattern)

A browser makes one or two calls a frame:

1. **Aiming** (`need.kind == "throw"`): `frame({ dt, arm, plan, move, walk })` once a
   frame, and the aim calls (`setTarget`, `setStance`, ...) when input asks. Draw
   `view().items` (cache them; they change only after a throw), `out.aim`, `out.camera`
   and `out.dial`. When this browser plays the side, send `aimState()` to the room a few
   times a second; the others call `showAim(state)` when it arrives and keep calling
   `frame({ dt })` for their camera.
2. **The release**: `out.action` is set. Send it to the room, then play the recording.
3. **Playback**: `showAt(t)` once a frame with `t += dt * out.speed` (the returned
   `speed`: 1, slowing to the recording's `slow.rate` around the hit), until `done`.
   Draw `items`, `camera`, and the `burst` named ("clean", "king", ...). Skipping is
   `showAt(recording.duration)`.
4. **Then** `view()` and `need()` once, and back to 1, or to the raise or punishment
   screen, or the end.

A computer side runs through `frame({ dt })` as well: its aim shows for `cpuThink`, its
arm plays on the dial, and on release the browser with `cpu: true` gets the `action`.
Other browsers see the same think and arm and then hold at the release until the action
arrives.

Calls are cheap: `frame` is well under a millisecond; the release (the whole throw is
simulated to rest) is a few milliseconds natively.

### Example: a practice throw

```js
const engine = await Engine.create({ sources, wasmUrl });
let view = engine.newPractice({ surface: "grass" });
// each frame, while aiming:
const out = engine.frame({ dt, arm: pointerOnDial ? armDegrees : null });
draw(view.items, out.camera, out.aim, out.dial);
if (out.event === "release") {
  const rec = out.recording;
  let t = 0;
  // each frame, while playing back:
  const p = engine.showAt(t);
  draw(p.items, p.camera, null, p.dial, p.burst);
  t += dt * p.speed;
  // when p.done:
  view = engine.view(); // the flag, the verdicts, the circle on the next kubb
}
```

### Example: a match between two browsers

```js
// Browser 1 (hosts, plays A, throws for the computer)
a.newMatch({ seed: 42, cpu: "B", teams, start, raising: "hand" });
a.setControl({ sides: ["A"], cpu: true });
room.send({ type: "start", snapshot: a.snapshot() });

// Browser 2 (joins, a spectator here)
b.restore(msg.snapshot);
b.setControl({ sides: [], cpu: false });

// Browser 1, a frame of its own throw or the computer's:
const out = a.frame({ dt, arm });
if (out.action)
  room.send({ type: "action", action: out.action, hash: a.hash().hash });

// Browser 2, on that message:
const r = b.apply(msg.action); // the same recording, byte for byte
if (b.hash().hash !== msg.hash) resync(); // never happens unless a message was lost
play(r.recording);
```

Raising and punishment by hand work the same: the side's own browser sends `{ type:
"raise", choice }` or `{ type: "punish", x, y }`, everyone applies it. A late joiner
restores from any browser's current `snapshot()` and applies what follows; the tests
prove it stays in step.

## Determinism

Every browser runs the same wasm and the same Lua, so the same action on the same state
gives the same floats everywhere. What the session adds:

- **The action path is the remote path.** The actor's own throw is turned into JSON and
  back before it is applied (`json.decode(json.encode(action))` in `Session:frame`), so
  the actor and every other browser run exactly the same numbers. JSON numbers are read
  back with their kind: `F` makes floats, `I` integers (JavaScript writes 3.0 as 3).
- **No sequential random stream.** The Playdate's match keeps random generators that
  advance as the game goes; the web's every random draw is seeded from the match seed
  and a counter, so restoring needs no generator state:
  `mix(seed, purpose, n) = ((seed * 0x9E3779B1) ~ (purpose * 0x85EBCA6B) ~ (n *
0xC2B2AE35)) & 0x7fffffff`, fed to `core/autothrow.rng`. Purposes: 1 the computer's
  choice (n = throws so far), 2 the wind's turn (n = turn), 3 the gusts (n = throws).
  The computer chooses with `autothrow.choose(setup, rng, cpuScatter)`, with no level,
  as the Playdate's match does.
- **JSON is deterministic.** Sorted keys, integers as integers, floats as the shortest
  text that reads back to the same double (with `.0` when integral), so equal states
  give equal text and equal hashes.
- **The snapshot is the state before the throw is set up.** It holds `{ v, opts, save
(core/save.pack of the match), throws, finish, resignPending, side, lastThrower, mem
(the aim memory the set-up reads), settle }`; `restore` unpacks it and runs the same
  set-up (`advance`) again, so the restored throw is the very throw the others have.
  The aim memory is normalised (floats, booleans) as it is captured, so the acting
  browser and a restored one hold identical values. Cards are not in it; they are
  recomputed.

Native Lua and wasmoon are not mixed in one match: the desktop libm may round sin and
cos differently from the wasm's (docs/DETERMINISM.md). The tests check each on its own.

Measured (cpu against cpu, 228 throws, 28 turns): snapshots average 8.4 KB, at most
13.2 KB. A baton throw's recording is about 12 KB of JSON (142 frames, 2 moving bodies);
a big knock is larger, since every moving body has 7 numbers a frame.

## The recording

What a throw did, for the renderer and for a replay:

```
{
  frameDt, frames, duration, poseScale, seq,
  projectile { id, kind, how },          // how: "baton" | "drill" | "lob"
  items   [{ id, kind, team, x, y, z, qw, qx, qy, qz, toppled }],   // the pitch at the release
  bodies  [{ id, kind, team, start, frames, poses, touchT, toppleT, thrown }],
  launch  { x, y, speed, loft, swivel, tilt, tumble, legal },
  landing { x, y, T },
  result  { flag, legal, down, toppled [ids], hit, distance, landX, landY,
            restCm, restText, restX, restY,
            verdicts { power, release, steady, side?, powerV, releaseV, sideV? }, back, stop,
            ruling { text, short, code, n, parts [{ code, n }], winner } },  // matches
  timeline {
    firstContact { t, x, y, z, with }, firstHit { t, x, y, z, with },
    touches [{ id, kind, t }],
    bursts  [{ kind, id, start, anchor { x, y, z }, sure, takenBack, second? }],
    slow    { hit, from, full, to, rate },
  },
  marker { x, y, r }                       // a drill's circle
}
```

`bodies` holds every body that moved, from its first moving frame. `poses` is a flat
array of integers, 7 a frame (`x y z qw qx qy qz` times `poseScale`, 1e5): pose j is
frame `start + j`, at time `(start + j) * frameDt`. Before `start` a body is where
`items` has it; after its last pose it stays there. `showAt` does this interpolation and
the cameras for you; the raw track is for a renderer that wants it. `slow` is the
playback speed curve: full speed until `from`, `rate` from `hit` to `full`, back to full
speed by `to`. `bursts` are known in full at the release (see below), so `sure` is true
and `takenBack` false on the web; the fields stay so the format matches render/burst.

Since 0.7.2 a match's `ruling` carries codes beside its words, so a reader need not parse
the English: `parts` one `{ code, n? }` per part of the line, `code` and `n` the first
part's, `winner` the side that won when the throw ended the match. A baton's codes:
`miss`, `kingMiss`, `field` (n kubbs), `base` (n), `helicopter`, `ownHalf`, `baseEarly`,
`pushedOut`, `kingWin`, `kingEarly`, `resigned`. A kubb's: `inForNow`, `outForNow`,
`ownHalfOut`, then at the round's last kubb `in` (n thrown), `rethrow` (n), `punish`
(n), `lowered`, `rescue` (n), `ownHalf`, or `kingKubb` (the king toppled). The words are
as they were.

Since 0.4.1, `timeline.contacts` lists wood-on-wood strikes in physics time
(seconds from release). Each `{t, a, b, idA, idB, strength}` gives both body
kinds and IDs. Keep the first positive normal impulse per unordered pair per
throw. Of its points in that same solver step use the largest peak impulse,
divided by 2 N·s and capped at 1. Rolling or later collisions of that same
pair stay quiet. Another pair has its own strike. `timeline.batonLanding` is
the thrown baton's first positive ground impulse, even if it struck wood first.
It gives `{t, strength, surface}` using the same curve and first-step peak.
Kubb throws have no baton landing. These fields and dial crossings are
presentation only. Old recordings may omit them. Snapshots and actions are
unchanged.

## Tunables

A host changes the game only through a tune: `tune/<name>.lua`, each value with its
reason in a comment, chosen once by `useTune` (see "Starting"), whose `tune.apply()` puts
its values into the core's tables. The pointer tune (`tune/pointer.lua`, the web's) is:

- **core/swing**: `swingStartDps` 300 (core 200: a pointer let down by hand drifts back
  at 300 to 400 deg/s), `speedWindow` 3 frames (core 2: at 60 fps two frames are 33 ms and
  one empty coalesced pointer frame would read as a stop), `releaseStopDps` 150 (kept),
  `fullFlickDps` 1200 (core 1000: a pointer flicks faster than a crank; 1500 at first, lowered after the browser sweeps in the web's docs/CLIENT.md), `pullFrames` 3
  (the same 50 ms as the core's 2 device frames), `roughFull` 4.0 (core 3.0: coalesced
  events make an honest drag look rough), `maxSamples` 600 (10 s at 60 fps).
- **core/autothrow**: its `flickDps` and `softDps` are remapped linearly from the core's
  `swingStartDps..fullFlickDps` onto the web's, so each computer flick gives the same
  flick fraction and the computer throws exactly as on the Playdate.
- **The dial** (`tune.dial`): `pressArmDeg` 30 (a press within 30 degrees behind 6 counts
  as starting at the bottom; a crank has to cross 6, a finger lands anywhere),
  `upFeedS` 0.25 and `upFeedDt` 1/60 (lifting the pointer while swinging forward feeds
  stopped frames until the core's stop test releases).
- **The throw** (`tune.throw`): `frameDt` 1/60 (a recorded pose for every displayed
  frame), `slewDt` 1/60 (the impact camera's slew is integrated in fixed steps so it is a
  function of shown time), `burstLift` 0.12, `cpuThink` 0.9 and `cpuScatter` 1.0 (the
  Playdate's), `poseDecimals` 5.
- `throw.tune` in `session/throw.lua` copies scenes/throw.lua's own tune (walk speed,
  pitch half-width, snap radius, the arc's points, the impact camera's swing) unchanged.

Physics is the core's default, unchanged. Measuring it on the web (frame time per throw
on a phone) is optional work, not done here; the native drill throw takes about 2 ms.

## Differences from the Playdate

- **The whole throw is known at the release.** The Playdate simulates the flight while
  it plays it, paced by the device; the web runs it to rest in the release call and
  plays the recording back in real time. So bursts are decided with the end known: a
  burst is shown only for a piece that ends toppled (never shown and then taken back),
  and a later king fall is a second burst.
- **Real-time playback.** `showAt(t)` is a pure function of shown time: the impact
  camera's slew toward the hit is integrated in fixed `slewDt` steps from the start, not
  frame by frame, so every browser shows the same picture at the same `t`, and seeking
  works.
- **Absolute pointer aim.** The dial takes the pointer's angle each frame instead of the
  crank's change; a press inside the dead zone arms at once (`pressArmDeg`); lifting the
  pointer while swinging forward releases; lifting it while winding lets the arm down.
  The circle and the stance can be placed directly (`setTarget`, `setStance`) as well as
  moved by keys.
- **Seeded draws instead of running generators** (see "Determinism").
- **Actions.** Every change to a match is an action any browser can apply; the Playdate
  has one player at one device.
- **Cards don't block.** The handoff, pass and settle cards are in `need.card` for the
  screen to show; no call waits on them.
- **The computer's think and swing** play the same, but a browser that does not throw
  for the computer holds at the release until the action arrives.

Not carried over: the Playdate's device pacing, frame telemetry and time budget; render
bursts' provisional states; the readout and trace overlays; the sheet viewer; saving to
the datastore and the persisted history (the web keeps its own); the how-to; the raise
screen's crank-tip camera and look-around (the web gets the poses and draws its own);
the sequential random generators.

## Tests

- `make test-session`: `tests/lua/session/` under desktop Lua 5.4, in a Lua state of
  its own (it loads the pointer tune, which changes the core's tables): the host's calls,
  aim and dial, practice throws and the drill, matches, raising and punishment, snapshot
  and restore, resigning, a change of thrower, replays, the wide view, and
  (`test_check.lua`) a server's checks: the computer's throws made again, a person's
  dial and touch throws held to `checkThrow` and the forged cases refused, a renamed
  start, and a replay's document against a real room's.
- `make test-wasm`: `tests/node/session.test.mjs` under wasmoon, loaded from the bundle:
  the host's calls, a practice throw, the multiplayer proof (one Lua state plays a whole
  match with the computer on one side and scripted dial swings on the other, a second
  only applies its actions, a third restores mid-match; after every action the
  recordings are identical and the hashes equal) and a replay.
- `make golden-check`: the golden hashes, the gate for hash-neutral changes
  (docs/DETERMINISM.md).

For private throw reports, `reportThrow` returns the last action sequence, result and
settled piece poses in the thrower’s frame. For practice it also returns
`practiceBefore`, opaque engine JSON for the pitch immediately before that throw.
Pass it to `restorePractice { checkpoint }` and then `apply` the recorded throw
action to reproduce its contacts even when the full practice history is unavailable.
