# Scenes

Since 0.14 a scene is one of the engine's own objects (`core/scenes`), and it decides
which surfaces and kubb sets a match may have. This note keeps the owner's decisions, the
design and how it met the code. The session's API is in docs/SESSION.md ("Scenes",
"Ground impacts"), the pitch's in docs/PITCH.md (difference 10, `optionRows`), the grid's
physics in docs/notes/physics.md ("The grid"), and the Tournament's neighbouring pitches
in docs/notes/tournament.md.

## The owner's decisions (Jamie, 2026-11-21 and 22)

Product decisions about the game, so they live here rather than in
`docs/reference/observations/` (which records what sources and the owner say about how
kubb is played).

- "I finally figured out how Scenes should be related to Pitch surface and Kubb sets. The
  short version is a Scene should have an allowed set of surfaces and pitch types. This
  way scenes can have special and unique Kubb sets and pitches... it allows the Playdate
  'scene' to become a 1st class object and work in the other games... I'm hoping this
  allows us to simplify things a little bit."
- **Black & White**: "This IS the Playdate", opened to every game for a pure black and
  white view.
- **Tournament**: a kubb tournament, "a grid of pitches that are all live"; the only scene
  where you play with the USA kubb set's colouring. No championship's name or logo
  anywhere.
- **Park**: what exists today, a grassy area (stored id `day`).
- **Beach**: emphasises the sand pitch.
- **Camping**: the existing night scene (stored id `night`).
- **Techno**: dark neon grid (stored id `neon`). "I think the surface should feel
  intentionally flat and electronic, maybe even magnetic." And: "when something hits the
  floor it should give a visual ring on impact."
- **Minnesota**: "so there is a place for Snow".
- All of them in the first App Store release, so engine 0.14.0, the clients next. Kid
  mode is not part of this.

## The catalogue

| id | shown | surfaces (default first) | sets | flags |
| --- | --- | --- | --- | --- |
| `day` | Park | grass | classic | |
| `beach` | Beach | sand | classic | |
| `night` | Camping | grass | classic | dark |
| `neon` | Techno | grid | classic | dark, ring |
| `minnesota` | Minnesota | snow | minnesota | |
| `tournament` | Tournament | grass | usa | |
| `bw` | Black & White | grass, sand, snow | classic | mono |

The engine owner's choices inside Jamie's: Black & White allows the three outdoor
surfaces (it is the Playdate's plain view of any pitch) and not the grid, which is
Techno's own; Beach, Park, Camping and Tournament one surface each; every scene one set,
built for more (`sets` is a list, `choices` names `set` when one allows two). `sweden`
and `wisconsin` are in no scene and stay valid in anything kept. The flags are what a
renderer cannot work out from the surface: a dark sky, impacts that ring, black and
white only. Sand puffs and snow sprays are the client's to draw from the surface and the
impacts; only Techno's ring was asked for.

## How the rule is applied

A scene decides where a client sets options, and nowhere else:

- `kubbCall("new")` (match and practice): `session.sceneOptions` resolves a named scene
  (`scenes.resolve`: the surface given if the scene allows it, else its default; the set
  likewise; an unknown id is Park). Practice keeps `setSurface` to the scene's surfaces.
- the pitch: `setOptions` holds the merged surface and set to the named scene's,
  `optionsOf` and `matchOptions` read them through it again (docs/PITCH.md difference 10);
  `optionRows(scene)` is the card.
- the Playdate (`core/matchopts`): its scene is always `bw`, its Surface row is that
  scene's surfaces, and `apply` names the scene.
- `names.check` holds a snapshot's `opts.scene` to the scenes the catalogue lists and
  `opts.set` to every set the engine takes.

## Where the design did not survive contact with the code

- **"An unknown scene id is treated as day" could not cover a missing one.** The pitch's
  vectors (tests/pitch/vectors/, a frozen corpus from the web's JavaScript) hold
  documents with sand, snow, `usa` and `sweden` and no scene, through `setOptions`,
  `matchOptions` and `startMatch`; the golden corpus plays sand and snow matches that name
  no scene through `new`. Reading no scene as Park would turn every one of them to grass
  and move their hashes and outputs. So a scene decides only when one is named: options
  with no scene stand as given, as before 0.14. An id that is named but not listed is
  Park, as asked. A 0.14 client always sends a scene, so on its own screens the rule
  holds everywhere; the gap is only a document or match from before.
- **The rule applies to options being set, not to every place a match is made.** Restore,
  replay, `checkStart` and `renameStart` all build a match through `session.new` from its
  recorded options; a 0.13 match could name Camping on sand. So the rule sits at the
  client's door (`new`) and in the pitch's option calls, and `session.new` keeps any
  recorded scene, surface and set (tested: a 0.13-style Camping match on sand with the
  wisconsin set checks, restores and replays hash for hash).
- **`MATCH_OPTIONS` keeps every value.** It is also the pitch's list of values
  `cleanOptions` accepts and `optionLabel` names (both in the vectors), so it cannot drop
  sweden and wisconsin or lose its set row. It gains the Scene row (first) and `grid`, and
  the card a client shows comes from the new `optionRows(scene)`, with no Kubbs row while
  no scene allows two sets.
- **`setOptions` now refuses a scene id the engine does not list** (0.9 to 0.13 took any
  well formed id). The document still keeps a well formed id another engine wrote, read as
  Park, so a newer engine's scene survives this one's writes.
