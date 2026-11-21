# Plays: raising

The defender stands each thrown kubb on one end. It is the only defence against a group.
These plays come from one long piece by Chris Hodges (`ko-2013-fence`); the inkastare's
side of the same contest is `inkast.options`. Read them with Q7.

Every `Levels` line is a proposal of ours, not a source's.

## raise.par: Stand each kubb where the attacker needs the most batons

- **When:** raise, a kubb with a choice of end.
- **Play:** Judge the standing kubbs from where the attacker will throw, and count the
  batons they will need: par. Choose the end that makes par highest. Count again after
  each kubb, and look a baton or two ahead.
- **Why:** Raising is playing the percentages. A group judged at three batons that keeps
  falling to one means the judging is wrong, not the luck.
- **Says who:** ko-2013-fence#p1.4, ko-2013-fence#p1.5, ko-2013-fence#p1.6,
  ko-2013-fence#p1.18 (Chris Hodges)
- **Basis:** player
- **Against:** Q7.
- **Levels:** pro (0.12.0). Club spreads kubbs apart without counting, as in 0.11.2. A
  person's side, raised by the engine, takes it as the engine's best advice at every
  level (owner-2026-11-21#s5).
- **Engine:** modelled (0.12.0): the pro computer raises by it (`core/cpu.raising`,
  `cpu.raise`, why `raise.par` in `cpu.last`), and so does a person's side at every level
  when the engine raises it, and it is the end a client offers first by hand
  (`cpu.advice`, `match.raisePolicy`). `raising.policies.par` (built 0.11.2) is the end that leaves the
  attacker's batons the fewest kubbs one behind another, a pair weighed by how close it
  is across the baton's path and how far along it (`raising.tune.par*`). It counts pairs
  in line, not batons, and looks no baton ahead. Club raises `apart` (the end farthest
  from the nearest other kubb: distance, not batons) and beginner `first`, standing in
  for a random end. The Gym's measures are in docs/notes/gym.md, "Raising by the
  attacker's batons" and "Raising by level".
- **Gym:** the attacker's `g.btc` and `g.cleared`, policy against policy.

## raise.order: Forced kubbs first, and decide them all before standing one

- **When:** raise, several kubbs to stand.
- **Play:** Stand the kubbs that have no choice first. Then the ones that can plainly be
  stood away from the group to cost a baton. For the rest, work out where every one goes
  before standing any, because a later choice can undo an earlier one.
- **Why:** A kubb once stood is committed. Giving away one kubb by poor placement is too
  many.
- **Says who:** ko-2013-fence#p1.2, ko-2013-fence#p1.3, ko-2013-fence#p1.16,
  ko-2013-fence#p1.17 (Chris Hodges)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: pro and club.
- **Engine:** modelled in part (0.11.0). `raising.options` separates forced kubbs from
  those with a choice, but each choice is then made kubb by kubb with no look at the
  others still to stand, in id order, forced or not. `par` (the pro computer's and a
  person's automatic raising since 0.12.0) plans every kubb still lying before it answers
  for one, so a later kubb's place counts; the rules still ask in id order, and club
  (`apart`) and beginner (`first`) look at no other kubb still to stand.
- **Gym:** nothing yet.

## raise.across: Space across the pitch is worth more than space along it

- **When:** raise, choosing between an end that separates kubbs across the pitch and one
  that separates them along it.
- **Play:** Prefer across. A fairly tight fence across the pitch beats a looser line
  along it.
- **Why:** A struck kubb is pushed up the pitch easily and across it hardly at all, so
  kubbs one behind another fall together and kubbs side by side do not. This is the
  defender's side of `inkast.depth`: depth is what the attacker wants.
- **Says who:** ko-2013-fence#p1.11 (Chris Hodges); pk-strategy#p1.10 (Planet Kubb wiki)
- **Basis:** player
- **Against:** Q7. PLAY.md has the defender standing each kubb furthest from its
  neighbours in any direction (owner, coach). In the Gym the engine's `apart` policy
  turned a row lying across the pitch into kubbs staggered in depth, which helped the
  attacker (Q6).
- **Levels:** Proposed: pro and club.
- **Engine:** modelled at pro (0.12.0), through `par`, which counts a pair side by side
  across the pitch as no double and a pair one behind another as one; so does a person's
  automatic raising. Club's `apart` treats every direction alike.
- **Gym:** `g.field2`, `g.field3` for the attacker, policy against policy.

## raise.double: When a double cannot be avoided

- **When:** raise, every choice for a kubb leaves two kubbs one baton can take.
- **Play:** Make the line through the double point away from the other field kubbs. If
  that does not decide it, choose the double that lies most across the pitch. Sometimes
  give up one easy double on purpose to leave two kubbs isolated.
- **Why:** A double pointed at other kubbs can become a triple. A shot across the pitch
  is longer and sends less debris downrange. In his example of four kubbs lying in an X,
  standing two toward the centre costs the attacker a baton more than standing all four
  outward.
- **Says who:** ko-2013-fence#p1.8, ko-2013-fence#p1.9, ko-2013-fence#p1.10,
  ko-2013-fence#p1.12, ko-2013-fence#p1.13 (Chris Hodges)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: pro.
- **Engine:** not modelled (0.11.0).
- **Gym:** nothing yet.

## raise.square: Location before footing

- **When:** raise, a choice between a firm footing and a better place.
- **Play:** Take the better place. Only when the baton count is the same either way,
  turn the kubb so the attacker has to hit it squarely.
- **Why:** Costing the attacker a whole baton is worth more than a kubb that stands
  firm but leaves a double. A leaning kubb falls to a touch a firm one would survive, so
  footing still counts when nothing else does.
- **Says who:** ko-2013-fence#p1.14, ko-2013-fence#p1.15 (Chris Hodges)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: pro.
- **Engine:** not modelled (0.11.0). A raised kubb faces the way it lay; nothing chooses
  its facing.
- **Gym:** nothing yet.

## raise.facing: Mind which way each kubb is turned

- **When:** raise, a kubb that will stand in front of another on the attacker's line.
- **Play:** Have the front kubb of a likely double stand with a corner toward the
  attacker, not a flat face.
- **Why:** A front kubb struck square on a flat face is driven straight back through the
  one behind: an easy double. Struck on a corner, the baton glances one way and the kubb
  goes the other, and the kubb behind stays up. The cost: a corner-facing kubb shows more
  surface and falls to a throw a few centimetres off.
- **Says who:** ko-2012-doubles#p1.5, ko-2012-doubles#p1.8, ko-2012-doubles#p1.10,
  ko-2012-doubles#p1.11, ko-2012-doubles#p1.16 (Josh Feathers); ko-2013-fence#p1.5,
  ko-2013-fence#p1.15 (Chris Hodges); pk-strategy#p1.9 (Planet Kubb wiki)
- **Basis:** player
- **Against:** Q15. Under the rule the engine follows, a kubb is tipped up on one end
  with that end's bottom edge on the ground, so its facing is set by how it lay and the
  defender chooses only the end.
- **Levels:** Proposed: pro, if the rules allow the choice at all.
- **Engine:** the physics has it: kubbs are boxes, so a corner and a face meet a baton
  differently. Nothing chooses or reads a facing (0.11.0).
- **Gym:** needs a row: kubbs taken per baton by the front kubb's facing.

