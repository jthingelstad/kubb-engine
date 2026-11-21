# How kubb is played, by level

A reference for the computer player and the Kubb Gym: what a game looks like when
beginners, club players and pros play it, and the habits that make the difference.
It changes nothing in the engine. What to tune from it is Jamie's call.

`play-levels.json` beside this file holds the same thing as numbers: a target range per
level for each Gym scorecard row, and the measured figures they come from.
`node tools/realtiers.mjs <real games dir> --json` reproduces the measured block.

## Where it comes from

Every claim here carries one of four tags.

- **measured**: counted from the 150 scored tournament games (docs/notes/real-games.md),
  split by team strength with `tools/realtiers.mjs`.
- **owner**: Jamie's statements from playing the game.
- **coach**: Eric Anderson's ten Inkastare Training Tips (2013 videos), with Josh
  Feathers in tip 6, and his "How To Throw Kubbs - The Basics" for the U.S. National
  Kubb Championship (2020). They teach method and give no numbers.
- **estimate**: worked out from the others. Nobody has measured it.

Three limits to keep in mind.

- All 150 games are tournament games. The weakest third of those teams still drills
  and throws a half-turn baton. It stands in for club play; it is not beginners.
- **There is no beginner data at all.** Every beginner number is an estimate.
- Teams are ranked by field kubbs a baton, so the hit-rate rows are partly circular:
  the top third hits more because that is how it was picked. The rows the ranking did
  not use (8 m, king, rethrows, clearing, game length) are the honest comparison.

## The shape of a game

A game is a race to keep clearing the field. Each turn a team throws in the kubbs it
was handed, knocks them down, and spends what batons are left on base kubbs at 8 m.
The turn it fails to clear, the other team walks up to an advantage line, and the game
usually ends there.

- A turn that left field kubbs standing: that team lost 83% of the time (measured,
  191 turns).
- A turn thrown from an advantage line: that team won 83% of the time (measured,
  192 turns). Owner: "Against a really good team leaving an advantage line means you
  very likely lose."
- A game is 8 or 9 turns (median 8; one in ten is over in 5, one in ten runs past 16).
- The most kubbs on the field at once in a typical game is 7.
- When a team clears, it has 2.5 to 2.8 batons left for the baseline, at every level.
  Better teams do not save more batons. They face bigger fields and still clear them,
  and they hit more from 8 m with what is left.

Clearing gets hard fast as the field fills, and that is where levels separate:

| Field kubbs | All | Top third | Middle | Low third |
| --- | --- | --- | --- | --- |
| 2-3 | 94% | 100% | 99% | 90% |
| 4-5 | 87% | 97% | 90% | 74% |
| 6-7 | 76% | 90% | 81% | 40% |
| 8+  | 60% | 72% | 52% | 44% |

Share of turns that cleared the field (measured). A low-tier team facing six kubbs
clears less than half the time; a top team still clears nine in ten.

## The three levels

| | Beginner | Club | Pro |
| --- | --- | --- | --- |
| Anchor | estimate | low third, measured | top third, measured, plus owner |
| Field batons that miss | 45-60% | 30-40% | 12-19% |
| Field batons that take two | 1-5% | 8-13% | 17-23% |
| ... three or more | 0-1% | 3-7% | 12-18% |
| Turns that clear the field | 35-55% | 68-80% | 87-94% |
| Base kubb from 8 m | 7-13% | 19-27% | 39-48% |
| Base kubb from an advantage line | 20-32% | 33-45% | 58-82% |
| King | 40-60% | 62-75% | 84-96% |
| Kubbs thrown again (first throw out) | 15-30% | 11-18% | 8-17% |
| Punishment kubbs | 3-8% | 1-2.5% | 0.5-1.5% |
| Turns from an advantage line | 30-50% | 15-22% | 8-15% |
| Opening six batons, base kubbs down | 0.4-0.8 | 0.9-1.4 | 2.1-2.7 |
| Game length, turns | 14-24 | 8-13 | 6-10 |

**Beginner.** Owner: beginners "toss" kubbs, "there is really no group to get", and
they "almost never hit combos". The kubbs land spread across the half, so every baton
is a single at 3 to 6 m, and the field is often left standing. Games are long.

**Club.** Owner: "the kubbs are less controlled", with "some combos but rare to see
more than a triple". They drill to the corner and get a loose group: the first baton
at four or five kubbs takes two or more less than half the time (46%). They hold up
at small fields and fall apart at six.

**Pro.** Owner: "a good driller can get 6-7 kubbs all touching each other in the
basket", and a kubb goes out only by a bad bounce or a risk taken on purpose. The
first baton at four or five kubbs takes two or more 71% of the time, and 81% at six
or seven. Owner accepted the computer's pro at 80% from an advantage line and 96% at
the king as "just right", above the measured 60% and 85%, which rest on few throws.

## The inkast

The inkast is where the levels differ most (owner), and it is what the videos teach.

1. **The goal is one baton.** Coach, quoting Niklas Augren: "I am happy with my
   performance if I have placed the kubbs so that there is a realistic chance one
   stick could knock them all down." Judge a group by the batons it takes to clear,
   not by how close the kubbs are.
