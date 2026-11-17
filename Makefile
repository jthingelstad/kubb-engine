# The Kubb Engine: desktop targets. Lua 5.4 and Node; nothing else for `make test`.

LUA  ?= lua5.4
NODE ?= node
# pk-kubb-score (for realgames and sync-notation): $PK_KUBB_SCORE, else a sibling checkout.
PKSCORE := $(or $(PK_KUBB_SCORE),$(CURDIR)/../pk-kubb-score)

.PHONY: test test-lua test-node manifest manifest-check games realgames physfuzz mjref sync-notation clean

test: test-lua test-node manifest-check

test-lua:
	"$(LUA)" tests/lua/run.lua

test-node:
	"$(NODE)" tests/node/notation-gate.mjs tests/fixtures/games
	"$(NODE)" tests/node/gate-rejects.mjs
	"$(NODE)" tools/realgames.mjs tests/fixtures/games tests/fixtures/games > /dev/null

# engine.json: a sha256 per core file. `make manifest` rewrites it after an
# intended core change; `make manifest-check` (part of `make test`) fails on a mismatch.
manifest:
	"$(NODE)" tools/manifest.mjs write

manifest-check:
	"$(NODE)" tools/manifest.mjs check

# Headless games: GAMES_N seeded random games through the rules engine
# (tools/games.lua, no physics) into build/games, then the notation gate over
# all of them. Then PHYS_N matches with real physics (tools/physmatch.lua) into
# build/physgames, gated the same way. Same seed, same files.
GAMES_N    := 500
GAMES_SEED := 1
PHYS_N     := 5

games:
	@rm -rf build/games build/physgames
	"$(LUA)" tools/games.lua --n $(GAMES_N) --seed $(GAMES_SEED) --out build/games
	"$(NODE)" tests/node/notation-gate.mjs build/games
	"$(LUA)" tools/physmatch.lua --n $(PHYS_N) --seed $(GAMES_SEED) --out build/physgames
	"$(NODE)" tests/node/notation-gate.mjs build/physgames

# Real games against the engine's own (tools/realgames.mjs, docs/notes/real-games.md):
# REAL_N physics matches into build/realgames, then the same figures from them
# and from the games people scored in a pk-kubb-score checkout (read only).
# Optional: needs that checkout, so it is not part of `make test` or CI.
REAL_N       := 150
REAL_SEED    := 2
REAL_SCATTER := 1
REAL_LEVEL   := pro

realgames:
	@test -d "$(PKSCORE)/games" || { echo "realgames: no games folder in a pk-kubb-score checkout (set PK_KUBB_SCORE)"; exit 1; }
	@rm -rf build/realgames
	"$(LUA)" tools/physmatch.lua --n $(REAL_N) --seed $(REAL_SEED) --scatter $(REAL_SCATTER) --level $(REAL_LEVEL) --out build/realgames
	"$(NODE)" tools/realgames.mjs "$(PKSCORE)/games" build/realgames

# The physics fuzzer (tools/physfuzz.lua, docs/notes/physics-fuzz.md). A
# measuring tool, not part of `make test`; its pinned cases are.
N       := 2000
SEED    := 1
SURFACE := Grass

physfuzz:
	"$(LUA)" tools/physfuzz.lua --n $(N) --seed $(SEED) --surface $(SURFACE)

# The reference-engine comparison (tools/mjref, docs/notes/reference-engine.md).
# Optional: MJPY is a Python with mujoco and numpy (python3 -m venv <dir>, then
# <dir>/bin/pip install mujoco numpy; make mjref MJPY=<dir>/bin/python).
MJPY  ?= python3
MJREF := build/mjref

mjref:
	@mkdir -p $(MJREF)
	"$(LUA)" tools/mjref/export.lua $(MJREF)
	"$(LUA)" tools/mjref/ours.lua $(MJREF)
	"$(MJPY)" tools/mjref/mjsim.py $(MJREF)
	"$(MJPY)" tools/mjref/compare.py $(MJREF)

# Refresh the vendored notation parser and scorer from a pk-kubb-score checkout,
# then show what changed. Review, run `make test` and `make games`, commit.
sync-notation:
	cp "$(PKSCORE)/site/assets/notation-parser.js" "$(PKSCORE)/site/assets/kubb.js" tests/vendor/pk-kubb-score/
	git --no-pager diff --stat -- tests/vendor/pk-kubb-score

clean:
	rm -rf build
