# The Kubb Gym

A measuring tool (2026-11-20). One command plays hundreds of seeded physics matches, thrown
the way the computer throws and the way people throw, reads every throw with forensics,
lists the odd throws with a command that replays each one, and puts it all on one page beside
the 150 real games. It changes nothing in the engine; what to tune from it is Jamie's call.
Paths are from the repo root.

## Commands

| command | what it does |
|---|---|
| `make gym` or `node tools/gym.mjs` | the scorecard, quick: 40 matches a configuration, about a minute |
| `node tools/gym.mjs --full` | 300 matches a configuration (about 6 minutes on a 10-core Mac) |
| `node tools/gym.mjs compare <A> <B>` | two scorecards (`--json` files), engine folders or git refs; prints only what moved |
| `node tools/gym.mjs sweep <path> <v1,v2,...>` | the scorecard once per value of one tuning number |
| `node tools/gym.mjs versus --a "<spec>" --b "<spec>"` | two teams that play differently: games won, and each team's rows side by side (below) |
| `node tools/gym.mjs fit <records> [--write]` | recovers recorded swings and fits the human thrower |
| `node tools/gym.mjs bank <records>` | throws every recorded swing again (also `--records <dir>` on a run) |
| `lua5.4 tools/gym/match.lua ... --repro M:T` | plays match M up to throw T and prints that throw in full |

Run options: `--throwers cpu,human`, `--levels beginner,club,pro`, `--surfaces Grass`,
`--n 40`, `--seed 1`, `--set path=value` (repeatable), `--jobs N` (default: every core),
`--json file`, `--real <pk-kubb-score>/games` (default: `$PK_KUBB_SCORE` or the sibling
checkout; without it the reference column is left out), `--gate` (exit 1 on a hard
defect, below). `make gym GYM="--full --json build/gym.json"` passes options through.

The JSON (`"tool": "kubb-gym"`) carries the engine version and commit (and whether core,
session, tune or room had local changes), the mode, seed, sets, the human model's version
and fit counts, every counter (so `compare` can do its statistics) and the anomaly clusters
with their repro commands.

## What is played

- **Configurations**: thrower x level x surface, by default the computer and the human
  thrower at beginner, club and pro on grass. Each match is both teams of that thrower at
  that level, raising as the engine raises such a side (since 0.11.3: the computer by its
  level, `cpu.raising`, the human thrower by the engine's advice, `cpu.advice`; both
  `apart` until they are switched on). Match `i` of
  seed `s` is the same match whichever process plays it; the computer's matches are
  `tools/physmatch.lua`'s to the bit (its game files are identical; it raises by the level
  too), so the computer's column is the one `docs/notes/real-games.md` reports.
- **The computer** is `core/autothrow` as the game plays it.
- **The human thrower** (`tools/gym/human.lua`) is a person at the meter. It picks the
  target and stance as the computer does, plans the throw at its own level as the session
  plans a player's (the level's gauge forgiveness, the default arc for the distance, no tilt or
  spin), draws a swing from the fitted model, and makes the launch as `throw.playerLaunch`
  does, nerves seeded by the swing. So it plays through the same forgiveness and nerves a
  person gets; only the swing is drawn instead of cranked.
- **Desktop Lua 5.4** plays the matches (stock `lua5.4`, many processes). Results are
  statistics, so the few-ulp differences from the reference do not matter. Everything
  compared with a recorded hash uses wasmoon, the reference (`docs/DETERMINISM.md`): the
  bank's hash checks do.

## Forensics (`tools/gym/forensics.lua`)

Every throw is stepped as `world.run` steps it, with `w.onContact` listening, and the
narrow phase called between steps to find where a touched piece was met.
`lua5.4 tools/gym/match.lua --selftest` throws a few matches with and without forensics and
checks that every body ends bit for bit the same; it does (665 throws). Cost: about 10% over
a bare match. Per throw it records:

- the ground first or a piece first; where it landed against its target's centre (along the
  throw: short or past; across: wide), its speed landing and how far its centre ran on
  (centre at the landing step to centre at rest: from the contact point, a nose-first
  landing's tip would read as the baton going back)
- the first standing piece it touched: top face, top edge, body or bottom, how high, the
  baton's speed, its lean from vertical and how steeply it came down, the speed it kept
  0.05 s later, and the kubb's fate (toppled, rocked, slid, nudged, did not move)
- a baton's arrival at its first kubb (below)
- how many fell, and how each fell: touched by the projectile, or only by another kubb
- every hard touch (3 m/s or more) and its fate; kubbs that moved and rest standing tilted
  past 10 degrees (propped); the time to rest; the largest rise in the world's energy
- a drill's rest against its mark; the field group's spread at the turn's first baton
- the group as a thrower reads it (2026-11-21, from the inkast videos: judge a group by
  the batons it needs). Standing, at the first baton, for groups of 3 or more: the
  batons it takes at best (chains of kubbs within 20 cm of each other), the share
  touching another (within 11 cm) and the longest touching chain. Lying, after an inkast
  of 3 or more and before the kubbs are raised: the share touching another (each kubb
  as three 7 cm discs along its long axis, within 2 cm), the longest chain, and how
  often 3 or more and 5 or more touch. Raising spreads a tight lying group, so the two
  are counted apart. Batons that toppled three or more and four or more are rows too.

Engines before 0.4.1 have no `onContact` (the bank throws on them): forensics finds touches
by the narrow phase each step, and the landing only when the ground was the first contact.

How the page counts a miss: a baton at a field or base kubb that left it standing touched
it, or landed short or past (more than 0.15 m along) or wide (more than 0.10 m across),
whichever is the larger share of its limit. "Meter all good" is power and release on target
and steady (the verdicts a player sees).

### Arrival

Where on the kubb the first contact point is (within 1 cm of the top, the face, the body)
does not say what the baton was doing: a baton's end coming down onto the top and its
shaft meeting the upper front corner as it travels both read as "top". So a baton's first
touch of a kubb also records its arrival: the part of the baton that met it (from its
lower tip, 0, to its upper tip, 1), its signed lean (+ the upper end ahead of its travel),
its descent, the contact normal's vertical share, its turn since release (read in the
throw's plane; the half turn is 180), its lowest point as its centre passes the target's
near face, and where its centre would have come down with nothing in the way (the hit
window). From these, one class each, the names a kubb player uses:

| class | when |
|---|---|
| came down on top | the contact is within 1 cm of the top and its normal is within about 45 degrees of vertical |
| clipped the top going over | within 1 cm of the top, the normal mostly sideways |
| body hit, upright | on the body, the baton within 45 degrees of vertical (the intended hit) |
| body hit, flat or sideways | on the body, the baton leaning more |
| ground first, then the kubb | it had met the ground before |

The page gives each as a share of throws and of touches, beside an "owner (est.)" column:
an experienced player's estimates from play (a baton comes down on top at most 1 in 20 to
30 throws; the throw makes a half turn and the hand end meets the kubb; a top hit topples
some of the time). The engine releases a baton upright and turns it upper end forward, so
after its half turn the end that was up at release is the lower one.

