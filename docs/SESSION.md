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
| `session/names.lua`   | `tw.web.names`: generated names, `kubbCall("names.<name>")` (below, "Names"; docs/NAMES.md).                       |
| `session/namecheck.lua` | `tw.web.namecheck`: the names in a match from outside, `names.check` and the strict doors (below, "Names"; since 0.13.4). |
| `session/touch.lua`   | `tw.web.touch`: a finger on the pendulum, projected onto the crank (below, "Touch pendulum").                      |
| `session/neighbours.lua` | `tw.web.neighbours`: the Tournament's neighbouring pitches, `kubbCall("neighbours.<name>")` (below, "Neighbours"; since 0.15.1). |
| `session/record.lua`  | `tw.web.record`: record mode, a real game scored throw by throw, `kubbCall("record.<name>")` (docs/RECORD.md; since 1.1.0). |
| `session/json.lua`    | `tw.web.json`: deterministic JSON (sorted keys, shortest round-trip floats, integers kept apart from floats).      |
| `pitch/`              | The pitch's calls, `kubbCall("pitch.<name>")` (`room.` before 0.13): a shared pitch's document, who acts (docs/PITCH.md). |
| `tune/pointer.lua`    | `tw.tune.pointer`: a pointer's values for the core's tune tables, and the session's dial and throw tables.         |
| `tune/touch.lua`      | `tw.tune.touch`: the pointer's tables, and the touch pendulum's projection constants.                              |
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

The label and the location are not in the snapshot, the pitch document (`replayDocument`)
or any recording, so neither ever changes a hash, and two hosts with different
locations play one match in step. The tune can: it sets how
the computer's flick maps onto the swing, so peers in one online match load the same
tune (the golden hashes are recorded with `pointer`).

## The API

Every method below is `kubbCall(name, JSON.stringify(args))` behind a wrapper. Results
are plain objects. The pitch's calls (`pitch.<name>`, `room.<name>` before 0.13) are in docs/PITCH.md, record mode's (`record.<name>`, since 1.1.0) in docs/RECORD.md. Angles are degrees unless named otherwise; times are seconds.

### Sessions

| Call                         | Returns           | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `newPractice(opts)`          | view              | `{ scene, surface: "grass" \| "sand" \| "snow" \| "grid", level, set, drill, throw }`. The practice pitch (scenes/drills.lua's free throw); `drill: true` throws kubbs at the circle. Since 0.14 a `scene` named decides the surface and the set as for a match (below), and `setSurface` then takes only a surface the scene allows.                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `newMatch(opts)`             | view              | `{ seed, teams, cpu, first, opening, raising, wind, surface, set, computer, rules, scene, start, maxTurns, modeName }`. `rules: "kid"` (since 0.15): the Kid rules whatever the computer (pass and play with two children); absent, a match has them only with the Kid computer. `teams: { A: { name, players: [{ name, level, key }] }, B: ... }`, 1 to 6 players a side (strings work as names); since 0.17 a player may be a computer player, `{ cpu: true, level, name?, key? }` ("Computer players", below). `cpu`: `"A"`, `"B"`, `"both"` or a list: every player of that side is the computer, at the match's `computer` level, as before 0.17. `first: "A" \| "B"`. `opening: "2-4-6" \| "six"`. `raising: "hand" \| "auto"`. `wind: "off"` or a core/wind level (`"light"`, `"strong"`, ...). `start: { year, month, day, hour, min }`: the match clock's start (the game file's date; pass the host's local time). `maxTurns`: the side to throw at that turn resigns (tests, quick games). `computer` (since 0.9): the computer's level, `"kid"` (since 0.15), `"beginner"`, `"club"` or `"pro"`, given to every player on a computer side whose entry names no level of its own; `"kid"` with a computer side makes the match a Kid match ("Kid matches", below); absent, unknown or `"club"` (the default) the option is not kept, so the start is the one a match always had, and the computer throws at club. A person's level is their entry's own. `scene` (since 0.9): the look to draw the pitch in, an id of lowercase letters, digits and hyphens, 1 to 24 characters (`pitch/lobby.isScene`); the engine keeps it in the start like `set` and never reads it otherwise. Absent, invalid or `"day"` (the default) it is not kept. The view's `scene` is the one to draw (`"day"` when none); a client draws a scene it does not know as `"day"`. Practice (`new` with `mode: "practice"`) takes `scene` too. **Since 0.14 a scene decides** ("Scenes", below): with `scene` named, `new` takes the surface given only if the scene allows it (else the scene's default) and the set likewise, and an id the catalogue does not have is Park (`"day"`, not kept). With no `scene`, the options stand as given, as before 0.14. Restore, replay, checkStart and renameStart make a match from its options as they were recorded, whatever its scene. |
| `restore(snapshotText)`      | view              | A match from a snapshot. Since 0.13.4 also `{ snap, names: "check" }`, which refuses a snapshot whose names the engine does not allow ("Names", below). Restored while raising, placing a punishment kubb or after the end, the view shows the match's pitch as it stands (pieces and debris, a king that ended the match lying down) in the last throw's frame, as live, until the next throw is set up. The restored session acts for every side and the computer until `setControl` says otherwise.                                                                                                                                                                                                                                   |
| `snapshot()`                 | text              | The whole match as JSON text. Opaque: store and send it as it is, byte for byte. Matches only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `hash()`                     | `{ hash, bytes }` | FNV-1a 32 of the snapshot text (8 hex digits) and its length. Equal hashes mean equal matches.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `scenes()`                   | catalogue         | Since 0.14, no session needed: `{ default, scenes: [{ id, name, surfaces, surface, sets, set, dark, ring, mono, choices }], surfaces: [{ id, name }], sets: [{ id, name }] }` ("Scenes", below).                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `setImpacts({ on })`         | `{ on }`          | Since 0.14: while on, each recording's timeline carries `impacts` ("Ground impacts", below). Belongs to the Lua state, like the wide view; off by default, and off nothing is gathered.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `setControl({ sides, cpu })` | need              | Which sides this browser plays (`sides: ["A"]`, `[]` for a spectator) and whether it throws for the computer (`cpu`, default true). One browser on a pitch has `cpu: true`.                                                                                                                                                                                                                                                                                                                                                                                                                                |

### Reading

| Call          | Returns                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `view()`      | `{ need, items, minimap, aim, camera, dial, surface, set, scene }`: everything the screen needs when nothing plays back (`scene`: the one to draw, `"day"` when none). |
| `frameView()` | The same view, in the thrower's view frame even while the wide view is on: what a report records (the web's `src/net/report.js`), so its replay compares like with like. |
| `need()`      | What happens next (below).                                                                                                                                               |
| `aim()`       | `{ aim, camera }`.                                                                                                                                                       |
| `reportThrow()` | Last throw’s result, sequence and final piece poses in its thrower frame, including its projectile. Empty before a throw or after a restore. |
| `recording()` | The last throw's recording (below), or `{}`.                                                                                                                             |

**need** is one of:

