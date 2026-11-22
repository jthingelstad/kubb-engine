# Tournament: the neighbouring pitches (a design, not built)

Jamie (2026-11-21): the Tournament scene is "a kubb tournament", "a grid of pitches that
are all live", the only scene with the USA kubb set's colouring, and no championship's
name or logo anywhere. 0.14 ships the scene itself (core/scenes `tournament`: grass, the
`usa` set) with the player's own pitch only. This note is what the engine would offer for
the pitches around it, so the next step can start from it. Nothing here is built.

## What the player sees

The player's pitch in the middle of a grid of pitches (say 3 x 3, the player's in the
centre, or a row either side for a phone held sideways), each with two computer teams
playing a match of their own: batons in the air, kubbs falling, teams walking to inkast,
a king going down and a new match setting out. They are scenery. Nothing on them touches
the player's match, its rules, its snapshot, its actions or its hashes, and a shared
match need not show the same neighbours on two phones (though it can: below).

## What the engine would offer

A small module beside the session, `session/neighbours.lua`, behind its own calls, in a
Lua state of its own on the web (a worker running a second engine) and on the iPhone (a
second `lua_State`), so it can never reach the player's session (`S` in session/api).

- `neighbours.open { seed, count, level, surface, set }`: lays out `count` pitches, each
  a computer-against-computer match (core/match, core/autothrow, core/world: the
  physmatch path, tools/physmatch.lua) seeded from `seed` and its place, at `level`
  (club by default; a mix of levels reads more like a real tournament). Returns `{ pitches
  = [{ id, offset = { x, y }, teams, set }] }`: where each stands relative to the player's
  pitch (pitch spacing a few metres, as a tournament field), and its team names
  (core/namegen: generated names, the same content policy as every other name).
- `neighbours.advance { budgetMs }` (or `{ steps }`, for a host that counts work rather
  than time): runs the neighbours forward. A throw is computed whole before it plays, as
  the player's are (`world.run`, then `core/playback`), but here in slices: each call
  steps the throw in hand at most `budgetMs` of work (the world steps until the clock or
  the step count passes it), so a frame never stalls on a neighbour's throw. A finished
  throw becomes a recording (session/throw's format, `poseScale` 1e5, poses every 1/50 s,
  thinned to every second or third frame for a far pitch) queued with its start time.
  Returns what changed: `{ pitches = [{ id, recording?, items?, phase }] }`.
- `neighbours.view { id }`: a pitch's pieces as they stand (`items`), for a pitch coming
  into view or after a pause.
- `neighbours.close {}`.

The client plays each recording on its own clock (showAt's interpolation, no slow
motion, no cameras) and between throws shows the pitch at rest, the thrower walking
back. When a match ends the pitch starts the next one (`seed + n`). Determinism comes
for free (the core is the same everywhere): two clients that open the neighbours with the
same seed (the match's own, for example) and advance them on the same match clock see the
same throws, so a shared Tournament match can show the same tournament on both phones.
Nothing obliges a client to keep them in step.

## What it costs

Measured on the desktop (an M4, stock Lua 5.4; `tools/physmatch.lua --n 6 --level club`):
473 throws in 2.0 s, about 4 ms a throw with the computer's planning, raising and
inkasting included; a match about 0.3 s. A throw is about 1100 physics steps (half of
them the baton alone in the air, the cheap lone flight; docs/notes/physics.md). Real
play paces a throw every 8 to 15 s of a match (the walk, the aim, the swing, the pieces
settling), so:

- eight neighbours make about one throw a second between them: about 4 ms a second on
  the desktop, under half a percent of one core. Native Lua on an iPhone is the same
  order as the desktop; the web's WebAssembly Lua two to four times slower, so 1 to 2% of
  a core. Sliced at 2 ms a frame, a throw lands within a few frames of being due.
- memory: a world and a match per pitch, tens of kilobytes each; recordings are about
  12 KB of JSON a throw before thinning, dropped once played.
- the drawing costs more than the physics: eight more pitches of pieces, batons and
  teams. A client draws far pitches with fewer details (no shadows, fewer frames).

A cheaper fallback for the far rows: the rules without physics (tools/games.lua's
headless games) decide which kubbs fall on each baton, and the client animates a
standard fall. It looks less real and is not needed at these costs; it stays an option
for an old phone.

## Questions for the next step

- How many pitches and how far apart (a product call; the costs above allow 8 to 12).
- Whether the neighbours follow the player's match clock (pausing when it pauses) or run
  on the wall clock.
- Whether a neighbour's king going down makes a sound or a cheer on the player's pitch.