## Anomalies

Each is counted per 1000 throws, clustered by kind, piece, where and distance band, ranked,
and listed with a command that replays the throw (`--dump file` adds every body's state each
step, as physfuzz's dump):

| kind | what | gate |
|---|---|---|
| hardUnmoved | a touch at 3 m/s or more left the kubb unmoved | no |
| topVault | a touch within 1 cm of the top at 3 m/s or more, the kubb stood | no |
| propped | a kubb moved and rests standing, tilted past 10 degrees | no |
| deadStop | a baton landed at 4 m/s or more and went under 0.15 m | no |
| energy | the world's energy rose more than 0.02 J above its low | no |
| unsettled | still moving when the throw ran out of time (12 s) | yes |
| broken | a body's state is not a number, or a body sank under the ground | yes |

Only `unsettled` and `broken` are hard defects; `--gate` fails on them. The rest are rates:
some of each is real kubb, and whether a rate is too high is a judgement, never a gate.

## Fitting the human thrower

`node tools/gym.mjs fit <records> --write` reads a folder of recorded online matches (the
web repository's `npm run games:pull` writes one). The records are private: names and room
codes. The tools take the folder as an argument and never copy it; the snapshots and actions
go to the workers in a temporary folder that is removed before the command ends, and
`tools/gym/human-model.json` holds only counts and quantiles.

For each person's throw (`tools/gym/invert.lua`): restore the snapshot before it, plan it as
the player's session did (stance, target; the arc and tilt or spin the player set, which a
record names since 0.9 and are otherwise solved for: the release whose loft is the recorded
one, the planned tilt that keeps the STEADY verdict as recorded), then recover the rest from
the launch: the backswing and stop are recorded; the shake comes from the tilt, the pull from
its sign, the side draw from the swivel, and the flick and the length and tumble draws from
the speed and the tumble (the flick with the smallest draws). The launch rebuilt from these
must match the recorded one to a relative 1e-6.

Every tagged engine and the checkout are tried. Any engine whose plan is close enough
rebuilds a launch exactly (the draws absorb the difference), so the error cannot choose:
the engine is the one the record names, or, for records that name none (they predate the
first tag), the oldest. With that choice the recovered nerve draws come out as a standard
normal, as the engine's nerves model them (side mean -0.05, sd 1.03; length 0.07, 0.97;
tumble 0.06, 0.94), which says the inversion and the choice are right. Choosing the oldest
for every throw gave the length and tumble draws a mean of 1.5 and -2.8.

Fit 1 (2026-11-20): 418 of 420 recorded throws by people (273 batons, 145 drills) from 6
matches, club 327 and beginner 91, web and iPhone. There is no pro play recorded; pro uses
club's swings (on pro's tighter gauge). The model keeps, per level and projectile, 21
quantiles of: the backswing past the power target's centre, the stop past the release
target's centre, the flick's share of the power when it was not full (with the share of
full flicks), the shake, and the share pulled right. Each part is drawn on its own; the fit
prints their correlations, which are small (backswing and release -0.16, the rest under
0.07).

Validation is the bank's columns (below): what recorded throws did, beside the human
thrower's own throws at the same level.

## The recorded-throw bank

`--records <dir>` on a run (or `bank <dir>`) throws every recovered swing three ways, with
forensics:

- **played**: the recorded launch on the engine that planned it: what happened
- **launch now**: the recorded launch on this checkout's physics
- **re-planned now**: the same misses (counted from this checkout's targets), the same
  nerve draws, planned and thrown by this checkout

beside the human thrower's columns at the same levels. It also replays each room throw from
its snapshot under wasmoon on its own engine and checks the recorded hash, and does the same
on desktop Lua to show how far desktop agrees with the reference.

## Compare and sweep

`compare` takes two `--json` scorecards, or two git refs: it writes each ref's engine (core,
session, tune, room, version.lua) to a temporary folder, plays it with this checkout's gym
tools (`match.lua --engine DIR`), and removes the folder. With `--json` or `--keep` the
engine goes to `build/gym/engine-<commit>` and stays, so the saved replay commands still
run. An engine folder (a prototype
copy holding core, session, tune, room and version.lua) is played as it is; `run`, `bank`
and `--records` take one too (`--engine DIR`), so a candidate that is not a commit can be
scored, compared and banked. It prints only the figures whose
difference is past 2.58 standard errors (99%: a page has about 80 figures, so at 95% four
would move by chance). Both sides use the same seed, so the matches start alike.

