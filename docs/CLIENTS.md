# Moving a client from 0.9.0 to 1.0.0

The web game, the iPhone app and the Playdate game all vendored engine 0.9.0 when this
page was begun; on 2026-11-22 all three are on 1.0.0. This page is what each changes to
move to 0.13.0, built from the "For clients" parts of
docs/VERSIONING.md's 0.10.0, 0.11.0, 0.11.1 to 0.11.3, 0.12.0 and 0.13.0 entries, and
checked against each client's code as it stood on 2026-11-21 (file names below are the
client's own), and then each release on top. The notes say why; this says what.

"Must" is what breaks, or plays an older engine's game, if left undone. "Worth showing"
is new and optional.

## Every client

- **Sync the tag**, each by its own command, from a kubb-engine checkout beside it:
  web `npm run vendor:sync -- --tag v0.13.0`, iPhone `TAG=v0.13.0` in
  `scripts/vendor-engine.sh`, then `scripts/vendor-engine.sh sync`, Playdate
  `make vendor-sync TAG=v0.13.0` (core only).
- **Carry the newest engine alone.** A client carries an engine only while we have
  decided it is supported, and today that is the newest minor (VERSIONING.md "Carrying
  several engines"; decided 2026-11-21, after this guide was first written to keep 0.9
  beside 0.13). Drop 0.9, 0.8 and 0.7: web `vendor:sync` with `--drop`, iPhone an empty
  `OLDER`. A match, replay or reel made on a dropped engine is not replayed on another;
  the client says it was made on an older version of the game. (Since 2026-11-22 the web
  also carries the engines of the current App Store and TestFlight builds of the iPhone
  app, so a later move reads the web's docs/ENGINES.md before it drops one.)
- **Web and iPhone share a match only on the same major.minor.** Both must be on 0.13
  to play each other; a pitch whose players carry no common engine says who must
  update (`engineFor`'s `missing`). A player whose client has no supported engine is told to
  update; ship both clients close together so that is brief.

## Web (`kubb.thingelstad.xyz`)

Must:

- **The pitch rename (0.13).** Add `"pitch"` to `DIRS` in `tools/lua-bundle.mjs` and to
  `ENGINE_DIRS` in `tools/vendor.mjs`, keeping `"room"`, and let `engineFiles` skip a
  directory an engine does not have (it reads every listed directory of every carried
  engine; 0.7 to 0.9 have only `room/`). The bundle's modules are then `pitch/lobby` and
  so on, and its sha256 matches engine.json's.
- **The bridge prefix may stay.** `roomCall` in `src/net/room-engine.js` says
  `room.${name}`; 0.13 answers `room.` as the old spelling, and 0.7 to 0.9 know nothing
  else. Move it to `pitch.` when convenient: per engine (`pitch.` from 0.13) or once
  0.7 to 0.9 are dropped. `tests/net/room-engines.test.mjs` (the asked call names) and
  `tests/game/room-version.test.mjs` (counts calls starting `room.`) follow the prefix.
- **The arc's default moves with the stance (0.10).** `view.aim.controls.arc.default`
  changes as the circle or the stance moves, until the player sets the arc. Read it from
  each view, not once a throw (`src/game/plan-sliders.js` reads `controls.arc`; check
  that nothing caches the default).
- **A kubb throw's `launch.scatter` (0.11).** Pass actions through as `frame` returns
  them; `checkThrow` refuses a kubb throw whose scatter is not its level's. The web
  builds no launch of its own, so nothing to change unless a tool does.
- **A raise by hand offers `need.default` first (0.12).** It is now the engine's advice
  (`par`); a `raise` action with no choice takes it. Nothing to pass.
- **The bars go by distance (0.13).** `plan.powerLo..powerHi` and
  `releaseLo..releaseHi` are the bars for the plan as it is: redraw them whenever the
  plan changes (circle or stance moved), not once a throw (`src/render/dial.js`,
  `src/render/linear.js`, `src/game/coach.js`, `src/game/nudge.js` read them).
- **The release's pull (0.13).** A release past its bar comes back PULLED LEFT or RIGHT
  in the verdict's side cell, beside HIGH or LOW. `src/game/hud.js` already draws a
  PULLED side; check it shows for these.
- **`checkThrow` against the meter (0.13).** A person's throw that fits lists every
  level with `atLevel` true. `backend/reels/check.mjs` calls it; it should accept that.

Worth showing:

- **The person's level picker can go (0.13).** A person's level no longer changes their
  throw (it is still taken and kept, so leaving it breaks nothing). The computer's
  level picker stays. The web's is in `src/ui/settings.js` and the solo card and lobby
  "You" row (`src/game/throw-level.js`).
- **The arc slider's long mark** sits at 3 o'clock (`limits.releaseNormal` in
  `src/game/plan-sliders.js`); since 0.10 the default arc is by distance, so a mark at
  `controls.arc.default` says more.
- **The spin control (0.11)** is unchanged in meaning (-3 to 3 taps, + rolls right), but
  the roll is now real and aimed for: the marker is where a clean throw rests. A spin
  control can say so.

## iPhone (`throwingwood-ios`)

Must:

- **The pitch rename (0.13).** Add `pitch` to `engine_paths` in
  `scripts/vendor-engine.sh` (it copies what each tag has, so keep `room` for the older
  tags). `Engine.init(directory:)` loads what `engine.json`'s `files` names and needs no
  change (its comment lists `room/`).
- **The bridge prefix may stay.** `PitchController.roomCall` says `"room." + name`, and
  `SoloMatch.swift`, `OnlinePitch.swift` and `Share.swift` call `room.constants` and
  `room.cleanName` directly; 0.13 answers them. Move to `pitch.` as for the web.
- **The arc's default (0.10)**, **`launch.scatter` (0.11)** and **`need.default`
  (0.12)**: as for the web.
- **The bars go by distance (0.13).** Redraw them on every plan change
  (`BoardView.swift`, `LinearMeterHUD.swift`, `PracticeHUD.swift` read
  `powerLo`/`releaseLo`).
- **The release's pull (0.13).** A release past its bar comes back PULLED LEFT or RIGHT
  in the recording's `verdicts.side`. `Recording.swift` already reads `side` and shows
  it when it is not STRAIGHT; check the caption has room for it beside HIGH or LOW.

Worth showing:

- **The person's level picker can go (0.13):** "Your level" in `LevelSettings.swift`.
  The computer's level stays.
- **The spin control (0.11):** as for the web.

## Playdate (`playdate-kubb`)

The Playdate vendors `core/` and drives `core/match` directly, so the session's changes
reach it only where it makes them itself.

Must:

- **A person throws on the meter (0.13).** The session plans a person's throw with
  `q.meter = plan.meter()`; the Playdate builds its own plan (`scenes/throw.lua`, `q.level
  = throw.levelFor(s)` before `plan.solve`). Set `q.meter = plan.meter()` there for a
  person's throw, and keep `q.level` for the computer's, or a person still throws by
  level as on 0.12 (docs/notes/throw.md "The person's meter").
- **A kubb throw's scatter (0.11).** `world.launchDrill` takes the scatter as its last
  argument (nil: 1); the core's drills change with it.
- **The arc's default (0.10).** `autothrow.tune.drillSpin` is a number, `plan.tune.arc`
  holds only `drill`, and `drill.body`'s fifth argument is the loft. `plan.arcFor` takes
  the distance: `scenes/throw.lua` called it with the target's kind alone, which since
  0.10 silently gives every target the 8 m arc; pass the distance from the stance to
  the aim circle, as `session/throw.lua`'s `defaultArc` does.
- **Raising by side (0.12).** In VS PLAYDATE the core infers the computer is Team B and
  raises by level, with nothing to change. Two things need the Playdate's own change:
  `scenes/settle.lua` offers its first end with `g.raisePolicy` (`apart`); pass
  `tw.match.raisePolicy(m, side) or g.raisePolicy` to give a person the advice. And
  PASS + PLAY (`scenes/match.lua`, `cmatch.new` with no `mode`) keeps `apart` unless it
  passes `cpu = {}` to `match.new` (and sets `m.cpu = {}` on resume).

Worth showing:

- **The bars and the pull (0.13).** The bars narrow with distance; the HUD already has
  the side cell (`render/hud.lua`, PULLED LEFT / STRAIGHT / PULLED RIGHT).
- **The person's LEVEL row** (`scenes/players.lua`) no longer changes a person's throw
  once the meter is used; the computer's row (`core/matchopts`) stays.

## 0.13.1 on top

0.13.1 is 0.13.0 with the game file written in Planet Kubb Notation 2. No hash moves, so
it shares matches with 0.13.0. Sync `v0.13.1` in place of `v0.13.0` above, and:

- **Web**: `sheet.text` has `@` and `*` position lines where it had `(@ ...)` comments;
  `sheet.shown` leaves them out as before. Rewrite the two tests that look for the
  comments (`tests/game/client.test.mjs`, `tests/net/record.test.mjs`) and the comments
  that describe them (`src/ui/sheet.js`, `src/engine/index.js`, docs/CLIENT.md).
- **iPhone**: nothing in Swift. Run `SoloTests` and the sheet's snapshot again.
- **Playdate**: `scenes/sheet.lua` skips lines where `gamefile.isPosition(line)` is true.
  The Playdate's own notation gate, its fixtures and its vendored reader move to
  Notation 2 with it (pk-kubb-score `v2-2026.11`), or every game file its self-tests
  write fails the gate.
- **Playdate, on the device**: `raising.policies.par` costs about 33 ms a decision on
  the device (0.06 ms in desktop Lua), and a settle makes every raise in one call, so
  eight kubbs add about 0.2 s to a still frame. The Playdate sets `tw.cpu.raising.pro`
  and its automatic raising of a person's kubbs to `apart` from its own setup code
  (never by editing the vendored core). The pro computer's attacking plays cost one
  89 ms frame and stay on.

## 0.13.2 on top

0.13.2 is 0.13.1 with `[Throw Levels]` naming the computer's players only, and none at
all when no computer plays (`match.fileLevels`). No hash moves, so 0.13.0, 0.13.1 and
0.13.2 share matches. Sync `v0.13.2` in place of `v0.13.1`, and:

- **Web**: nothing but the sync.
- **iPhone**: nothing but the sync.
- **Playdate**: `source/selftest/match-teams.lua` checks that its pass-and-play file has
  no `[Throw Levels]` (it looked for the people's levels); `docs/notes/saved-players.md`
  says the header names the Playdate's player only.

## 0.13.3 on top

0.13.3 is 0.13.2 with the session's `names.*` calls (docs/SESSION.md "Names"). No hash
moves and nothing must change; sync `v0.13.3` in place of `v0.13.2`. It is what the web
and the iPhone need to replace typed names with generated ones (docs/NAMES.md section 8,
steps 2 and 3): roll one on first run and keep its text, build the name row from `roll`,
`step` and `choices`, and check every name that arrives from outside with `valid`,
accepting `ok` or `default`.

## 0.13.4 on top

0.13.4 is 0.13.3 with `names.check` and a strict `restore` and `replayLoad`
(docs/SESSION.md "Names"). No hash moves, so 0.13.0 to 0.13.4 share matches. Sync
`v0.13.4` in place of `v0.13.3`, and replace each field check of a match from outside
with the engine's:

- **Web**:
  - `src/net/pitch.js` `enterMatch(m)`: in place of
    `badNames(this.names, setupOfSnapshot(m.snap)).length`, refuse when
    `!engine.call("names.check", { snap: m.snap }).allowed` (the match's own engine). Then
    adopt the snapshot through the strict door: `src/engine/index.js` gains a
    `restoreChecked(snap)` that sends `JSON.stringify({ snap, names: "check" })` to
    `restore` and throws on its error, and `game.adopt` uses it for every snapshot the
    pitch hands it (entering, `resync`, joining part way). A local resume keeps
    `restore`.
  - `src/replay/player.js` `replayProblem(r)`: in place of
    `badNames(namesOf(e), r.setup)`, `"names"` when
    `!e.call("names.check", { replay: r }).allowed`, with the whole kept replay (its
    `start` or `setup`, `snap`, `players`, `log`). `src/engine/index.js` `replayLoad`
    passes `names: "check"`, so a replay that skips `replayProblem` is refused too.
  - The lobby: `names.check({ document: doc, members })` where it now checks
    `teamNames` and `teamsLine`'s players one by one; show a refused name's default.
  - `badNames` and `setupOfSnapshot` go; `names.valid` stays for the name row and the
    share's single names (`src/net/share.js`).
- **iPhone**: the same three: a pitch's snapshot through `restore` with
  `{ snap, names: "check" }`, a replay or kept match through `names.check({ replay })` and
  `replayLoad` with `names: "check"`, a lobby through `names.check({ document, members })`.
  The device's own kept matches resume with the plain `restore`.
- **Playdate**: nothing but the sync.

## 0.14 on top

0.14.0 is a minor: it moves golden coverage (two grid matches) and adds options, so it
shares matches with no 0.13. Web and iPhone move together. Sync `v0.14.0` in place of
`v0.13.4` (web `npm run vendor:sync -- --tag v0.14.0`, iPhone `TAG=v0.14.0`, Playdate
`make vendor-sync TAG=v0.14.0`), and (docs/SESSION.md "Scenes" and "Ground impacts",
docs/PITCH.md `optionRows` and difference 10):

- **Web**
  - Must: the options card is scene first. `src/ui/cards.js` (the solo card) and
    `src/ui/lobby.js` build their rows from `pitch.optionRows({ scene })` instead of
    `MATCH_OPTIONS` plus `SCENE_ROW` (`src/render/scenes.js`): the Scene row first with the
    engine's names, a Surface row only when the rows carry one (Black & White), no Kubbs
    row. When the player changes scene, take the new rows and their `defaults`. The
    engine's `MATCH_OPTIONS` now holds a Scene row and `grid`, so a card that still walks
    it shows two Scene rows; `takesComputer` in `src/main.js` still works.
  - Must: send `scene` with every `setOptions` (the pitch), `newMatch` and `newPractice`
    (`sceneOpt` in `src/main.js`), and draw what the view says (`scene`, `surface`, `set`):
    the engine has decided them. A saved choice of surface or set from before (prefs)
    goes through the scene and may come back changed.
  - Worth showing: the new scenes (Beach on sand, Minnesota on snow with the Minnesota set,
    Tournament with the USA set, Black & White for any pitch) and the grid floor under
    Techno; an undrawn scene is drawn as Park. Techno's rings: `setImpacts({ on: true })`
    once, then a ring at each `recording.timeline.impacts` entry when playback reaches its
    `t` (`src/render/stardust.js` already times `batonLanding` the same way).
- **iPhone**
  - Must: the same card from `pitch.optionRows` in `SoloMatch.swift`, `SoloPitch.swift`
    and `OnlinePitch.swift` (in place of `SceneLook`'s `id: "scene"` row and the engine's
    Surface and Kubbs rows), and `scene` with every `setOptions` and `new`.
  - Worth showing: `SceneLook.drawn` grows as each scene is drawn; Techno's rings from
    `timeline.impacts`, beside what `Recording.swift`, `Stardust.swift` and
    `PitchFeedback.swift` take from `contacts` and `batonLanding`.
- **Playdate**: nothing must change. `core/matchopts`' Surface row is Black & White's
  (grass, sand, snow, as before) and `apply` sets `opts.scene = "bw"`, which nothing reads
  yet. `core/scenes` and the grid arrive with the core; the Playdate offers neither.

## 0.15 on top

0.15.0 is a minor: Kid mode (docs/notes/kid-mode.md). It adds golden coverage (two Kid
matches) and new rules and options, so it shares matches with no 0.14. Web and iPhone move
together. Sync `v0.15.0` in place of `v0.14.0` (web `npm run vendor:sync -- --tag v0.15.0`,
iPhone `TAG=v0.15.0`, Playdate `make vendor-sync TAG=v0.15.0`). One switch: the Kid
computer makes the match a Kid match (the Kid rules for both sides, the Kid meter for a
person); a client shows Kid on its Computer row and draws the Kid line, and the engine does
the rest (docs/SESSION.md "Kid matches", docs/PITCH.md difference 9).

- **Web**
  - Must: Kid on the solo card's Computer level row, first (`OPTION_ROWS` in
    `src/ui/cards.js` holds its own Beginner, Club, Pro; or take the row from
    `pitch.optionRows`), and a kept `computer: "kid"` accepted wherever saved options are
    read. The lobby walks the engine's `MATCH_OPTIONS` and has Kid already.
  - Must: draw the Kid line at `aim.kidY` (and `minimap.kidY`) in the pitch view
    (`src/game/game.js` passes only `aim.advY` as `advantageY` today). The stance starts on
    it and `aim.advText` already reads `KID LINE  2.0 M`.
  - Worth showing: "Kid match" on the hand-off or rail from `need.kid`; the ruling codes
    `kingUp` ("king down early: stood back up"), `helicopterCounts` and `placed`.
- **iPhone**
  - Must: draw the Kid line from `setup.kidY` / `aim.kidY` in `PitchRenderer.swift`,
    `SceneRenderer.swift` and `PitchMap.swift` (their `advantageY` is the advantage line
    only), and word `StandPad`'s caption for the Kid line (it says "up to the advantage
    line" whenever the forward limit is ahead of the line, which in a Kid match is always).
  - Nothing else must: the Computer row is the engine's `MATCH_OPTIONS`, so Kid is there
    first, and `LEVELS` has four. Worth showing: "Kid match" from `need.kid`.
- **Playdate**
  - The COMPUTER row offers KID first (`core/matchopts`: the fourth stored value, stepped
    first, so a kept choice keeps its level), and `apply` sets `opts.rules = "kid"`.
  - Must, for a Kid match: `main.lua` passes `opts.rules` on to `match.new` as `rules`, the
    throw scene plans a person's throw on `plan.meter("kid")` in a Kid match, and draws the
    Kid line from the setup's `kidY`. Until then KID is the Kid computer under the standard
    rules and meter.

## 0.15.1 on top

0.15.1 is 0.15.0 with the Tournament's neighbouring pitches (docs/SESSION.md
"Neighbours", docs/notes/tournament.md). No hash moves, so it shares matches with 0.15.0.
Sync `v0.15.1` in place of `v0.15.0`; nothing must change. Two Kid fixes come with it,
and a client that worked round them may stop: the wide view now turns `kidY` for Team B
(draw the far side's Kid line from it), and a counted helicopter's `result.flag` is what
it knocked down, so the flag need not be rebuilt from the ruling codes. The neighbours are worth
showing in the Tournament scene (and any scene that wants a field around it), and this is
the whole of what it takes. The numbers below are measured (docs/notes/tournament.md
"What it costs").

- **Web** (a worker running a second engine)
  - Start a Web Worker that loads wasmoon and the same bundle the page loads, through the
    same import shim as `src/engine/index.js` (no `useTune`, no `setClient`: the
    neighbours need neither), and sets `lua.global.set("__kubbClock", () =>
    performance.now())`. On entering a Tournament match it calls `neighbours.open({ seed:
    <the match's seed>, scene: "tournament", count: 8 })` (the grid, in every layout: see
    "What the clients found" below) and posts the pitches back; on leaving, `neighbours.close({})`.
  - Once a frame the page posts `{ now }`, the match clock in seconds (stopped while the
    game is paused); the worker answers with `neighbours.advance({ now, budgetMs: 2 })`'s
    `events`. The worker's slices never stall the page; 2 ms keeps its work, and a phone's
    battery, to about 0.5% of a core for eight pitches (the mean call is 0.08 ms).
  - Lay pitch `i` out with its origin at `offset` in the player's pitch's world frame,
    parallel to it; while the view is in Team B's frame, turn the whole field 180 degrees
    about (0, 4) as the session's items are turned. Draw its `items` and the six `stakes`
    from `open` with `src/render/world.js`'s pieces, at a far pitch's detail (no shadows,
    the `set` colours).
  - Play a `throw`'s recording yourself: the web plays its own throws through `showAt`,
    which belongs to the other engine, so copy `playRecording(items, recording, t)` from
    `tests/node/neighbours.test.mjs` (the same as the iPhone's `Playback.pieces(at:)`) and
    call it each frame with `t = now - event.at`, at real speed, no slow motion or cameras.
    At `t >= recording.duration` keep its last poses as the pitch's `items`.
  - Between throws draw the pitch at rest and what the last beat says: a thrower standing
    at `from` (the next one after `aim`), the teams crossing on `walk`, kubbs stood up on
    `raise` (replace `items`), a cheer on `over` (`winner`), teams setting out on `setup`
    (new `items` and `teams`). A pitch coming into view, or after a pause, takes
    `neighbours.view({ id })`.
- **iPhone** (a second `lua_State`)
  - Make a second `Engine` (`Engine(appVersion:)` opens its own `luaL_newstate`) and give
    its state a C function `__kubbClock` returning monotonic milliseconds
    (`clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1e6`), registered before the boot chunk;
    no `useTune`. `neighbours.open` as for the web on entering a Tournament match, and
    `neighbours.close` on leaving.
  - Once a frame, from the render loop (or a serial queue of the neighbours' own; never
    the player's engine's), `neighbours.advance({ now, budgetMs: 2 })` with the match
    clock. Native Lua is as fast as the desktop's: the mean call is 0.06 ms.
  - Lay out and turn the field from `offset` as for the web, drawn by
    `PitchRenderer`/`SceneRenderer` at far detail with the USA set.
  - Play a recording with `Playback.pieces(at:)` in `Recording.swift`: decode the
    neighbour's recording into a small `Decodable` with `frameDt`, `duration`,
    `poseScale` and `bodies` (the same `Body` fields) and let `Playback` take the pitch's
    current `items` in place of `recording.items` (a body not among them, the thrown
    piece, is added at its first pose). At the end keep the last poses as `items`.
  - Between throws as for the web, from each event's `phase`.
- **Playdate**: nothing. It vendors only `core/`, whose two new hooks (`m.run` in
  core/match, `raising.probe` in core/raising) are nil unless a host sets them, so the
  game plays exactly as on 0.15.0. Neighbours are not for the device.

**What the clients found** (web 0.16.0 and the iPhone, 2026-11-22), for the next client:

- **Use the grid, never the row, with the thrower's camera.** That camera frames the
  player's own pitch, so a row either side lies outside the picture and a phone on its
  side shows no tournament at all. With the grid the pitch straight ahead plays on behind
  the far baseline in every layout. `layout: "row"` stays for a host with a camera of its
  own.
- **No people on the two pitches in line with the player's** (straight ahead and behind).
  At real scale a person a few metres past the far kubbs stands taller than anything the
  player aims at. Their kubbs and batons still play; the pitches beside keep their people.
- **Never send an earlier `now`.** The engine refuses a clock that goes back, and a host
  that treats a refusal as failure would end its neighbours; clamp to the last value sent.
- **The view does not say which frame it is in.** A client turning the field for Team B
  tracks the last throw's side, and reads it once from the base kubbs for a restored match.
- The measured drawing cost was 0.05 to 0.2 ms a frame on the web and about 1 ms on a
  phone, so neither thinned the field beyond skipping pitches wholly off screen.

## 0.16 on top

0.16.0 is a minor: the drive, a baton thrown flat or down and hard into a group
(docs/notes/throw.md "The drive"), and a thrown kubb's bars narrowed to a baton's on the
standard meter ("The thrown kubb on the person's meter"). The golden matches with a
person's side move (their default throws at the king, base kubbs and kept circles), a
person can make throws a 0.15 engine's `check.throw` refuses (a release under 15), and a
0.15 session plans other defaults, so it shares matches with no 0.15. Web and iPhone move together. Sync `v0.16.0` (web `npm run vendor:sync -- --tag
v0.16.0`, iPhone `TAG=v0.16.0`, Playdate `make vendor-sync TAG=v0.16.0`).

What every client gets for nothing: a baton's default arc is the lowered line, by
distance for every target (firm and low close in: a release of 6, launch loft -4.6 at
6.5 m/s at 1.5 m; the old line from 8 m), a drive under the knee does not turn end over
end, a plan under the throw's floor is raised to it, and the power band, the planned
speed and `aim.arc` follow. A thrown kubb is planned and launched on narrower bars. The
verdict's words are as before and right for a drive: SHORT and LONG are the power, LOW and
HIGH the stop against the bar, and PULLED the release past it; a drive that lands short is
SHORT. A helicopter is the tilt alone, as before.

Two output-only additions (no snapshot or hash moves):

- **A raise the engine makes is shown from `setup.settled`** (docs/SESSION.md "need"): the
  kubbs the computer or Raising: Automatic stood up, and a punishment kubb it placed, in
  order, each with its end and its lying and standing poses in the raiser's view frame
  (raiseInfo's frame and shape: draw them with the raise-by-hand view's code), turned to
  the world frame in the wide view. Never compare pieces before and after, or convert
  frames. After a restore there is none: the kubbs already stand.
- **The neighbours' sounds**: each neighbour `throw` recording carries `hits` (the first
  contact on each body struck, with a strength) and `landing` (the thrown piece's first
  touch of the ground): a kubb struck and left standing knocks, a topple's sound can go by
  its hit's strength, and a landing need not be read from poses.

- **Web**
  - Must: the ARC slider's range from `aim.controls.arc` every frame it is drawn, not 15 to
    165: `min` is the throw's floor (0 at a kubb a metre away, about 12 at 4 m, 15 from
    about 5 m) and moves as the circle and the stance move. A slider fixed at 15 cannot
    reach the drive, and one fixed at 0 offers throws under the floor (they are planned at
    the floor, so nothing breaks, but the thumb and the throw disagree). `value` is never
    under `min`.
  - Must: the side view draws `aim.arc` as it is, down as well as up: from 0.16 a planned
    flight can leave the hand going down (a launch loft under 0) and meet the kubb's face
    lower than the hand. A view that assumes the arc rises first, or that scales its height
    from the arc's peak over the hand, would draw a drive flat along the ground or clip it
    (not checked against the web's code for this release).
  - Worth showing: a tick or a change of colour on the ARC slider at `arc.knee` (15, half
    past 5), with the part under it named DRIVE; the clock's release band under half past
    5 is where a drive is released.
- **iPhone**
  - Must: the same two: the ARC slider takes `min` from `controls.arc` each frame, and the
    side view draws `aim.arc` with a falling start. Both as the web's (not checked against
    the app's code for this release: look for a range fixed at 15 and a view that assumes
    the arc rises).
  - Worth showing: DRIVE under the knee, as the web.
- **Playdate** (it vendors the core only and plans in its own `scenes/throw.lua`)
  - Must, for the drive: B + down steps the release under 15 (`plan.clampRelease(r,
    projectile)`: pass the projectile, so a thrown kubb still stops at 15), from the
    release as planned and never under the throw's floor: `f = plan.arcFloor(q)` for the
    plan's question, then `max(f, plan.clampRelease(max(release, f) + step * arcStepDeg,
    projectile))`, as `session/throw` `stepArc` does, so a press at the floor and back is
    never a dead step. The default
    needs nothing: `plan.arcFor("baton", d)` is the lowered line. The computer's arc is
    `plan.sharedArcFor` (the line before) until its drive is switched on.
  - Gets for nothing: `plan.solve`'s floor and the drive's turn, the narrower kubb bars on
    the standard meter, and `plan.launch`'s loft (`plan.launchLoft`). The crank feeds the
    same arm degrees to `core/swing`, and the recorded device traces replay as before
    (`test_swing`). Check that the aim arc (`drawArc`, the same parabola from the hand as
    `session/throw`'s `arcLaunch`) draws a falling start.
    The cost per aim frame is unchanged; a plan under the knee costs one bisection (24
    steps of a carry) when the plan changes, and the floor for the slider one more solve.
## 0.17 on top

0.17.0 is a minor: computer players in teams (docs/SESSION.md "Computer players",
docs/PITCH.md "Computer seats"). It adds golden coverage, so it shares matches with no
0.16; web and iPhone move together (web `npm run vendor:sync -- --tag v0.17.0`, iPhone
`TAG=v0.17.0`, Playdate `make vendor-sync TAG=v0.17.0`). A match with no computer seat
plays exactly as on 0.16, so nothing breaks if a client does nothing; what follows is what
it takes to offer computer players.

- **Web** (the lobby, `src/net/lobby.js` over `pitch.*`)
  - Must, to offer it: on the host's lobby, per team, "Add computer" with a level picker
    (Beginner, Club, Pro: `constants.SEAT_LEVELS`), calling `pitch.addComputer({ doc,
    side, level, seed })` with a seed of the host's own draw and writing the value as any
    reducer's; each seat row shows its `computers[id].name` and level, with the host's
    level picker (`setComputerLevel`), up and down or drag in the order and across teams
    (`moveComputer` with `index`), and remove (`removeComputer`). A row in `teams` whose
    id `pitch.isSeat` says is a seat is drawn from `computers`, never looked up as a
    member. Six a team counts seats.
  - Must: show `startCheck`'s `text` when it carries `why` (`person`, `size`, `level`), as
    it shows `differ` and `unknown` now. Pass `lineup.players` through to `startMatch`
    unchanged (it keeps `cpu` and `level` on computer players).
  - Must: when the pitch's Computer setting is Kid and any computer plays, show the seats
    as Kid: the match is a Kid match and every computer is the Kid computer.
  - Must: build `ctx.players` from `doc.match.players` as it does now (the computer
    players are marked there); nothing else in who acts changes. On a host change, call
    `setControl` with the new `controlFor` as now: the session resumes a held computer
    throw by itself.
  - Worth showing: "Bold Birch · computer · Pro" from `need.setup.thrower.cpu` and
    `.level`, on the rail and the hand-off (`card.handoff.throwerCpu`, `throwerLevel`,
    `order[i].cpu`, `.level`, `inkasterCpu`), and a computer's name in `candidates` greyed
    (`ok: false`, `why: "computer"`).
  - Solo (optional, the client's call): the same teams work with no pitch, `newMatch`
    with `{ cpu: true, level }` entries and no `cpu` option.
- **iPhone** (`LobbyView` and its pitch calls)
  - The same as the web: the add, level, move and remove controls over the four reducers,
    seat rows drawn from `computers`, `startCheck`'s `text`, Kid shown on seats in a Kid
    pitch, and the thrower's computer and level on the rail and the hand-off. Its
    `ctx.players` and `controlFor` handling need no change.
- **Web and iPhone, the two QA fixes**: read `result.flag` as it comes (a Kid match's early
  king now reads `"KING BACK UP"` or the kubbs alone, so nothing need rebuild it from the
  ruling), and say a rethrow from `need.setup.rethrow` with its own count, "rethrow 1 of 1",
  never adding it to the first round's.
- **Web and iPhone, the engine's raises in full**: each `setup.settled` entry now has
  `others` and `king`, the surroundings in the raiser's view frame as `raiseInfo` gives
  them for a raise by hand (and as `punishInfo` gives them for a punishment kubb), turned
  to the world frame in the wide view. Draw a watched engine raise with the raise-by-hand
  view: the kubb from `lying` to `standing`, `others` and `king` around it, entry by
  entry; nothing need be taken from the next throw's `items` or converted.
- **Pitch server** (`backend/pitch-server`)
  - Must: check the names of computer seats. `core.mjs`'s check of a document's names
    (`teamNames`, `match.players`, and a start's `meta`) gains `doc.computers[id].name`
    as a player name for every record, so a typed name in a seat is refused `bad-name`
    like one in `match.players`. Computer players in `match.players`, `meta.players` and
    `meta.setup.teams[side].players` carry generated names already and pass as they are.
  - Nothing else: the document is the lobby's and the server keeps it as given
    (`computers` is a top-level key, under the 64 KB limit with room to spare), seat ids
    are never member ids (they have a colon), and the computer's throws arrive as the
    host's actions, as a computer side's do. An open pitch's `seats` (the web sends it) is
    the twelve places less the seats; the server's own count of players is of members, as
    now.
- **Playdate**
  - Nothing must change: it vendors only `core/`, and a lineup with no computer entry
    plays as before.
  - A computer teammate on its TEAMS screen is now possible from the core's side: a
    lineup entry `{ name, level, cpu = true }` (core/lineup's entries are passed to
    `match.new` as they are, and `match.lineupOf` keeps `cpu`) makes `match.thrower`
    name it with `cpu = true`, `match.raisePolicy` raise for a team of computers at its
    strongest level, the `thrower` change refuse it, and `[Throw Levels]` name it. What
    the game would need: a way on TEAMS to add a computer player with a level (and a
    generated name, `core/namegen`) beside saved players and guests, not saved to the
    roster; `scenes/match.lua` to throw by core/autothrow whenever `setup.thrower.cpu`
    (it decides today by `s.cpu`, the Playdate's side), to skip the hand-off and pass
    cards for such a thrower, and to raise by hand only for a team with a person
    (`match.hasPerson`); and the save to keep the lineup's `cpu` (it keeps `m.lineup`
    already).

## 0.18 on top

0.18.0 is a minor: the computer drives at club and pro (it plans every baton but the king
shot on the person's default line), its king shot is calibrated by level, and the drive's
floor is cheap. Sync
`v0.18.0` in place of `v0.17.0`; nothing must change to play, and every client should
pass `at` (below) so a match has a real length. It shares matches with no 0.17: web and
iPhone move together. Worth showing: the computer's reason `field.drive` ("Driven low
and hard into the field kubb, the way the line throws close in.") from `tw.cpu.last`.

- **The Playdate's floor**: `plan.solve` and `plan.arcFloor` no longer bisect for the
  drive's floor (a plan under its floor costs about a default plan's, 0.02 ms in desktop
  Lua where it cost up to 0.7 ms, about 25 times as much) and keep the last floor, and
  `arcFloor` makes no table. The throw scene can drop its own cache of the floor and solve
  as the circle moves, as it does for every other plan.

- **A match's length** (docs/SESSION.md "Actions", `at`): stamp the throws the engine makes
  by passing `at` (`{ year, month, day, hour, min }` on the start's clock) in every
  `frame` call, and put it on the raise, punish and resign actions you make. Every client
  then writes the same End and Duration. Without stamps a finished match has no Duration
  (it was 0 minutes): show no time rather than "under a min" when `winner.minutes` is nil.
  Put the starting host's UTC offset on the start (`utcOffset`, minutes east of UTC) and
  stamp every action as UTC plus that offset, so a joiner in another zone stamps on the
  start's clock.

- **The baton's blow** (docs/notes/physics.md "The baton's blow"): a change to how a
  baton meets a kubb's face, so every throw that meets one moves and every golden hash
  with it. Nothing for a client to change. What a player notices: a baton that hits a kubb
  square on its face knocks it a little harder (about 4% faster, 6% more turn on average);
  the rates a match shows (doubles, triples, base kubbs from 8 m, the king) are the same
  within the Gym's noise. The Playdate's step costs the same.

## 1.0 on top

1.0.0 is the released engine, a major by declaration (docs/VERSIONING.md 1.0.0): no
format changes, so a client built for 0.18 reads everything 1.0 writes. Sync `v1.0.0`
in place of `v0.18.0` (web `npm run vendor:sync -- --tag v1.0.0`, iPhone `TAG=v1.0.0`,
Playdate `make vendor-sync TAG=v1.0.0`). It shares matches with no 0.18 (the physics
differs): web and iPhone move together.

- **A pitch with computer seats** (docs/PITCH.md "Computer seats"): `pitch.engineFor`
  leaves seats out (a seat carries the pitch's engine), so a pitch with a seat finds its
  engine and START runs. Must, when convenient (the workaround still gives the right
  answer, so nothing breaks if it stays a little): drop it. The web's `roomEngineFor` in
  `src/net/lobby.js` passes the document through `withoutSeats` before asking; the
  iPhone's `PitchController.withoutSeats` does the same at its two `engineFor` calls.
  Each has a test that pins 0.18's behaviour and fails on 1.0.0 by design: the web's
  `tests/net/computer-seats.test.mjs` ("a seat carries none (engines 0.17.0 and 0.18.0's
  engineFor count it)") and the iPhone's `ComputerSeatTests.swift` (the raw call finds no
  engine). Delete each workaround with its test, or turn the test to assert the raw call
  finds the engine. The iPhone's AGENTS.md and docs/ONLINE.md name the gap too.
- **The seat, for renderers** (docs/notes/physics.md "The seat"): kubbs stand very slightly
  off plumb on grass, sand and snow (up to 2, 3 and 1.5 degrees; plumb on the grid), and a
  hard touch leaves a kubb standing less often. The items a client draws now lean, and
  that is correct: draw each piece's quaternion as given, as now. Nothing must change.
  Optional polish: a watched or hand raise that ends its animation plumb sees the kubb take
  its seat (up to 3 degrees) at the next throw's first frame. Each `setup.settled` entry
  now carries `seat` (docs/SESSION.md), the orientation it will stand at, in the same frame
  as its poses: end the raise there and nothing steps. A raise by hand can end on that
  kubb's item pose once the pitch's items come back.
- **The Playdate's floor**: `plan.solve` no longer runs a 3000-step carry for a line no
  speed reaches when the circle or the stance moves under a kept drive, and a plan under
  the knee spends no solve on the top speed. In desktop Lua a kept drive raised to a new
  floor costs 0.025 to 0.09 ms at 1.5 to 5 m (worst 0.16), where 0.18 cost 0.47; a
  default plan under the knee 0.005 to 0.008 ms (0.017 to 0.019 on 0.18). On the device,
  at the repo's factor of about 280 times desktop Lua that is 7 to 25 ms (worst about 45)
  for the new-floor case; at about 430 times, which the device's own check implies for a
  0.18 default solve (7.3 ms against 0.017), 11 to 39 ms (worst about 69). The device's
  measured repeat cases on 0.18 (0.14.0 build 16): `plan.solve` 7.25 ms at 1.5 m and 7.29
  at 3 m, solve at the floor 12.23 and 16.15, `arcFloor` 11.54 and 6.69, and the new-floor
  case was estimated at about 150 ms. Whether the throw scene can drop its floor cache on
  these numbers is the Playdate's call; measure the new-floor case on the device first.
- **The rest**: nothing to change. pairRoll from the first step and the propped contacts
  change how throws settle (a few throws in thousands no longer run to the 12 s limit).

## 1.1 on top

1.1.0 adds record mode (docs/RECORD.md), for Kubb: Pitchside. Nothing else changes, and no
hash moves. Sync `v1.1.0` (web `npm run vendor:sync -- --tag v1.1.0`, iPhone `TAG=v1.1.0`,
Playdate `make vendor-sync TAG=v1.1.0`).

- **Every client**: nothing must change. The Playdate's `core/` gains `core/record.lua`,
  which nothing it runs imports. A game file the rules engine writes is unchanged: `Y`
  (`notation.inkastBody`) appears only in record mode's files.
- **Web and iPhone, online play**: matches are shared on major.minor (docs/VERSIONING.md
  "Playing together"), so a web on 1.1 must also carry 1.0 while an iPhone build on 1.0
  is in TestFlight or the App Store (`docs/ENGINES.md` in the web repository), or both
  move at once.
- **Kubb: Pitchside**: the whole of docs/RECORD.md. It loads the engine as the iPhone app
  does (the bundle, `import "session/api"`) and calls only `record.<name>`, with no
  `useTune`.

## What the engine now offers that no surface shows yet

- **The computer's reason** (`tw.cpu.last`, since 0.11.1): the play and situation behind
  its last throw or raise (`kind`, `why.play`, such as `field.line` or `raise.par`).
  Never on an action or anything hashed, so a client may show it freely
  (docs/notes/computer-player.md).
- **Generated names** (`core/namegen`, `core/namewords`, since 0.11.3; the session's
  `names.*` calls since 0.13.3): team and player names from curated word lists, the step
  that replaces every typed name (docs/NAMES.md section 10, decided). The web and the
  iPhone call `names.roll` (a seed of their own, locked words in `keep`), `names.step` and
  `names.choices` for a name row with Shuffle, a picker and a lock per word,
  `names.valid` wherever a name arrives from outside, and `names.all` once to size the row
  for the widest name in their own font; the pitch server checks names from
  `names.words` without Lua (docs/SESSION.md "Names"). The Playdate calls `core/namegen`
  directly. The web and the iPhone have the name row and the pitch server checks names
  (docs/NAMES.md section 8, steps 2 and 3).
- **Choosing the next thrower**: the session's `thrower` action among
  `need.candidates`; the web has no control for it (its docs/MULTIPLAYER.md "Not done
  yet"). Since 0.17 it is between people only.
- **Kid rules without the computer** (0.15): `newMatch`'s `rules: "kid"` gives pass and play
  the Kid rules and meter; no options card offers it yet.
