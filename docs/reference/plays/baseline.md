# Plays: batons at the base kubbs

The throw at a base kubb, from 8 m or from an advantage line. The first plays here come
from two short lessons observed on 2026-11-21: one coach on the baton's rotation
(`yt-Rl8PNnjDidQ`) and another on where to stand (`yt-KnLTnKVVPMg`). In neither is a
baton thrown, so both rest on what the speakers say.

Every `Levels` line is a proposal of ours, not a source's.

## baseline.rotation: A half turn or a whole one, and never short of it

- **When:** baseline, a baton at a base kubb from 8 m.
- **Play:** Throw a half turn or a whole turn. When it is off, let it be a little over,
  not a little under.
- **Why:** At his first World Championship (2011) the coach saw most of the top players
  throw the 8 m baton with half a turn or one, where his own turned two or more; he
  thinks all top players would agree on half or one. With the half turn the room for
  error runs long: a little over-rotated, the baton still lands on the kubb. A little
  under-rotated, it hits and sticks or pops over the kubb, and the hit rate is much
  lower. He came down a step at a time (one and a half, one, a half), and the half took
  him most of a year.
- **Says who:** yt-Rl8PNnjDidQ#0:17, yt-Rl8PNnjDidQ#0:32, yt-Rl8PNnjDidQ#0:51,
  yt-Rl8PNnjDidQ#2:18, yt-Rl8PNnjDidQ#2:33, yt-Rl8PNnjDidQ#2:41 (Eric Anderson) Every
  throw is mimed (yt-Rl8PNnjDidQ#2:23 is unclear on which end leads); the hit rates are
  his impression, not counted.
- **Basis:** coach
- **Against:** Q14, on the field throw: Phil Dickinson trains a full turn
  (ko-2017-dickinson#p1.10), which this play allows; Kyle Weakland's fault of a baton
  stopping dead on a low square hit (ko-2017-blasting#p1.22) may be the same as the
  under-rotated baton that sticks, or not.
- **Levels:** Proposed: half a turn at club and pro, as now. A beginner turns more and
  less evenly.
- **Engine:** modelled in part (0.5.0, `plan.levels`, `tumbleTurns`): club and pro aim for
  half a turn and a beginner for 0.62, with a spread (`tumbleSd`) that is even on both
  sides. Nothing makes the error lean long, and whether the physics punishes under-
  rotation more than over-rotation, as he says, has not been measured.
- **Gym:** needs a row: hits on a base kubb from 8 m by the baton's turns at first
  touch, under against over (the forensics record the arrival, docs/notes/gym.md
  "Arrival").

## baseline.angle: Step along the baseline to see a base kubb at an angle

- **When:** baseline, a base kubb from 8 m that stands at a slight angle, or square.
- **Play:** Step along the baseline, about 2 m off the middle, to see more of the kubb.
- **Why:** A kubb at a slight angle may go unnoticed from straight on; 2 m aside shows
  more of it, by his estimate 15 to 20% more, and makes the 8 m throw 8.25 m, only 3%
  longer.
- **Says who:** yt-KnLTnKVVPMg#1:50, yt-KnLTnKVVPMg#2:01, yt-KnLTnKVVPMg#2:09 (an
  unnamed coach in a Team Kubboom vest). The rules allow any stance between the
  sidelines (web-us-rules-v4#p5.3). His figures, worked aloud; the wider view is not
  shown (yt-KnLTnKVVPMg#2:01). Our check of the arithmetic is under `field.angle`.
- **Basis:** coach, estimate
- **Against:** nothing found. Base kubbs are set up square: the Belgian rules even
  require that no corner face the opponent (web-kf-rules-2026#p10.1), so a base kubb
  is square until something moves it.
- **Levels:** Proposed: pro, and not before the Gym shows a gain.
- **Engine:** not modelled (0.13.0). The computer throws at a base kubb from straight
  behind it (`plan.stance`).
- **Gym:** base kubbs from 8 m (`g.base8` or its equivalent), stance straight behind
  against 2 m aside.