`sweep` sets one number per run (`--set`). What can be swept: any number reachable by a
path from `tw` in a tune or level table that is read when a throw is made: `plan.tune.*`,
`plan.levels.<level>.*` (a level's nerves and tumble also go to the computer's copy of the
level), `autothrow.tune.*` (`swingScale.pro`, ...), `world.tune.*`, `flight.tune.*`,
`drill.tune.*`, `forensics.tune` is not in `tw` and is not a game number. What cannot: code;
strings and booleans; a number a module copies into a local when it is imported (it keeps the
old value; the sweep still runs, and nothing moves); the session's tunes (`tune/pointer`: the
gym does not play through the session); the human model (fit again, or pass `--model`).

## Versus

`run` plays one configuration against itself, so it can say a variant clears the field
more often but not whether it wins. `versus` (2026-11-21) plays two teams that play
differently against each other:

    node tools/gym.mjs versus --a "level=pro" --b "level=pro;autothrow.tune.inkast.pro.row=0"

A spec is one team: `level=` (beginner, club, pro; default club), `thrower=` (cpu or
human; default cpu), `raise=` (the policy it raises the other team's kubbs with when it
defends; default, since 0.11.3, what the engine does for such a side: the computer by its
level, `cpu.raising`, and the human thrower, a person whose kubbs the engine raises, by
`cpu.advice`; in 0.11.3, and on an engine before it, `apart`) and any number of `path=value` tune settings, the paths `--set`
takes. Parts are split by `;` or `,`. Options: `--n` (seeds, default 300), `--seed`,
`--surfaces`, `--maxturns`, `--jobs`, `--json`, `--set` (for both teams), `--probe N`
(below), `--engine`.

**What a team's spec reaches.** Its level and thrower make its throws (`autothrow.choose`
or the human thrower at that level, so its target, stance, arc and swing). Its raising
policy is given to the engine (`game.raisePolicy`) just before it raises; the Gym raises
and places punishment kubbs itself, with that team's numbers in force, before
`match.setup` (whose own settle then has nothing to do). Its tune settings are in force
while it acts: its setup (with the settling of tilted pieces before its throw), its throw's
plan, swing and physics, and the ruling on it; and, as the defender, its raising and its
punishment kubb placement.

**How the settings are switched** (`tools/gym/versus.lua`). Each set key is taken out of
its table and served by the table's `__index`: the acting team's value, or the shipped one
when that team does not set it or no team acts. No module can read the other team's number,
whatever local it holds the table in. A `plan.levels.<level>` nerve or tumble goes to the
computer's copy of the level too, as with `--set`. Every read is counted by team, and the
run prints the counts.

**What is refused.** Before the matches it plays `--probe` seeds (default 2) both ways
round without forensics and refuses a spec that sets a number nothing reads while that
team acts: a number a module copied into a local at import (`pitch.kubbLong`: core/raising
keeps half of it), or one that team never reaches (`autothrow.tune.inkast.pro.row` on a
club team). It also refuses a value equal to the shipped one, an unknown policy and a path
that is not a number. A number read only rarely (a punishment kubb's grid) may need a larger
`--probe`. What cannot be switched by team at all: code, strings and booleans, the session's
tunes (the Gym does not play through the session), and anything the engine reads outside a
team's action (none in a match today: the counts print reads outside an action, and they
are 0).

