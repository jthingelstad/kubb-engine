# Determinism

An online match stays in step because every client applies the same actions to the same
state and gets the same floats: after each action the session's hash (FNV-1a of the
snapshot text) must be equal everywhere. How the session keeps its own part
deterministic (seeded draws, deterministic JSON, the action path as the remote path) is
in docs/SESSION.md "Determinism". This file is about the platform under it.

## The reference platform is wasm with musl's libm

The physics calls `sin`, `cos`, `atan2`, `sqrt`, `exp` and the like thousands of times a
throw, and libm implementations differ in the last bit. One ulp in a launch angle grows
into a different landing within a few throws.

The reference results are **wasmoon 1.16.0**: Lua 5.4 built to WebAssembly with
Emscripten, whose libm is musl's portable C, and WebAssembly's floating point is IEEE
754 with no fused multiply-add unless asked for. Every browser runs those same bytes, so
the web agrees with itself everywhere. The golden corpus (`tests/golden/hashes.json`) is
generated and checked under it.

A native host (the iPhone app, a native server) that must agree with the web links
musl's generic math functions instead of the system's, built with

    -O2 -ffp-contract=off -U__FP_FAST_FMA -fno-builtin -std=c99

(no contraction into fused multiply-adds, no compiler built-ins in place of the library
calls), and Lua 5.4 itself with `-ffp-contract=off`. It proves itself against the golden
corpus before it plays anyone. The Playdate's 32-bit floats never agree with either; it
plays alone.

## Stock native Lua is for logic tests only

The desktop `lua5.4` links the system libm. The Lua tests (`make test-lua`,
`make test-session`) run on it and check outcomes with tolerances, never against the
golden hashes. `make golden-native` plays the golden matches under it and counts how
many actions agree with the reference. On macOS with Apple's libm (measured 2026-11-17,
engine 0.2.0, 12 matches, 453 actions):

- every match starts on the same hash, and 75 actions agree before each match's first
  difference (the first one is the 4th action of the first match);
- 141 of 453 actions agree index for index (save.pack rounds positions, so a match
  sometimes falls back into step for a while).

The differences are one-ulp results of trigonometric functions, not a bug in the
engine. Other system libms (glibc) are not measured here and need not agree either. So: never share a match between stock native Lua
and wasm, and never regenerate the corpus anywhere but under wasmoon (`make golden`).

## The gate

`make golden-check` (in `make test` and CI) plays `tests/golden/drive.lua`'s twenty-one
matches through `kubbCall`, under wasmoon, and compares the hash after every action with
the corpus. Twelve are computer against computer at club, across the three surfaces,
three winds and both first teams, with the pointer tune and at most six turns each. The thirteenth
(since 0.8.0) is a person against the computer, ten turns on grass: the person's batons
at field kubbs are scripted actions from 0.35, 0.75, 1.25, 1.9 and 2.0 m, on the power
band and then one band long, with the core's own launch (`plan.solve`, `plan.launch`),
so the corpus covers a baton planned under `flight.tune.nearM`, which the computer
never throws; the person's other throws are swings on the dial, and the person raises by
hand, taking the end offered first. The fourteenth and fifteenth (since 0.12.0) cover
raising by side (`match.raisePolicy`): a person whose kubbs the engine raises
(RAISING: AUTOMATIC, so by par) throwing as the thirteenth's does, against the computer
at pro, and the computer at beginner both sides. The sixteenth and seventeenth (since
0.14.0) are on the grid, the eighteenth and nineteenth (since 0.15.0) Kid matches, and the
twentieth and twenty-first (since 0.17.0) have computer players in teams. It passing is what
"hash-neutral" means in docs/VERSIONING.md. The hashes do not depend on the frame time
the host feeds `frame` (1/60 s and 1/4 s give the same corpus).
