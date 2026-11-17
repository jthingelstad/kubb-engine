# The Kubb Engine

The rules, physics and notation of Kubb: Throwing Wood, as pure Lua 5.4: the rules
engine (`core/rules`), the physics (`core/world`, `core/collide`, `core/body`), the
throw and the computer thrower (`core/throwplan`, `core/autothrow`), matches
(`core/match`) and the Planet Kubb Notation writer (`core/notation`, `core/gamefile`).
It has no drawing, input or file access; a client supplies those.

It was extracted from the Playdate game (`playdate-kubb`, `source/core/`) at the commit
recorded in `engine.json`, with the history of the files kept here.

## Clients

Three clients run this engine unchanged:

- the Playdate game (`playdate-kubb`),
- the browser version at throwingwood.com (`kubb.thingelstad.xyz`),
- the coming iPhone app.

Each vendors `core/` byte for byte at a tagged version of this repository and never
edits its copy. `engine.json` holds the engine's name and version and a sha256 for
every file in `core/`, so a client can check its copy.

## Loading

Every module uses Playdate's `import "core/<name>"` and stores itself on the global
table `tw` (made in `core/tw.lua`). On the desktop, `tests/lua/run.lua` defines an
`import` that loads `<repo>/core/<name>.lua` once, the same way.

## Tests

Needs Lua 5.4 and Node.

- `make test`: the Lua tests (`tests/lua/`), the notation gate over
  `tests/fixtures/games/` and its refusal cases (`tests/fixtures/bad/`), and the
  `engine.json` check.
- `make games`: 500 seeded rules-only games and 5 physics matches, every one gated.
- `make physfuzz`: the physics fuzzer (a measuring tool).
- `make realgames`: optional; needs a pk-kubb-score checkout (`PK_KUBB_SCORE`).
- `make mjref`: optional; needs a Python with `mujoco` and `numpy` (`MJPY`).

The notes in `docs/notes/` explain the rules engine, the physics and the tools.

## License

MIT. See `LICENSE`.
