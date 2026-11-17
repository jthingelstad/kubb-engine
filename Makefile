# The Kubb Engine: desktop targets. Lua 5.4 and Node (`npm ci` first, for wasmoon);
# nothing else for `make test`.

LUA  ?= lua5.4
NODE ?= node
# pk-kubb-score (for realgames and sync-notation): $PK_KUBB_SCORE, else a sibling checkout.
PKSCORE := $(or $(PK_KUBB_SCORE),$(CURDIR)/../pk-kubb-score)

# The web's online-play modules (for room-vectors): $KUBB_WEB, else a sibling checkout.
KUBB_WEB ?= $(CURDIR)/../kubb.thingelstad.xyz

.PHONY: test test-lua test-session test-room room-vectors test-node test-wasm golden-check golden golden-native bundle manifest manifest-check games realgames physfuzz mjref sync-notation clean

test: test-lua test-session test-room test-node test-wasm golden-check manifest-check

# The core's tests, then the session's in a Lua state of their own: the session's
# tests load the pointer tune, which changes the core's swing and autothrow tables.
test-lua:
	"$(LUA)" tests/lua/run.lua

test-session:
	"$(LUA)" tests/lua/run.lua tests/lua/session/test_*.lua

# The room's calls (docs/ROOM.md) under desktop Lua: the web's unit tests ported, the
# deliberate differences, and every committed vector in tests/room/vectors/.
test-room:
	"$(LUA)" tests/lua/run.lua tests/lua/room/test_*.lua

# Rewrite tests/room/vectors/ from the web's JavaScript at KUBB_WEB (read only). Pass
# WEB_COMMIT=<sha> for an export that is not a git checkout; then set engine.json's
# roomFrom.commit to the same commit.
room-vectors:
	"$(NODE)" tools/room-vectors.mjs --web "$(KUBB_WEB)" $(if $(WEB_COMMIT),--commit $(WEB_COMMIT))

test-node:
	"$(NODE)" tests/node/notation-gate.mjs tests/fixtures/games
	"$(NODE)" tests/node/gate-rejects.mjs
	"$(NODE)" tools/realgames.mjs tests/fixtures/games tests/fixtures/games > /dev/null

# The session under wasmoon (the reference platform), loaded from the bundle.
test-wasm:
	"$(NODE)" --test tests/node/*.test.mjs

# The golden hashes (docs/DETERMINISM.md): tests/golden/drive.lua's matches under
# wasmoon must give every hash in tests/golden/hashes.json. A change that moves one
# needs a minor version bump and `make golden`, which rewrites the corpus on purpose.
# `make golden-native` plays the same matches under desktop Lua and says how many
# actions agree: stock native Lua is for logic tests only.
golden-check:
	"$(NODE)" tests/golden/golden.mjs --check

golden:
	"$(NODE)" tests/golden/golden.mjs --write

golden-native:
	@mkdir -p build
	"$(LUA)" tests/golden/native.lua > build/golden-native.json
	"$(NODE)" tests/golden/golden.mjs --compare build/golden-native.json

# The engine as one artifact: build/kubb-engine-sources.json and its .sha256.
bundle:
	"$(NODE)" tools/bundle.mjs

# engine.json: a sha256 per engine Lua file and for the bundle, the version (checked
# against version.lua). `make manifest` rewrites the hashes after an intended change;
# `make manifest-check` (part of `make test`) fails on a mismatch.
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