- `{ kind: "throw", side, setup, cpu, local, candidates?, wind, ... }`. `setup` is the
  throw (`kind`, `projectile` "baton" or "kubb", `n` of `of`, `label`, `kingShot`,
  `rethrow`, `lineY`, `forwardY`, `advY`, `targets`, `thrower { id, name, level, key, cpu?, throw? }`;
  for a kubb, `n` of `of` is its place in its round (since 0.17.0): the kubbs thrown in
  first ("kubb 2 of 2"), or with `rethrow` true the kubbs rethrown ("rethrow 1 of 1": two
  in and one out, the out one again; before, "kubb 3 of 3"); the label and the aim's
  `rail` (`n`, `of`, `rethrow`) say the same. A kubb out twice is not thrown a third time;
  and in a Kid match `kid: true` and `kidY`, the Kid line in the view frame;
  `key` is the lineup's key for that player, on a shared pitch the pitch member it
  belongs to).
  `setup.settled` (0.16.0): what the engine raised and placed itself just before this
  throw (the computer's raises, a match with Raising: Automatic, a punishment kubb it
  placed), on the first throw need after it and nil otherwise: `{ raised, punished, list
  }`, `list` in the order done, each `{ kind: "raise", id, side, which, lying, standing,
  displaced, crowded }` or `{ kind: "punish", id, side, pose }`. `side` is the side that
  raised (the defender; word it from that), `which` the end as a raise action names it,
  and every pose `{ x, y, standing, angle }` in that side's view frame: the frame and
  shape a person's raise by hand is given in (`raiseInfo`), so one path draws both. In
  the wide view every pose is turned to the world frame (Team A's) whoever raised, and
  each entry says `frame: "world"`. A session restored from a snapshot after the raise
  hands out none (the kubbs already stand raised in its items); nothing of it is in a
  snapshot, an action or a hash. A raise the engine makes is shown from `setup.settled`:
  never compare pieces before and after, or convert frames. Since 1.0 each entry also has
  `seat` `{ qw, qx, qy, qz }`, the orientation the kubb stands at in the next throw's world
  (its seat in the turf, up to 3 degrees off plumb; absent when it stands plumb, as on the
  grid), in the same frame as its poses: end a watched raise there and the kubb does not
  step when the throw begins. Since 0.17.0 each entry also
  carries its surroundings as they stood while it was done, what a raise or punishment
  kubb by hand is shown with: `others` `[{ id, pose }]` (every other piece on the pitch,
  as `raiseInfo`'s `others`; for a punishment kubb only those near its half, as
  `punishInfo`'s) and `king` (its pose), in the same raiser's view frame (the world frame,
  turned, in the wide view). They are per entry: a kubb raised earlier stands among the
  next one's `others`. So a client draws the engine's raise with the code and the picture
  it draws a raise by hand with, and the next thrower's `items` (in the other team's
  frame) are not needed for it.
  `cpu`: the computer throws (a side the computer plays, or since 0.17 a computer player
  in a team; `thrower.cpu` is then true too, and `thrower.level` its level). `local`: this
  browser acts for it. `candidates`: the team's players when the team has more than one
  person (for the `thrower` action; a computer player is listed with `cpu: true`, `ok:
  false`, `why: "computer"`). Practice:
  `{ kind: "throw", practice: true, drill, surface, level, set }`.
- `{ kind: "raise", side, kubb, pose, mode, choices, ends, default, others, king, n, of,
team, local }`: a kubb to raise by hand. `choices[i] = { which, pose, displaced,
crowded }`; `ends[i] = { which, pose, inBounds, obstructedBy, ok, why }` (`why`: "THAT
  END IS OUT" or "THAT END IS BLOCKED"); `default` is the index the engine would pick for
  this person: its best advice, `par` (since 0.12.0; it was `apart`), so a client offers it
  first.
- `{ kind: "punish", side, kubb, cursor {x, y}, bounds {xMin, xMax, yMin, yMax}, keepOut
[{ kind, id, x, y, r }], others, n, of, team, local }`: a punishment kubb to place.
- `{ kind: "over", winner, how, file { text, name }, text, short }`: the match is over;
  `file` is the game file (match.file, `version` the client label, see "Starting").
  `short` is `text` as a few capital words (`session.short`): `"KING DOWN"`,
  `"KING TOO EARLY: GAME OVER"`, and `"RESIGNED"` for a resignation, whose `text`
  begins with the team's name (`"Riverside resigned: Oak wins"`; before 0.7.4 its
  `short` was the first 12 characters, `"RIVERSIDE RE"`). Words no rule knows are cut
  at a word, never inside one. In a Kid match (0.15.0) a king stood back up reads
  `"KING BACK UP"` and a kubb the engine placed `"OUT TWICE: PLACED"`, never the
  standard game's ending or punishment. Output only: not in the snapshot or any hash.

Every match need also carries `card` (informational: `{ kind: "settle" | "handoff" |
"pass", ... }`, the Playdate's cards; nothing waits on them), `turn`, `throws`, `teams`,
`standing`, `last { text, short }` (the last ruling) and `resignPending`, and in a Kid
match `kid: true` (since 0.15), so a client can say so on screen.

**items** are the pieces as the renderer draws them: `{ id, kind, team, x, y, z, qw, qx,
qy, qz, toppled }`, kinds `kubb`, `king`, `baton`, `stake`. **camera** is core/camera's
table: position `px py pz`, unit `f*` forward, `r*` right and `u*` up, `lx ly lz` the
point looked at, focal length `f` with principal point `cx cy` for the Playdate's 400 x
240 screen (scale `f` by the canvas width over 400). **aim** is `{ marker { x, y, r, on,
set, kind, shown }, thrower { x, y, swivel, set }, plan { release, arcSet, tilt, spin,
level, speed, loft, swivel, dist, back, powerLo, powerHi, releaseLo, releaseHi }, arc
[{x, y, z}]?, projectile, drill, lineY, forwardY, advY, advText, kidY?, halfWidth, backMax,
rail { name, kind, n, of, r1, r2 }, flag, restText, verdicts?, wind?, mix, watching }`.
**dial** is hud.clock's state: `{ phase, arm, crank, back, powerLo, powerHi, releaseLo,
releaseHi, deadDeg, overDeg, lastBack, lastStop, prompt }`. **minimap** is `{ pieces,
aim { x0, y0, x1, y1 }, advY, lineY, kidY?, wind }`.

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
release that this browser acts for, `action` is the throw to send to the pitch,
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
| `setLevel(level)`              | The thrower's level (practice: the default level). Kept and stored; from 0.13 it changes nothing in a person's throw (below). |

Practice also has `setDrill(on)`, `reset()` and `setSurface(name)`, which return a view.

**Levels and the person's meter** (0.13; docs/notes/throw.md "The person's meter"). A
level (`kid`, `beginner`, `club`, `pro`) is the computer's standard only: the `computer` option, a
computer side's players. Every person throws on one meter, whatever level `newPractice`,
a player's entry, a thrower or `setLevel` names; those fields are still taken, kept and
returned (the view's `plan.level`, `need.level`, `thrower.level`), so older callers do not
break, and a person's level picker can go. The bars carry the difficulty by distance: wide
for a short throw, narrow for a long one. The aim view's `plan.powerLo..powerHi` and
`releaseLo..releaseHi` (and the dial's) are the bars for the throw as it is aimed now and
change whenever the circle or the stance moves, so a surface redraws its bands from every
view, as it already does; there is no new field. A Kid match's people throw on the Kid meter
(0.15, docs/notes/throw.md "The Kid meter"): the same fields, much wider bars.

**A person's throw level** (since 1.3.0; docs/notes/throw.md "The honest meter (1.3.0)").
A person's player entry in `newMatch`'s teams takes `throw`: `"easy"`, `"standard"` or
`"hard"`, the meter that person throws on (`plan.meters`); absent is `"standard"`. The
levels differ only in their bars (wider on easy, narrower on hard) and in how much an error
inside a bar counts, never in randomness: since 1.3.0 a person's throw has no nerves, so
the same swing gives the same throw. `"standard"` is not kept, so a match without the field
(or with `"standard"`) has the start, snapshot and hashes it would have had; `"easy"` and
`"hard"` are kept on the entry in the start (`opts.teams.<side>.players[i].throw`) and in
the match's lineup, so a restore and a replay throw on the same meter. Any other value is
refused: `newMatch` fails with an error that says so. A computer entry carries none.
`need.setup.thrower.throw` is the thrower's level when not standard, and the aim view's
bars are that meter's, switching when the `thrower` action hands the throw to a person on
another level. `newPractice` takes `throw` too (an unknown value is standard) and its throw
checkpoint keeps it. A Kid match keeps the Kid meter for every person, whatever their level.
On a shared pitch each member says their own level as `me.throw` (docs/PITCH.md).

**Computer players** (0.17.0). Jamie (2026-11-22): "In online play we should be able to
add computer players to the match, with a specified level. I may have three friends and we
want to play a team of three computers (two at club and one at pro). Or we want to play 2
v 2 where Tyler and I each have a pro computer partner." A team may hold people,
computers or both, up to six together, each computer at its own level:

```
teams: {
  A: { name: "Birch Batons", players: [{ name: "Mighty Maple", key: "m1" },
                                       { cpu: true, level: "pro" }] },
  B: { players: [{ cpu: true, level: "club" }, { cpu: true, level: "club" },
                 { cpu: true, level: "pro", name: "Proud Plum", key: "cpu:3" }] },
}
```

- **The entry.** `cpu: true` (exactly `true`) makes the player a computer. `level`:
  `"beginner"`, `"club"` or `"pro"`; absent, the match's `computer` level (club when
  none). `"kid"`, or any other value, is refused: `newMatch` fails with an error that says
  so. Kid is a match's rules, chosen as before by `computer: "kid"`: with it chosen, a
  computer player makes the match a Kid match just as a computer side does, and in a Kid
  match every computer player is the Kid computer (its level becomes `"kid"`). `name`: a
  generated name, or absent; an absent name is made by core/namegen from the match's seed
  and the seat (Team A's players 1 to 6, Team B's 7 to 12; `mix(seed, 4, seat)`), never
  one another player of the match has, so every client makes the same. `key`: as for a
  person (on a pitch, the seat id). A team of one computer player and no team name is
  named for the player. Only computer entries carry `cpu`, so a match without one has the
  start, snapshot and hashes it always had; the old `cpu` option is unchanged and means
  what it meant.
- **Who throws.** The team's throwing order (core/order: blocks of batons dealt round the
  team, one inkaster a turn) decides every throw, so a computer partner takes its share of
  the batons. The kubbs: in a team with a computer player the inkaster goes round the team
  turn by turn (`rotateInk`), so the partner takes its share of them too. A team of people
  keeps the turn's first baton thrower, as before; with one, two, three or six players and
  six batons the deal opens every turn with the same player, who so throws every turn's
  kubbs, and a team of people can hand them on with the `thrower` action, which a
  computer cannot take. A person's throw waits for that person; a computer player's is
  chosen by core/autothrow at that player's own level and run through `frame` as the
  computer side's always was (`need.cpu`, its think and arm on the dial, the action from
  the client with `control.cpu`). `checkThrow`, a replay's `checkCpu` and `cpuAction`
  treat it as the computer's throw.
- **What the rules give the team.** A team with a person on it decides by its people: it
  raises the kubbs thrown into its half and places a punishment kubb by hand (or by the
  match's Raising option, `auto`: the engine's advice, par), and on a shared pitch any of
  its connected people may (docs/PITCH.md "Who acts"). A team of computers decides itself,
  at its strongest player's level (pro above club above beginner: `match.strongestLevel`,
  raising by `cpu.raising` of that level; punishment kubbs placed by the engine, as for a
  computer side). The `thrower` action is between people only: it refuses
  (`why: "computer"`) while a computer's throw is set up or when it names a computer, so a
  person never takes a computer partner's throw or hands one to it, and a swap between two
  people leaves the computer's batons where the order put them.
- **What a client shows.** `need.setup.thrower` has `cpu: true` and `level` for a computer
  thrower ("Bold Birch · computer · Pro"); the hand-off card (`card.handoff`) has
  `throwerCpu` and `throwerLevel` for a computer opening the turn, `order[i].cpu` and
  `.level`, and `inkasterCpu`. The hand-off card shows whenever the team on turn has a
  person, whoever throws first; the pass card only before a person's throw.
- **The game file.** `[Throw Levels]` names every computer player with its level, in team
  order, Team A's first; people are not listed, except (since 1.3.0) a person on `easy` or
  `hard`, as `<id> easy` (never in a Kid match); `[Mode]` is `"Vs Computer"` when any
  computer plays, `"Computer vs Computer"` when both teams are computers only, `"Pass and
  Play"` otherwise.
- **One device.** The same lineup plays with no pitch: a person with a computer partner
  against two computers is `newMatch` with those teams and no `cpu`; `setControl` is not
  needed (one client acts for every side and the computer).
- **A host change mid-throw.** A client that held at a computer's release (`control.cpu`
  false) and is given `cpu: true` by `setControl` releases on its next frame, the very
  throw the old host would have made.

