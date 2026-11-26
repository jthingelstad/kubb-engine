# Versioning

The engine has one version, `major.minor.patch`, in `version.lua` (`tw.engine.version`,
the API's `engineVersion` call) and in `engine.json`; `make test` fails when they differ.
It names the whole engine: `core/`, `pitch/` (`room/` before 0.13), `session/`, `tune/` and `version.lua`.

## What each part means

- **Major**: a format change. The snapshot (`session.snapshotVersion`), an action's
  shape, or a document format a client stores or sends (the recording, the game file
  the session writes, the pitch's document in a way an older client cannot read) changes, so an old client cannot read what a new one writes.
  A format change an older client cannot read is a major; fields that only add, inside
  a match pinned to its major.minor, go with the minor. A major may also be declared:
  the owner names a release the next major with no format change (1.0.0, 2026-11-22: the
  released engine, the one the App Store build ships). A declared major is a minor in all
  else: it may move hashes, it shares no match with the minor before it (a match is
  shared on the same major.minor), and what clients call only grows across it.
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

The pitch enforces it: START writes `match.engine` and refuses while a player names
another engine, and a client joining a running match checks with `pitch.mayPlay`
(docs/PITCH.md "Engines in one match"). When clients carry several engines, the next
match runs on the pitch's engine, the newest that the host and every player carry
(`pitch.engineFor`), and a client that carries several speaks down to it so a client
that carries one agrees. Records of a match name the engine it was played on
(`replayOf` carries `engine`), so a replay knows which engine reproduces it.

## Carrying several engines

A client carries an engine only while we have decided it is supported, never because it
was once released (the owner, 2026-11-21: "We should only support engines that we decide
are worth supporting not just ones that have published so that we can push players to
the new engines"). **The supported set today is the engines of the builds people have.**
The web carries its own engine, the newest, and those of the current App Store,
TestFlight Beta and TestFlight Dev builds of the iPhone app, four at most (the owner,
2026-11-22: "Web will support the CURRENT App Store release and the CURRENT Test Flight
Dev and Beta releases. At most the web will support those three versions and whatever
version it is running natively."; the web's docs/ENGINES.md keeps the table of those
builds). An iPhone build carries the newest alone, and the Playdate shares no match.
From 2026-11-21 until then the set was the newest minor alone. The machinery
below lets a client carry more than one, each at that minor's last tag, byte for byte,
and load only the one a page needs; it is not a promise to keep any engine past that
rule. How a pitch picks between engines is the pitch's (docs/PITCH.md).

- **The principle.** A match runs, replays, renders and is checked on its own
  `match.engine`. A client that carries it uses it; one that does not says so, as
  `mayPlay` does. A kept match from an engine a client no longer carries is not
  replayed on another: the client says it was made on an older version.
- **The supported set is a decision.** An engine is in it because we said so, and leaves
  when we say so: not when the last kept match on it has aged out, and not while some
  superseded build is still in someone's hands (the current App Store and TestFlight
  builds are the ones the rule above keeps an engine for). A player on a client with no supported engine
  in common is told to update (`engineFor`'s `missing`), and a kept match or replay from
  an engine no longer carried says it was made on an older version and cannot be
  replayed. Dropping a minor is a client's release, never the engine's. (Until
  2026-11-21 the rule was a window: a minor stayed a year after its last match. That is
  gone.)
- **What clients call only grows.** One client code base drives every
  engine it carries, so from one minor to the next the session's and the pitch's calls,
  their arguments and their results only gain: no call, field or value a client relies
  on is renamed, removed or changes meaning. A client feature-detects anything newer
  (a call that answers `{"error": "unknown call ..."}`, a field that is absent) and does
  without it on an older engine. The pitch's document grows the same way: new top-level
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
  never on the pitch's wire or in a kept match, replay or share: those name only the
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

- **1.3.0** (minor; draft, the person's meter part). The honest person's meter (the
  owner, 2026-11-26: "no nerves for people, the release pulls batons and kubbs, release bar
  5 at 8 m", "Easy/Standard/Hard player levels as bar widths"; docs/notes/throw.md "The
  honest meter (1.3.0)").
  - **No nerves on a person's throw**: `nervesDeg`, `nervesLen`, `tumbleSd` 0 on the
    person's meters, so the same swing gives the same throw. The Kid meter and the
    computer's levels keep theirs.
  - **The release bar** at 8 m is 5 degrees either side (was 7.5); the power bar is
    unchanged.
  - **The release pulls inside its bar** (`edgeM` 0.05: 5 cm at the throw's distance at
    the bar's edge), and **a thrown kubb is pulled** too (`kubbPull` 0.15, inside a bar
    `kubbInGain` 0.3). A perfect swing and a steady swing inside both bars still fell a
    lone kubb at 4, 6 and 8 m; the recorded hand now sits on club's row (70 / 50 / 28 at
    4 / 6 / 8 m, was 76 / 62 / 44).
  - **Easy, Standard and Hard for a person**: a player entry's `throw` (`"easy"`,
    `"standard"`, `"hard"`; absent is standard), the meter that person throws on, wider or
    narrower bars only. Kept in the start only when not standard; carried by the pitch as
    `me.throw` into `lineup` and `matchOptions`; written in `[Throw Levels]` as
    `<id> easy` or `<id> hard`; `newPractice` takes it. `pitch.constants` has
    `THROW_LEVELS`.
  - **`checkThrow`** models the edge and kubb pulls exactly, and with no nerves pins a
    person's swivel, speed and tumble to the swing within rounding.
  - **Golden hashes**: every golden match with a person changes (`make golden`); the
    computer's fixture (`tests/fixtures/cpu/choose.txt`) and the matches without a
    person do not.
  - **Playing together**: a 1.3 match shares a pitch only with a client on 1.3.
  - **For clients**: optional. A client may offer the throw level and send it as the
    player entry's `throw` (and `me.throw` on a pitch); one that does not plays
    everyone on Standard.
- **1.2.0** (minor). The computer's inkast, from a played game (the owner, 2026-11-26:
  the computer "drills its kubbs a couple meters back from the midline. That isn't what
  real players do", and "its first Kubb in went out of bounds. It then threw kubbs toward
  that out of bound Kubb attempting to make a group").
  - **Kubbs out for now** (`read.inNow`, `autothrow.tune.inkastSkipOut`): a kubb thrown
    this turn that could not be raised in bounds where it lies (the rules' own test,
    `raising.canRaise`) no longer counts for a basket and is never built beside (row,
    into, column). In 1.1 a club row built on a kubb past the sideline or short of the
    centre line, aiming the next kubbs out too (10 of the 12 kubbs out in 20 seeded club
    matches drew a later kubb within half a metre of them).
  - **Baskets nearer the centre line** (`autothrow.tune.inkast.<level>.basketY`): club
    4.45 m from the baseline (was 4.75), pro 4.3, and pro's columns may reach to 4.15 m
    (`cpu.tune.depth.front`, was 4.35). Beginner and kid keep 4.75 and their scatter.
    Where the computer's kubbs rest, past the centre line, median (20 seeded matches a
    level): club 0.85 to 0.54 m, pro 0.67 to 0.45 m (p90 1.71 to 1.34, 0.92 to 0.71).
  - **Neighbours** (`session/neighbours`): when a setup differs from the last by no more
    than rounding and so sends no items, the next throw's `after` is baked from what is
    shown, so a client playing the events and `neighbours.view` agree on bodies the throw
    leaves still (they could differ by one rounding step).
  - **Gym, 120 matches a level, computer, 1.1.0 to 1.2.0** (only moves past 99%): club
    field batons missed 23.2 to 20.5%, rethrown 1.3 to 0.8%, target toppled 73.3 to 76.4%;
    pro cleared its field kubbs 87.9 to 82.8% of turns (real tournament games 83.4),
    batons to clear 3.34 to 3.60, two or more from one baton 20.4 to 22.4%, kubbs lying
    touching after an inkast of three or more 17.1 to 22.0%, illegal batons 1.0 to 2.3%
    (more throws at about 4 m, where the engine's batons helicopter most at every level).
  - **Golden hashes**: changed (`make golden`); the computer's fixture
    (`tests/fixtures/cpu/choose.txt`) rewritten; the neighbours hash moved.
  - **Playing together**: a 1.2 match shares a pitch only with a client on 1.2.
  - **For clients**: nothing in a call or format changes. docs/CLIENTS.md "1.2 on top".
- **1.1.0** (minor). Record mode (docs/RECORD.md): a real game of kubb scored throw by
  throw, for Kubb: Pitchside, behind `kubbCall("record.<name>")`. It only adds. There is a
  new door, `core/record` and `session/record`, and no existing call, format or hash
  changes. The minor is for the new door, as "fields that only add go with the minor"
  says. It is not a patch because a client may rely on the door being there.
  - **Record mode**: a setup and a log of plain events (toss, punish, pitch, advantage,
    baton, resign, call, capture, note). It is rebuilt from the whole log for an undo or
    an edit. Every call returns the state a scorer's screen needs, with the notation file
    and the score sheet's rows on request. Capture switches (players, pitch, lay, stance)
    choose the lines the file writes. Breaches of the rules come back as warnings. It has
    no Kid rules.
  - **`Y` in the inkast token** (`notation.inkastBody`): failed rescues, which only record
    mode writes, go after `P` (`IRPYQN`, the canonical order). The rules engine never has
    a `Y`, so no game file it writes changes. `core/gamefile` reads a token of failed
    rescues alone (`2Y`) as an inkast, not as batons, and `cards.batonCounts` counts `W`
    (a game called) as no baton, as it does `G`.
  - **Golden hashes**: unchanged (`make golden-check` passes with no `make golden`). Record
    mode uses no physics, no tune and no random draw.
  - **Playing together**: a 1.1 match plays exactly as a 1.0 match (the same hashes). By
    "Playing together", it still shares a pitch only with a client on 1.1. The web
    carries 1.1 alongside 1.0 while an iPhone build on 1.0 is live, or the web and the
    iPhone move together.
  - **For clients**: nothing must change. docs/CLIENTS.md "1.1 on top".
- **1.0.0** (major, declared). The owner (2026-11-22): "lets move all four projects to
  version 1.0.0 and tag those releases. We will use that version to submit to the App
  Store as well." No format changes: the snapshot, actions, the recording, the game file
  and the pitch's document read and write as on 0.18, and every call 0.18 answers answers
  the same way or gains a field. The number is the declaration that this is the released
  engine; under "Playing together" 1.0 shares matches with no 0.18 (the physics differs).
  Six changes:
  - **`pitch.engineFor` and computer seats** (docs/PITCH.md "Computer seats"): a seat
    (`cpu:<n>`) carries the pitch's engine, so `engineFor` leaves seats out of the players
    it asks and `startCheck` asks no engine of a seat id. In 0.17 and 0.18 a pitch with any
    seat found no engine and START was blocked. No hash moves by it (the pitch is not
    hashed; the vectors are untouched).
  - **The drive's floor, cheap for a new geometry** (`core/throwplan`, docs/notes/throw.md
    "The floor"): a line whose drag-free speed is already past the swing's top speed is
    unfit with no carry, the top speed is kept for its tune, and a line that fits keeps its
    carry. A kept drive raised to a new floor costs 0.025 to 0.09 ms in desktop Lua (worst
    0.16; it was 0.47 at 2 to 5 m), a default plan under the knee 0.005 to 0.008 ms (0.017
    to 0.019). Floors over 1 to 8 m move by under 1e-7 degrees but at one geometry where the
    carry speed steps (a kubb 2.21 m away, 7e-4 degrees). Hash-neutral on its own: `make
    golden-check` passed on that commit, and `tests/fixtures/cpu/choose.txt` holds.
  - **pairRoll from the first step** (docs/notes/physics.md "A baton rocking in a groove"):
    `pairRollAfter` is gone and the push the lever works on is capped at the baton's weight
    in the step. The Gym against 0.18.0 moved nothing past its noise (6 of 612 figures past
    99%).
  - **The seat** (docs/notes/physics.md "The seat"; the owner, 2026-11-22: "yes turn on the
    kubbs too stable"): a kubb standing plumb leans up to its surface's `seat` (grass 2,
    sand 3, snow 1.5 degrees, the grid 0; estimates), seeded from where it stands, the same
    in either side's view. The session draws the pose the throw's world builds, a settle
    leaves a seated kubb alone, and each `setup.settled` entry carries the `seat` it will
    stand at. Off against on (300 matches a configuration): a touch at 3 m/s or more that
    left the kubb unmoved, the computer at beginner 7.4 to 4.8%, at club 2.4 to 1.5; took
    two and three or more barely move.
  - **A piece propped on another comes to rest** (docs/notes/physics.md): three contact
    faults (`cornersInto`'s corner beside a box read as inside it; `capsuleBox` dropping a
    pair when its projection stopped just over the margin, and dropping a deeper stretch
    end near the projected point) held seven throws open to the 12 s limit in seeds 1 to 8
    of the Gym's quick gate with the seat on; none now.
  - **Golden hashes** (`make golden`: 21 matches, 880 actions, from 854). Every match moves.
    pairRoll alone moves all 21 (first at actions 1 to 10) with no winner, turn count or
    action count changed; on top of it the seat moves every match with kubbs on grass, sand
    or snow at its first action (a kubb stands leaning from the first throw), and m16
    (the grid, no seat) moves at action 4 as pairRoll and the contacts have it. Against
    0.18.0: three winners change (m10 B to A, seven turns where it was five; m18, Kid, A to
    B, four turns where it was three; m19, Kid, A to B, seven where it was eight), and
    eleven matches change their action count (m10 33 to 47, m18 16 to 26, m19 61 to 50, m21
    60 to 69, the others by one to four). The start hashes are as they were (the version
    is not in a snapshot). The pinned neighbours hash moves (`33173648`).
  - **The Gym against 0.18.0** (`gym compare v0.18.0 HEAD --full`, 300 matches a
    configuration): 49 figures past 99%, most of them the touches the seat was for (a
    touch at 3 m/s or more that left the kubb unmoved: the computer at beginner 7.4 to
    4.0%, club 2.4 to 1.2, pro 2.5 to 1.4, the person 2.5, 4.5, 2.6 to 1.1, 1.0, 1.2; the
    kubb did not move, beginner 2.8 to 1.3). Took two or more at club 13.4 to 14.4%, three
    or more 2.3 to 2.7; the person at club's illegal batons 1.0 to 0.2% (most likely
    own-half touches the propped contacts no longer make) and their throws that gained
    energy 5.0 to 2.0%.
  - **For clients**: sync `v1.0.0`; drop the `engineFor` workaround; nothing else must
    change. docs/CLIENTS.md "1.0 on top".
- **0.18.0** (minor). The computer's drive (`field.drive`, docs/reference/plays/field.md),
  switched on at club and pro as "How a play gets in" asks, the computer's king shot by
  level, the baton's blow, a match's length, and a cheap drive floor.
  - **The computer**: at club and pro (every computer player at its own level, 0.17.0's
    teams included) every baton but the king shot is planned on a
    person's default line (`plan.arcFor`, the drive close in) instead of the line before
    (`plan.sharedArcFor`). Side against side it beat the group-only drive it was built as
    (56.0% at club, 55.0% at pro) and the computer without it (docs/notes/gym.md "The
    computer's drive"). Beginner and kid throw as before. `core/plays` names
    `field.drive` when the arc at a field kubb is a drive.
  - **The king shot** (`autothrow.tune.kingScale`: beginner 1.4, club 1.6, pro 1.3): the
    computer's king shot is thrown on the line before, its swing's mistakes and its
    nerves times the level's scale, set in the Gym so every level's king shots sit in its
    row: 52.5% / 71.5% / 91.5% against 40 to 60 / 62 to 75 / 84 to 96 (docs/notes/gym.md
    "The king shot").
  - `tests/fixtures/cpu/choose.txt` is rewritten (`tools/cpufixture.lua`); the 0.11 fixture
    still holds with every play off and every king scale 1.
  - **Not shipped**: a hard throw's power bar for a person (`powerSpeed`, built and off:
    docs/notes/throw.md "A hard throw's power bar").
  - **The drive floor, cheap**: `plan.solve` finds a floor by Illinois steps from the line's
    geometric limit instead of 24 bisection steps, never computes a carry for a line no
    speed reaches (it ran 3000 carry steps to find out), and keeps the last floor, so a
    plan whose release alone changed, and `plan.arcFloor` after it, reuse it; `arcFloor`
    makes no table. A plan under its floor costs about what a default plan costs (0.02 ms
    in desktop Lua where it cost 0.58 to 0.71 at 2 to 6 m). The floor moves by under 1e-6
    degrees (the bisection's answer was up to 9e-7 over the root; this one is within 1e-7);
    no golden plan sits under its floor.
  - **A match's length**: `frame({ at })` and `Session:cpuAction(at)` put the host's time
    stamp on the action they make, a raise or punish action's `at` counts as a throw's
    does, a match no action stamped (or stamped before its start) has no End or Duration
    line and no minutes (it was 0 minutes: the finish fell back to the start), and the
    start keeps the starting host's `utcOffset` (minutes), the clock stamps are on. No hash
    moves without a stamp or an offset; a new match that gives an offset has other hashes.
  - **The baton's blow** (docs/notes/physics.md "The baton's blow"): a baton meeting a kubb
    or the king along a face or an edge is held by the two ends of that line only, not also
    by the closest point between them, which held the blow low on the face. An upright
    baton driven level into a lone kubb now sends it off at about 0.96 of MuJoCo's speed
    when struck low, from 0.94 (0.91 on average over the cases measured, from 0.87).
    Nothing in the Gym moves past its noise.
  - **A baton rocking in a groove** (docs/notes/physics.md, "A baton rocking in a groove"):
    a baton resting on other pieces feels their rolling resistance (`world.tune.pairRoll`,
    a 2 mm lever, wood on wood) from 4 s into a throw (`pairRollAfter`). A baton lying in
    the groove of two lying batons rocked at the sleep threshold and held the throw open
    to the 12 s limit (the Gym gate's one hard defect on the refitted person, about one
    throw in some thousands); it now rests at 4.3 s. No golden hash moves by it: every
    golden throw settles before 4 s. The term from the first step moves throws that settle
    normally and waits for a minor with its Gym rows.
  - **Golden hashes** (`make golden`: 21 matches, 854 actions). By the computer's line:
    every match with a club or pro computer moves at its first baton the line plans
    differently from the line before (the openers from the baseline at 8 m are the same),
    m20 and m21 (0.17.0's computer players) at their computers' first batons on the new
    line; two winners change (m09, m10, ending two turns sooner). By the baton's blow, on
    top of that: sixteen matches move again at their first baton that meets a face along a
    line (m04 and m07 to m10 have none), among them m15 (beginner both sides), m18 and m19
    (Kid), which the computer's line left exactly as 0.17.0 has them; no winner, turn count
    or action count changes by it. No golden match reaches a computer's king shot (the turn
    limit ends them), so the king scale moves none. The corpus's winner records lose
    `minutes: 0` (no stamps). The pinned neighbours hash moves too (`e427782a`: the
    neighbours' club and pro computers drive and their batons' blows move; none of seed 9's
    pitches reaches a king shot in its three minutes).
  - **For clients**: nothing must change to play; stamp `frame` and put `utcOffset` on the
    start to get a match's length; the Playdate can drop its floor cache. 0.18 shares
    matches with no 0.17 (the computer's throws differ). docs/CLIENTS.md "0.18 on top".
- **0.17.0** (minor). Computer players in teams. Jamie (2026-11-22): "In online play we
  should be able to add computer players to the match, with a specified level. I may have
  three friends and we want to play a team of three computers (two at club and one at
  pro). Or we want to play 2 v 2 where Tyler and I each have a pro computer partner." A
  team may hold people, computers or both, up to six, each computer at its own level
  (docs/SESSION.md "Computer players", docs/PITCH.md "Computer seats"):
  - **Core**: `match.lineupOf` carries a lineup entry's `cpu`; `match.isComputer`,
    `isSeat`, `hasPerson`, `people` and `strongestLevel`; `match.thrower` says `cpu`; a
    team of computers raises at its strongest level (`match.raisePolicy`); the `thrower`
    change refuses a computer player (`"computer"`), and `candidates` lists one as not
    ok; `[Throw Levels]` names every computer player with its level; the hand-off card
    says which throwers are computers. In a team with a computer player the kubbs go
    round the team turn by turn (core/order `rotateInk`, set by `match.new`): the deal
    opens every turn of six batons with the same player in a team of 1, 2, 3 or 6, who
    would otherwise throw every turn's kubbs (in the Gym, a beginner and pro pair had the
    beginner throw all of them). A team of people keeps its order exactly.
  - **Session**: a player entry `{ cpu: true, level, name?, key? }` (Beginner, Club or Pro;
    Kid refused, as it is the match's); a computer player's throw is the computer's, at
    its own level, in the team's throwing order; a team with a person raises and places
    by hand, a team of computers by itself; unnamed computer players get generated names
    from the seed and the seat (`mix(seed, 4, seat)`); `need.setup.thrower.cpu`; the mode
    counts a computer partner; a client given `control.cpu` while held at a computer's
    release throws it on the next frame (a host change mid-throw).
  - **Pitch**: the document's `computers` and seat ids (`cpu:<n>`) in `teams`; the host's
    `addComputer`, `setComputerLevel`, `moveComputer`, `removeComputer` and `isSeat`;
    seats in `lineup`, `matchOptions` and `match.players`; computer players are not
    members for who acts; `startCheck` (and so `startMatch`) refuses a lineup with no
    person, a team over six or a seat level that is not a seat's, with `why` and `text`.
    `settings.computer` stays the level of the computer on an empty side, and Kid there
    makes a Kid match in which every computer is the Kid computer.
  - **Old matches**: the old `cpu` option means what it meant, and only computer
    entries carry `cpu`, so every existing match, snapshot and replay plays as before:
    the 19 golden matches give every hash as recorded. Two golden matches are new: m20, a
    person (scripted near throws) with a pro partner against club and beginner computers,
    raised by hand; m21, two club and one pro against three club, on sand in light wind.
  - **The Gym**: `gym versus` takes `team=club+club+pro` (a team of computers, one level
    a player in throwing order) and reports each level's share of the batons, its hit
    rate and its inkasts. `make games` gates game files with computer players in teams
    (`tools/games.lua` one game in five, `tools/physmatch.lua --mixed`).
  - **Two fixes from the web's QA pass, output only** (in no snapshot or hash): a Kid
    match's king knocked down early and stood back up is no kubb down in the recording's
    `result` (`down` counts the kubbs, `flag` is theirs or `"KING BACK UP"`, as
    `ruling.short`; it read `"1 DOWN"` for a baton that felled only the king); and a
    rethrown kubb is counted in its own round (`need.setup.n` and `of`, the label and the
    aim's `rail`: two in and one out reads "rethrow 1 of 1", not "kubb 3 of 3"). The
    setup's own `n` and `of` (the turn's count, which the computer's inkast reads) are
    unchanged, so no throw and no golden hash moves.
  - **The engine's raises, with their surroundings, output only**: each `setup.settled`
    entry carries `others` and `king` as they stood while it was done, in the raiser's
    view frame (what `raiseInfo` and `punishInfo` give for the same kubb by hand), so a
    client draws the engine's raise as it draws one by hand.
  - **For clients**: docs/CLIENTS.md "0.17 on top". Shares matches with no 0.16.

- **0.16.0** (minor). The drive: a baton thrown flat or down and hard into a group, and
  a person's thrown kubb held to narrower bars (docs/notes/throw.md "The drive", "The
  thrown kubb on the person's meter"; the owner's reports,
  docs/reference/observations/owner-2026-11-22.md).
  - **The release scale** (`core/throwplan`): under `driveKneeDeg` (15) the planned loft
    falls on a steeper line to `loftAt0` (-15) at a release of 0 (`releaseMinDeg` 0,
    `loftMinDeg` -15). A swing's error about a plan keeps the one line's slope
    (`plan.launchLoft`), so a plan from the knee up launches as before. A thrown kubb has no
    drive (`plan.clampRelease(r, "kubb")`, `plan.loftFor(r, true)`).
  - **The floor**: `plan.solve` raises a plan under the knee to the lowest release whose
    line the hand can make and whose speed is at most `plan.speedFor(driveBackMaxDeg)` (140).
    `plan.arcFloor(q)` gives it; ARC keeps a set value no lower than the floor and steps
    from the release as planned, never under the floor (Codex on #47).
  - **The turn**: under the knee the planned tumble eases to none by a release loft of
    `driveTurnToDeg` (-4); the tilt and the helicopter rule are as before.
  - **The default**: one line by distance for every target, lowered (`plan.tune.arcLine`:
    the drive at 1.5 m, as before at 8 m and out); the line before is
    `plan.sharedArcFor`, the computer's until its drive is on. The king and a Kid match's
    base kubbs hold on it (Q18, closed).
  - **The thrown kubb's bars** on the standard meter are a baton's (`kubbPower`,
    `kubbRelease` 1, from 1.35). The Kid meter is unchanged.
  - **The computer**: `field.drive` (`cpu.tune.drive`) built switched off; nothing it does
    changes (`tests/fixtures/cpu/choose.txt` passes untouched).
  - **The session**: `aim.controls.arc.min` is the throw's floor and `arc.knee` the knee;
    `session/check` admits the drive (releases from 0, the plan the action names first) and
    refuses a launch the plan at its floor could not give.
  - **Golden hashes** (`make golden`: 19 matches, 724 actions): the four with a person's
    side move, each at the first throw the person makes on the default arc at something the
    0.15 default and the lowered line plan differently (the corpus's batons at field kubbs
    carry their own release; the computer's throws are bit for bit as before):
    `m13-grass-off-A-near` at action 16, the king shot from the baseline (4 m: release 13.6
    where it was 30); `m14-grass-off-B-auto-pro` at action 22 and
    `m17-neon-grid-off-B-near-pro` at action 6, a circle kept beside a field kubb rather
    than on it (5.7 m: 33.4 where it was 42.5; 4.8 m: 23.2 where it was 36.1), which the
    first build's field-only line missed; `m18-grass-off-A-near-kid` at its first action, a
    base kubb from the Kid line (6 m: 37.5 where it was 45). The winners are the same; m14
    has one hit fewer and m17 ends a turn sooner. 0.16 shares matches with no 0.15.
    `tools/physdump.lua` is unchanged.
  - **Output only** (no snapshot or hash moves): the throw need's `setup.settled` lists
    what the engine raised and placed before the throw (it was declared and never filled:
    `core/match` kept a count on the match), in the raiser's view frame, turned to the
    world frame in the wide view; each neighbour `throw` recording carries `hits` and
    `landing` (the pinned neighbours hash moves: `tests/node/neighbours.test.mjs`).
  - **Measuring tools**: `tools/driveprobe.lua` (the two group positions), `tools/mjref`
    `--cases drive` and `drive.py` (the drive and a struck column against MuJoCo),
    `tools/meterprobe.lua --arc` and `--king` and the drill part's rms, within a kubb's length
    and out; the Gym passes `--rules kid` to its matches (read and dropped before).
  - **For clients**: docs/CLIENTS.md "0.16 on top": ARC's range from `aim.controls.arc`, a
    side view that draws a falling arc, and on the Playdate the projectile passed to
    `plan.clampRelease`.
- **0.15.1** (patch). The Tournament's neighbouring pitches (docs/notes/tournament.md):
  computer-against-computer matches on the pitches around the player's, as live scenery,
  behind `neighbours.open`, `neighbours.advance`, `neighbours.view` and
  `neighbours.close` (`session/neighbours.lua`, docs/SESSION.md "Neighbours"), meant for a
  Lua state of its own. Each pitch plays the physmatch path in a coroutine cut into slices
  at every physics step and every decision, so `advance` keeps to a budget by the host's
  clock (`__kubbClock`, a global the host defines, in milliseconds) or a step count; the
  pace (a baton every 8 to 15 s, the walk, the raise, 40 to 60 s between matches) is on the
  host's clock passed in, and the events come from the seed and that clock alone. Recordings
  are thinned (a pose every 0.04 s, to the millimetre, only what moved, trailing still
  frames cut): 1.7 KB a throw on average.
  - **Core**: two hooks a host may set, nil by default and changing nothing when nil:
    `m.run` on a match (core/match runs the world that settles standing pieces with it in
    place of `world.run`: the same steps in the same order) and `raising.probe`
    (core/raising calls it before each spot it tries in a crowded corner's search). The
    neighbours use them to slice the only long parts of a set-up.
  - **Hash neutral**: nothing in the session, its snapshot, actions or recordings
    changes, and the 19 golden matches give every hash as recorded. The neighbours touch
    no state the session keeps; the tests run them beside a session in one Lua state and
    its snapshots and recordings do not move.
  - **Two Kid fixes, output only** (found by the web's move to 0.15.0): the wide view
    turns `aim.kidY` and `minimap.kidY` for Team B, as it turns the advantage line (it
    left them in the thrower's frame, so a client could not draw the far side's Kid line);
    and a Kid match's counted helicopter has a recording `result.flag` of what it knocked
    down (`MISS`, `1 DOWN`), not `HELICOPTER`. Neither is in a snapshot or a hash.
  - **For clients**: nothing must change. Showing neighbours is docs/CLIENTS.md "0.15.1 on
    top": a worker with a second engine (web), a second `lua_State` (iPhone); the Playdate
    does nothing.
- **0.15.0** (minor). Kid mode. Jamie (2026-11-21): "'Kid' would be a super good level to
  add: Kid, Beginner, Club, Pro… then we can make a mode for kids to have fun with", and
  "kid level is for kids to have fun with kubb". The computer's levels are Kid, Beginner,
  Club, Pro, and choosing the Kid computer makes the match a Kid match
  (docs/notes/kid-mode.md):
  - **The Kid rules** (`core/rules` `rules.kid`, `rules = "kid"` on `rules.new` and
    `match.new`, kept as `g.rules`): three base kubbs a side (x = -1, 0, 1); every kubb
    thrown in and every baton at a kubb, by either side, from the Kid line 2 m in front of
    the baseline, or the advantage line when that is nearer the middle (the king shot from
    the baseline); the king knocked down early, by a baton or a kubb thrown in, stood back
    up where it was and the turn goes on; no punishment kubbs (a kubb out twice is stood by
    the engine at the fair spot, `raising.fairSpot`, 1 m either side of the middle and 1 m
    past the centre line, and nobody is asked); no illegal throws (a helicopter counts).
    Everything else as the standard rules. `match.setup` gives `kid`, `kidY` and
    `forwardY` from the line.
  - **The Kid meter** (`plan.meters.kid`): bars about five times the standard's at 6 m,
    an in-bar gain of 0.02, a gentler pull, shake and scatter past the bars, and a soft
    flick forgiven (`flickIn`, read by `plan.launch` only on this meter). A small child
    (the Gym's recorded hand, misses tripled) fells a lone kubb 3 m away 80% of the time
    and 6 m away 54% (31% and 10% on the standard meter). `tools/meterprobe.lua --meter
    kid --hands 3,2,1`.
  - **The Kid computer** (`plan.levels.kid`, `autothrow.tune` `swingScale.kid` 1.5 and
    `inkast.kid`, `cpu.raising.kid` `first`): misses by its nerves, tosses its kubbs out,
    raises simply, knows no play. In the Gym (`versus --rules kid`, 300 seeds each way) a
    child on the Kid meter wins 71.8% (68.2 to 75.5) and 77.3% (74.1 to 80.6) on seeds 1
    and 2; a match lasts about five turns.
  - **Session**: `newMatch`'s `computer` takes `"kid"`; with a computer side it sets
    `opts.rules = "kid"` (also taken outright as `rules: "kid"`), kept in the snapshot
    only then. A person's throw state carries `meter = "kid"` (`throw.meterFor`), and
    `checkThrow` holds a throw to the match's meter. The view: `need.kid`, `setup.kid` and
    `setup.kidY`, `aim.kidY`, `minimap.kidY`; `aim.advText` reads `KID LINE  2.0 M`; a
    kubb's setup now has its `forwardY` (the baseline in a standard match). Ruling codes
    `kingUp`, `helicopterCounts` and `placed`. `names.check` knows `opts.rules`,
    `save.game.rules` and the Kid notes and rulings.
  - **Pitch**: `MATCH_OPTIONS`' Computer row and `optionRows` gain Kid, first; `LEVELS` is
    the four; `setOptions` takes `computer: "kid"`.
  - **Game file**: `[Rules "Kid rules, 2-4-6: ..."]` and `[Base kubbs "3"]`; a king stood
    back up, a helicopter that counts and a kubb at the fair spot are written as notes (no
    `E`, no `Z`, no `P`; no pitch line the turn a kubb is placed); `[Throw Levels "... kid"]`.
    The notation has no way to say where a Kid match's kubbs and batons are thrown from,
    a king stood back up or a placed kubb that is no punishment (docs/notes/kid-mode.md
    "What the game file says"). `make games` plays every fourth headless game and five
    physics matches by the Kid rules through the gate.
  - **Playdate options** (`core/matchopts`): Kid is the Computer row's fourth value (a
    choice kept before keeps its level) and steps first (`order`); `apply` sets
    `opts.rules = "kid"` with it.
  - Golden: the seventeen matches move no hash; two more are Kid matches (`m18`, a person
    against the Kid computer; `m19`, the Kid computer both sides). The cpu fixtures' level
    the engine does not know is renamed `toddler` (it was `kid`); every result is as
    recorded. `plan.LEVELS` is the four, so `checkThrow`'s `levels` lists `kid` too.

  For clients: sync `v0.15.0` (it shares matches with no 0.14; web and iPhone move
  together). A Kid match needs one more segment on the Computer row and the Kid line drawn:
  - **Web**: the solo card's own Computer level row (`OPTION_ROWS` in `src/ui/cards.js`)
    gains `["kid", "Kid"]` first (or the card takes the engine's row from
    `pitch.optionRows`); the lobby, which walks the engine's `MATCH_OPTIONS`, has it
    already. A kept `computer: "kid"` must be a value the card accepts. Draw the Kid line
    at `aim.kidY` (and the minimap's `kidY`) beside the advantage line (`advY`), and say
    "Kid match" from `need.kid`; the stance, its limit and `advText` already come from the
    engine. A Kid match never asks for a punishment kubb.
  - **iPhone**: the Computer row is the engine's (`MATCH_OPTIONS`), so Kid appears first
    by itself; `LEVELS` has four. Draw the Kid line from `kidY` in `PitchRenderer`,
    `SceneRenderer` and `PitchMap` (`advantageY` is only the advantage line), word
    `StandPad`'s caption for it (it says "up to the advantage line" whenever the forward
    limit is ahead of the line), and show "Kid match" from `need.kid`.
  - **Playdate**: sync the core. The COMPUTER row offers KID first; to make it a Kid match
    the match scene passes `opts.rules` to `match.new` as `rules` and plans the person's
    throw on `plan.meter("kid")` (the throw scene's `plan.meter()`), and draws the line from
    the setup's `kidY`. Until it does, KID plays the Kid computer under the standard rules.

- **0.14.0** (minor). Scenes become the engine's, and the Techno scene gets a floor of its
  own. Jamie (2026-11-21): "a Scene should have an allowed set of surfaces and pitch
  types". `core/scenes` (new, so the Playdate has it too) is the catalogue: Park (`day`),
  Beach, Camping (`night`), Techno (`neon`), Minnesota, Tournament and Black & White
  (`bw`), each with its name, the surfaces and kubb sets it allows (one default each) and
  flags a renderer reads (`dark`, `ring`, `mono`); docs/SESSION.md "Scenes",
  docs/notes/scenes.md. A scene decides: where a client sets options with a scene named
  (`new`, the pitch's `setOptions`, `optionsOf`, `matchOptions`) the surface is the one
  given if the scene allows it, else its default, and the set likewise; an id the
  catalogue does not have is Park. Options that name no scene stand as given, and
  restore, replay, `checkStart` and `renameStart` make a match from its options as
  recorded, so every match, save and document from before loads and plays as it was
  (tested with a Camping match on sand with the wisconsin set). `MATCH_OPTIONS` gains a
  Scene row (first) and `grid`; `pitch.optionRows(scene)` is the card a scene leaves to
  the player; `setOptions` takes only a listed scene (a document keeps any well formed id,
  read as Park). `names.check` holds `opts.scene` to the catalogue and `opts.set` to every
  set the engine takes (sweden and wisconsin are in no scene but still valid). The
  Playdate's `core/matchopts` is Black & White: its Surface row is that scene's and
  `apply` sets `opts.scene = "bw"`.
  - **`grid`, a fourth surface** (`world.surfaces.grid`; docs/notes/physics.md "The
    grid"): no texture (the same throw does the same thing on any ground), a glide (mu
    0.55, drag 0.6: a baton slides 1.9 m after touching down against grass's 1.0), a
    magnetic stop (grip 60 a second below 0.7 m/s) and a mild hold on a standing kubb's
    rocking (`texture.hold` 6, new). Still kubb: in the Gym's 200 matches a configuration
    turns, kubbs a field baton and the 8 m base kubb are within a turn or a few points of
    grass; batons that land short skip on farther and the club computer's uncaught drills
    glide apart. Grass, sand and snow are bit-identical (`tools/physdump.lua`).
    `drill.tune.slide.grid` and `roll.grid` are measured.
  - **Ground impacts** (`setImpacts`, docs/SESSION.md "Ground impacts"): while on, each
    recording's `timeline.impacts` lists where, when (the recording's clock), how hard and
    with what each piece met the ground. Never in a snapshot, an action or a hash; off,
    nothing is gathered (the world's `onGround` hook is one test when unset).
  - Golden: the fifteen matches move no hash; two more (`m16`, `m17`) play on the grid,
    chosen by the scene `neon`, the computer both sides and a person against the pro
    computer. Kid mode is not in this release; the Tournament's live neighbouring pitches
    are a design (docs/notes/tournament.md).

  For clients: sync `v0.14.0` (it shares matches with no 0.13; both phones move
  together). The options card is scene first:
  - **Web**: build the solo card and the lobby's options from `pitch.optionRows({ scene
    })` in place of `MATCH_OPTIONS` and `src/render/scenes.js`'s `SCENE_ROW`: the Scene row
    first (the engine's names: Park, Beach, Camping, Techno, Minnesota, Tournament, Black &
    White), a Surface row only when the rows carry one (Black & White), no Kubbs row.
    `MATCH_OPTIONS` itself now has a Scene row and `grid`, so a card that walks it shows
    the scene twice. Always send `scene` with `setOptions` and `newMatch`/`newPractice`,
    and draw from `view().scene`, `surface` and `set`: the engine has already decided them.
    `kubbCall("scenes")` gives the catalogue (names, `dark`, `ring`, `mono`, `choices`).
    Draw the new scenes (Beach, Minnesota, Tournament with the USA set, Black & White) and
    the grid floor under Techno; until one is drawn, draw it as Park, as for any id.
    Techno's rings: `setImpacts({ on: true })` once, then ring at each
    `recording.timeline.impacts` entry as playback reaches its `t`, scaled by `speed` or
    `strength`.
  - **iPhone**: the same: `SceneLook`'s own Scene row and the Surface and Kubbs rows give
    way to `pitch.optionRows` (`SoloMatch.swift`, `SoloPitch.swift`, `OnlinePitch.swift`),
    `SceneLook.drawn` grows with each scene drawn, `scene` goes with every `setOptions` and
    `new`, and Techno rings from `timeline.impacts` beside the sounds `Recording.swift`
    already takes from `contacts` and `batonLanding`.
  - **Playdate**: sync the core; nothing must change. `core/matchopts` gives the same
    Surface row (grass, sand, snow) and now names the scene `bw`; the grid is never
    offered there.
  - `grid` needs nothing from a client beyond drawing its scene; the game file's Surface
    line reads `Grid`.

- **0.13.4** (patch). The engine says which names a match from outside would show. A
  forged pitch start could keep generated names in `snap.opts.teams` while `save.game`
  held typed ones: `restore` builds the match from `save`, so the rail, the sheet and the
  winner card showed the typed text, and a client checking `opts` (the web's `badNames`)
  passed it. The session's new `names.check` (session/namecheck.lua; docs/SESSION.md
  "Names") takes a snapshot (`{ snap }`, text or object), a replay or kept match
  (`{ replay }`) or a pitch's document (`{ document, members? }`) and walks it whole:
  every name in it with where it is, its kind, `ok` and `default` (names.valid's check;
  a team on a side of one may be a player's name), each player's id against the one its
  name makes, the ruling, note and mode lines, every other string held to what the
  engine writes in that place, and the two copies of each name compared. `allowed` is
  true when nothing is refused and nothing disagrees. It changes nothing. `restore` also
  takes `{ snap, names: "check" }` and `replayLoad` `names: "check"` (Lua:
  `session.restore(text, control, { names = "check" })`, `replay.new { ..., names =
  "check" }`): the same check, refused before anything changes, the error naming the
  places and never the text. Without it both behave exactly as before, so a person's own
  kept match with typed names still resumes. Hash neutral: no golden hash or cpu fixture
  moves; 0.13.4 shares matches with 0.13.0 to 0.13.3. One more file,
  `session/namecheck.lua`; `session.matchOptions` is exported for it. A failed `restore`
  now leaves the session (and a loaded replay) as it was; before, it ended the replay.

  For clients: sync the tag, then at each boundary call the engine instead of reading a
  snapshot's fields:
  - **A pitch match arriving** (the header's `snap`, on entering it and on every resync):
    adopt it with `kubbCall("restore", JSON.stringify({ snap, names: "check" }))`; an
    error means do not show it ("This match has a name the game did not make"). To decide
    before restoring (the web's `enterMatch`): `names.check({ snap: m.snap }).allowed`.
  - **A replay or kept match** (`replayProblem`, a kept list, an embed, a share's start):
    `names.check({ replay: r })` with the whole object (setup or start, snap, players,
    log), and load it with `replayLoad({ ..., names: "check" })`.
  - **A lobby**: `names.check({ document, members })` for the host's `teamNames`, the
    match header's players and the members' names; a name that is refused is shown as
    its default ("Team A", "Player n"), as before.
  - **A local resume** (the device's own kept match): the plain `restore`, no check.
  - `names.valid` stays the check for a single name (the name row, a share's names).
  - **Playdate**: nothing; it has no pitch.

- **0.13.3** (patch). Generated names reach the web and the iPhone. The session's new
  `names.*` calls (`roll`, `step`, `choices`, `make`, `valid`, `words`, `all`;
  docs/SESSION.md "Names") make, step and check player and team names from
  `core/namewords`, drawing from a seed the client passes (`plan.rng`), so a seed gives
  one name on every client. `names.valid` marks the engine's own names ("Computer",
  "Team A", "Player 1") as `default`, apart from `ok`, so a boundary can accept
  `ok or default` while a client checking its own stored name is not fooled by them.
  `names.words` gives the lists, the shapes, the rules' number and a hash of them all,
  which is enough to check a name without Lua; a test does it in JavaScript over every
  name and over two thousand near misses. No pitch reducer changes: a pitch still takes
  a typed name (docs/NAMES.md section 8, step 2, says where the check goes and how it is
  staged). Hash neutral: no golden hash moves, and 0.13.3 shares matches with 0.13.0 to
  0.13.2. The session has one more file, `session/names.lua`.

  For clients: sync the tag; nothing must change.
  - **Web and iPhone**, to replace typed names: `names.roll` on first run, and keep the
    text; the name row from `names.roll` with `keep` for Shuffle and locks, and
    `names.step` or `names.choices` per word; names that arrive from outside checked with
    `names.valid`, accepting `ok` or `default`; every name from `names.all` measured in
    the client's own font to size the row. A side of one player is named after that
    player, so a team name's check accepts a player's name there.
  - **The web's pitch server** can check names without Lua from `names.words`, and
    compare its `hash` with a client's.
  - **Playdate**: nothing; it calls `core/namegen` directly.

- **0.13.2** (patch). The game file's `[Throw Levels]` names the computer's players only.
  Since 0.13.0 a level is the computer's standard and a person's changes nothing in their
  throw, so a file that wrote `[Throw Levels "you club, computer club"]` presented the
  person's level as if it counted. `match.fileLevels` (new; `match.file` and the session's
  `sheet` both use it) lists each player of a side the computer plays, as the header's id
  and the level it throws at (its lineup's, else `autothrow.tune.level`), Team A's then
  Team B's. The computer's sides are `match.cpuSides`: `match.new`'s `cpu` (the session's
  `cpu` option), or the Playdate's "Vs Playdate" mode, Team B. With no computer (pass and
  play, online with people only) the file has no `[Throw Levels]`; so does a match from a
  caller that gives neither `cpu` nor that mode, since nothing says which side is the
  computer. A person against the computer: `[Throw Levels "computer club"]` (before, the
  person's entry alone when the computer took the default club). Computer against
  computer: every player. Nothing reads the header back into a throw: `core/gamefile`
  keeps it in `headers` like any other and its summary does not use it, the history and
  the cards take levels from the match, and resume and replay from the save and the log,
  so files from 0.13.1 and before (every player listed) read as they did. The gate's
  rules-only games now write all three shapes (`tools/games.lua`). Every golden hash and
  `tests/fixtures/cpu/choose.txt` are as recorded. Also: docs/SESSION.md's arc default
  says what `plan.arcFor` has done since 0.10 (by distance, not by target).

  For clients: sync the tag. 0.13.0, 0.13.1 and 0.13.2 share matches (no hash moves).
  - **Web**: nothing but the sync; no code or test reads `[Throw Levels]`.
  - **iPhone**: nothing but the sync.
  - **Playdate**: `source/selftest/match-teams.lua` (around line 83) expects
    `[Throw Levels "k pro, l beginner"]` from a pass-and-play match; on 0.13.2 that file
    has no `[Throw Levels]`, so the selftest checks for its absence instead.
    `selftest/match-vs.lua` (`[^"]*pro"`) still passes. `docs/notes/saved-players.md`
    ("The game file") and the comment over `cpuLevel` in `scenes/match.lua` say the
    header names the computer's players.

- **0.13.1** (patch). The game file is Planet Kubb Notation 2, as pk-kubb-score released
  it (`v2-2026.11`), in its canonical form: `[Notation "2"]` first, the `Base kubbs`,
  `Batons` and `Opening` headers, the turn lines as before (the advantage line a bare
  `A`), and positions as lines of their own in the notation's frame (across from the
  left sideline, depth from the centre line, two decimals): a pitch line `@a` or `@b`
  for the half under attack and a felled line `*a` or `*b` with a word per baton
  (`notation.positionLines`, `notation.toPitch`, `notation.fromPitch`,
  `notation.point`). The engine's own `(@ ...)` comments and its fork of the reader are
  gone: `tests/vendor/pk-kubb-score/` is the released parser, canonical form and scorer
  (`make sync-notation`, `SOURCE` names the tag), and the gate also reads every point
  back and compares it with what the engine had. A line is written only when it can be
  true and whole: no pitch line in a turn with a punishment kubb or with field kubbs
  left from earlier turns, and a `-` for a baton whose kubb an earlier baton had moved.
  Not yet written: the thrower's own half, the lay line `~` and the stance line `^`.
  They need more kept in the score sheet, which is saved and hashed, so they come with a
  minor. Nothing a seeded match does changes: every golden hash is as recorded, and a
  save or recorded match from 0.13.0 loads unchanged. `core/gamefile` still reads the
  older notation, the `(@ ...)` comments included (`tests/fixtures/legacy/`), and skips
  position lines (`gamefile.isPosition`). Gone from `core/notation`: `pitchXY`,
  `positions`, `batonCount`; new: `batonParts`.

  For clients: sync the tag. A 0.13.0 client and a 0.13.1 client share a match (no hash
  moves).
  - **Web**: `sheet.shown` leaves position lines out, and `sheet.text` (COPY, DOWNLOAD,
    the upload, SHOW POSITIONS) has `@` and `*` lines where it had `(@ ...)` comments.
    Two tests that look for the comments follow: `tests/game/client.test.mjs` (shown
    against the file less its comments) and `tests/net/record.test.mjs` (`/\(@ /`).
  - **iPhone**: nothing but the sync; the sheet's decoded fields are the same four. Run
    the sheet's snapshot again.
  - **Playdate**: the sheet scene builds its lines from the file's text, so it skips a
    line where `gamefile.isPosition(line)` is true (it would draw blank).

- **0.13.0** (minor). A level is the computer's standard only, and every person throws on
  one meter (the owner, 2026-11-21: "player level really should only mean for the
  computer opponent. It doesn't mean anything for the human player. The human player
  should be playing based on their capabilities."; docs/notes/throw.md "The person's
  meter"). On 0.12 a person's perfect swing at a lone kubb 8 m away felled it 13%, 38% or
  63% of the time by the level picked, because the level's nerves were drawn on the
  person's throw and the level set the person's bars. The meter is set to the reference's
  rows (docs/reference/PLAY.md): the recorded people throw like club players (about 27%
  from 8 m), a newcomer like beginners, a master like pros. The beginner and club
  computers move toward their rows; pro throws exactly as in 0.12.0.

  What a player sees:
  - **One meter for everyone.** The level a player, a thrower or `setLevel` names no
    longer changes their throw.
  - **The bars go by distance.** Wide for a short throw, narrow for a long one: 5.6 and 21
    degrees either side at 4 m, 3.8 and 14.2 at 6 m, 2 and 7.5 at 8 m.
  - **A degree is a degree.** Past the power bar the backswing counts one for one at every
    range, so the same backswing carries the same distance whatever the target.
  - **The release sets the line.** A release past its bar pulls a baton off the line,
    0.15 degrees a degree: a late release (HIGH) pulls left, an early one (LOW) pulls
    right; inside the bar, none. The verdict says so: HIGH with PULLED LEFT, LOW with
    PULLED RIGHT.
  - **An honest meter.** A steady swing inside both bars goes where it was aimed (a
    perfect swing fells a lone kubb at 4, 6 and 8 m every time; steady swings anywhere
    inside both bars 99 to 100%) and never comes back PULLED; every miss reads SHORT,
    LONG, LOW, HIGH, SHAKY or PULLED.
  - **A person's kubb** keeps a clean hand (pro's) inside both bars and steady, and
    scatters with the shake and with how far past a bar the swing went.
  - **The beginner computer** (swing scale 1.6 to 2.2) misses 43% of its field batons and
    clears about half its fields (it missed 33% and cleared 88%, better than beginner
    play); a newcomer wins about 52 games in 100 against it (was 3).
  - **The club computer** (`nervesDeg` 0.8 to 0.5) fells 25% of base kubbs from 8 m (was
    19.5%, the bottom of club's 19 to 27); a typical player wins about 49 in 100 against it
    (about 60 at 0.8). Its field game is as before.

  How: `plan.meters`, `plan.meter`, `plan.meterLevel`; `plan.solve` takes `q.meter` and
  keeps the meter's table for the distance as the solution's `level`;
  `plan.releasePull`, `plan.shakeCounts`, `plan.unshake` and `plan.scatterFor`. The
  session plans a person's throw on `throw.meterFor(s)`, and `checkThrow` holds a person's
  throw to the meter (and refuses any speed, of either sign, from a swing that counts as
  no power). `autothrow.tune.swingScale.beginner` 2.2, `plan.levels.club.nervesDeg` 0.5.
  The Gym's human thrower plans on the meter and takes a hand scale (`hand=` in a versus
  spec); `tools/meterprobe.lua` measures the meter against the reference rows.

  Golden corpus: every match moves (the club computer plays all of them): 15 matches,
  579 action hashes. `tests/fixtures/cpu/choose.txt` is rewritten: 288 of its 480 setups
  (every one thrown at beginner or club); `choose-0.11.txt` still matches with the plays
  off and 0.12's beginner and club.

  For clients: sync the tag.
  - A person's level picker has no effect on their throw and can go (the fields are still
    taken and kept, so nothing breaks if it stays). The computer's level picker stays.
  - The bars change with the throw's distance: the aim view's `plan.powerLo..powerHi` and
    `releaseLo..releaseHi` are the bars for the plan as it is, so redraw them whenever the
    plan changes (the circle or the stance moved), not once a throw.
  - A release past its bar now comes back PULLED LEFT or RIGHT as well as HIGH or LOW
    (the verdicts' side cell); show it as you show the others.
  - `checkThrow` on a person's throw checks it against the meter: a throw that fits lists
    every level and `atLevel` is true.
  - Web and iPhone must both be on 0.13 to share a match.
  - **Playdate** (the core, with its own call to `plan.solve`): the session does this for
    the web and the iPhone, but the Playdate builds a person's plan itself, so it passes
    `meter = plan.meter()` in place of `level` in that query and no `level` to
    `plan.launch`. Without it a person still throws on a level's bars and nerves, as on
    0.12.

  **The pitch rename.** The shared-pitch module is `pitch`, as the clients and the pitch
  server already say (the web's docs/PITCH-SERVER.md, "Naming"): the directory `room/` is
  `pitch/`, its tables `tw.shared.*`, its calls `kubbCall("pitch.<name>")` (the same 37),
  docs/ROOM.md is docs/PITCH.md. `room.<name>` stays as the old spelling of every call and
  `tw.room` as the same table as `tw.shared`; an error names the call as it was made. No
  call, field, document or result changes, and no hash moves. `make room-vectors`,
  `tools/room-vectors.mjs` and `tools/room-scenarios.mjs` are gone, with the half of the
  node test that compared the engine live with the web's modules: those modules have
  called the engine since 0.3, so the comparison could only compare the engine with
  itself. `tests/pitch/vectors/` is the same corpus, byte for byte, and is frozen;
  `engine.json`'s `roomFrom` is `pitchFrom`, with the same commit.

  For clients (the rename), at the same sync as the rest of 0.13:
  - **Web** (`kubb.thingelstad.xyz`): add `"pitch"` to the engine directory lists and keep
    `"room"`, skipping a directory an engine does not have: `DIRS` in
    `tools/lua-bundle.mjs` (its `engineFiles` reads every listed directory of every
    carried engine, and 0.7 to 0.9 have only `room/`) and `ENGINE_DIRS` in
    `tools/vendor.mjs`. The newest engine's bundle modules are `pitch/lobby`,
    `pitch/seats`, `pitch/sync`, `pitch/js`, `pitch/engines` and `pitch/api`; its bundle
    sha256 is engine.json's only when the module names are these.
  - **iPhone** (`throwingwood-ios`): add `pitch` to `engine_paths` in
    `scripts/vendor-engine.sh` and keep `room` (it copies what the tag has, so one list
    serves every tag). The loader reads paths from `engine.json`'s `files` and needs no
    change.
  - **Both**: the bridges (`roomCall` in the web's `src/net/room-engine.js`,
    `PitchController.roomCall` and the direct `engine.call("room.…")` calls in the app)
    may keep saying `room.` while they also drive carried engines: 0.13 answers it. Move
    the prefix to `pitch.` at leisure, per engine when the bridge knows the engine's
    version (`pitch.` from 0.13 on), or everywhere once 0.7 to 0.9 are no longer
    carried. Carried engines 0.7 to 0.9 keep `room/` and `room.`.
  - **Playdate**: nothing; it vendors `core/` only.

- **0.12.0** (minor). The defender's raising goes by who defends (raise.par, Q7;
  Jamie's decision of 2026-11-21), and the pro computer attacks with two new plays, so
  that a pro who defends well also attacks well: `inkast.depth` (it lays its kubbs in
  columns down the baton's path) and `field.line` (it stands where the kubbs line up).
  The club and beginner computer throw exactly as in 0.11.2: club is to be retuned as a
  whole in a later release against its new target (a typical online player wins about
  four games in ten), so it gets none of the new plays now. A 0.11 match replays
  differently on 0.12 from its first raise the new policy decides otherwise or its first
  pro computer throw a play changes, and the room refuses a match between 0.11 and 0.12.

  What a player sees:
  - **The computer raises by its level** (`core/cpu.raising`): pro by the attacker's
    batons (`par`, built in 0.11.2), club `apart` as before (what club players do: spread
    the kubbs), beginner `first`, standing in for a random end until Choose has a random
    stream of its own.
  - **A person gets the engine's best advice, `par`** (`cpu.advice`): when the engine
    raises their kubbs (RAISING: AUTOMATIC), and as the end offered first when they raise
    by hand (the session's `need.default`; a `raise` action with no choice takes it).
  - **The pro computer lays columns** (`inkast.depth`, `core/cpu` depthSpot): the
    kubbs end to end down the baton's path, 4 cm apart, four to a column and none nearer
    the centre line than 4.35 m, with the row's dead landing and roll; then the next
    column beside the last. A defender raises a lying kubb only along its length, so a
    column stays one lane whichever ends are chosen. Until now it laid a row across, as
    club still does.
  - **The pro computer stands where the kubbs line up** (`field.line`, `core/cpu`
    lineChoice, `read.lineLane`): for each standing field kubb, straight behind it and
    the point on the throwing line that puts it and a kubb behind it one behind the other
    (and a step along the line when straight behind is no good), scored by the lane along
    that line times the chance of hitting from there; never through the king, past a kubb
    in front, or within 0.3 m of a field kubb in its own half (II.B.11).
  - Both are in `cpu.tune`, switched by level and off entirely (`on = 0`); the Gym reaches
    every number (`--set cpu.tune.line.pro=0`). Neither draws from a random stream (a
    level knows a play or does not), so Choose still has no stream of its own and the
    throw's stream is drawn as before.
  - The computer's raise keeps its reason in `cpu.last` (`kind = "raise"`, at pro
    `why.play = "raise.par"`), never on the game, an action or anything hashed; a throw's
    names `field.line` or `inkast.depth` when they chose it. `core/plays` has `raise.par`,
    `field.line` and `inkast.depth`.

  How: `match.settle` raises each kubb with the defender's policy,
  `match.raisePolicy(m, side)`. It knows the computer's sides from `match.new`'s new
  `cpu` (a list or set of sides; `{}` for none) or, without it, from the mode
  `Vs Playdate` (Team B), and each computer side's level from the lineup (none:
  `autothrow.tune.level`). `match.new`'s `raising = { A, B }` names a side's policy
  outright. Neither is saved; the mode is. A match that says none of it raises every kubb
  with `game.raisePolicy`, `apart`, exactly as before (the rules are unchanged).

  Golden corpus: the twelve computer matches (m01 to m12) play the club computer on both
  sides and keep every 0.11.2 hash. m13 (a person against the club computer) moves from
  action 52, the person's raise by hand with the end offered first, now `par`. Two
  matches are new in 0.12.0: m14 (a person raised automatically against the pro
  computer, seed 1027) and m15 (the beginner computer both sides, seed 1015). 15 matches,
  599 action hashes.
  `tests/fixtures/cpu/choose.txt` is rewritten (`tools/cpufixture.lua`): against 0.11.0's
  fixture 1464 lines of 480 setups move, all pro decisions a play now makes (22 of 62 pro
  batons and 34 of 54 pro tosses); no beginner, kid or club decision differs from 0.11.0.
  0.11.0's fixture is kept as `choose-0.11.txt` and still passes untouched with both
  plays off. `make games`: the 500 rules games are 0.11.2's; its five physics matches play the
  club computer both sides, which throws and raises as on 0.11.2, and pass the notation
  gate with no warnings.

  The Kubb Gym, 0.11.2 against 0.12.0 (300 matches a configuration, seed 1;
  docs/notes/gym.md, "Raising by level" and "The attacker's plays"). The computer's rows
  beside their target; bold moved past 2.58 standard errors:

  | computer | 0.11.2 | 0.12.0 | target |
  |---|---|---|---|
  | pro: field batons that took two | 22.2% | 22.2% | 17 to 23 |
  | pro: ... three or more | 4.9% | **6.8%** | 12 to 18 |
  | pro: missed | 14.6% | **16.9%** | 12 to 19 |
  | pro: turns that cleared the field | 77.0% | 78.5% | 87 to 94 |
  | pro: turns from an advantage line | 20.1% | 18.7% | 8 to 15 |
  | pro: turns a game | 12.2 | 12.3 | 6 to 10 |
  | pro: standing kubbs touching another | 4% | **30%** | 60 to 90 |
  | beginner: field batons that took two | 6.3% | **8.5%** | 1 to 5 |
  | beginner: ... three or more | 0.5% | **0.8%** | 0 to 1 |

  Club's rows are 0.11.2's to the last figure (the same games). The beginner's moved by
  its raising (`first`) only; a person's, by `par`: the human thrower's took two 10.4% to
  9.6% at beginner and 8.5% to 6.9% at club (target 8 to 13: now under it).

  Pro is partly toward real play: three or more up from 4.9% to 6.8% (still about half
  the real figure), took two in range, and turns cleared and turns a game back where
  0.11.2 had them, which the raising alone had pushed away; cleared turns (78.5% against
  87 to 94) and game length (12.3 turns against 6 to 10) are still short of real play.
  Side against side the 0.12.0 pro beats 0.11.2's pro (`raise=apart`, the row, both
  plays off) 79.0% and 81.3% (seeds 1 and 2). Pro over club 97.0% and 97.2%, club over
  beginner 93.5% and 94.1%, pro over beginner 99.8% and 100% (0.11.2: 96.0, 93.7, 99.7).
  The human thrower against the computer at the same level: beginner 97.8% and 97.6%,
  club 15.7% and 16.8% (0.11.2: 12.3%; the person's `par` raising), pro 0.2% and 0.0%.
  Against this attacker `par` and `apart` are level at pro (50.3%, 51.8%; 76.8% against
  the old attacker) and `par` beats the same-end policies 55 to 57, so `par` stays. A
  beginner raising `first` loses to one raising `apart`, 40.2% (36.8 to 43.5).

  What it costs: a `par` decision with eight kubbs still lying takes about 0.12 ms in
  desktop Lua (0.11.2's measure), against 0.001 ms for `apart`; it now runs at every pro
  raise and every person's automatic raise. A `field.line` decision at ten standing field
  kubbs in a tight group makes 23 lane tests (at most 55, and four more for each kubb whose
  straight stance is no good) and takes about 0.11 ms in desktop Lua against 0.016 ms
  without; a pro `inkast.depth` toss about 0.018 ms against 0.003. None has been timed on a
  Playdate.

  For clients:
  - Sync the tag. Rooms refuse mixed minors, so a client that shares matches carries
    0.12 beside the engines it already carries.
  - The attacking plays need nothing from any client: they are inside
    `autothrow.choose`, which every client already calls for the computer's throws. Only
    the pro computer plays differently; a client that offers club or beginner shows the
    same computer as on 0.11.2, apart from a person's raising (`par`) and the beginner's
    own (`first`).
  - **Web and iPhone** (the session): nothing to pass. The session hands its `cpu` option
    to the core, so the computer raises by its level, a person's automatic raising is
    `par`, and `need.default` for a raise by hand is `par`. Offer `default` first, as
    before; a `raise` action with no choice now takes it.
  - **Playdate** (the core, `match.new` directly): in VS PLAYDATE (`mode = "Vs
    Playdate"`) the core infers that Team B is the computer, so the Playdate raises by
    its level and a person's kubbs raised by `match.setup` (the AUTOMATIC option) go up
    by `par`, with no code of its own; a resumed match keeps it (the mode is saved). Two
    things need its own change: `scenes/settle` picks the end it offers first, and REST
    OF GAME's raises, with `g.raisePolicy` (still `apart`); to give a person the
    advice there it passes `tw.match.raisePolicy(m, side) or g.raisePolicy` instead. And
    PASS + PLAY with AUTOMATIC raising says nothing of sides, so it keeps `apart` unless
    it passes `cpu = {}` to `match.new` (again on resume: `m.cpu = {}`). Passing nothing
    keeps 0.11's raising exactly.

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
  the core; a client passes nothing new. This is also the first tagged version to carry
  the name generator (`core/namegen`, `core/namewords`, docs/NAMES.md), which reached
  main after 0.11.2 was tagged and changes nothing a seeded match does.

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
