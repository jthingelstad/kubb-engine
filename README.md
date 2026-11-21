# The Kubb Engine

The rules, physics, notation and session of Kubb: Throwing Wood, as pure Lua 5.4: the
rules engine (`core/rules`), the physics (`core/world`, `core/collide`, `core/body`), the
throw and the computer player (`core/throwplan`; `core/read`, `core/plays`, `core/cpu` and
`core/autothrow`, docs/notes/computer-player.md), matches
(`core/match`) and the Planet Kubb Notation writer (`core/notation`, `core/gamefile`);
the session (`session/`), a practice pitch or a match behind one door, `kubbCall`,
with JSON in and out (docs/SESSION.md); and the room (`room/`), a shared pitch's
document and who acts in it, behind the same door (docs/ROOM.md). It has no drawing,
input, network or file access; a client supplies those.

The core was extracted from the Playdate game (`playdate-kubb`, `source/core/`) and the
session and the room from the web game (`kubb.thingelstad.xyz`, `lua/web/` and
`src/net/`), at the commits recorded in `engine.json`.

## Layout

- `core/`: rules, physics, notation.
- `room/`: a shared pitch's document, its reducers, who acts and staying in step.
- `session/`: the session and its API (`session/api.lua`), the room's calls too.
- `tune/`: a host's values for the core's tune tables (`tune/pointer.lua`, the web's).
- `version.lua`: the engine's version.

## Clients

Three clients run this engine unchanged:

- the Playdate game (`playdate-kubb`),
- the browser version at throwingwood.com (`kubb.thingelstad.xyz`),
- the coming iPhone app.

Each vendors a tagged release (`vX.Y.Z`) byte for byte and never edits its copy: the
Playdate takes `core/`, the web and the iPhone the whole engine, as files or as the
bundle (`make bundle`: `build/kubb-engine-sources.json`, one JSON module map, and its
sha256). `engine.json` holds the engine's name and version, a sha256 for every engine
Lua file and the bundle's, so a client can check its copy. The version rules are in
`docs/VERSIONING.md`; why the reference results are wasm's is in `docs/DETERMINISM.md`.

## Loading

Every module uses Playdate's `import "core/<name>"` and stores itself on the global
table `tw` (made in `core/tw.lua`). On the desktop, `tests/lua/run.lua` defines an
`import` that loads `<repo>/<name>.lua` once, the same way. A host loads the session
with `import "session/api"`, then calls `useTune` and, if it likes, `setClient` before
the first match (docs/SESSION.md "Starting").

## Tests

Needs Lua 5.4 and Node; run `npm ci` once (wasmoon, for the wasm tests).

- `make test`: the core's Lua tests (`tests/lua/`), the session's
  (`tests/lua/session/`) and the room's (`tests/lua/room/`, with the vectors in
  `tests/room/vectors/`), the notation gate over `tests/fixtures/games/` and its refusal
  cases (`tests/fixtures/bad/`), the session under wasmoon, the golden hashes and the
  `engine.json` check.
- `make golden`: rewrite the golden hashes (only with a minor version bump);
  `make golden-native`: how far desktop Lua agrees with them.
- `make bundle`: the engine as one JSON file in `build/`.
- `make room-vectors KUBB_WEB=<dir>`: rewrite the room's vectors from the web's
  JavaScript (read only).
- `make games`: 500 seeded rules-only games and 5 physics matches, every one gated.
- `make physfuzz`: the physics fuzzer (a measuring tool).
- `make realgames`: optional; needs a pk-kubb-score checkout (`PK_KUBB_SCORE`).
- `make gym`: the Kubb Gym's scorecard (docs/notes/gym.md), a measuring tool.
- `make mjref`: optional; needs a Python with `mujoco` and `numpy` (`MJPY`).

The notes in `docs/notes/` explain the rules engine, the physics and the tools.

## License

The engine is under the [MIT license](LICENSE). The Planet Kubb Notation test tools
are also MIT-licensed. Their [vendor notes](tests/vendor/pk-kubb-score/README.md#license)
include the Peggy attribution.
