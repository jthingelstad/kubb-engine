# Situations: the shared vocabulary

Observations, plays, Gym rows and the computer player describe the same moments. This
file gives those moments one set of names, so a play's `When` can be read by a person,
measured by the Gym and tested for in code.

A first version. The words come from PLAY.md, the engine's own comments and the two
sources observed so far. Add a word when a source needs one; do not rename one that
plays use.

## Phases

A turn is a sequence of phases. Each play belongs to one, and `plays/<phase>.md` holds it.

| Phase | The moment | In the engine |
| --- | --- | --- |
| `inkast` | Throwing the kubbs in: where each should rest, and how it is thrown | `match.setup` with `kind = "toss"`; `cpu.basket`, `cpu.spot` |
| `raise` | The defender stands each thrown kubb on one end | `raising.choose` and its `raisePolicy` |
| `punish` | The defender places a kubb that went out twice | `raising.autoPunishment` |
| `field` | Batons at field kubbs: which, in what order, from where | `kind = "baton"` with field kubbs in `targets`; `cpu.decide`, `read.lane` |
| `baseline` | Batons at base kubbs, from 8 m or from an advantage line | `kind = "baton"` with only base kubbs in `targets` |
| `king` | The throw at the king | `kingShot` |

Observations also use four subjects that are not phases: `rules`, `practice`, `surface`
and `levels`.

## What describes a situation

The quantities a `When` may use. Each can be read from a match setup (`core/match.lua`)
or counted from a score sheet.

| Name | Meaning | Engine, where it exists |
| --- | --- | --- |
| kubbs in hand | Kubbs this team throws in this turn | `s.of` on a toss |
| kubb number | Which of them is being thrown | `s.n` |
| rethrow | This kubb went out once and is being thrown again | `s.rethrow` |
| field kubbs | Kubbs standing in the half being attacked | pieces with `role = "field"` |
| base kubbs | Kubbs left on the baseline being attacked | pieces with `role = "base"` |
| batons left | Batons this team has not thrown this turn | `s.of - s.n + 1` on a baton |
| advantage line | The thrower stands forward of the baseline, at the field kubb nearest the centre line that the other team left standing | `s.forwardY` |
| surface | The ground: it changes how a kubb stops | `s.surface` |
| level | kid, beginner, club or pro. Kid is proposed; the engine has the other three | `s.thrower.level`, `plan.LEVELS` |

Not in the engine yet, and needed by plays already written:

| Name | Meaning |
| --- | --- |
| clear count | How many field kubbs this team can expect to topple with the batons it has. A level's number, from the Gym |
| options left | How many thrown kubbs the defender could choose an end for when raising. Fewer is a better inkast. The engine can already count it (`raising.options` returns `"choice"` or `"forced"` for each kubb); nothing reads it yet |
| handedness | Which hand the inkastare and each baton thrower use. It decides the corner |
| the score | Who is ahead in base kubbs, and by how many |

## Places on the pitch

The game's own words, as the sources use them.

- **Basket:** the corner where the centre line meets a sideline, in the half being thrown
  into. Where a group is built. The engine's `basketX`, `basketY`.
- **The pin:** the centre line's stake at the sideline, the basket's corner.
- **Short:** near the centre line. A short kubb is a short throw for the batons that follow.
- **Deep:** near the far baseline. A deep kubb left standing gives almost no advantage line.
- **On the line:** touching the centre line or a sideline. Such a kubb can only be raised
  into the pitch, so the defender loses the choice of end (`core/raising.lua`, U.S. rules
  II.D.2 and II.D.3). Players build on the lines for that reason.

## Shapes

- **Line:** kubbs one behind another along the baton's path.
- **Row:** kubbs side by side across the baton's path. The sources also call it a fence
  or a wall, and do not all mean the same direction by "wall".
- **Group, cluster, pile:** kubbs touching or nearly, in no single direction.
- **Stray:** a kubb that came to rest away from the group.

## Throws

- **Drill:** the spun inkast, nose down.
- **Cut:** a drill released with the wrist turned so the kubb kicks sideways on landing.
- **Blast:** a baton thrown at a group to take several.
- **Rescue:** a kubb thrown at a standing field kubb so both go out and come back.
- **Rethrow:** a second try at a kubb that went out of bounds.

## Roles

Inkastare (throws the kubbs in), blaster (first batons at the group), cleanup (single
kubbs that must fall), eights (base kubbs from 8 m).