**Kid matches** (0.15.0, docs/notes/kid-mode.md). The Kid computer (`computer: "kid"` with a
computer side) or `rules: "kid"` makes the match a Kid match: `opts.rules = "kid"` in the
snapshot (absent in every other match, whose snapshot is as before), the Kid rules for both
sides (three base kubbs a side; every kubb and every baton at a kubb thrown from the Kid
line, 2 m in front of the baseline, or the advantage line beyond it; the king shot from the
baseline; an early king stood back up; no punishment kubbs, so no `punish` need; a
helicopter counts) and the Kid meter for every person. What a client does with it:
`need.kid` to say it is a Kid match; `setup.kidY` (also `aim.kidY` and `minimap.kidY`) to
draw the Kid line, which in a Kid match is where the thrower stands by default (`forwardY`,
the stance's limit, is the Kid line or the advantage line beyond it, for kubbs too);
`aim.advText` reads `KID LINE  2.0 M` while the Kid line is the one thrown from. A kubb's
setup has `forwardY` too: the baseline in a standard match, as before.

**The controls** (since 0.9; Jamie, 2026-11-20: "more analog allow the slider to select
any value in a range"). `aim.controls` gives a slider its numbers from the engine:
`arc` always, `tilt` for a baton, `spin` for a kubb, each `{ min, max, default, value,
tick, step, unit, scope }` (`arc` also `set`, `spin` also `radPerTap` and `baseRad`).
`tick` is the fine move a held key slides by, one a frame (`plan.tune.arcTickDeg`,
`tiltTickDeg`, `spinTick`); `step` what a press jumps by (the step calls). `scope` is
`"throw"` or `"turn"` (below).

The drive (0.16). A baton's `arc.min` is the throw's floor, not a constant: the lowest
release whose line the hand can make and whose speed the swing can give a person steadily
(`plan.tune.driveBackMaxDeg`, a backswing of 140), worked out by `replan` whenever the
circle or the stance moves (`plan.solve` with release 0). It is 0 at a kubb a metre away, 5
at 2 m, about 12 at 4 m and 15 (the knee) from about 5 m, where nothing under the knee can
be made. `arc.knee` (15) is where the drive starts: under it the planned loft falls on the
drive's steeper line and the planned turn eases to none by a release of 7.5 (a release
loft of -4, before a short throw's flattening), so a slider can mark it. A
value set under the floor is raised to it (`setArc` keeps what ARC shows). When the
circle or the stance moves and the floor rises past the kept value, the throw is planned
(and shown) at the floor, and when the floor falls again it comes back to the kept value,
the one the player last saw. A step (`stepArc`) goes from the release as it is planned,
never from a kept value under the floor, and never under the floor, so every step and
every reversal at the floor moves the throw at once; `arc.value` and `aim.plan.release`
are always the planned release (Codex on #47). Tilt and spin have fixed ranges and no
floor: a step at an end and back moves them at once as before.
`aim.plan.speed`, `back` and the power band move out with the drive's speed as with any
other plan, and `aim.arc` is the planned flight, down as well as up.

| Control | Range | Default | Tick | Step | Physically |
| ------- | ----- | ------- | ---- | ---- | ---------- |
| `arc` | a baton's: its floor for the throw in hand (`min`, 0.16) to 165 clock degrees (half past 12); a kubb's: 15 (half past 5) to 165 | the plan's own (`plan.arcFor`): a baton's goes by the distance from the stance to the aim circle, never the target's kind: from 0.16 the lowered line (`plan.tune.arcLine`: 15 at 1 m and under, 6 at 1.5 m, 13.6 at 4 m, 37.5 at 6 m, 60 at 8 m, and from 8 m out as before; until 0.16 15 at 2 m or closer rising 7.5 a metre to 60 at 8 m); a drilled kubb 135 | 5 | 15 | the release target; the loft is `plan.loftFor` of it: from the knee (`knee`, 15) up the line through 5 and 3 o'clock, 7 to 57 degrees; under it the drive, down to -15 at 0 (docs/notes/throw.md "The drive") |
| `tilt` | -20 to 20 degrees | 0 | 1 | 5 | the baton's spin plane tipped, before the shake's tilt; over 30 with the shake is a helicopter |
| `spin` | -3 to 3 taps | 0 | 0.25 | 1 | 22 rad/s a tap about the kubb's long axis, + clockwise from behind (rolls right), on top of the wrist's 3 rad/s spiral, which goes the spin's way from 0.11: -69 to +69 rad/s. From 0.11 a spun kubb that lands dead rolls that way, about 5 cm for one tap, 16 for two and 33 for three on grass, and the aim allows for it (`drill.rollFor`) |

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
file in Planet Kubb Notation 2 as it stands (its position lines included), `shown` the
lines a screen shows: every line of `text` but the position lines under the turns (those
that start `@`, `~`, `^` or `*` and a half, `core/gamefile.isPosition`), in order.

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
  the pitch document with its full match (docs/PITCH.md "The full match"). `cpuChecked` and `throwsChecked` count what
  was checked.
- `replayDocument()` returns `{ document, h0, hashes }` once the replay is finished:
  the pitch document with its full match (docs/PITCH.md "The full match") with the teams joined, the options
  set, START with the first snapshot and every action committed with the snapshot and
  hash after it, `over` on the last; `hashes[i]` is the hash after action i. It refuses
  a replay not played to its end, one with a refused action, and a match of the
  computer against itself. Member ids are each player's `key`, else the side and number
  (`"A1"`); `match.engine` is this engine's major.minor.
- `checkThrow(action)` returns `{ ok, why, computer, levels, level, atLevel }`: could
  `action` be the next throw of the match as it stands now (`levels` the player levels
  that fit it: from 0.13 a person's throw is on one meter, so one that fits lists every
  level and `atLevel` is true).
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
  for the stance and target with every release and tilt (or spin) a player can choose
  (since 0.9 any value in range, the action's `plan` tried first), on the person's meter
  (from 0.13; every level before; since 1.3.0 the thrower's own `throw` meter); the loft pinned by the stop (since 0.8.0, a baton planned under 2 m with the
  plan's flatter share of it and the heave of a swing past the power target, as
  `plan.launch` gives them); the tilt pinning the shake and the pull; the
  swivel, speed and tumble within the nerves' largest draw (since 1.3.0 a person's meter has
  no nerves, so these are pinned to what the swing gives, the release's pull on a baton and
  a thrown kubb included, within rounding; and never under the floors
  the throw clamps to: a tumble under `tumbleMin`, a length draw under `lenMin`), `ZMAX` = sqrt(-2 ln 1e-12),
  about 7.43 sds (`plan.rng`'s normal floors u1 at 1e-12); the flick between
  `minFlickFrac` and 1 and matching the power verdict; a kubb's `scatter` the one the swing gives (from 0.13 `plan.scatterFor` of the shake and how far past a bar the swing went; 0.11 and 0.12: the level's `drillScatter`); a kubb's nose, spin and wobble
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

A drilled kubb's nose was a known gap in 0.9.0 (a drill released very early or at the
sky end passed with its `noseDown` changed). From 0.10.0 the nose goes by the loft the
kubb leaves at (`drill.noseFor`), which the check holds, so a forged nose is refused at
every release (`a drill released very early or at the sky end takes no forged noseDown`,
`tests/lua/session/test_check.lua`).

### Names

Generated player and team names (docs/NAMES.md), since 0.13.3:
`kubbCall("names.<name>", argsJson)`, dispatched like `pitch.<name>`. Like the pitch's
calls they need no `useTune`, `new` or match. Results are plain objects; an argument that
is wrong (a kind that is not `"player"` or `"team"`, a shape the kind does not have, a
slot out of range, a seed that is not a whole number) is `{"error": "names.<call>: ..."}`
as for every session call. A name that cannot be made is not an error: its `text` is
`null`.

**parts** is `{ shape, words: [word, ...] }`: the shape's id (`"adj"` for a player;
`"adj"`, `"the"` or `"wood"` for a team: `names.words().shapes`) and one word per slot, in
order. **slot** is 0-based, an index into `words`. A name is always kept and sent as its
text; parts are for a picker.

| Call            | Arguments                    | Returns                                                                                                                                                                                                                                                       |
| --------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `names.roll`    | `{ kind, seed, keep? }`      | `{ text, parts }`: a name drawn from `seed` (any whole number; the client's own random draw) through the engine's seeded stream (`plan.rng`), so the same seed gives the same name on every client. `keep`: the locked slots, `{ shape, words: [word \| null, ...] }`; a lock keeps the shape, and `{ shape }` alone picks the shape and draws every word. A kept word not in its slot's list (taken out for safety, or a typo) is drawn again. `text` and `parts` null when the kept words make no name. |
| `names.step`    | `{ kind, parts, slot, dir? }` | `{ text, parts, moved }`: the next word in `slot` (`dir` 1, the default, or -1) that makes a name with the other words, round the list: a picker's arrows, the crank. `moved` false, the parts as they came, when no other word fits. `parts` needs every word. |
| `names.choices` | `{ kind, parts, slot }`      | `{ words }`: every word `slot` can take with the other words as they are, in `step`'s order: what a wheel or a list offers. The other slots need their words.                                                                                                  |
| `names.make`    | `{ kind, parts }`            | `{ text, why }`: the text, or `text` null and `why`: `"word"` (missing, or not in its slot's list), `"long"`, `"never"` or `"repeat"` (a word that begins with the one before it).                                                                             |
| `names.valid`   | `{ kind, text }`             | `{ ok, parts, default }`: `ok` and `parts` when `text` is a generated name of `kind` (exact: one space, the words' capitals); `default` when it is one of the engine's own names for no name (`defaults` below). A boundary takes `ok` or `default`; a client asking whether its own kept name still stands reads `ok`. |
| `names.words`   | `{}`                         | `{ version, rules, max, lists, shapes, never, defaults, hash }`: everything a check outside Lua needs to give `valid`'s answer (below).                                                                                                                       |
| `names.all`     | `{ kind }`                   | `{ names }`: every name of the kind, sorted (about 110 KB for teams): to measure the widest name in a client's own font, once or at build time.                                                                                                                |

`names.words`:

- `lists`: `{ adjectives, woods, teams }`, each word once, letters only, capitalised.
- `shapes`: `{ player: [...], team: [...] }`, each `{ id, prefix, slots }`: `prefix` a
  literal first word (`"The"`) or null, `slots` the list each slot draws from.
- `max`: `{ player, team }`, the longest name in characters (16).
- `never`: whole names that are never names, though each word is fine.
- `defaults`: `"Computer"`, `"Team A"`, `"Team B"`, `"Player 1"` to `"Player 6"`: what the
  engine and the pitch write when there is no name (a computer side, a side with no name,
  a member with none). Not generated, never typed.
- `version`: `namewords.version`, up with any change to a list. `rules`: up with any
  change to how a name is checked beyond its words.
- `hash`: FNV-1a 32 (8 hex digits) of the canonical JSON of every other field (keys
  sorted at every level, no spaces: the engine's encoder, or `JSON.stringify` with sorted
  keys). Two ends that hold the same `hash` check names the same way.

A name is valid for a kind when it is a string of at most `max[kind]` characters, its
words split on single spaces (no empty word), it is not in `never`, no word begins with
the word before it (ignoring case), and it matches one of the kind's shapes: the
`prefix` when there is one, then one word from each slot's list. `tests/node/names.test.mjs`
holds that check in JavaScript, made from `names.words` alone, and proves it agrees with
`names.valid` on every name and on thousands of near misses.

A team's name on a side of one player is that player's name (the pitch's `matchOptions`
and `renameStart` do this), so a boundary checking a team takes a player name there too.

Worked examples (each line is `kubbCall(name, args)` and its result):

```
names.roll    {"kind":"player","seed":42}
           -> {"parts":{"shape":"adj","words":["Midsummer","Myrtle"]},"text":"Midsummer Myrtle"}
names.roll    {"kind":"team","seed":7,"keep":{"shape":"adj","words":[null,"Lumberjacks"]}}
           -> {"parts":{"shape":"adj","words":["Epic","Lumberjacks"]},"text":"Epic Lumberjacks"}
names.step    {"kind":"player","parts":{"shape":"adj","words":["Mighty","Maple"]},"slot":1}
           -> {"moved":true,"parts":{"shape":"adj","words":["Mighty","Myrtle"]},"text":"Mighty Myrtle"}
names.choices {"kind":"player","parts":{"shape":"adj","words":["Magnificent","Maple"]},"slot":1}
           -> {"words":["Ash","Elm","Fir","Oak","Pear","Pine","Plum","Teak"]}
names.make    {"kind":"player","parts":{"shape":"adj","words":["Salty","Walnut"]}}
           -> {"text":null,"why":"never"}
names.valid   {"kind":"team","text":"Birch Batons"}
           -> {"default":false,"ok":true,"parts":{"shape":"wood","words":["Birch","Batons"]}}
names.valid   {"kind":"player","text":"Computer"}
           -> {"default":true,"ok":false,"parts":null}
```

What a client does with them:

- **First run**: `names.roll` with a seed of its own, keep the `text`.
- **On opening**: `names.valid` on the kept text; when `ok` is false (a word taken out for
  safety), `names.roll` with the still-good words in `keep` (a kept word no longer in its
  list is drawn again), or with none.
- **The name row**: Shuffle is `names.roll` with a new seed and the locked words in
  `keep`; each word's arrows are `names.step`; a wheel or list offers `names.choices`.
  Changing a team's shape is `names.roll` with `keep: { shape }` (and any word that has a
  slot of the same list in the new shape). Show `text`; store `text`.
- **Layout**: measure every name from `names.all` in the client's own font once (a test or
  a build step) and size the row for the widest. The longest in characters is not the
  widest in a proportional font, so the engine gives the whole list, not one name.
- **Boundaries**: `names.valid` (or the JavaScript check from `names.words` where no Lua
  runs) for a single name that arrives from outside; `names.check` (below) for a whole
  match, replay or pitch document: docs/NAMES.md section 6.

#### A match from outside: `names.check` and the strict doors

Since 0.13.4. A snapshot holds each name twice (`opts.teams` and `save.game.teams`),
makes ids from them and writes them into rulings and the score sheet; `restore` builds
the match from `save`. A client should not have to know which of those reach the screen,
so it asks the engine:

| Call | Arguments | Returns |
| ---- | --------- | ------- |
| `names.check` | exactly one of `{ snap }` (a snapshot, its text or the decoded object), `{ replay }` (a replay or kept match: `setup` or `start`, and `snap`, `players`, `log` when it has them) or `{ document, members? }` (a pitch's document, docs/PITCH.md, and the pitch's members `[{ id, me }]`) | `{ what, allowed, names, ids, lines, refused, mismatches }` |

- `what`: `"snapshot"`, `"replay"` or `"document"`.
- `names`: every name, `{ text, from, kind, as?, ok, default }`. `from` is where it is, a
  path with JSON indices from 0 (`save.game.teams.A.players[0].name`; a replay's are
  under `setup.`, `start.`, `snap.`, `players.`; a document's under `teamNames.`,
  `match.`, `members[i].me.name`). `kind` is `"team"` or `"player"`; `ok` and `default`
  are `names.valid`'s. A team on a side of one player passes as that player's name too,
  and then `as` is `"player"`. A replay's setup is read as `newMatch` reads it, so a
  name it leaves out is reported as the default the match would show.
- `ids`: each player's id in `save.game.teams`, `{ text, from, name, ok }`: `ok` when it
  is the id the engine makes from the names (`notation.assignIds`). The score sheet
  writes ids.
- `lines`: the sentences a snapshot carries, `{ text, from, kind, ok }`: the ruling line
  (`save.text`: the engine's words, a team name only where the engine puts one), how it
  ended (`save.game.how`), the sheet's notes and the mode.
- `refused`: everything that does not pass, `{ text, from, kind, why }`: a name that is
  neither generated nor a default, an id not made from its name, a line not in the
  engine's words, and any other string that is not what the engine writes in that place
  (a side, a phase, a kubb id, a player id, a baton token, a level, a kubb set...),
  including a string where the engine writes none (a number turned to text, a field it
  never has, a map key). Every string in a snapshot is looked at, at every depth, so
  nothing a restored match shows (the rail, the teams, the thrower, the cards, the
  score sheet and its file name, the winner card, the ruling line) comes from a field
  the check skipped. A document's own fields other than `teamNames` and `match` are
  the client's and are not read.
- `mismatches`: `{ from, other, text, otherText }` where two copies disagree (a name in
  `save.game.teams` and `opts.teams`, the number of players, `save.mode` and the mode
  the options make). An honest snapshot never has one: it is a sign of forgery.
- `allowed`: nothing refused and nothing mismatched.
- `place` (and a mismatch's `otherPlace`), on every refusal and mismatch: a forged
  snapshot chooses its own keys, so `from` can carry submitted text. `place` is the same
  path with each component the engine does not itself name replaced by `?`. Show
  `place`, never `from` or `text`; the strict doors' errors use it too.

Something that is not a snapshot (or a replay, or a document) is not an error: `allowed`
is false and `refused` says why. Two of `snap`, `replay` and `document`, or none, is an
error. `names.check` makes, restores and changes nothing (no session is needed), and
never alters what it is given. Its `text` fields are what was sent: a client must not
show them.

The strict doors refuse a match before anything changes, with an error that names the
places (`restore: names not allowed: save.game.teams.A.name, ...`) and never the text:

- `restore` takes the snapshot text, as always, or `{ snap, names: "check" }`
  (`snap` the text or object; a snapshot has `v`, the wrapper does not). With
  `names: "check"` a snapshot `names.check` does not allow is refused; without it (the
  text alone, or a wrapper with no `names`) it restores exactly as before. Lua:
  `session.restore(text, control, { names = "check" })`. Since 0.13.4 a `restore` that
  fails leaves the session and a loaded replay as they were.
- `replayLoad({ ..., names: "check" })`: the same for a replay (its setup or start, and
  its `snap`, `players` and `log` when given). Lua: `replay.new { ..., names = "check" }`.

Use the strict doors for anything someone else sent (a pitch's snapshot on entering and
on every resync, a kept replay, a share's start) and the plain ones for the device's own
kept match, which may hold typed names from before generated names and is shown only to
its owner. Neither changes a hash.

```
names.check {"snap": "<an honest snapshot>"}
  -> {"allowed":true,"what":"snapshot","refused":[],"mismatches":[],
      "names":[{"from":"opts.teams.A.name","kind":"team","text":"Wobbly Towers","ok":true,"default":false},
               ...,
               {"from":"save.game.teams.B.name","kind":"team","as":"player","text":"Jolly Juniper","ok":true,"default":false}],
      "ids":[{"from":"save.game.teams.A.players[0].id","name":"Mighty Maple","text":"mighty_maple","ok":true}, ...],
      "lines":[{"from":"save.mode","kind":"mode","text":"Computer vs Computer","ok":true},
               {"from":"save.text","kind":"ruling","text":"field kubb down","ok":true}]}
names.check {"snap": "<the same, save.game.teams.A typed>"}
  -> {"allowed":false,
      "refused":[{"from":"save.game.teams.A.name","kind":"team","text":"Anything Typed","why":"not a generated name"},
                 {"from":"save.game.teams.A.players[0].name","kind":"player","text":"Typed Too","why":"not a generated name"},
                 {"from":"save.game.teams.A.players[0].id","kind":"id","text":"mighty_maple","why":"not the id the engine makes from the name"}],
      "mismatches":[{"from":"save.game.teams.A.name","other":"opts.teams.A.name","text":"Anything Typed","otherText":"Wobbly Towers"},
                    {"from":"save.game.teams.A.players[0].name","other":"opts.teams.A.players[0].name","text":"Typed Too","otherText":"Mighty Maple"}], ...}
restore {"snap": "<that snapshot>", "names": "check"}
  -> {"error":"restore: names not allowed: save.game.teams.A.name, save.game.teams.A.players[0].name, ..."}
```

### Neighbours

Since 0.15.1: computer-against-computer matches on the pitches around the player's, as
live scenery for the Tournament scene (docs/notes/tournament.md),
`kubbCall("neighbours.<name>", argsJson)`, dispatched like `names.<name>`. They need no
`useTune`, `new` or match, and they never touch the session: run them in a Lua state of
their own (a worker running a second engine on the web, a second `lua_State` on the
iPhone), loaded from the same bundle. One set of neighbours per Lua state. A wrong argument
is `{"error": "neighbours.<call>: ..."}` as for every call.

Each pitch plays whole matches as `tools/physmatch.lua` does: core/match, the computer on
both sides (core/autothrow at each team's level), every throw simulated to rest. The work
runs in slices, so `advance` keeps to the budget it is given. What a pitch shows, and when,
comes from the seed and the clock passed to `advance`, never from the slicing: two hosts
that open the same seed and advance on the same clock get the same events, byte for byte
(on the reference platform; docs/DETERMINISM.md).

**The pitch frame.** Everything a neighbour gives is in its own pitch's frame, Team A's
(core/frame's world frame): Team A's baseline at y = 0, Team B's at y = 8, x across,
metres. `offset` places that frame's origin in the player's pitch's world frame; neighbours
stand parallel to the player's pitch, facing the same way. The session's own items are in
the thrower's view frame, so while the player's pitch is drawn in Team B's frame turn the
whole neighbour field with it: a point `(ox + x, oy + y)` is drawn at
`(-(ox + x), 8 - (oy + y))` and an orientation is half turned about z
(`frame.quat("B", ...)`); one parent node turned 180 degrees about the player's pitch
centre (0, 4) does it for everything.

| Call | Arguments | Returns |
| --- | --- | --- |
| `neighbours.open` | `{ seed, count, scene, surface, set, level \| levels, layout, spacing, thin, now }`, all optional | `{ pitches: [pitch], seed, count, scene, surface, set, frameDt, poseScale, stakes: [{ x, y }], stakeHeight, now }` |
| `neighbours.advance` | `{ now, budgetMs }` or `{ now, steps }` | `{ now, events: [event], used: { ms } \| { steps }, late }` |
| `neighbours.view` | `{ id }`, or `{}` for every pitch | a pitch as it stands now (below), or `{ now, pitches: [...] }` |
| `neighbours.close` | `{}` | `{}` |

`open`:

- `seed`: a whole number (default 1). Every draw (teams, levels, sizes, who throws first,
  the computer's throws, the pace) comes from it, each pitch and match its own stream
  (the session's seed mix, "Determinism" below). The match's own seed is a good
  one when two phones in a shared Tournament match should show the same tournament.
- `count`: 1 to 24 pitches (default 8). `layout`: `"grid"` (default: the ring of 8 round
  the player's pitch in a 3 x 3 grid, then the ring of 16 in a 5 x 5; beside first, then
  ahead and behind, then the corners) or `"row"` (a row either side: -1, +1, -2, +2, ...
  pitches across; not for the thrower's camera, which does not see it: docs/CLIENTS.md
  "0.15.1 on top"). `spacing`: `{ x, y }` between pitch
  origins, default `{ x: 8, y: 12 }` (5 m pitches 3 m apart; 8 m pitches 4 m apart);
  at least 5.5 and 8.5.
- `scene`, `surface`, `set`: as for `new` since 0.14: the scene (default `"tournament"`)
  decides, holding the surface and the set to those it allows (Tournament: grass and
  `usa`). Any scene works. A pitch's surface is the scene's; the set is for drawing only.
- `level`: `"beginner"`, `"club"` or `"pro"` for every team; or `levels`: weights to draw
  each team's level from, default `{ beginner: 3, club: 5, pro: 2 }`. Kid is refused: a
  neighbour plays the standard rules.
- `thin`: 1, 2 or 3 (default 2): a recording's poses every `thin / 50` s (`frameDt`).
- `now`: the host's clock at opening, seconds (default 0). Each pitch's first throw comes
  1 to 20 s after it, so the pitches do not start together.

A **pitch** (from `open`, `view`): `{ id, offset: { x, y }, teams, phase, at, items }`,
and while a throw plays `recording`, `side`, `kind`, `from` as in its event. `id` is 1 to
`count`. `teams`: `{ A: { name, level, players }, B: ... }`, `name` a generated team name
(core/namegen, the engine's content policy), `players` 3 to 6. `items`: the pitch at rest,
`[{ id, kind, team, x, y, z, qw, qx, qy, qz, toppled }]` as the session's items, rounded to
the millimetre, without the stakes (`open` gives the six once: the same on every pitch,
`stakeHeight` tall). `phase` and `at`: the last beat shown (below), or `"rest"` once a
throw's recording has played out.

`advance { now, budgetMs | steps }` runs the neighbours forward, once a frame:

- `now`: the host's clock, seconds, never going back. It paces everything: pass the match
  clock that stops when the game pauses, and the neighbours pause with it. A jump of more
  than 30 s between two calls (the app was asleep) moves every pitch's schedule on by the
  jump, so they pick up where they were instead of racing through what they missed.
- `budgetMs`: the most the call may spend, by the host's clock: the host defines a global
  function `__kubbClock()` in the Lua state, returning milliseconds (`performance.now` on
  the web, a monotonic clock on the iPhone), as it defines `__kubbSource`. Without it
  `budgetMs` is refused. The work is cut before every physics step, every decision of the
  computer's (its choice, each raise, each spot of a crowded raise's search), every body
  of a recording and its encoding; a unit starts only if 1.5 times its recent cost is left,
  and the time the answer takes to encode is held back from the budget. The first unit of
  a call always runs, so any budget makes progress.
- `steps`: a count of work in physics steps instead (a choice counts 6, a set-up 5, a
  raise 6, a recording's body 3): never passed, but not a time (a step costs 0.003 to
  0.5 ms). For tests and hosts that count work.
- `used`: what the call spent (`ms` by the host's clock, or `steps`). `late`: how many
  pitches have a throw due that is not yet computed (0 unless the budget is far too small;
  a late throw comes when it is ready, with the time it was due).

An **event** is a beat on one pitch, in time order, each `{ id, phase, at }` (`at`: when
it happens on the host's clock, at or before `now`) with:

| phase | when | carries |
| --- | --- | --- |
| `throw` | a throw leaves the hand at `at` | `side` (`"A"` \| `"B"`), `kind` (`"baton"` \| `"kubb"`), `from: { x, y }` (where the thrower stands), `recording`, `down` (pieces toppled), `king` (true when it felled the king) |
| `aim` | the next thrower steps up (2 s after the last throw came to rest) | `items` only when the pitch changed between throws (a throw put back, a piece settled) |
| `walk` | the turn is over: batons and felled kubbs picked up, the teams change ends | `items`: the pitch for the next turn |
| `raise` | the kubbs thrown in are raised (and a punishment kubb placed) | `items` |
| `over` | the king is down (1 s after the throw came to rest) | `winner`, `how` |
| `setup` | the next match sets out, 40 to 60 s later | `items` (a fresh pitch), `teams` (new teams) |

A neighbour's **recording** is the session's recording cut to what a far pitch needs:

```
{ frameDt, frames, duration, poseScale,
  projectile { id, kind },
  bodies [{ id, kind, team, start, frames, poses, toppleT }],
  hits [{ t, id, strength }], landing { t, strength } }
```

The sounds (0.16.0): `hits` is the first contact on each body something strikes (the
thrown piece or another moving piece; a stake too), in time order, `t` seconds from the
release, `strength` 0 to 1 on the session's own contact scale (an impulse of 2 N s is 1),
so a kubb struck and left standing knocks and a hard hit sounds harder than a graze;
`landing` is the thrown piece's first touch of the ground. Either is left out when there
is none. They are listeners on the same steps, so the throws are as before; the events'
pinned hash in `tests/node/neighbours.test.mjs` moved because the recordings carry them
(`bafb735b` to `f3f06bfd`). They add 58 bytes a throw on average (190 throws of seed 9,
six pitches: 0.4 hits a throw, most throws being drills into open ground and batons that
touch nothing).

`bodies` holds only the bodies that moved; `poses` 7 integers a frame (`x y z qw qx qy qz`
times `poseScale`, 1000), pose j at time `(start + j) * frameDt`, as in the session's
recording. A body's track ends at its last pose that differs from the one before; after
it the body stays there, before `start` it is where the pitch's items have it, and the
thrown piece (not among the items) starts at frame 0. `frames` is the last frame anything
moves and `duration = frames * frameDt`. `toppleT`: when a piece toppled (seconds from
the release). There are no items, cameras, bursts, slow motion or ruling: the pitch's
items are the last beat's, or the previous recording played to its end. Measured (club
mostly, `thin` 2): 1.7 KB of JSON a throw on average, 4.6 KB at most; `thin` 1 3.1 KB,
`thin` 3 1.2 KB. An `items` list is about 1.3 KB.

What a client keeps for each pitch: its `items`; on an event with `items`, replace them;
on a `throw`, play the recording from `items` (the moved bodies interpolated between their
two poses around `t = now - at`, the quaternion's sign matched, as the iPhone's
`Playback.pieces(at:)` and `playRecording` in `tests/node/neighbours.test.mjs` do) and at
its end keep its last poses as the new `items`. That model equals `view`'s `items` after
every call (the tests prove it). Draw between throws what the phase says: a thrower at
`from` before the next throw, the teams walking on `walk`, kubbs being stood up on `raise`,
a cheer on `over`, teams setting out on `setup`.

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
- `{ type: "raise", choice }`: the index into `need.choices` (leave it out for
  `need.default`, the engine's advice). Raised automatically (the match option
  `raising: "auto"`), a person's kubbs go up by the same advice and the computer's by its
  level (pro `par`, club `apart`, beginner `first`; since 0.12.0, when every side used
  `apart`). The session tells the core which sides the computer plays from the match's
  `cpu` option; a client passes nothing new.
- `{ type: "punish", x, y }`: the spot in the defender's view frame. Refused spots come
  back `{ ok: false, why, label }` (label e.g. "TOO NEAR THE KING") and change nothing.
- `{ type: "resign", side, at? }`: waits for that side's own turn (the rules allow it
  only then), as on the Playdate.
- `{ type: "thrower", id }`: who throws next for the side to throw (`need.candidates`).

`at` (optional) is the finish time stamp the game file uses: `{ year, month, day, hour,
min }`, whole numbers, on the start's clock. The match's finish is the last stamp an
applied action carried (a throw, a raise, a punishment kubb, a resignation); with none the
finished file has no End or Duration line and the winner card no `minutes` (until 0.18.0
the finish fell back to the start, so every match lasted 0 minutes).

Stamping (0.18.0). A person's and the computer's throw actions are made inside the engine,
so a host stamps them by passing `at` to the call that makes them: `frame({ ..., at })` puts
it on the action that frame makes (and `Session:cpuAction(at)`, the check's own, likewise);
a raise, punish or resign action is the client's, so it carries `at` itself. Every client
applying the action takes the stamp from it, never from its own clock, so all of them
write the same End and Duration, and a snapshot carries the finish. The clock is the
start's: `opts.start` is the starting host's local wall time, and its `utcOffset` (0.18.0,
optional: minutes east of UTC, whole, -900 to 900, the starting host's) says which clock
that is. Any member stamps the time on that clock: its own UTC time plus the start's
`utcOffset`. The field is kept on the start through the snapshot, a restore, a replay
and a pitch's match header; given, it is in the snapshot, so a new match that gives it has
other hashes than one that does not (an old match, and every golden match, gives none and
keeps its hashes); a value that is not whole minutes in range is dropped. A stamp that is
not five whole numbers is dropped, a stamp before the start is no finish (never negative
minutes), and nothing is ever stamped for a host that passes none.
`check.same` and `checkThrow` leave `at` aside.

## The frame (per-frame call pattern)

A browser makes one or two calls a frame:

1. **Aiming** (`need.kind == "throw"`): `frame({ dt, arm, plan, move, walk })` once a
   frame, and the aim calls (`setTarget`, `setStance`, ...) when input asks. Draw
   `view().items` (cache them; they change only after a throw), `out.aim`, `out.camera`
   and `out.dial`. When this browser plays the side, send `aimState()` to the pitch a few
   times a second; the others call `showAim(state)` when it arrives and keep calling
   `frame({ dt })` for their camera.
2. **The release**: `out.action` is set. Send it to the pitch, then play the recording.
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
pitch.send({ type: "start", snapshot: a.snapshot() });

// Browser 2 (joins, a spectator here)
b.restore(msg.snapshot);
b.setControl({ sides: [], cpu: false });

// Browser 1, a frame of its own throw or the computer's:
const out = a.frame({ dt, arm });
if (out.action)
  pitch.send({ type: "action", action: out.action, hash: a.hash().hash });

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
    contacts [{ t, a, b, idA, idB, strength }], batonLanding { t, strength, surface },
    impacts  [{ t, x, y, id, with, thrown, speed, strength }],   // only while setImpacts is on
  },
  marker { x, y, r }                       // a drill's circle
}
```

`result.flag` is the throw's words for a baton: `"HELICOPTER"` (an illegal baton by the
standard rules), `"<n> DOWN"`, `"MISS"`; none for a kubb thrown in (its `restText` is its
line). `down` is the pieces it toppled. In a Kid match, a king knocked down early and stood
back up (the ruling's `kingUp`) is no kubb down: since 0.17.0 `down` then counts the kubbs
only and `flag` is theirs (`"1 DOWN"`), or `"KING BACK UP"` when the king was all it
felled, as `ruling.short` says (before, such a baton read `"1 DOWN"` beside a ruling of
`miss` and `kingUp`). `toppled` still lists the king.

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
as they were. A Kid match (0.15.0) adds `kingUp` (the king knocked down early and stood
back up: "king down early: stood back up" after a baton's parts, "king down: stood back
up" for a kubb thrown in), `helicopterCounts` ("helicopter: counted") and `placed` (n
kubbs out twice stood at the fair spot, in place of `punish`).

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

### Ground impacts

Since 0.14 a scene may ring, puff or spray where something meets the ground (the Techno
scene's catalogue entry has `ring: true`). `setImpacts({ on: true })` asks for it: from the
next throw each recording's `timeline.impacts` lists, for the throw being shown, each time
a piece met the ground hard enough to matter, in time order:

- `t`: seconds from the release, the clock `contacts`, `touches`, `slow` and `showAt` use
  (play a ring at `t` as the playback reaches it, slow motion included);
- `x`, `y`: where, in the recording's frame like `firstContact` and the result's spots
  (the wide view un-turns them with the rest); the ground is `z = 0`;
- `id`, `with`: the piece and its kind, `"baton"`, `"kubb"` or `"king"`; `thrown`: it is the
  thrown piece (a baton or a thrown kubb) rather than one knocked over;
- `speed`: how fast it came down onto the ground (m/s, along the ground's normal), at
  least `throw.tune.impactSpeed` (0.8); `strength`: its push on the ground in the
  strike's step over 2 N s, capped at 1, the scale `contacts` uses. Scale a ring by
  either.

One strike is one impact: a piece's touches within `impactGap` (0.12 s) of its first make
one, at the point of the strongest push. A piece that bounces strikes again. At most
`impactMax` (64) a throw. The world reports every ground contact of any piece striking
faster than `restitutionSpeed` (`w.onGround`, set only while impacts are on); nothing is
gathered when they are off, and nothing here is in a snapshot, an action or a hash.

A worked example (scene `neon`, seed 1016, the computer both sides, the first baton that
felled a kubb: a direct hit on b1 at 0.87 s, whose slow motion runs from 0.77 to 1.14 s):

```
{ t: 0.954, x: -2.02, y:  8.22, id: "b1",     with: "kubb",  thrown: false, speed: 1.41, strength: 0.25 }
{ t: 1.121, x: -1.98, y:  8.47, id: "b1",     with: "kubb",  thrown: false, speed: 1.05, strength: 0.20 }
{ t: 1.292, x: -2.04, y:  8.73, id: "b1",     with: "kubb",  thrown: false, speed: 1.26, strength: 0.22 }
{ t: 1.300, x: -2.35, y:  9.87, id: "baton1", with: "baton", thrown: true,  speed: 2.86, strength: 0.37 }
{ t: 1.533, x: -2.64, y: 10.72, id: "baton1", with: "baton", thrown: true,  speed: 3.80, strength: 0.24 }
{ t: 1.558, x: -2.00, y:  8.98, id: "b1",     with: "kubb",  thrown: false, speed: 1.13, strength: 0.05 }
{ t: 1.750, x: -2.96, y: 11.06, id: "baton1", with: "baton", thrown: true,  speed: 2.07, strength: 0.09 }
```

The kubb strikes the floor at 0.95 s, a tenth of a second after the hit and inside the
slow motion, and tumbles on along the throw three more times; the baton carries on, meets
the floor beyond the base line at 1.30 s and skips twice. A Techno renderer draws seven
rings, the strongest (by `speed`) the baton's skip at 1.53 s.

## Scenes

Since 0.14 the engine owns the scenes (core/scenes; Jamie, 2026-11-21: "a Scene should
have an allowed set of surfaces and pitch types"). `scenes()` returns the catalogue:

| id | name | surfaces (default first) | sets | flags |
| --- | --- | --- | --- | --- |
| `day` | Park | grass | classic | |
| `beach` | Beach | sand | classic | |
| `night` | Camping | grass | classic | dark |
| `neon` | Techno | grid | classic | dark, ring |
| `minnesota` | Minnesota | snow | minnesota | |
| `tournament` | Tournament | grass | usa | |
| `bw` | Black & White | grass, sand, snow | classic | mono |

`choices` is the option keys a scene leaves to the player (`["surface"]` for Black &
White, `[]` for the rest): show a Surface row (or a Kubbs row) only where it names one, or
build the card from `pitch.optionRows` (docs/PITCH.md). `dark`: a night sky, draw light on
dark. `ring`: a ground impact rings ("Ground impacts"). `mono`: black and white only (the
Playdate's own look). `sweden` and `wisconsin` are in no scene; an older match or save
that carries them still loads and draws them. The stored ids of three scenes are older
than their names: `day` is Park, `night` Camping, `neon` Techno.

`grid` is the Techno scene's floor, a fourth surface (docs/notes/physics.md "The grid"):
flat and electronic, the same throw doing the same thing every time, pieces gliding
farther than on grass and stopping dead when slow. A client needs nothing for it beyond
drawing its scene; the game file's Surface line reads `Grid`.

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
  start, and a replay's document against a real pitch's.
- `make test-wasm`: `tests/node/session.test.mjs` under wasmoon, loaded from the bundle:
  the host's calls, a practice throw, the multiplayer proof (one Lua state plays a whole
  match with the computer on one side and scripted dial swings on the other, a second
  only applies its actions, a third restores mid-match; after every action the
  recordings are identical and the hashes equal) and a replay.
- Names: `tests/lua/session/test_names.lua` (desktop) and `tests/node/names.test.mjs`
  (wasmoon) check the `names.*` calls, the same fingerprint of 300 seeds' names on both,
  and a JavaScript check built from `names.words` alone against `names.valid`.
- Neighbours: `tests/lua/session/test_neighbours.lua` (desktop) and
  `tests/node/neighbours.test.mjs` (wasmoon): opening, the first recordings and their
  pace, a client's model from the events alone equal to `view` after every call, a match
  ending and the next setting out, the budget, the same events from slices of any size
  (a crowded raise searched in slices among them), and the player's session's snapshots
  and recordings unchanged by neighbours run in the same Lua state. The wasmoon test pins
  one seed's events by their hash.
- Computer players: `tests/lua/session/test_computers.lua`: names, the throwing order
  with mixed teams, each computer at its own level, team decisions, the thrower action,
  Kid and the refusals, the old `cpu` option, the game file and names.check, one device,
  and a host change mid-throw.
- `make golden-check`: the golden hashes, the gate for hash-neutral changes
  (docs/DETERMINISM.md). m20 and m21 (0.17.0) are a person with a computer partner and a
  team of computers at mixed levels.

For private throw reports, `reportThrow` returns the last action sequence, result and
settled piece poses in the thrower’s frame. For practice it also returns
`practiceBefore`, opaque engine JSON for the pitch immediately before that throw.
Pass it to `restorePractice { checkpoint }` and then `apply` the recorded throw
action to reproduce its contacts even when the full practice history is unavailable.
