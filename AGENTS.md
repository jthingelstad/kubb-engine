# The Kubb Engine

The rules, physics, notation and session of Kubb: Throwing Wood, in pure Lua 5.4. Three
clients vendor it byte for byte at a tagged release: the Playdate game (`playdate-kubb`,
`core/`), the web game (`kubb.thingelstad.xyz`, at throwingwood.com) and the coming
iPhone app (the bundle: core, session and tune).
`CLAUDE.md` is a symlink to this file. `README.md` says what is here.

## Repo and pull requests

- GitHub: `jthingelstad/kubb-engine`, private for now. Manage it as if it were public:
  no account ids, email addresses, device serial numbers, home-directory paths or
  personal details in files, commit messages or pull requests.
- Changes reach `main` only through a pull request. Merges are rebase merges; branches
  are deleted on merge.
- Before opening a pull request run `npm ci` once, then `make test` (and `make games` for
  a change to the rules, notation or physics). CI (`.github/workflows/validate.yml`)
  runs `make test` and `make games`.
- Codex reviews every pull request. Read its inline findings and fix or answer each one
  before calling the work done.
- Other sessions may share this checkout. Do side work in a `git worktree`.

## The pure core rule

- `core/` is pure Lua 5.4. No `playdate.*`, no `CoreLibs`, no browser or iOS APIs
  (`test_harness` fails the build on `playdate`).
- No `os.*`, `io.*` or `math.random` in `core/`: times and random seeds are passed in,
  so the same inputs give the same results on every client.
- Every module uses `import "core/<name>"` (no `.lua`), runs once, returns nothing, and
  stores itself on the global `tw` (`tw.vec`, `tw.rules`). `tests/lua/run.lua` provides
  `import` on the desktop.
- Playdate floats are 32-bit and desktop doubles: test outcomes with tolerances.
- Hot physics paths (`core/world`, `core/collide`) make no tables or closures per step;
  a change there should keep `tools/physdump.lua`'s output bit-identical, or say why not.

## Layout

- `core/`: the rules, physics and notation (the Playdate vendors this part).
- `session/`: the platform-neutral session behind one door, `kubbCall` (from the web's
  `lua/web/`; docs/SESSION.md). Pure Lua like the core; tables keep their `tw.web.*`
  names so the web adopts it with path changes only.
- `tune/`: a host's values for the core's tune tables, chosen by the host's `useTune`
  call (`pointer` for the web). `tune/touch.lua` comes later with the touch throw.
- `version.lua`: the engine's version (not in `core/`).

## Versions, golden hashes and releases (docs/VERSIONING.md)

- **Anything that changes a golden hash needs a minor version bump and `make golden`,
  in the same pull request.** That is any physics, rules, tune or session change that
  alters what a seeded match does. `make golden-check` (in `make test` and CI) is the
  gate: it passing is what hash-neutral means, and only hash-neutral changes may be a
  patch. A snapshot, action or document format change is a major bump.
- Bump the version in `version.lua` and `engine.json` together (`make test` checks).
- The golden corpus is generated under wasmoon only, the reference platform
  (docs/DETERMINISM.md). Stock desktop Lua is for logic tests, never for hashes.
- After the release's pull request merges, tag `vX.Y.Z` on `main` and push the tag.
  Tags are never moved.

## Vendoring and engine.json

- Clients copy a tagged release byte for byte and never edit the copy. A fix belongs
  here, then each client moves to the new tag.
- `engine.json` holds the name, version, the playdate-kubb commit the core was extracted
  from, the web commit the session came from, a sha256 per engine Lua file (by path) and
  the bundle's sha256. After an intended change run `make manifest` and commit the
  result; `make test` fails while they disagree.

## Tests and tools

- Lua tests: `tests/lua/test_<thing>.lua`, with `test(name, fn)`, `expect.eq`,
  `expect.near`, `expect.truthy`. Pinned physics cases: `tests/lua/physcases/`. The
  session's are `tests/lua/session/`, run in a Lua state of their own (`make
  test-session`: they load the pointer tune, which changes core tables).
- `tests/node/session.test.mjs` runs the session under wasmoon (pinned to 1.16.0, the
  version the web ships) from the bundle; `tests/golden/` holds the golden driver and
  corpus.
- Notation gate: every game file the engine writes must pass the pk-kubb-score grammar
  with zero warnings, and `kubb.js` must find the same winner (`make games`).
- `tests/vendor/pk-kubb-score/` holds copies of pk-kubb-score's parser and scorer. Never
  edit them; `make sync-notation` refreshes them from a pk-kubb-score checkout, which is
  read only.
- `tests/fixtures/traces/device-*.jsonl` are crank traces recorded on a Playdate,
  replayed through `core/swing` by `test_swing`.
- Measuring tools (`tools/physfuzz.lua`, `clusters.lua`, `realgames.mjs` and the rest)
  change nothing in the engine; what to tune from them is Jamie's call.

## Notes

`docs/notes/` holds the subsystem notes (rules engine, physics, physics fuzz, the
reference engine, real games, headless games, the throw). Read the note before changing
the part it covers. `docs/SESSION.md` is the session's API, `docs/VERSIONING.md` and
`docs/DETERMINISM.md` the version rules and the reference platform. Code comments also
cite `docs/DESIGN.md` and `docs/PLAYERS.md`, which are in `playdate-kubb`, and the
session's cite `docs/CLIENT.md`, which is in `kubb.thingelstad.xyz`.
