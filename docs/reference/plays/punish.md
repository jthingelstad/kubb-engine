# Plays: the punishment kubb

A kubb thrown out of bounds twice is placed by the defender, anywhere in their half at
least a baton length from the king and the pins. These plays come from one piece by Chris
Hodges (`ko-2011-punishment`) and a remark by Josh Feathers. Punishment kubbs are about
one kubb in a hundred at tournament level (PLAY.md), so this phase matters least. See Q8.

Every `Levels` line is a proposal of ours, not a source's.

## punish.baseline: On the baseline, by default

- **When:** punish, the defender is behind by two base kubbs or more, or has left the
  attacker an advantage line.
- **Play:** Stand it on the defender's baseline.
- **Why:** It is the safe placement and the most common one. It is as far from the
  attacker as a kubb can be, and left standing it gives no advantage line.
- **Says who:** ko-2011-punishment#p1.5, ko-2011-punishment#p1.6 (Chris Hodges);
  kn-drill-2012#p3.9 (Josh Feathers)
- **Basis:** player
- **Against:** nothing found.
- **Levels:** Proposed: every level, as the default.
- **Engine:** modelled (0.11.0): `raising.autoPunishment` places it deep in the half and
  away from other kubbs, whatever the score.
- **Gym:** `g.punish`.

## punish.sideline: By the sideline, when the game is even

- **When:** punish, the base kubbs are about level.
- **Play:** Stand it by the sideline farthest from the other field kubbs, about half a
  metre in from the baseline for each field kubb the attacker threw this turn.
- **Why:** It costs the attacker a baton aimed away from the group and improves the
  defender's chance of an advantage line. The more kubbs the attacker has to clear, the
  further forward it can go.
- **Says who:** ko-2011-punishment#p1.7, ko-2011-punishment#p1.8 (Chris Hodges)
- **Basis:** player
- **Against:** nothing found. One player's rule of thumb.
- **Levels:** Proposed: pro.
- **Engine:** not modelled (0.11.0).
- **Gym:** nothing yet.

## punish.king: Behind the king, when ahead

- **When:** punish, the defender is ahead by two base kubbs or more, or the attacker
  threw more than six field kubbs.
- **Play:** Stand it a baton length behind the king, moved one kubb width to the
  thrower's off side: left for a right-hander. Less readily when the attacker's other
  field kubbs lie in a tight group.
- **Why:** The attacker must throw past the king, and a miss to the wrong side loses the
  game. A baton or two lost to caution is enough at that stage. The off side puts the
  thrower's own legs in the way, since both feet must stay inside the sidelines.
- **Says who:** ko-2011-punishment#p1.9, ko-2011-punishment#p1.10,
  ko-2011-punishment#p1.11, ko-2011-punishment#p1.13, ko-2011-punishment#p1.14,
  ko-2011-punishment#p1.15, ko-2011-punishment#p1.16 (Chris Hodges)
- **Basis:** player
- **Against:** nothing found. His angle figures are his own estimate
  (ko-2011-punishment#p1.17).
- **Levels:** Proposed: pro only. It needs a thrower who knows the opponent's hand.
- **Engine:** not modelled (0.11.0).
- **Gym:** nothing yet; needs the king felled early by a baton as a row.

## punish.safe: Never make a double with it

- **When:** punish, any placement.
- **Play:** Keep it out of line with every other kubb, and turn a flat face to the
  thrower.
- **Why:** A punishment kubb that pairs with another gives back the baton it was meant
  to cost. A flat face is the smaller target; he notes the other school, an edge toward
  the thrower for support, and has seen no difference in which falls.
- **Says who:** ko-2011-punishment#p1.18, ko-2011-punishment#p1.19,
  ko-2011-punishment#p1.20 (Chris Hodges)
- **Basis:** player
- **Against:** Q8, on the facing only.
- **Levels:** Proposed: every level.
- **Engine:** modelled in part (0.11.0): the automatic placement keeps away from other
  kubbs by distance. It does not check lines, and the kubb stands square to the pitch.
- **Gym:** nothing yet.
