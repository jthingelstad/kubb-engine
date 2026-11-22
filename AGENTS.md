# The Kubb Engine

The rules, physics, notation and session of Kubb: Throwing Wood, in pure Lua 5.4. Three
clients vendor it byte for byte at a tagged release: the Playdate game (`playdate-kubb`,
`core/`), the web game (`kubb.thingelstad.xyz`, at throwingwood.com) and the coming
iPhone app (the bundle: core, pitch, session and tune).
`CLAUDE.md` is a symlink to this file. `README.md` says what is here.

## Repo and pull requests

- GitHub: `jthingelstad/kubb-engine` is public. Keep account ids, email addresses, device
  serial numbers, home-directory paths and personal details out of files, commit messages
  and pull requests.
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
- `pitch/`: a shared pitch's document and reducers, who acts, the pitch's engine, behind
  `kubbCall("pitch.<name>")` (`room/` and `room.<name>` before 0.13; `room.` and `tw.room`
  stay as aliases; docs/PITCH.md). Pure like the core. It began as the web's
  `src/net/lobby.js`, `seats.js` and `sync.js`, which are now wrappers over it, so the Lua
  is the source of truth. Its deliberate differences from the JavaScript the vectors were
  recorded from are listed in docs/PITCH.md; any other difference is a bug.
- `tune/`: a host's values for the core's tune tables, chosen by the host's `useTune`
  call (`pointer` for the web). `tune/touch.lua` calibrates the pendulum in `session/touch.lua`; both inputs share the CPU and physics tune.
- `version.lua`: the engine's version (not in `core/`).

## Versions, golden hashes and releases (docs/VERSIONING.md)

- **Anything that changes a golden hash needs a minor version bump and `make golden`,
  in the same pull request.** That is any physics, rules, tune or session change that
  alters what a seeded match does. `make golden-check` (in `make test` and CI) is the
  gate: it passing is what hash-neutral means, and only hash-neutral changes may be a
  patch. A format change an older client cannot read is a major bump; fields that only
  add, inside a match pinned to its major.minor, go with the minor (docs/VERSIONING.md).
- Bump the version in `version.lua` and `engine.json` together (`make test` checks).
- The golden corpus is generated under wasmoon only, the reference platform
  (docs/DETERMINISM.md). Stock desktop Lua is for logic tests, never for hashes.
- After the release's pull request merges, tag `vX.Y.Z` on `main` and push the tag.
  Tags are never moved.

## Vendoring and engine.json

- Clients copy a tagged release byte for byte and never edit the copy. A fix belongs
  here, then each client moves to the new tag.
- `engine.json` holds the name, version, the playdate-kubb commit the core was extracted
  from, the web commits the session and the pitch came from, a sha256 per engine Lua
  file (by path) and the bundle's sha256. After an intended change run `make manifest` and commit the
  result; `make test` fails while they disagree.

## Tests and tools