2. **Where.** The corner where the centre line meets a sideline. Short throws for the
   blasters, and two lines the defender cannot raise past. All drilling levels.
   A right-hander throws from the right sideline into the right corner, for three
   reasons (coach): the kubbs land by the line and can be worked in from either side;
   the natural cut runs left to right, so each kubb rolls over and stacks against the
   ones before it, "a wall" along the sideline; and the baton thrower can then stand at
   the sideline and throw straight down the line of kubbs. The first kubb sets the
   spot, and the rest build off it.
3. **Shape.** Two or three kubbs: a line along the thrower's path, so one baton runs
   through them. Four or more: a cluster (coach).
4. **No wood on wood in the air.** A kubb that lands on another bounces anywhere.
   Land short and roll in, or land beside (coach).
5. **The cut.** The wrist is turned at release so the kubb travels a little sideways,
   lands, and kicks across into the group (coach). Left to right is the natural cut
   for a right-hander; right to left "takes a lot of practice". Most of the time it
   is a light cut: land beside the group and roll in. A big cut is the exception.
   The engine has no such throw yet.
6. **Spin, height and landing vary by player.** Some throw with no spin, some slow,
   some "really rip it"; the tighter the spiral the better. The nose comes down along
   the line of flight, never up and over. Some throw high and some low, and wind
   punishes the high throw. A kubb can land flat, steep, at an angle, or short and
   roll in, and a good inkastare has practised each (coach). So spread at a level is
   not one number: it is how often the kubb lands the way it was meant to.
7. **Look again after every kubb.** When one strays, the plan changes: count what is
   down and what is in hand and build where one baton takes the most (coach). A club
   player keeps to the plan too long.
8. **The first throw is a free look.** A kubb out of bounds is thrown again, so the
   first throw can chase the lines. Measured: the top third rethrows 15.6% of its
   kubbs, and half its inkasts have at least one rethrow, as many as anyone. The share
   climbs with the kubbs in hand, from one in ten to more than one in six. Out twice
   is a punishment kubb, and that stays rare at every tournament level (1.3%).
9. **Deep kubbs.** A team that cannot clear what it holds should throw the ones it
   will not reach to 7 or 8 m: left standing there, they give the other team almost
   no advantage line (coach). This is a weaker team's best tool, and a beginner or
   club computer that knows its limit would use it.
10. **The rescue.** A kubb may be thrown at a standing field kubb to put it out and get
   it back. Known, legal and rare: 3 times in 5,270 kubbs (measured).

## Batons at the field

- Clear the field before anything else. Nothing at 8 m is worth an advantage line.
- The group first, with the baton most likely to take it; then the strays, nearest
  the centre line first, since that one sets the advantage line.
- The half-turn throw arrives low: a field throw at 5 m is waist high, and a kubb a
  step away is hit low and hard. Top hits are 1 in 20 to 30 (owner).
- Size of the first-baton take rises with the group, at every level: about a quarter
  take two or more from two or three kubbs, 59% from four or five, 70% from six or
  seven (measured, all teams).

## Raising and punishment

- The defender stands each kubb on the end that puts it furthest from its neighbours
  (owner, coach). Tight groups survive this; loose ones lose their doubles.
- A punishment kubb goes deep and far from the group, away from the corner the
  opponent is building in, and not where one baton lines it up with anything (coach).

## The baseline and the king

- From 8 m a base kubb falls a third of the time across all teams: 44% for the top
  third, 23% for the low third. This row was not used to rank teams, and it spreads
  as widely as the field rows do.
- The six opening batons take 1.9 base kubbs on average: 2.4 for the top third, 1.1
  for the low third. A game between good teams starts with two or three kubbs in play.
- Teams that reach the king take it. About one king shot a game.

## What the Gym should take from this

1. **Score each level against its own column**, not one `real` column. The pooled
   real numbers sit between club and pro and describe neither.
2. **Add rows the levels turn on**: turns cleared by field size, first-baton take by
   field size, base kubbs from the opening six, and batons needed to clear a group.
   `realtiers.mjs` gives the real side of the first three.
3. **Build the inkast by level** in this order of effect: how far a kubb lands from
   its spot (beginner wide and rolling, club loose, pro tight), then the line for two
   or three kubbs, then replanning after a stray.
4. **Rethrows at pro are low.** 0.10.0 measures about 2% rethrown. Real top teams are
   at 8 to 17%, because they aim at the lines. See the open questions.
5. **Deep kubbs** would give the lower levels a real decision and make their losses
   look like kubb instead of like missing.
6. **Do not tune a beginner to these numbers alone.** They are estimates. Get Jamie's
   read on a beginner game first.

## Open questions for Jamie

1. **Pro rethrows.** The best third of teams rethrows 16% of kubbs. Is that risk
   taken on purpose, as the coach describes, and should the pro computer do it?
2. **Is the low third "club"?** Or does club sit below any tournament team, with these
   numbers too kind to it?
3. **Beginner numbers.** All estimates. Which look wrong from the pitch?
4. **Deep kubbs.** Should the weaker computer levels throw them?
5. **Advantage line at pro.** Measured 60% over 67 batons; the computer's 80% read
   "just right". The range keeps both. Narrow it?
