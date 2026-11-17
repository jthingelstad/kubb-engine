# The Kubb Engine

The rules, physics and notation of Kubb: Throwing Wood, in pure Lua 5.4. Three clients
vendor `core/` byte for byte: the Playdate game (`playdate-kubb`), the web game
(`kubb.thingelstad.xyz`, at throwingwood.com) and the coming iPhone app.
`CLAUDE.md` is a symlink to this file. `README.md` says what is here.

## Repo and pull requests

- GitHub: `jthingelstad/kubb-engine`, private for now. Manage it as if it were public:
  no account ids, email addresses, device serial numbers, home-directory paths or
  personal details in files, commit messages or pull requests.
- Changes reach `main` only through a pull request. Merges are rebase merges; branches
  are deleted on merge.
- Before opening a pull request run `make test` (and `make games` for a change to the
  rules, notation or physics). CI (`.github/workflows/validate.yml`) runs `make test`.
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

## Vendoring and engine.json

- Clients copy `core/` byte for byte at a tagged version and never edit the copy. A fix
  belongs here, then each client syncs.
- `engine.json` holds the name, version, the playdate-kubb commit the engine was
  extracted from and a sha256 per core file. After an intended change to `core/` run
  `make manifest` and commit the result; `make test` fails while they disagree.

## Tests and tools

- Lua tests: `tests/lua/test_<thing>.lua`, with `test(name, fn)`, `expect.eq`,
  `expect.near`, `expect.truthy`. Pinned physics cases: `tests/lua/physcases/`.
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
the part it covers. Code comments also cite `docs/DESIGN.md` and `docs/PLAYERS.md`, which
are in `playdate-kubb`.
