# Moving a client from 0.9.0 to 0.14

The web game, the iPhone app and the Playdate game all vendor engine 0.9.0. This page is
what each changes to move to 0.13.0, built from the "For clients" parts of
docs/VERSIONING.md's 0.10.0, 0.11.0, 0.11.1 to 0.11.3, 0.12.0 and 0.13.0 entries, and
checked against each client's code as it stood on 2026-11-21 (file names below are the
client's own). The notes say why; this says what.

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
  the client says it was made on an older version of the game.
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
  directly. No surface uses them yet (docs/NAMES.md section 8, steps 2 and 3).
- **Choosing the next thrower**: the session's `thrower` action among
  `need.candidates`; the web has no control for it (its docs/MULTIPLAYER.md "Not done
  yet").
- **Other meters**: `plan.meters` names one, `standard`; a wider one (a Kid mode) would
  be another entry (docs/notes/throw.md).
