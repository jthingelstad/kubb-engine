# The Kubb Engine

The rules, physics, notation and session of Kubb: Throwing Wood, as pure Lua 5.4: the
rules engine (`core/rules`), the physics (`core/world`, `core/collide`, `core/body`), the
throw and the computer thrower (`core/throwplan`, `core/autothrow`), matches
(`core/match`) and the Planet Kubb Notation writer (`core/notation`, `core/gamefile`);
and the session (`session/`), a practice pitch or a match behind one door, `kubbCall`,
with JSON in and out (docs/SESSION.md). It has no drawing, input or file access; a
client supplies those.

The core was extracted from the Playdate game (`playdate-kubb`, `source/core/`) and the
session from the web game (`kubb.thingelstad.xyz`, `lua/web/`), at the commits recorded
in `engine.json`.

## Layout

- `core/`: rules, physics, notation.
- `session/`: the session and its API (`session/api.lua`).
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

- `make test`: the core's Lua tests (`tests/lua/`) and the session's
  (`tests/lua/session/`), the notation gate over `tests/fixtures/games/` and its refusal
  cases (`tests/fixtures/bad/`), the session under wasmoon, the golden hashes and the
  `engine.json` check.
- `make golden`: rewrite the golden hashes (only with a minor version bump);
  `make golden-native`: how far desktop Lua agrees with them.
- `make bundle`: the engine as one JSON file in `build/`.
- `make games`: 500 seeded rules-only games and 5 physics matches, every one gated.
- `make physfuzz`: the physics fuzzer (a measuring tool).
- `make realgames`: optional; needs a pk-kubb-score checkout (`PK_KUBB_SCORE`).
- `make mjref`: optional; needs a Python with `mujoco` and `numpy` (`MJPY`).

The notes in `docs/notes/` explain the rules engine, the physics and the tools.

## License

MIT. See `LICENSE`.
