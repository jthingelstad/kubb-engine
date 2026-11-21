# Versioning

The engine has one version, `major.minor.patch`, in `version.lua` (`tw.engine.version`,
the API's `engineVersion` call) and in `engine.json`; `make test` fails when they differ.
It names the whole engine: `core/`, `room/`, `session/`, `tune/` and `version.lua`.

## What each part means

- **Major**: a format change. The snapshot (`session.snapshotVersion`), an action's
  shape, or a document format a client stores or sends (the recording, the game file
  the session writes, the room's document in a way an older client cannot read) changes, so an old client cannot read what a new one writes.
  A format change an older client cannot read is a major; fields that only add, inside
  a match pinned to its major.minor, go with the minor.
- **Minor**: anything that can change a hash. Any physics, rules, tune or session change
  that alters what a seeded match does: a constant, an order of operations, a rounding,
  a new random draw. If it is not proven hash-neutral, it is a minor change.
- **Patch**: proven hash-neutral. `make golden-check` (part of `make test` and CI)
  replays the golden corpus, `tests/golden/hashes.json`, under wasmoon and every hash
  matches: comments, docs, tools, tests, refactors that give the same numbers.

A change that moves a golden hash needs a minor bump (or major) and `make golden`, which
rewrites the corpus on purpose, in the same pull request. Never run `make golden` to
make a failing check pass without bumping the version.

## Playing together

A match belongs to the engine major.minor it was started on, for its whole life: its
play, its replay, its embed, its highlight reel, a share's check and its score sheet.
Two clients share an online match only when both carry that engine (and load the same
tune; docs/SESSION.md "Starting"). Patch versions may differ.

The room enforces it: START writes `match.engine` and refuses while a player names
another engine, and a client joining a running match checks with `room.mayPlay`
(docs/ROOM.md "Engines in one match"). When clients carry several engines, the next
match runs on the room's engine, the newest that the host and every player carry
(`room.engineFor`), and a client that carries several speaks down to it so a client
that carries one agrees. Records of a match name the engine it was played on
(`replayOf` carries `engine`), so a replay knows which engine reproduces it.

## Carrying several engines

A client need not carry only one engine. The web carries every minor that kept matches
still need, each at that minor's last tag, byte for byte, and loads only the one a page
needs; the iPhone app carries what its build shipped with, and may bundle the previous
one or two so phones on different builds can play together. How a room picks between
them is the room's (docs/ROOM.md "The room's engine" and "Speaking down").

- **The principle.** A match runs, replays, renders and is checked on its own
  `match.engine`. A client that carries it uses it; one that does not says so, as
  `mayPlay` does. A kept match from an engine no client carries any more falls back to
  the newest engine, with the hash that disagrees noted, as replays always have.
- **The support window.** An engine stays in the set while a kept match may need it:
  rooms and replays are kept a year from the end of their match, so a minor stays until
  a year after the last match started on it ended, and while clients that carry only it
  are still about (an iPhone build in testers' or players' hands). Dropping a minor is a
  client's release, never the engine's.
- **What clients call only grows.** Within the window one client code base drives every
  engine it carries, so from one minor to the next the session's and the room's calls,
  their arguments and their results only gain: no call, field or value a client relies
  on is renamed, removed or changes meaning. A client feature-detects anything newer
  (a call that answers `{"error": "unknown call ..."}`, a field that is absent) and does
  without it on an older engine. The room's document grows the same way: new top-level
  keys only, which `lobbyOf` keeps, because a watcher on another engine writes its own
  seat. A change that cannot keep to this is a major version.

## What a client shows

Every client shows its own version with the engine's beside it, in one form:

    <app version> (<engine version>)        0.9.8 (0.8.1)

- The app's version comes first. The engine's full version (`engineVersion`, read from
  the vendored copy at run time, never typed a second time) is in the parentheses, and
  nothing else is.
- A client that carries several engines shows the newest it carries, the one a new
  match against the computer plays on. Where it shows detail it lists the others after
  the label ("Also plays 0.7.4").
- A platform's build number is not part of the label. Where it is shown it stands
  apart, as "build 114".
- The label is for a person reading the app and for a private feedback report. It is
  never on the room's wire or in a kept match, replay or share: those name only the
  engine the match was played on, and say nothing of which client played.

## Releases and vendoring

- A release is a tag `vX.Y.Z` on `main`, made after the pull request that sets
  `version.lua` and `engine.json` to `X.Y.Z` has merged. Tags are never moved.
- Clients (the Playdate game, the web game, the iPhone app) vendor a tagged release byte
  for byte and never edit their copy: the Playdate takes `core/`; the web and the iPhone
  take the bundle (`make bundle`: one JSON module map of every engine Lua file and its
  sha256) or the files themselves.
- Each client checks its copy against that tag's `engine.json`: a sha256 per file
  (keyed by path, `core/world.lua`) and the bundle's. A fix belongs here, then each
  client moves to the new tag.

## Release notes

- **0.11.3** (patch). The defender's raising by side and two attacking plays for the
  computer, built switched off (docs/notes/computer-player.md, "How a play gets in"):
  - **Raising by side**: `match.settle` raises each kubb with the defender's policy,
    `match.raisePolicy(m, side)`: the computer's by its level (`core/cpu.raising`,
    `cpu.raise`, its reason in `cpu.last` with `kind = "raise"`), a person's by the
    engine's advice (`cpu.advice`), which is also the session's `need.default` for a
    raise by hand (a `raise` action with no choice takes it). The match knows the
    computer's sides from `match.new`'s new `cpu` (a list or set of sides; the session
    passes its own `cpu` option) or, without it, from the mode `Vs Playdate` (Team B);
    `match.new`'s `raising = { A, B }` names a side's policy outright. Neither is saved;
    the mode is. Every level and the advice are `apart`, so every side raises as before.
  - **`field.line`** (`core/cpu` lineChoice, `read.lineLane`): stand on the throwing line
    where the kubbs line up behind the front one, scored by the lane along that line
    (weighed as `raise.par` weighs a pair) times the chance of hitting from there; never
    through the king, past a kubb in front, or within 0.3 m of a field kubb in the
    thrower's own half (II.B.11).
  - **`inkast.depth`** (`core/cpu` depthSpot): lay the kubbs end to end in columns down
    the baton's path, 4 cm apart, four to a column and none nearer the centre line than
    4.35 m, with the row's dead landing and roll.
  - Both plays are in `cpu.tune`, switched by level (`0` at every level) and off entirely
    (`on = 0`); the Gym reaches every number (`--set cpu.tune.line.pro=1`). Neither draws
    from a random stream. `core/plays` has `raise.par`, `field.line` and `inkast.depth`
    with no levels: no level uses them yet. The Gym's plain run, `tools/physmatch.lua`
    and a `versus` team that names no `raise=` raise as the engine raises such a side
    (`apart` here).

  No level uses any of it: the computer throws and raises exactly as on 0.11.2. All 532
  golden action hashes match 0.11.2, `tests/fixtures/cpu/choose.txt` (0.11.0's) still
  passes untouched (`tools/cpufixture.lua` writes it again byte for byte), and
  `tools/physdump.lua`'s output is the same byte for byte. The tests switch each play
  and the raising on inside the test to prove what it does.

  Measured switched on through the Gym, as Jamie decided they are to be enabled (pro
  `par`, club `apart`, beginner `first`, a person `par`; `field.line` and `inkast.depth`
  at pro; docs/notes/gym.md, "Raising by level" and "The attacker's plays"): the pro
  computer with both plays beats the pro without them 79.4% and 79.9% (seeds 1 and 2),
  and beats 0.11.2's pro 79.0% and 81.3%; its field batons that took three or more go
  from 4.9% to 6.8% (the target is 12 to 18). With the plays, `par` and `apart` are level
  at pro, and `par` beats the same-end policies 55 to 57. At club the column wins too
  (58.8%, 62.0%) but moves club away from real play, so it is to stay off at club.
  Switched on, a `par` decision with eight kubbs still lying takes about 0.12 ms in
  desktop Lua (0.001 ms for `apart`), a `field.line` decision at ten standing field kubbs
  about 0.11 ms (0.016 ms without) and a pro `inkast.depth` toss about 0.018 ms (0.003).

  For clients: sync the tag; nothing else changes. The session passes its `cpu` option to
  the core; a client passes nothing new.

- **0.11.2** (patch). A raising policy that counts the attacker's batons,
  `raising.policies.par` (raise.par, raise.across), built switched off: the end that
  leaves the fewest kubbs one behind another on a baton's path, seen straight down the
  pitch and from both ends of the throwing line, with a plan over the kubbs still lying.
  Its numbers are `raising.tune.par*`. A decision with eight kubbs still lying takes about
  0.12 ms in desktop Lua (apart 0.001 ms, the `raising.options` every raise already pays
  0.017 ms), a few hundred pair tests and a dozen small tables. `Game:context` gives each other kubb its `kind`,
  so the policy leaves base kubbs out. Nothing uses `par` yet: `apart` is still every
  level's policy and auto raise's, and all 532 golden action hashes match 0.11.1. The
  Gym's measure is in docs/notes/gym.md, "Raising by the attacker's batons".

  For clients: sync the tag; nothing else changes.

- **0.11.1** (patch). The computer player in the parts its design calls for
  (docs/notes/computer-player.md), with no change in play: `core/read` (the situation:
  the field kubbs near each basket, the lying kubbs near one and the innermost of them,
  the clear spot test, a front kubb's lane), `core/plays` (the three plays 0.11.0
  carries out: `inkast.corner`, `inkast.roll`, `field.roles`) and `core/cpu`
  (`cpu.decide(s, r, level)`: the choices `autothrow.choose` made, in the same order,
  returned as an intent and a reason). `autothrow.choose` keeps its signature and its
  result, and is now `cpu.decide` then the hand; `autothrow.basket` and `autothrow.spot`
  stay as names for `cpu.basket` and `cpu.spot`. Every tune number stays in
  `autothrow.tune`. The reason is not on the throw's table, which reaches the session's
  actions and recordings: the last decision is `cpu.last`. `make refcheck` also checks
  that every id in `core/plays.lua` is a play in `docs/reference/plays/`.
  `tests/fixtures/cpu/choose.txt`, written by 0.11.0, holds every field of
  `autothrow.choose`'s result and the next number of its stream over 480 seeded setups;
  0.11.1 matches it in every field (floats to one part in 10^9, since desktop maths
  libraries differ in a last digit). All 532 golden action hashes match 0.11.0, and
  `tools/physdump.lua`'s output is the same byte for byte.

  For clients: sync the tag; nothing else changes. The core has three more files, all
  imported by `core/autothrow`.

- **0.11.0** (minor). A thrown kubb can land dead and roll, and the three levels throw
  their kubbs in differently (Jamie, 2026-11-21: "Spinning is the key to kubbs touching.
  By spinning they land and then roll into each other"). Every drilled kubb lands
  differently, so the golden corpus is new. A 0.10 match replays differently on 0.11,
  and the room refuses a match between 0.10 and 0.11.

  What a player sees:
  - **The dead landing.** A spun kubb that arrives nose first, on line and not tumbling
    stops where it touches: no bounce, no run-on. One that flies wrong bounces with its
    spin and goes where it goes, as before. A kubb with no taps is never caught.
  - **The roll.** A caught kubb lies down and rolls the way it was spun: on grass about
    5 cm for one tap, 16 for two and 33 for three. Sand rolls less, snow a little more.
  - **The aim counts both.** The marker is where a clean throw rests, whatever its taps
    (`drill.tune.slide` measured again, `drill.tune.roll` new, `drill.rollFor`). A
    one-tap drill at the default arc was aimed 24 cm short for a run-on it no longer has.
  - **The throw level sets the hand.** `plan.levels` has `drillScatter` (beginner 2,
    club 1, pro 0.35): how unsteady the release is, and so how often a kubb is caught.
    A clean pro drill is caught 96 times in 100 and rests 6 cm from its mark; club about
    half the time.
  - **The spiral goes the taps' way.** A left spin is now as steady as a right one. The
    launch's spin for no taps is still +3 rad/s; for any left spin it is 6 rad/s more
    to the left than 0.10 gave.
  - **The computer's inkast goes by its level** (`autothrow.tune.inkast`). Beginner:
    every kubb at the basket, no spin, a loose hand. Club and pro: one tap toward the
    sideline, each kubb laid flank to flank with the last in a row; they differ in the
    hand.
  - A lying kubb that rolls is no longer stopped in a step by the turf
    (`world.tune.kubbSpinHold`), so a struck kubb can roll a little farther.

  The Kubb Gym, 0.10.0 against 0.11.0 (300 matches a configuration; real games beside):

  | computer | beginner | club | pro | real |
  |---|---|---|---|---|
  | lying kubbs touching another after an inkast of 3 or more | 15% to 7% | 17% to 40% | 20% to 66% | |
  | such inkasts with 3 or more touching in a chain | 5% to 2% | 7% to 22% | 12% to 57% | |
  | ... with 5 or more | 0 to 0 | 0.1% to 1.1% | 0.6% to 9.5% | |
  | a drill rests from its mark | 0.28 to 0.53 m | 0.28 to 0.21 m | 0.27 to 0.06 m | |
  | batons that took two | 9.9% to 6.3% | 12.3% to 13.1% | 15.6% to 22.2% | 16% |
  | batons that took three or more | 1.2% to 0.5% | 1.9% to 1.9% | 2.9% to 4.9% | 10% |
  | turns that cleared the field | no change | 70.6% to 73.1% | 67.8% to 77.0% | 83.4% |
  | kubbs rethrown | 1.9% to 4.6% | 2.1% to 1.5% | 2.0% to 0.3% | 14.1% |
  | turns a game | no change | no change | 15.7 to 12.2 | 8.9 |

  The human thrower (it now spins as the computer at its level does): batons that took
  two 8.2% to 10.4% at beginner, 4.2% to 8.5% at club, 2.1% to 4.1% at pro; kubbs
  rethrown 10.3% to 3.7%, 13.1% to 9.3%, 18.7% to 14.2%. No throw failed to settle in
  1800 matches.

  Known gaps:
  - The catch is a rule standing in for turf, not contact physics (docs/notes/physics.md
    "The dead landing").
  - Triples are still short of real play (pro 4.9% of batons against 10%), and a pro's
    6 or 7 kubbs touching is rare (5 or more in 1 inkast in 10). The row lies across the
    throw, and the defender raises each kubb away from its neighbours.
  - Rethrows are far under real play at every level (the hand's worst throws are not
    bad enough).
  - A beginner's unspun kubb rests 16 cm short of its mark on average: the no-spin aim
    was measured with the ordinary hand, not the beginner's.
  - Three taps roll 33 cm, more than "one or two rolls".

  For clients:
  - Sync the tag. Rooms refuse mixed minors, so a client that shares matches carries
    0.11 beside the engines it already carries.
  - A kubb throw's `launch` has a new number, `scatter` (the level's `drillScatter`);
    pass it through as the other launch fields are. `checkThrow` refuses a kubb throw
    whose scatter is not its level's.
  - `world.launchDrill` takes the scatter as its last argument (nil: 1).
  - The spin control's meaning is unchanged (-3 to 3 taps, + rolls right); what is new
    is that the roll is real and aimed for, so a spin control can say so.
  - The Playdate vendors the core only; its drills change with it.

- **0.10.0** (minor). Four fixed assumptions about a throw are replaced by what the
  throw itself is doing (Jamie, 2026-11-20: "arc based on target is just obviously
  wrong"), so the golden corpus is new. A 0.9 match replays differently on 0.10, and the
  room refuses a match between 0.9 and 0.10.

  What a player sees:
  - A baton's default arc goes by how far away the target is, never by what it is. Half
    past 5 at 2 m and under, 4 o'clock at 8 m, a line between (`plan.arcFor(kind, d)`,
    `throw.defaultArc`). A 5 m field throw peaks about waist high. Until now a base kubb
    was lobbed at 3 o'clock from any distance, the king at half past 3 and a field kubb
    at 4 o'clock.
  - A baton's nerves go by how far the throw is, not by how far back the arm went
    (`plan.nervesBack`). A low throw needs more backswing than a lobbed one to the same
    spot; it is no longer a wilder throw for it.
  - A thrown kubb leaves the hand square to the arm: its nose is 90 less the loft below
    the horizontal (`drill.noseFor`), whatever arc was planned. At the default arc that
    is 43 degrees (it was 45); a low drill leaves nose well down and tumbles on more.
  - The aim of a thrown kubb counts its spin (`drill.tune.slide` has a table per spin,
    measured again). A spun kubb stops shorter; on grass from 6 m at the default arc it
    runs on 0.72 m with no spin and 0.17 m with one tap, and until now both were aimed
    0.75 m short.
  - The computer spins every kubb one tap. Its spin went by its level's name
    (beginner none, club one, pro two).

  The Kubb Gym, 0.9.0 against 0.10.0 (300 matches a configuration; real games beside):
  - Computer club: field batons missed 41.7% to 24.1% (real 24.7%); turns that cleared
    the field 54.0% to 70.6% (real 83.4%); a baton taking two 4.7% to 12.3% (real
    16.0%); king shots 74.2% to 91.4% (real 83.8%); kubb groups 1.05 m to 0.32 m from
    their centre; kubbs rethrown 19.4% to 2.1% (real 14.1%); turns a game 22.4 to 17.1
    (real 8.9).
  - The human thrower at club: field batons missed 49.1% to 40.9%.
  - Worse, and open: the computer now drills better than real players (2% rethrown
    against 14%), the pro computer takes a base kubb from an advantage line 80% of the
    time (real 51.7%), and the beginner's batons come down on a kubb's top more often
    (human beginner 13.9% to 19.0% of batons at kubbs).

  Not in this release: a thrown kubb's loft still does not go by its distance. At the
  low arc a real 8 m kubb is thrown on (as high as the player), the engine's kubb lands
  and runs on 1 to 2 m on grass, where real ones stop within 0.3 m. That is the landing
  on grass, and it comes first.

  For clients:
  - Sync the tag. Rooms refuse mixed minors, so the web and the iPhone carry 0.10 next
    to 0.9 for 0.9 matches.
  - `view.aim.controls.arc.default` now moves as the stance or the circle moves, until
    the player sets the arc. Nothing else in the view or the calls changes.
  - `autothrow.tune.drillSpin` is a number, `plan.tune.arc` holds only `drill`, and
    `drill.body`'s fifth argument is the loft, not a loft difference.

- **0.9.0** (minor). Physics and the computer change what a seeded match does, so the
  golden corpus is new (13 matches, 523 action hashes, header 0.9.0). A 0.8 match
  replays differently on 0.9, and the room refuses a match between 0.8 and 0.9.

  What a player sees:
  - A kubb held up by the ground alone comes to rest only on a face, never balanced
    on an edge or a corner.
  - Batons aim lower, at a kubb's body rather than its top (`aimHeightShare` 0.5 to
    0.3), so fewer bounce off the top.
  - The computer steps up to a kubb a step away from the line (`minRange` 2.0 to
    0.25 m) and throws the low, hard point-blank baton.
  - The computer's target label names the kubb it is aiming at.
  - A kubb's spin is kept for the side's next kubb in the inkast turn, and goes when
    the turn ends, the side changes or a match starts. Arc and tilt go back to the
    plan's own at every throw.
  - Tilt, arc and spin take any value in their range, not only the steps.
  - The computer's level (beginner, club or pro) and the scene are match options.
  - The Playdate's match options have no kubb set row. Sets are a web and iPhone look.
  - A save keeps automatic raising for the rest of the match.

  For clients:
  - Sync the tag. Rooms refuse mixed minors, so the web and the iPhone carry 0.9 next
    to 0.8 for 0.8 matches.
  - Web and iPhone: draw the plan's sliders from `view.aim.controls`
    (`{ min, max, value, default, tick, step, unit, scope }`) and call `setArc`,
    `setTilt` or `setSpin` with any value. The step calls are unchanged.
  - Web and iPhone: offer Computer (from `MATCH_OPTIONS`) and a scene, and pass
    `computer` and `scene` to `setOptions` (the same call as the other options) and to
    a solo `newMatch`. In a room they are kept in the document's top-level `settings`,
    not in `options`, so a 0.8 client's lobby write keeps them: read every option, with
    defaults filled in, from the new room call `optionsOf { doc }`, not from
    `doc.options` (docs/ROOM.md difference 9). Club and day,
    the defaults, are not written, so a start without them is unchanged. A scene is an
    id of lowercase letters, digits and hyphens, up to 24 characters
    (`room/lobby.isScene`). Draw `view.scene`, and draw an unknown one as day.
  - A person's throw action now carries `plan` (`{ release, tilt }` or
    `{ release, spin }`). Send the action as `frame` returns it.
  - Playdate: a d-pad tap moves a control one tick (`plan.tune.arcTickDeg`,
    `tiltTickDeg`, `spinTick`); held, it slides a tick a frame, clamped by
    `plan.clampRelease`, `clampTilt` and `clampSpin`.
  - Playdate: keep a kubb's spin for the turn as the session does, or decide not to.
  - Playdate: show the COMPUTER row from `core/matchopts`. Give each computer
    player `opts.computer` as its level, so the game file and a resume carry it.
  - Playdate: drop its SET filter. `matchopts.apply` no longer sets `opts.set`.
  - Playdate: pass `autoRaise` (true, or nil for by hand) to `save.write`. It comes
    back from `save.unpack`, so the side file can go.
  - A client that throws the computer's batons through `autothrow.launch` now gets
    the plan's hand (`handZ`, `handFwd`, `handTip`), as the session throws them.
  - Known gap: `checkThrow` takes a forged `noseDown` on a drill released very early
    or at the sky end (docs/SESSION.md "What a server can prove").