- Lua tests: `tests/lua/test_<thing>.lua`, with `test(name, fn)`, `expect.eq`,
  `expect.near`, `expect.truthy`. Pinned physics cases: `tests/lua/physcases/`. The
  session's are `tests/lua/session/`, run in a Lua state of their own (`make
  test-session`: they load the pointer tune, which changes core tables).
- The pitch's tests are `tests/lua/pitch/` (`make test-pitch`) and
  `tests/node/pitch.test.mjs`: the web's unit tests ported, the differences, the `room.`
  alias, and the vectors in `tests/pitch/vectors/`. The vectors are a frozen corpus,
  recorded from the web's JavaScript at the commit engine.json's `pitchFrom.commit`
  names; they cannot be made again (the web's modules now call the engine). Never edit
  them. `tests/fixtures/room-0.8.2/` is 0.8.2's `room/lobby.lua`, verbatim.
- `tests/node/session.test.mjs` runs the session under wasmoon (pinned to 1.16.0, the
  version the web ships) from the bundle; `tests/golden/` holds the golden driver and
  corpus.
- The game file is Planet Kubb Notation 2 in its canonical form (pk-kubb-score's
  `docs/notation-2.md`); pk-kubb-score owns the notation and its grammar, the engine its
  writer (`core/notation`), the rules and its statistics. Positions are converted to the
  notation's frame in one place, `notation.toPitch` (docs/notes/rules-engine.md
  "Positions").
- Notation gate: every game file the engine writes must pass the pk-kubb-score grammar's
  canonical form, be unchanged by its canonical writer, give zero `kubb.js` warnings and
  the same winner, and its position lines must read back as the places the score sheet
  kept (`make games`; tools write those beside each game as `<name>.places.json`).
- `tests/vendor/pk-kubb-score/` holds copies of a tagged pk-kubb-score release's parser,
  canonical writer and reader (`SOURCE` names the tag and commit). Never edit them; `make
  sync-notation` refreshes them from a pk-kubb-score checkout (read only) at its latest
  tag, or `PKTAG=`. Something the engine needs that the notation lacks is raised there,
  never worked around here.
- Generated names (docs/NAMES.md): `core/namewords` is the content policy for every
  player and team name. A change to a word list needs `make names`, and a person reads
  the new names in the diff before it merges; a near miss goes into
  `tests/names/blocklist.txt`. Remove a word only for safety, and say so.
- `tests/fixtures/traces/device-*.jsonl` are crank traces recorded on a Playdate,
  replayed through `core/swing` by `test_swing`.
- Measuring tools (`tools/physfuzz.lua`, `clusters.lua`, `realgames.mjs` and the rest)
  change nothing in the engine. A change to how the computer plays follows
  docs/notes/computer-player.md, "How a play gets in": built switched off, proven in the
  Gym side against side, then switched on in its own pull request. What the game is (its
  levels and modes, and when a client takes a new tag) is Jamie's call.
- `lua5.4 tools/meterprobe.lua [--n 400] [--parts perfect,honest,hand,drill] [--meter kid]
  [--hands 3,2,1]`: the person's meter (or the Kid meter, 0.15) measured at a lone kubb (a
  perfect swing, steady swings inside both bars, the Gym's recorded hand scaled x2, x1 and
  x0.5, or the scales given) and on an inkast spot (docs/notes/throw.md "The person's
  meter", "The Kid meter").
- `node tools/batonvalue.mjs <games dir> [--json] [--tiers]` (`make batonvalue`): the batons a
  position costs, from scored games or the Gym's, beside Hodges' 2014 table, with bootstrap
  intervals and by tier (docs/notes/real-games.md "Baton value").
- `docs/reference/PLAY.md` and `play-levels.json`: how kubb is played at beginner, club
  and pro, with a target range per Gym row and its basis (measured, owner, coach or
  estimate). `node tools/realtiers.mjs <real games dir> --json` reproduces the measured
  block. Guidance for the computer player and the Gym, not a rule.
- The play reference's layers (`docs/reference/README.md`): `sources.json` lists every
  source, `observations/` records what each one says with no conclusions, `plays/` holds
  one choice per situation with the observations behind it, and `QUESTIONS.md` holds what
  sources disagree on and what only Jamie can answer. `make refcheck` (in `make test`)
  fails on a play that cites nothing or an anchor that does not exist. Originals
  (magazine PDFs, transcripts, captions) never go in the repository. Read a phase's plays
  before changing how the computer player decides in it, and name the play in the pull
  request.
- `node tools/watch.mjs <youtube link or id> --kind lesson|match|talk [--transcript]`: a
  video model's account of a public kubb video, saved privately outside the repository
  (`$KUBB_SOURCES/video`), for writing an observation from by hand. It needs
  `GEMINI_API_KEY` in the environment and never prints or stores it
  (docs/reference/README.md, "A video").
- The Kubb Gym (`make gym`, `node tools/gym.mjs`; docs/notes/gym.md): seeded matches by
  the computer and a human thrower fitted from recorded swings, forensics on every throw,
  anomalies with a replay command each, the real-games comparison on one page; `gym
  compare` two refs or scorecards, `gym sweep` one tuning number. Recorded matches are
  private: pass their folder (`--records`, `fit`, `bank`), never copy them into the repo;
  only `tools/gym/human-model.json`'s counts and quantiles live here.

## Notes

`docs/notes/` holds the subsystem notes (rules engine, physics, physics fuzz, the
reference engine, real games, headless games, the throw, the Kubb Gym, the computer
player, scenes, Kid mode, and the Tournament's neighbouring pitches, a design). Read the note before changing
the part it covers. `docs/SESSION.md` is the session's API, `docs/PITCH.md` the pitch's,
`docs/VERSIONING.md` and `docs/DETERMINISM.md` the version rules and the reference
platform, and `docs/CLIENTS.md` what each client (web, iPhone, Playdate) changes to move
from engine 0.9.0 to this release. Code comments also
cite `docs/DESIGN.md` and `docs/PLAYERS.md`, which are in `playdate-kubb`, and the
session's cite `docs/CLIENT.md`, which is in `kubb.thingelstad.xyz`.
