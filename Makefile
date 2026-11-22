# The Kubb Engine: desktop targets. Lua 5.4 and Node (`npm ci` first, for wasmoon);
# nothing else for `make test`.

LUA  ?= lua5.4
NODE ?= node
# pk-kubb-score (for realgames and sync-notation): $PK_KUBB_SCORE, else a sibling checkout.
PKSCORE := $(or $(PK_KUBB_SCORE),$(CURDIR)/../pk-kubb-score)

.PHONY: names names-check test test-lua test-session test-pitch test-node test-wasm golden-check golden golden-native bundle manifest manifest-check refcheck games realgames batonvalue physfuzz gym mjref sync-notation clean

test: test-lua test-session test-pitch test-node test-wasm golden-check manifest-check refcheck names-check

# The core's tests, then the session's in a Lua state of their own: the session's
# tests load the pointer tune, which changes the core's swing and autothrow tables.
test-lua:
	"$(LUA)" tests/lua/run.lua

test-session:
	"$(LUA)" tests/lua/run.lua tests/lua/session/test_*.lua
	"$(LUA)" tests/lua/run.lua tests/lua/session/direct/test_*.lua

# The pitch's calls (docs/PITCH.md) under desktop Lua: the web's unit tests ported, the
# deliberate differences, and every vector in tests/pitch/vectors/ (a frozen corpus).
test-pitch:
	"$(LUA)" tests/lua/run.lua tests/lua/pitch/test_*.lua

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

# Every generated name (core/namegen, docs/NAMES.md): `make names` writes
# tests/names/<kind>.txt from core/namewords, so a pull request that changes the
# words shows every name it adds or takes away; `make names-check` (part of
# `make test`) fails while the files and the words disagree.
names:
	"$(LUA)" tools/names.lua --write

names-check:
	"$(LUA)" tools/names.lua --check

# The play reference (docs/reference/README.md): every play cites an entry that exists,
# every observed source has its observation, every question a play names is asked.
# It reads docs/reference and changes nothing.
refcheck:
	"$(NODE)" tools/refcheck.mjs

# Headless games: GAMES_N seeded random games through the rules engine
# (tools/games.lua, no physics) into build/games, then the notation gate over
# all of them (every fourth by the Kid rules, 0.15.0). Then PHYS_N matches with real
# physics (tools/physmatch.lua) into build/physgames, and PHYS_N Kid matches with the Kid
# computer into build/physgames-kid, gated the same way, and PHYS_N with computer players
# in teams at mixed levels (0.17.0) into build/physgames-mixed. Same seed, same files.
GAMES_N    := 500
GAMES_SEED := 1
PHYS_N     := 5

games:
	@rm -rf build/games build/physgames build/physgames-kid build/physgames-mixed
	"$(LUA)" tools/games.lua --n $(GAMES_N) --seed $(GAMES_SEED) --out build/games
	"$(NODE)" tests/node/notation-gate.mjs build/games
	"$(LUA)" tools/physmatch.lua --n $(PHYS_N) --seed $(GAMES_SEED) --out build/physgames
	"$(NODE)" tests/node/notation-gate.mjs build/physgames
	"$(LUA)" tools/physmatch.lua --n $(PHYS_N) --seed $(GAMES_SEED) --rules kid --level kid --out build/physgames-kid
	"$(NODE)" tests/node/notation-gate.mjs build/physgames-kid
	"$(LUA)" tools/physmatch.lua --n $(PHYS_N) --seed $(GAMES_SEED) --mixed --out build/physgames-mixed
	"$(NODE)" tests/node/notation-gate.mjs build/physgames-mixed

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

# Baton value (tools/batonvalue.mjs, docs/notes/real-games.md "Baton value"): the batons a
# position costs, counted from the games people scored in a pk-kubb-score checkout (read
# only), for all teams and by tier, beside Hodges' 2014 table. Optional, like realgames.
# On the Gym's games: node tools/batonvalue.mjs <gym --out dir>/cpu-pro-grass/games
batonvalue:
	@test -d "$(PKSCORE)/games" || { echo "batonvalue: no games folder in a pk-kubb-score checkout (set PK_KUBB_SCORE)"; exit 1; }
	"$(NODE)" tools/batonvalue.mjs "$(PKSCORE)/games" --tiers

# The physics fuzzer (tools/physfuzz.lua, docs/notes/physics-fuzz.md). A
# measuring tool, not part of `make test`; its pinned cases are.
N       := 2000
SEED    := 1
SURFACE := Grass

physfuzz:
	"$(LUA)" tools/physfuzz.lua --n $(N) --seed $(SEED) --surface $(SURFACE)

# The Kubb Gym (tools/gym.mjs, docs/notes/gym.md): seeded matches by the computer
# and the human thrower, every throw's forensics, the anomalies, the real-games
# comparison on one page. A measuring tool, not part of `make test`. GYM is passed
# through: make gym GYM="--full --json build/gym.json".
GYM ?=

gym:
	LUA="$(LUA)" PK_KUBB_SCORE="$(PKSCORE)" "$(NODE)" tools/gym.mjs $(GYM)

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

# Refresh the vendored notation parser, canonical writer and reader from a release
# of pk-kubb-score: the files as they are at tag PKTAG (default: the checkout's latest
# tag), whatever its working tree holds, and SOURCE records the tag and its commit.
# Then show what changed. Review, run `make test` and `make games`, commit.
PKTAG ?= $(shell git -C "$(PKSCORE)" describe --tags --abbrev=0 2>/dev/null)
PKVENDOR := tests/vendor/pk-kubb-score

sync-notation:
	@test -n "$(PKTAG)" || { echo "sync-notation: no release tag in $(PKSCORE) (set PKTAG)"; exit 1; }
	git -C "$(PKSCORE)" show "$(PKTAG):site/assets/notation-parser.js" > $(PKVENDOR)/notation-parser.js
	git -C "$(PKSCORE)" show "$(PKTAG):site/assets/canonical.js" > $(PKVENDOR)/canonical.js
	git -C "$(PKSCORE)" show "$(PKTAG):site/assets/kubb.js" > $(PKVENDOR)/kubb.js
	echo "$(PKTAG)" > $(PKVENDOR)/SOURCE
	git -C "$(PKSCORE)" rev-parse "$(PKTAG)^{commit}" >> $(PKVENDOR)/SOURCE
	git --no-pager diff --stat -- $(PKVENDOR)

clean:
	rm -rf build