**Raising policies.** The engine's (`tw.raising.policies`: `apart`, every side's in
0.11.3 and before; `par`, built switched off; `first`; `together`) and two the Gym adds, which keep a row across the pitch
a row: every kubb with a choice goes up on the same end, `away` on the end away from the
centre line (deeper in the defender's half), `toward` on the end toward it. A kubb with
one choice goes where the rules put it.

**How the teams are swapped.** Every seed is played twice. In the first game team A
plays side A and team B side B; in the second they change sides. The side that opens
(match `i` of physmatch's rule) and the random stream are the seed's in both, so team A
opens one game of the pair and team B the other, from the same pitch with the same draws:
the opener's edge and the seed's luck fall on each team once. Two teams with the same
spec play the same game both ways round, bit for bit (the game files match; the page says
how many did), and come out at exactly 50%.

**What it reports.** Games won by A and by B and games that hit the turn limit (the
attacker resigns there). The interval is paired: each seed's two games give team A a
score of 0, 0.5 or 1 (a game at the turn limit counts half), and the 95% interval is the
normal one of the mean score over seeds; beside it, Wilson on the decided games as if they
were independent. Then the same split by who opened. Then each team's own scorecard rows
side by side: the `g.*` figures counted over that team's turns only (turns a game is its
turns; ended on the king when it toppled the king), and every forensics row over the
throws it made (its inkast's lying group; the standing group at its first baton, which it
threw in and the other team raised). The z column is compare's: B less A over the two
standard errors, `!` past 2.58. Last, each team's largest anomaly clusters with a
replay command (`match.lua --a ... --b ... --swap 0|1 --repro M:T`).

**What it cannot say.** The z of a scorecard row treats throws as independent; they are
not (throws of one game, and the two teams play the same games), so read only a z well
past 2.58, as compare's "moved". The wins are the measure. A team's turn-level figures
depend on the other team too (the field it throws at is the other team's raise of its own
inkast), so a row says what happened, not why. A game at the turn limit is a draw here,
which a real match never is. The human thrower takes the computer's target, and raises
as a person raised by the engine does (`cpu.advice`).

The next two sections measure what 0.11.3 builds switched off: the raising by level and
the two attacking plays, switched on in the Gym as they are to be enabled (pro `par`,
club `apart`, beginner `first`, a person `par`, Jamie's decisions of 2026-11-21:
owner-2026-11-21#s5, Q7; `field.line` and `inkast.depth` at pro). "On" in their tables
is that engine; 0.11.3 as shipped plays exactly as 0.11.2, so its rows are 0.11.2's.

### The first versus results (2026-11-21)

Engine 0.11.0, the computer on grass, 300 seeds (600 games) each, seed 1, turn limit 40;
20 to 90 s a pairing on 14 processes. A's score is the paired interval; a team's `raise`
is how it stands up the other team's kubbs.

| A | B | won A / B / limit | A's score |
|---|---|---|---|
| pro | club | 576 / 24 / 0 | 96.0 (94.5 to 97.5) |
| club | beginner | 560 / 36 / 4 | 93.7 (91.8 to 95.5) |
| pro | beginner | 598 / 2 / 0 | 99.7 (99.2 to 100) |
| pro, row | pro, `inkast.pro.row=0` | 404 / 193 / 3 | 67.6 (64.2 to 71.0) |
| club, row | club, `inkast.club.row=0` | 299 / 291 / 10 | 50.7 (47.1 to 54.3) |
| pro, raise apart | pro, raise together | 141 / 455 / 4 | 23.8 (20.8 to 26.9) |
| pro, raise apart | pro, raise first | 164 / 434 / 2 | 27.5 (24.3 to 30.7) |
| pro, raise apart | pro, raise away | 163 / 435 / 2 | 27.3 (24.2 to 30.5) |
| pro, raise apart | pro, raise toward | 146 / 453 / 1 | 24.4 (21.4 to 27.5) |
| row, its kubbs raised away | line, raised away | 219 / 380 / 1 | 36.6 (33.2 to 39.9) |
| row, raised apart | line, raised away | 330 / 268 / 2 | 55.2 (51.8 to 58.5) |
| row, raised away | line, raised apart | 264 / 330 / 6 | 44.5 (41.1 to 47.9) |
| pro | pro (the same spec) | 299 / 299 / 2 | 50.0, every pair split |

- The levels are far apart: the weaker level wins 0.3 to 6% of games.
- **Raising apart loses.** Against the computer, `apart` (the computer's own policy and
  auto raise's) is the worst of the five: the team that raises any other way wins 72 to
  76%. Kept together, a turn's kubbs stand flank to flank across the pitch about 10 cm
  apart (touching another: 57 to 69% of them, against 4% raised apart), and the computer
  takes them one at a time from the front (two with one baton 14 to 15% of field batons,
  against 20 to 22% at a field raised apart; cleared 67 to 70% of turns against 82%).
  The computer's lane (`autothrow.tune.laneHalf`, 7 cm) never joins two kubbs side by side.
- **The row wins only through apart.** At pro the row beats the line 68 to 32 with both
  raising apart, 55 to 45 when only the row is raised apart, and loses 37 to 63 when both
  are raised away; at club it is even. So the row's worth is the defender's staggering,
  as the 2026-11-21 measurement suspected.
- The opener wins about 54.5% at pro (163 of 299 with the same spec both sides).
- The grid inkast (`row=0`) gains energy on about 8 throws in 1000 (the row 1), most of
  them drills (the one replayed came down on a kubb already lying).

### Raising by the attacker's batons (2026-11-21)

Engine 0.11.2, `raising.policies.par` (raise.par; built, used by no level), the computer
on grass, 300 seeds each, seed 1 with seed 2 beside it; `line` is
`autothrow.tune.inkast.<level>.row=0` on that team. A team's `raise` is how it stands the
other team's kubbs.

| A | B | won A / B / limit (seed 1) | A's score, seed 1 | seed 2 |
|---|---|---|---|---|
| pro, raise par | pro, raise apart | 460 / 138 / 2 | 76.8 (73.8 to 79.9) | 75.1 (72.1 to 78.1) |
| pro, raise par | pro, raise away | 326 / 267 / 7 | 54.9 (51.6 to 58.3) | 55.2 (51.7 to 58.6) |
| pro, raise par | pro, raise together | 290 / 296 / 14 | 49.5 (46.1 to 52.9) | 50.6 (47.1 to 54.1) |
| pro line, raise par | pro line, raise apart | 317 / 269 / 14 | 54.0 (50.8 to 57.2) | 52.1 (48.9 to 55.3) |
| pro line, raise par | pro line, raise away | 391 / 204 / 5 | 65.6 (62.0 to 69.2) | 64.3 (60.9 to 67.6) |
| pro row, raise par | pro line, raise par | 277 / 313 / 10 | 47.0 (43.2 to 50.8) | 43.3 (40.0 to 46.6) |
| club, raise par | club, raise apart | 337 / 255 / 8 | 56.8 (53.6 to 60.1) | 59.1 (55.6 to 62.5) |
| club, raise par | club, raise away | 337 / 256 / 7 | 56.8 (53.3 to 60.2) | 60.3 (56.8 to 63.7) |
| club, raise par | club, raise together | 343 / 253 / 4 | 57.5 (54.0 to 61.0) | 60.4 (57.0 to 63.8) |
| club line, raise par | club line, raise apart | 288 / 294 / 18 | 49.5 (46.3 to 52.7) | 53.4 (50.2 to 56.6) |
| club line, raise par | club line, raise away | 372 / 220 / 8 | 62.7 (59.5 to 65.8) | 61.0 (57.6 to 64.4) |
| pro, raise par | the same spec | 290 / 290 / 20 | 50.0, every pair split | |

- **par does what apart did best and what the fence did best.** Against the row it wins
  as the fence policies did against apart (77 to 23), and against `together` and `away`
  it is even at pro and wins 57 to 60% at club. Against the line it is even with apart at
  pro (the policy that did well there; 54.0 and 52.1, both intervals touching 50), even
  to slightly ahead at club (49.5 and 53.4), and beats `away` 61 to 66%.
- **How.** At pro, a field raised by par against one raised apart (the row): field
  batons that took two 14.2% against 21.6%, three or more 2.3% against 4.4%, turns
  cleared 70.0% against 83.1%, batons to clear 3.82 against 3.63.
- **Against par, the line beats the row** (row's score 47.0 and 43.3): Q6's answer under a
  defender who raises by the attacker's batons. The line's attacker clears 72 to 76% of
  its turns against the row's 69 to 70%.
- **What did not matter, against the computer.** par with only the straight-on view
  (`parSide=0`: 77.3, 55.4, 52.0, 65.3 on the first four rows), or with no plan over the
  kubbs still lying (`parSweeps=0`: 77.2, 56.3, 52.5, 65.8), or a wider lane (`parAcrossReach=0.18`:
  76.0, 55.9, 54.6, 65.8): all within the intervals of the shipped numbers. The computer always stands
  straight behind its target, so the side views cannot show against it; they are kept for
  a person who throws from the end of the line.

### Raising by level (2026-11-21)

The raising switched on, against 0.11.2: the computer raises by its level (pro `par`,
club `apart`, beginner `first`) and a person's side raised by the engine by `par`;
before, every side raised `apart`. Grass, seed 1, 300 matches a configuration (600 games a pairing), turn
limit 40. The scorecard is `node tools/gym.mjs --throwers cpu,human --levels
beginner,club,pro --full --seed 1` on the engine with `cpu.raising` and `cpu.advice` set
so, the before run on 0.11.2's engine (`--engine`).

The computer's rows that moved past 2.58 standard errors, beside the level's target
(`docs/reference/play-levels.json`). Club raises `apart` as before: none of its rows moved.

| level | row | 0.11.2 | on | target | |
|---|---|---|---|---|---|
| pro | field batons that took two | 22.2% | 13.6% | 17 to 23 (measured) | away: out of range |
| pro | ... took three or more | 4.9% | 1.8% | 12 to 18 (measured) | away |
| pro | turns that cleared the field | 77.0% | 69.5% | 87 to 94 (measured) | away |
| pro | batons to clear, when cleared | 3.70 | 3.96 | | |
| pro | turns from an advantage line | 20.1% | 26.9% | 8 to 15 (measured) | away |
| pro | turns a game | 12.2 | 14.1 | 6 to 10 (measured) | away |
| pro | ended on the king (else the turn limit) | 99.7% | 96.7% | | |
| pro | standing field group: kubbs touching another | 4% | 54% | | |
| beginner | field batons that took two | 6.3% | 8.5% | 1 to 5 (owner) | away (it was above already) |
| beginner | ... took three or more | 0.5% | 0.8% | 0 to 1 (owner) | in range |

The human thrower plays both sides and so raises `par` against itself: field batons that
took two 10.4% to 9.6% at beginner, 8.5% to 6.9% at club (target 8 to 13: now under it),
4.1% to 3.6% at pro.

**Pro moves away from real play, as expected.** With both pro teams raising by the
attacker's batons, each faces a fence the computer's baton cannot take (Q16: it never
joins two kubbs standing flank to flank), so it takes two with one baton 14% of the time
instead of 22%, clears 70% of its fields instead of 77%, throws from an advantage line
more often and needs two more turns a game. The raising is right (Q7); the attacker is
what is short, and it is the next item of work (docs/notes/computer-player.md).

`versus`, 300 seeds each way round (A's score is the paired interval):

| A | B | won A / B / limit | A's score | 0.11.2 |
|---|---|---|---|---|
| pro (par) | pro, `raise=apart` (0.11.2's pro) | 460 / 138 / 2 | 76.8 (73.8 to 79.9) | |
| pro | club | 581 / 19 / 0 | 96.8 (95.5 to 98.2) | 96.0 (94.5 to 97.5) |
| club | beginner | 559 / 37 / 4 | 93.5 (91.6 to 95.4) | 93.7 (91.8 to 95.5) |
| pro | beginner | 595 / 5 / 0 | 99.2 (98.4 to 99.9) | 99.7 (99.2 to 100) |
| beginner (first) | beginner, `raise=apart` | 216 / 334 / 50 | 40.2 (36.8 to 43.5) | |

- The ladder holds: each level beats the one below it about as often as before.
- **A beginner's `first` is a worse defence than `apart`** (40 to 60): standing every
  kubb on the first end the rules list leaves more doubles (its attacker took two with
  8.3% of field batons against 6.6%). That fits a beginner who stands kubbs anyhow; a
  random end, when Choose has its own stream, may land between the two.

The human thrower at each level against the computer at the same level (the person's
kubbs raised by the engine), on 0.11.2 (both `apart`) and with the raising on (the person
`par`, the computer by its level):

| level | 0.11.2: won A / B / limit, A's score | on | the computer's field batons that took two |
|---|---|---|---|
| beginner | 585 / 12 / 3, 97.8 (96.6 to 98.9) | 586 / 13 / 1, 97.8 (96.6 to 98.9) | 6.8% to 6.3% |
| club | 73 / 526 / 1, 12.3 (9.6 to 14.9) | 91 / 503 / 6, 15.7 (12.8 to 18.6) | 11.8% to 9.5% |
| pro | 0 / 600 / 0, 0.0 | 0 / 600 / 0, 0.0 | 16.9% to 9.0% |

At club the engine's advice wins a person about 3 games in 100 more; at pro it halves the
doubles the computer takes but the human thrower at pro (its model's weakest level) wins
none either way. The pro computer's own defence costs the human pro little: its field
batons took two 4.4% to 3.5%.

### The attacker's plays (2026-11-21)

`field.line` (pro) and `inkast.depth` (club and pro, as first switched on; club's column
is left out of what is to be enabled, below), the plays in `cpu.tune`
(docs/notes/computer-player.md), with the raising on. Grass, 300 seeds (600 games) a pairing, seed 1
with seed 2 beside it, turn limit 40. Both pro teams defend with `par`, both club teams
with `apart` (the levels' raising, on). "Without" is the level with the play switched
off, as 0.11.3 ships it; with it is `--set cpu.tune.<play>.<level>=1`.

| A | B | A's score, seed 1 | seed 2 |
|---|---|---|---|
| pro, `inkast.depth` | pro without either | 74.5 (71.3 to 77.7) | 74.5 (71.4 to 77.6) |
| pro, `field.line` | pro without either | 54.8 (51.5 to 58.0) | 56.9 (53.7 to 60.2) |
| pro, both (as to be enabled) | pro without either | 79.4 (76.4 to 82.4) | 79.9 (77.0 to 82.8) |
| pro, both | pro, `inkast.depth` only | 59.5 (56.3 to 62.7) | 61.4 (58.2 to 64.7) |
| club, `inkast.depth` (as first switched on) | club without | 58.8 (55.2 to 62.4) | 62.0 (58.3 to 65.7) |
| club, `field.line` | club without either | 53.1 (49.9 to 56.3) | 50.6 (47.4 to 53.8) |
| club, both | club, `inkast.depth` only | 52.0 (48.8 to 55.2) | 50.5 (47.2 to 53.8) |

Each team's own rows, seed 1 (A against B):

| pairing | took two | three or more | cleared | drill rests from its mark |
|---|---|---|---|---|
| pro `inkast.depth` / without | 21.6 / 13.8 | 4.6 / 2.3 | 79.3 / 68.4 | 0.06 / 0.07 m |
| pro `field.line` / without | 14.4 / 13.2 | 2.7 / 2.2 | 74.8 / 72.7 | |
| pro both / without | 22.0 / 14.5 | 5.9 / 2.5 | 85.2 / 68.9 | 0.06 / 0.06 m |
| pro both / `inkast.depth` | 22.3 / 22.0 | 6.8 / 5.4 | 81.6 / 77.3 | |
| club `inkast.depth` / without | 14.6 / 13.2 | 2.6 / 2.0 | 74.9 / 69.2 | 0.18 / 0.21 m |
| club `field.line` / without | 13.8 / 13.4 | 2.1 / 1.8 | 72.0 / 71.6 | |

- **The column is the larger play.** Laid end to end down the baton's path, a turn's
  kubbs stand in one lane whichever ends the defender raises them on, so `par` cannot
  take them apart, and the column's drills rest as close to their marks as the row's
  (closer: 0.06 m against 0.07 at pro, 0.18 against 0.21 at club).
- **`field.line` adds on top of it at pro** (59.5 and 61.4), mostly by three or more and
  by the turns cleared. At club it adds nothing, alone or on top of the column. The club
  hand scatters a column more, which leaves fewer pairs to line up.
- **What it cost to get there.** With both teams laying columns the first build forfeited
  3.6% of the pro's batons (real games: 0.0%), nearly all for touching a field kubb in the
  thrower's own half (II.B.11): the baskets face each other, so two columns grown to the
  centre line stand a hand apart, and the thrower on the advantage line stands among the
  other team's. `field.line` now rules out a stance within 0.3 m of such a kubb and steps
  along the line instead, and a column stops at 4.35 m (`cpu.tune.depth.front`). Pro
  forfeits are back to 1.1%. A column grown to 4.05 m still beats one held back 55.4%
  (52.2 to 58.6), from shorter throws, but with both teams doing it 3.6% of batons are
  forfeit again.

The designs tried, in order (pro against pro, seed 1 unless named):

| design | against | A's score |
|---|---|---|
| `field.line` 1: the lane's count along the true line | pro | 52.8 (50.0 to 55.7); seed 2 53.3 (50.2 to 56.3) |
| `field.line` 2: the lane weighed as `par` weighs a pair | pro | 53.3 (50.2 to 56.5); seed 2 55.0 (51.7 to 58.3) |
| design 2 against design 1 | | 52.2 (49.0 to 55.3) |
| design 2 on top of the column (gap 0.04), before the own-half rule | pro, column | 54.7 (51.3 to 58.1); seed 2 53.5 (50.4 to 56.6) |
| design 2 with the own-half rule and the step aside (built) | pro, column | 59.5 (56.3 to 62.7); seed 2 61.4 (58.2 to 64.7) |
| `inkast.depth`, gap 0.02 | pro | 71.3 (67.9 to 74.6) |
| against gap 0.02: gap 0, 0.04; run 3, 5; `x` 2.2; `back` 0.3 | the same, gap 0.02 | 38.8; 57.2; 50.3; 49.8; 52.8; 48.2 |
| against gap 0.04: gap 0.06, 0.08; `x` 2.2 | the same, gap 0.04 | 46.6; 43.7; 49.8 |
| gap 0.04 | pro | 77.8 (74.7 to 80.8); seed 2 75.8 (72.8 to 78.8) |
| gap 0.04, held at 4.35 m (built) | pro | 74.5 (71.3 to 77.7); seed 2 74.5 (71.4 to 77.6) |
| held at 4.05 m | built | 55.4 (52.2 to 58.6), but 3.6% forfeit when both teams do it |

**Club without the column (Jamie's decision of 2026-11-21).** With `inkast.depth` the
club computer beat the club without it 59 to 62 games in 100, but moved a little away
from real play (turns a game 15.5 to 17.8 against 8 to 14, took two 13.1% to 15.6%
against 8 to 13, turns cleared 73.1% to 70.6%), and a person at club won 10 games in 100
against it where the owner's new target for club is about 40 (owner-2026-11-21#s6). Club
is to be retuned as a whole against that target in a later release; until then it is to
play as in 0.11.2 (`cpu.tune.depth.club = 0`): it raises `apart`, lays the row and
stands straight behind its target. Pro is to have all three plays.

**Everything switched on, against 0.11.2.** `node tools/gym.mjs compare v0.11.2 <ref>
--throwers cpu,human --levels beginner,club,pro --full --seed 1`, the ref an engine with
every switch set as it is to be enabled. The computer's rows beside their target; an "on"
figure in bold moved past 2.58 standard errors from 0.11.2. "Raising only" is the
raising on and no attacking play (`par` at pro).

| level | row | 0.11.2 | raising only | on | target |
|---|---|---|---|---|---|
| pro | field batons that took two | 22.2% | 13.6% | 22.2% | 17 to 23 (measured) |
| pro | ... took three or more | 4.9% | 1.8% | **6.8%** | 12 to 18 (measured) |
| pro | missed | 14.6% | 13.9% | **16.9%** | 12 to 19 (measured) |
| pro | turns that cleared the field | 77.0% | 69.5% | 78.5% | 87 to 94 (measured) |
| pro | batons to clear, when cleared | 3.70 | 3.96 | 3.71 | |
| pro | turns from an advantage line | 20.1% | 26.9% | 18.7% | 8 to 15 (measured) |
| pro | turns a game | 12.2 | 14.1 | 12.3 | 6 to 10 (measured) |
| pro | standing field group: kubbs touching another | 4% | 54% | **30%** | 60 to 90 (owner) |
| beginner | field batons that took two | 6.3% | 8.5% | **8.5%** | 1 to 5 (owner) |
| beginner | ... took three or more | 0.5% | 0.8% | **0.8%** | 0 to 1 (owner) |

- **Club: unchanged.** Every row of the club computer is 0.11.2's to the last figure:
  the same games, since club throws and raises as before.
- **Beginner: the raising only.** It knows neither play; its took one, took two and three
  or more moved with `first` (and its field groups with them: 0.96 to 0.88 of a group's
  kubbs each its own baton).
- **A person: the raising only.** The human thrower plays both sides and so raises `par`
  against itself: took two 10.4% to 9.6% at beginner and 8.5% to 6.9% at club (target 8
  to 13: now under it), and at pro missed 56.2% to 54.6% and rethrown 14.2% to 12.9%.
- **Pro: partly toward real play.** The attacking plays win back everything the defence
  cost and a little more on three or more: took two is back in range, three or more is
  higher than 0.11.2 and still half the real figure, and the turns cleared and turns a
  game are back where 0.11.2 had them, still short of real play (78.5% against 87 to 94;
  12.3 turns against 6 to 10).

`versus`, 300 seeds each way round, seed 1 and seed 2, against the same pairings before.
Old pro is 0.11.2's pro as `versus` can stage it: `raise=apart`, both plays off (so the
row).

| A | B | on, seed 1 | seed 2 | raising only | 0.11.2 |
|---|---|---|---|---|---|
| pro | old pro | 79.0 (76.0 to 82.0) | 81.3 (78.4 to 84.1) | 76.8 | |
| pro | club | 97.0 (95.7 to 98.3) | 97.2 (95.9 to 98.5) | 96.8 | 96.0 |
| club | beginner | 93.5 (91.6 to 95.4) | 94.1 (92.2 to 96.0) | 93.5 | 93.7 |
| pro | beginner | 99.8 (99.5 to 100) | 100 (600 of 600) | 99.2 | 99.7 |
| human beginner | computer beginner | 97.8 (96.6 to 98.9) | 97.6 (96.4 to 98.8) | 97.8 | 97.8 |
| human club | computer club | 15.7 (12.8 to 18.6) | 16.8 (13.7 to 19.8) | 15.7 | 12.3 |
| human pro | computer pro | 0.2 (0.0 to 0.5) | 0.0 | 0.0 | 0.0 |

Club against beginner and the human thrower against club are the raising-only figures exactly,
as they should be: neither side throws a new play. The new pro beats the old 79 and 81
games in 100; its own rows against it (seed 1): took two 22.5% against 14.3%, three or
more 6.9% against 2.2%, turns cleared 84.2% against 70.2%. A person at club wins about
16 games in 100, against a target of about 40: club's retuning is to follow.

**The defence played again** (pro, both teams with the plays on; club with
`inkast.depth` on, as first switched on):

| A | B | on, seed 1 | seed 2 | against the raising-only attacker |
|---|---|---|---|---|
| pro, raise par | pro, raise apart | 50.3 (47.1 to 53.6) | 51.8 (48.7 to 55.0) | 76.8, 75.1 |
| pro, raise par | pro, raise away | 56.8 (53.5 to 60.2) | | 54.9, 55.2 |
| pro, raise par | pro, raise toward | 54.7 (51.5 to 57.9) | | |
| pro, raise par | pro, raise together | 56.8 (53.4 to 60.2) | | 49.5, 50.6 |
| club, raise par | club, raise apart | 53.5 (50.1 to 56.9) | 56.3 (53.2 to 59.3) | 56.8, 59.1 |

`par`'s 77-to-23 win over `apart` was the old attacker's blind spot: against an attacker
that lays columns and stands where the kubbs line up, the two are level. `par` now beats
the policies that keep every kubb on one end (55 to 57), which it only matched before,
and it is no worse than `apart` anywhere. So `par` is still the pro's and a person's
raising to enable; its case is now that it never loses, not that it wins by three games in four.

## Speed

On a 10-core Apple M4 (4 performance, 6 efficiency cores), one core, 12 matches each:
the computer about 65 matches a minute (beginner 69, club 65, pro 61), the human thrower
66 at beginner, 144 at club (shorter matches) and 87 at pro. About 200 throws a second a
core with forensics on. Quick (240 matches) takes about 50 s, full (1800 matches) about
5.5 minutes, the bank 40 to 75 s (most of it inverting on 17 engines).

## CI

The `gym` job in `.github/workflows/validate.yml` runs the quick scorecard on every pull
request with `--gate` and keeps the JSON as an artifact. It gates on the tool running and
on `unsettled` and `broken`, never on a rate. It has no real games and no records.

## The first full scorecard (2026-11-20)

Engine 0.9.0 (main), full: 300 matches a configuration, seed 1, grass, the computer and the
human thrower (fit 1) at beginner, club and pro, with the bank. 325 s for the matches and
about 40 s for the bank (6 min 7 s in all). Shares in %, each with its 95% half width.

| figure | cpu beg | cpu club | cpu pro | human beg | human club | human pro | real |
|---|---|---|---|---|---|---|---|
| turns a game | 25.2 | 22.4 | 18.3 | 20.8 | 18.9 | 22.8 | 8.9 |
| field batons missed | 49.9 | 41.7 | 24.0 | 36.0 | 49.1 | 62.8 | 24.7 |
| field batons took two | 2.6 | 4.7 | 8.6 | 3.2 | 2.4 | 1.3 | 16.0 |
| took three or more | 0.1 | 0.2 | 0.7 | 0.1 | 0.1 | 0.0 | 10.0 |
| field kubbs cleared | 54.6 | 54.0 | 60.1 | 68.2 | 51.6 | 40.0 | 83.4 |
| base kubb from 8 m | 6.8 | 16.3 | 28.1 | 8.0 | 15.1 | 16.0 | 32.7 |
| base kubb from an advantage line | 31.1 | 32.3 | 52.2 | 39.4 | 40.4 | 30.0 | 51.7 |
| king shots that toppled it | 59.4 | 74.2 | 86.6 | 88.2 | 71.8 | 48.9 | 83.8 |
| meter all good | 41.4 | 60.0 | 84.0 | 83.5 | 52.2 | 21.6 | |
| missed: landed short | 26.8 | 32.1 | 28.1 | 38.7 | 41.6 | 45.3 | |
| short, stopped before the kubb | 39.1 | 12.8 | 7.9 | 47.9 | 36.7 | 46.4 | |
| first touch on the top | 64.0 | 54.6 | 58.0 | 75.3 | 60.5 | 63.5 | |
| touched on the top, stood | 17.3 | 17.0 | 14.8 | 5.8 | 20.8 | 25.5 | |
| first touch, kubb did not move | 6.4 | 2.2 | 1.4 | 2.3 | 3.1 | 4.4 | |

Against `docs/notes/real-games.md`: the computer at pro gives what that note's per-level line
gave (seed 2 there, seed 1 here): turns 18.3 (17.8), field missed 24.0 (24.8), base from 8 m
28.1 (33.5), from an advantage line 52.2 (57.8), the king 86.6 (82.8), illegal 1.1 (1.1).
The base-kubb figures are lower by about the width of their intervals; nothing else moved.
The gaps to real play that note lists are all still here: about twice the turns, two kubbs
with one baton a third as often as people, three or more almost never.

The human thrower against the bank (recorded throws as played; human gym; club):
meter all good 51.9 / 52.2, field kubb toppled 48.1 / 49.2, missed short 34.8 / 41.6,
past 33.9 / 33.4, wide 7.8 / 11.1, touched and stood 23.5 / 13.9, short and stopped
35.0 / 36.7, first touch on the top 61.2 / 60.5; at beginner, meter all good 81.0 / 83.5,
field kubb toppled 68.8 / 63.1. Inside the bank's intervals on everything but "touched it,
it stood", where real throws touch and leave the kubb standing more often (23.5 against
13.9; and the kubb did not move 7.4 against 3.1). The human thrower at pro is club people
on pro's tighter gauge, so it plays worse than club; that column is a what-if, not a level.

Of the 417 room throws, 339 replay to the recorded snapshot under wasmoon on the engine
that planned them. The matches played before the first tag are recovered on v0.2.0, the
nearest tagged engine to what they ran, so not all of theirs can replay exactly. Desktop Lua gives 265, and the two agree on 343
of 417: desktop Lua is not a hash platform. On this checkout 323 replay unchanged.

What it says about what players notice:

- **Short batons.** Of the batons that miss a field or base kubb, people land 35% short
  (bank, club) and the human thrower 42%; 35 to 48% of those stop before reaching the kubb.
  The computer at pro: 28% short, 8% die before it. The human thrower reproduces the
  recorded rate, so it comes from swings as people make them through the engine's
  forgiveness and nerves; which part of the swing is behind it is not yet split out.
- **Tops.** 55 to 75% of first touches on a kubb are on its top (edge or face) in every
  column, people's too (61%). About one in five of those leaves the kubb standing; the
  `topVault` clusters (top edge, field kubb, 4 to 6 m, the kubb rocked) are the largest
  anomaly at every level, 30 to 39 per 1000 throws.
- **Kubbs that do not move.** Hard touches (3 m/s or more) that leave a kubb unmoved: 6 to
  10 per 1000 throws, mostly on the top face or edge of a field kubb from 4 to 6 m. In the
  recorded throws the first-touched kubb did not move 7.4% of the time, more than twice the
  human thrower's 3.1%.
- **One kubb at a time.** Two or more with one baton: 1.8% (human club) to 7.2% (cpu pro)
  of batons; people in the 150 real games take two 16% and three or more 10% of the time.
  When two fall, about a third of the time the second falls by kubb on kubb.
- **Dead stops.** A baton that lands at 4 m/s or more and goes under 15 cm: 34 per 1000 at
  beginner (mostly base kubbs from 6 m and beyond; the top example tumbles at 1.9 turns a
  second and lands 0.7 m short at 8.6 m/s), 1 at pro. Some go a few centimetres backwards.
- **Energy.** 1 to 4 per 1000 throws gain more than 0.02 J; the largest cluster is
  beginner drills (2.5 per 1000).

Nothing here is tuned or fixed: these are for Jamie.

## Not built

- No pro swings: nobody has played online at pro. The pro human column is club people on
  pro's gauge.
- The human thrower takes the computer's choice of target and stance, never tilts or spins,
  and never sets the arc (the records show 36 of 418 with a set arc, 1 with a tilt).
- The model draws the parts of a swing on their own; a person's misses within a match are
  not correlated (no hot or cold hand).
- Surfaces other than grass are run only when asked (`--surfaces`).
- The bank re-throws only; it does not replay whole recorded matches on the new engine.
