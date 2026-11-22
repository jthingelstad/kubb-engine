# Tournament: the neighbouring pitches

Jamie (2026-11-21): the Tournament scene is "a kubb tournament", "a grid of pitches that
are all live", the only scene with the USA kubb set's colouring, and no championship's
name or logo anywhere. 0.14 shipped the scene itself (core/scenes `tournament`: grass, the
`usa` set) with the player's own pitch only. 0.15.1 builds the pitches around it:
`session/neighbours.lua`, behind `kubbCall("neighbours.<name>")`. The calls and their
shapes are docs/SESSION.md "Neighbours"; what each client does is docs/CLIENTS.md "0.15.1
on top". This note is why it is built the way it is, and what it costs.

## What the player sees

The player's pitch in the middle of a field of pitches (the ring of 8 round it in a 3 x 3
grid by default, up to 24; or a row either side, which the clients do not use: the thrower's camera does not see it), each with two
computer teams playing a match of their own: batons in the air, kubbs falling, teams
walking to the other end, kubbs being raised, a king going down, and after a pause a new
pair of teams setting out. They are scenery. Nothing on them touches the player's match,
its rules, its snapshot, its actions or its hashes, and a shared match need not show the
same neighbours on two phones (though it can: open them with the match's seed).

## How it is built

- **A Lua state of its own.** The web runs a second engine in a worker, the iPhone a
  second `lua_State`, both from the same bundle. One set of neighbours per state (`F` in
  session/neighbours, as `S` is the session's). The module keeps nothing the session
  reads: its matches, worlds, random streams and recordings are its own. The tests go
  further and run neighbours beside a session in one state: the session's snapshots and
  recordings do not move.
- **The physmatch path.** Each pitch plays whole matches as `tools/physmatch.lua` does:
  `core/match` set up by the engine (raising and punishment kubbs automatic, by each
  side's level: `cpu.raise`), `core/autothrow` choosing every throw at the team's level,
  `core/world` run to rest through `core/playback`. The computer plays as it does
  against a person: no cheaper choices were needed (below).
- **Slices by coroutine.** Each pitch's work is a coroutine: set up, choose, simulate,
  record, rule, schedule. It checks the budget before every unit of work (each physics
  step, the set-up, each raise decision, the choice, each recorded body, the encoding,
  the ruling) and yields when the unit would not fit. Two places inside the core would
  otherwise run long without a checkpoint, so the core gained two hooks, nil by default
  and changing nothing when nil: `m.run` (core/match runs the world that settles standing
  pieces with it; the neighbours step it one checkpoint at a time, the same steps in the
  same order) and `raising.probe` (called before each spot core/raising's crowded-corner
  search tries; set only while a pitch's coroutine runs). Before the probe, that search
  was one unit of 10 ms in desktop Lua and 13 ms under wasmoon, once in about 2000 throws.
- **The budget.** `advance { now, budgetMs }` measures by the host's clock: a global
  `__kubbClock()` the host defines in the state, in milliseconds, as it defines
  `__kubbSource` (no `os.*`). Each kind of unit keeps its recent worst cost (a physics
  step the last step's, since a step costs about what the one before did); a unit starts
  only if 1.5 times that is left; a single reading more than three times the estimate (a
  pause of the host's or a garbage collection) moves it only that far, so one hiccup
  cannot stall the field; and the time the answer takes to encode is held back from the
  next budget (at most a quarter of it). The first unit of a call always runs, so any
  budget makes progress. `advance { now, steps }` counts work instead (a step 1, a choice
  6, ...): exact as a count, not a time.
- **Paced like real play, on the host's clock.** Every time is on the clock the host
  passes as `now`; nothing reads a clock of its own for the pace. The pace is drawn from
  each match's own stream (`neighbours.tune.pace`):

  | | seconds |
  | --- | --- |
  | a baton to the next baton, start to start | 8 to 15 (at least 3 after the last came to rest) |
  | a kubb thrown in to the next | 6 to 10 |
  | the turn's last throw at rest to the next turn's first (the walk) | 20 to 30 |
  | the last kubb thrown in at rest to the first baton (the raise) | 12 to 20 |
  | the king down to the next match setting out | 40 to 60 |
  | setting out to the first throw | 15 to 25 |
  | open to each pitch's first throw (so the field does not start together) | 1 to 20 |

  Measured over three hours of eight pitches (seed 5): a baton every 11.5 s on average
  (8.0 to 15.0), a kubb thrown in every 8.0 s, the walk 26.7 s from throw to throw, the
  raise 17.7 s; a recording lasts 1.5 s (0.4 to 3.5). A match lasts 14 minutes at the
  median (3 to 65; one still going at turn 40 is resigned) and 60 throws. Each pitch
  throws about every 14 s overall, so eight make a throw every 1.7 s between them.
- **One throw ahead.** A pitch computes its next throw as soon as the one before starts
  to show, so a throw is ready long before it is due; an event is given out once its time
  has come (`at <= now`). If the work falls behind (a budget far too small), the throw comes
  when it is ready with the time it was due, and `late` says so. A jump of the host's clock
  of more than 30 s between calls (the app was asleep) moves every pitch's schedule on by
  the jump.
- **Deterministic.** What a pitch shows and when comes from the seed and the sequence of
  `now` values alone, never from how the work was sliced: the tests give the same events,
  byte for byte, from slices of 8 steps, 60, 300, whole throws and a clock budget, two
  engines agree, and one seed's events are pinned by their hash under wasmoon (the
  reference platform; the iPhone matches it with musl's math, docs/DETERMINISM.md).
- **Light on the wire.** A neighbour's recording is the session's cut to what a far pitch
  needs: only the bodies that moved, a pose every `thin / 50` s (default 2: 25 a second),
  integers at a `poseScale` of 1000 (the millimetre; 0.001 of a quaternion), each body's
  track ended at its last pose that changes, the recording ended at the last frame
  anything moves, and no items, cameras, bursts, slow motion or ruling (the client already
  holds the pitch's items). Between throws an `aim` beat carries items only when the pitch
  changed.
- **Names and levels.** Each match draws two team names from `core/namegen` (the engine's
  content policy) and each team's level from the mix, by default beginner 3, club 5, pro
  2 (an open tournament: most club players, some newcomers, a few strong teams); Kid is
  refused, since a neighbour plays the standard rules. Team sizes are 3 to 6.
- **Any scene.** `open` takes the scene, surface and set as `new` does since 0.14, the
  scene deciding (default Tournament: grass, `usa`).

## Departures from the design

The design (this note before 0.15.1) is built as drawn, with these changes:

- **Events, not a list of pitches.** `advance` returns `events`, each a beat on one pitch
  with its time (`throw`, `aim`, `walk`, `raise`, `over`, `setup`), rather than
  `{ pitches = [{ id, recording?, items?, phase }] }`. A pitch can have two things due in
  one call (a throw and the walk after it, or many after a pause), and the beats between
  throws are what lets a client draw the walk and the raise at the right moment.
- **The pitch frame.** Everything is in the neighbour's own pitch frame (Team A's), not a
  thrower's view frame, so a client never turns a pitch from throw to throw; it turns the
  whole field only when the player's own view is Team B's.
- **The host's clock for the budget.** The design said the world steps "until the clock
  passes" the budget; with no `os.*` that clock is the host's `__kubbClock`.
- **A recording without items.** The design kept the session's format, thinned. The items
  (1.3 KB) are left out: the client holds them from the last beat, and a recording of a
  baton is 1.7 KB instead of 3 KB.
- **No cheaper choices.** The design allowed the computer cheaper choices if its
  planning could not be sliced; measured, no single unit of it is over about 1 ms under
  wasmoon once the crowded-corner search yields, so the neighbours play exactly as the
  computer does.

## What it costs

Measured on an M-class Mac under load from other work (so the worst cases include the
host's own pauses), eight pitches unless said, 20 minutes of clock in 1/60 s frames, seed
5. wasmoon is the web's Lua (1.16.0) in Node; stock is desktop Lua 5.4, which a native
iPhone build is of the same order as.

| | budget | mean call | 99.9% of calls under | worst call |
| --- | --- | --- | --- | --- |
| wasmoon | 2 ms | 0.08 ms | 2.0 ms | 2.1 to 2.4 ms (two runs of seven: a 49 and an 80 ms pause of the host's) |
| wasmoon | 1 ms | 0.08 ms | 1.0 ms | 1.5 ms |
| wasmoon, 24 pitches | 2 ms | 0.18 ms | 2.05 ms | 2.5 to 3.0 ms |
| wasmoon | 100 steps | 0.07 ms | 3.8 ms | 16 ms |
| stock | 2 ms | 0.06 ms | 2.0 ms | 2.2 ms |
| stock | 1 ms | 0.06 ms | 1.0 ms | 1.4 ms |
| stock, 24 pitches | 2 ms | 0.13 ms | 2.0 ms | 2.2 ms |
| stock | 100 steps | 0.05 ms | 2.9 ms | 9.1 ms |

What the engine spends inside the budget kept to it (the largest call measured by the
host's clock inside the engine was within 0.1 to 0.5 ms of the budget, the rest the host's
call and its own pauses). A step count is exact as a count but not a time: use `budgetMs`
where frames matter.

The units under wasmoon (eight pitches, 688 throws): a physics step 0.011 ms on average,
0.53 at most; the computer's choice 0.10 (0.64); a set-up 0.18 (0.92); a raise decision
0.13 (1.0); a recorded body 0.02 (0.54); a recording's encoding 0.14 (0.79); the ruling
0.05 (0.55). A throw is about 430 steps, so about 5.4 ms of work under wasmoon; eight
pitches use about 4.8 ms a second, half a percent of a core, and 24 about 11 ms a second.
`open` takes 5 ms for eight pitches and 12 ms for 24 (each first throw set up, not
sliced).

Memory (wasmoon, the Lua heap after a full collection): the engine alone 1.0 MB, with
eight pitches running 1.6 to 1.7 MB, with 24 2.6 MB. A pitch keeps only the recording showing.

Recordings (JSON as sent): 1.7 KB a throw on average and 4.4 to 4.6 KB at most at `thin`
2; 3.1 KB (5.9 at most) at `thin` 1; 1.2 KB (2.3) at `thin` 3. The session's own
recording of a baton is about 12 KB. An `items` list is 1.3 KB. Eight pitches send about
60 KB of recordings and 40 KB of items a minute.

The drawing costs more than all of this: eight more pitches of pieces, batons and teams.
A client draws far pitches with less (no shadows, the set's colours, people as simple
figures).

## Still open

- How many pitches and how far apart is a product call: the costs allow 24; the default
  is the ring of 8.
- Whether a neighbour's king going down makes a sound or a cheer on the player's pitch
  (the `over` event is there for it).
- The field opens with every match at its start (staggered by up to 20 s). Opening part
  way through matches would mean playing them forward first, about 0.3 to 1 s of work a
  pitch, so it is not done; after the first match each pitch's next starts at its own time.
