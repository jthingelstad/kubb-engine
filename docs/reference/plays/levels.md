# Plays: judging a position

Not a phase of the turn: the yardstick the other plays are compared by. From Chris
Hodges' three-part analysis of scored games (`ko-2014-advantage1` to `3`). His games are
Planet Kubb's, so they overlap the 150 this project holds (`games-pk150`) and are not a
second sample.

## levels.value: Count a position in batons

- **When:** any choice between two plays: where a kubb goes, which end it stands on,
  where a punishment kubb is put, whether to take the sure kubb.
- **Play:** Value a position by the average number of batons a team needs to finish it,
  and prefer the choice that leaves the other side needing more, or your own side fewer.
- **Why:** It puts every part of the game in one unit. From about 900 scored turns:
  clearing 1 to 8 field kubbs from the baseline takes 1.53, 2.36, 3.04, 3.63, 4.18, 4.68,
  5.15 and 5.59 batons; from an advantage line 1.11, 1.74, 2.27, 2.74, 3.16, 3.56, 3.94
  and 4.30. Each base kubb adds 2.85 from 8 m and 1.63 from an advantage line. The king
  is 1.2. Nine field kubbs take all six batons on average and leave none for the
  baseline, which is the arithmetic behind `inkast.deep`.
- **Says who:** ko-2014-advantage2#p1.10, ko-2014-advantage2#p1.11,
  ko-2014-advantage2#p1.12, ko-2014-advantage2#p1.14, ko-2014-advantage2#p1.15 (Chris
  Hodges)
- **Basis:** measured
- **Against:** nothing found. The table is all competitive teams pooled; a level needs
  its own.
- **Levels:** Proposed: every level reasons from its own table, counted from the Gym.
  The measured one is the check on pro and club.
- **Engine:** not modelled (0.11.0). Nothing in the computer player compares two choices
  by what follows from them.
- **Gym:** needs the table by level. `tools/batonvalue.mjs` (in progress) counts it from
  scored games.

## levels.efficiency: Score a turn against the average

- **When:** judging a turn or a game after it is played.
- **Play:** A turn's efficiency is the value it gained (the position's batons at the
  start less at the end) divided by the batons it threw.
- **Why:** It says how much better or worse a turn was than average for the position it
  began from, so turns from easy and hard positions can be compared. In his data winners
  average about 114% and losers about 84%, and the world champions of the day about 125%
  over 13 games.
- **Says who:** ko-2014-advantage2#p1.17, ko-2014-advantage2#p1.18,
  ko-2014-advantage2#p1.21 (Chris Hodges)
- **Basis:** measured
- **Against:** nothing found. His own figures for the winner's margin disagree (30
  points from the averages, 38 in the text).
- **Levels:** Proposed: a target per level. If pro is to feel like the best teams, its
  turns should average near 125% of the pooled table.
- **Engine:** not modelled (0.11.0).
- **Gym:** needs a row: efficiency per turn, by level.