- **0.8.2** (patch). A short baton's plan skips the carries whose answers it already
  has: the aim height's last `speedForCarry` repeated the one made for its answer, and a
  bisection whose ends are neighbouring floats (only a 32-bit float gets there) stops;
  `flight.carry` works its step's constant products out once, grouped as before. About
  10% off `plan.solve` at 1 m on the desktop. Every number `plan.solve`, `flight.handAt`
  and `flight.carry` return is the same as in 0.8.1 bit for bit, on doubles and on 32-bit
  floats: `tests/lua/planref.lua` keeps 0.8.1's plan and the identity tests compare the
  two over 431,516 cases on the desktop and under wasmoon. All 505 reference action
  hashes match 0.8.1 (the corpus keeps its 0.8.0 header).

  For clients: sync the tag; nothing else changes.

- **0.8.1** (patch). Several engines in one room (docs/ROOM.md "Engines in one match",
  "Carrying several engines" above). New room calls: `engineFor` (the room's engine:
  the newest major.minor that the host and every player carry, or null with who is
  missing it), `carried` (what a member's presence says it carries), `announce` (the
  presence a client carrying several sends: `engines`, and `engine` as the room's engine
  marked `+engines`), `speakAs` (the members as a host passes them to its START on the
  room's engine) and `compareEngines`. A client carrying several engines speaks down: it
  announces the room's engine and runs the lobby, START and the match on that engine's
  own calls, so a client carrying one (every earlier release, the iPhone's TestFlight
  build among them) agrees with it unchanged. Nothing else changes: `startCheck`,
  `startMatch`, `mayPlay` and every other call decide exactly as in 0.8.0, `constants`
  is unchanged, and all 505 reference action hashes match 0.8.0 (the corpus keeps its
  0.8.0 header).

  For clients: sync the tag. A client that carries one engine need do nothing; one that
  carries several uses the new calls from its newest engine (they are not in 0.8.0 or
  earlier) and every other call from the engine the room or the match runs on.

- **0.8.0** (minor). A person's baton planned under 2 m (`flight.tune.nearM`, the
  stance to the circle) is now a low, firm bowl: the hand lower and ahead of the feet,
  the baton tipped toward the kubb, the loft flatter, the aim into the kubb's face, an
  arrival turn that comes in flat or end over end rather than end down, and a swing past
  the power target heaving the baton up over the kubb (docs/notes/throw.md "The hand at
  a short throw"). What did not change: every throw planned at 2 m and over, every
  computer throw (the computer never stands nearer than 2 m) and every drilled kubb are
  bit-identical to 0.7.4, and all 437 reference action hashes match it. It is a minor
  version all the same: the action's format is unchanged, and the hand is worked out
  from the action's stance and circle, so a 0.7 client applying a 0.8 player's short
  baton throws it from the feet and falls out of step from that throw on. What it costs:
  the web and the iPhone move to 0.8 together (the room already refuses a match between
  0.7 and 0.8, docs/ROOM.md), and a kept 0.7 match with a person's baton under 2 m
  replays differently on 0.8 from that throw on. The golden corpus gains a thirteenth
  match that throws such batons (docs/DETERMINISM.md "The gate"); its header is 0.8.0.
  `checkThrow` (a server's `checkThrows`) holds a short baton's loft to what
  `plan.launch` gives it, the share and the heave included.

  For clients: sync the tag; no action, snapshot, document or recording format changes,
  and no session call or field is added. `flight.handAt(d)` (new in the core) returns
  five values: the hand's height, how far ahead of the feet it lets go, the share of the
  loft kept, the short throw's share s and the tip; `plan.solve`'s result gains
  `handZ`, `handFwd`, `loftShare`, `handTip` and `nearShare` for a baton. The aim arc
  (`aim.arc`) already starts at the hand and ends where the throw meets the aim; it is
  the planned arc, so it neither tips nor shows a live swing's overpower. A client
  whose own test pins the corpus at twelve matches (the iPhone's `GoldenTests`) needs
  thirteen.

- **0.7.4** (patch). The short words of a resignation (`need.short`, `last.short`) are `"RESIGNED"`: the ruling begins with the team's name
  (`"Riverside resigned: Oak wins"`), so no rule matched and the words were cut to 12
  characters (`"RIVERSIDE RE"`). Words no rule knows are now cut at a word.
  `setClient` returns `{ client, location }` with `location` always the game file's
  Location line (`"Playdate"` when none is given); the web and the iPhone app pass
  `location = "throwingwood.com"`. The location reaches the live sheet, the over card's
  file and a replay's, and is in no snapshot, document or hash. Output only: no throw,
  action, snapshot, document or file format changes, and all 437 reference action
  hashes match 0.7.3.

- **0.7.3** (patch). A server checking a shared match in one pass (`replayLoad` with
  `document`) no longer measures the whole room document on every action. The log
  budget's measure, the document's size counted as the room counts it, is now worked out
  as the size with an empty log plus each entry's size, kept once measured, plus the
  commas between them (`lobby.docSize`), which is the same number exactly: every piece of
  the text starts and ends on an ASCII character. The cost of `document` had grown with
  the square of the match's length (a 400-action match took several times as long as
  the replay without it). No throw and no document changes: the log is dropped at the
  same action as before, live play and the room's `commitAction` call measure as they
  did, and all 437 reference action hashes match 0.7.2.

- **0.7.2** (patch). What a server needs to check and publish a shared match against
  the computer (docs/SESSION.md "What a server can prove"): `replayLoad` options
  `checkCpu` (the computer's throws made again from the snapshot; `forged`, `forgedAt`),
  `checkThrows` (a person's throws held to bounds worked out from the code;
  `outOfBounds`, `outOfBoundsAt`) and `document`, with `replayFinish`,
  `replayDocument`, `refusedAt` and standing counts per step; `checkThrow`,
  `checkStart` and `renameStart`. Rulings carry codes beside their words. The wide view
  also un-turns a recording's landing, rest and first hit. `setClient` takes a
  `location` for the game file's Location line (default `"Playdate"`, as before).
  Snapshots, actions and recordings keep their shape (fields only added). All 437
  reference action hashes match 0.7.1.

- **0.7.1** (patch). The game file writes fewer player names: no prefix on a throw by a
  one-player team, and the player's initial (or the shortest start that tells two apart)
  on a team of more, with `[Team X Players]` and `[Throw Levels]` naming the same ids.
  Only the rendered file changes; game state, snapshots and saved history keep the full
  ids, and older files still read. All 437 reference action hashes match 0.7.0.

- **0.7.0**. Retires the straight-through practice input and its three exercises. The crank, pointer dial and touch pendulum follow the 0.5.1 throw model.

- **0.6.0**. A straight-through input and three practice exercises. Existing match actions retain their physics and wire format.

- **0.5.1** (patch). A compact practice checkpoint replays the reported throw,
  including accumulated wood and its surface. All 437 reference action hashes match 0.5.0.

- **0.5.0**. Baton rotation follows the thrower’s level. Skilled computer players add
  drill spin. Slow contact wakes resting pieces. These changes alter match hashes.

- **0.4.1** (patch). Optional dial band crossings, contact strengths and baton ground
  landings for presentation. The 453 reference action hashes and wire formats are unchanged.
- **0.4.0** (minor, additive input API). A touch pendulum feeds the existing swing at
  120 Hz. Human throw actions, recordings and crank traces can carry optional tuning
  metadata. Existing actions and snapshots remain readable. As with 0.3.0, the new
  engine capability gets a minor version. All 453 reference action hashes are unchanged.
- **0.3.0** (minor: a new API, hash-neutral). The room (`room/`, docs/ROOM.md): the web's
  online-play logic (`src/net/lobby.js`, `seats.js`, `sync.js`) in Lua behind
  `kubbCall("room.<name>")`, proven equal to the JavaScript by recorded vectors; START
  stamps `match.engine` and refuses a different engine. `json.decode(text, true)` keeps
  nulls and empty objects (the plain decode is unchanged). A snapshot restored while
  raising, placing a punishment kubb or after the end now shows the match's pitch, in the
  frame a live session shows it in, instead of the practice layout (display only). Every golden hash is
  unchanged.
- **0.2.0**: the engine extracted from playdate-kubb and the web's session.
