# The play reference

What we know about how kubb is played, where each piece came from, and how far it has
got into the engine. It changes nothing in the engine. What to build from it is Jamie's
call.

It has four layers, and knowledge moves through them in one direction:

    sources  ->  observations  ->  plays  ->  the computer player, measured in the Gym
                       \            /
                        questions

| Layer | File | Holds |
| --- | --- | --- |
| Sources | `sources.json` | Every source we know of: what it is, who speaks, where it lives |
| Observations | `observations/<source id>.md` | What one source says or shows. No conclusions |
| Plays | `plays/<phase>.md` | A situation, the choice, the reason, and the observations behind it |
| Questions | `QUESTIONS.md` | Where sources disagree, and what only Jamie can answer |

`SITUATIONS.md` is the vocabulary all of them share. `PLAY.md` and `play-levels.json` are
the summary by level and its numbers; PLAY.md's claims move into `plays/` as they gain a
source.

`make refcheck` (in `make test`) fails when a layer breaks the rules below.

## Rules

1. **An observation records. It does not conclude.** It says what a source says or shows,
   by page or timestamp and by speaker, in our own words. What it means for the game goes
   in a play.
2. **Every play cites observations.** A claim with no source is tagged `estimate` and
   says so.
3. **Nobody adds strategy from general knowledge.** If it is not in an observation, it is
   not in a play.
4. **A disagreement between sources is a question, not a decision.** It goes in
   `QUESTIONS.md` with both sides cited, a recommendation, and what would settle it: the
   rules text, a count from scored games, a comparison in the Gym, or a better source.
   Jamie decides what the game should be; he is not asked to referee technique between
   top players. What he does say goes in as an observation, in his words, dated
   (`observations/owner-<date>.md`).
5. **Originals stay out of this repository.** Magazine PDFs, transcripts and captions are
   other people's work. `sources.json` holds the link and, where we fetched a file, its
   sha256 and size, so the same file can be fetched again. Observations paraphrase; a
   quotation is a few words, marked as exact.
6. **A play changes the computer player only through a pull request** that names the play,
   adds or names the Gym row that measures it, and bumps the engine's version when a
   golden hash moves (`docs/VERSIONING.md`).

## Source ids

Lower case, a prefix for where it lives, then the shortest thing that names it:

| Prefix | For | Example |
| --- | --- | --- |
| `yt-` | A YouTube video: its video id, unchanged | `yt-Io-rxbSB3Ns` |
| `kn-` | Kubbnation Magazine | `kn-drill-2012`, `kn-2015` |
| `ko-` | Kubb On, by year and a word | `ko-2013-fence` |
| `pk-` | Planet Kubb | `pk-deep` |
| `pod-` | A podcast episode | `pod-happykubb-heremans` |
| `web-` | Any other page | `web-kubbsh-levels` |
| `owner-` | Jamie, by date | `owner-2026-11-21` |
| `games-` | A set of scored games | `games-pk150` |

## sources.json

One object, `sources`, keyed by id. Fields:

- `title`, `url`: as published. `url` may be an archive link.
- `kind`: `lesson`, `interviews`, `article`, `match`, `podcast`, `data`, `rules`, `book`
  or `owner`.
- `by`: who made it. `speakers`: an array of who speaks in it, when that differs.
- `standing`: one line on why their word counts, from a public results page or the
  source itself. `unknown` when we cannot tell.
- `year`, `language`, and `length` (`"9:09"`, `"6 pages"`).
- `status`: `found` (known, not read), `observed` (an observation file exists) or
  `set-aside` (looked at and not worth it, with `note` saying why).
- `covers`: an array of phases from SITUATIONS.md.
- `original`: `{ "sha256": ..., "bytes": ... }` for a file we fetched. Optional.
- `note`: anything else, one line. Optional.

## An observation file

Front matter, then prose, then one or more tables of entries.

    ---
    source: kn-drill-2012
    observed: 2026-11-21
    method: read as laid out, all six pages
    schema: 1
    ---

`method` says how it was read, and what was not: "captions only, nobody looked at the
picture" is a method.

Each entry is a table row. The first column, `At`, is the entry's anchor: a timestamp
(`1:30`) for sound or video, a page and a count (`p2.3`) for print or a web page, a
statement number (`s1`) for Jamie. Anchors are unique in the file. A play cites an entry as `<source id>#<anchor>`.

| At | Who | Topic | What is said or shown | Mark |
| --- | --- | --- | --- | --- |
| `p2.3` | the speaker | a phase or subject | our paraphrase | one mark |

The marks:

- `said`: the words carry it.
- `shown`: seen in the picture or on the page, no words needed.
- `points`: the speaker says "here" or "this way"; the words alone do not settle it.
- `inferred`: our reading of something garbled or incomplete.
- `unclear`: we cannot tell. Say what is missing.

An observation ends with `## Questions for Jamie` when it raises any.

## A play

A play is one choice in one situation. In `plays/<phase>.md`, each play is a section:

    ## inkast.deep: Throw deep what you cannot clear

    - **When:** the situation, in SITUATIONS.md's words.
    - **Play:** the choice.
    - **Why:** the reason the sources give.
    - **Says who:** kn-drill-2012#p2.16, kn-drill-2012#p2.17 (Joakim Ekelöf)
    - **Basis:** player
    - **Against:** Q3, or "nothing found".
    - **Levels:** who knows it and how reliably. "Proposed" until Jamie settles it.
    - **Engine:** "not modelled (0.11.0)", or the function and the version it arrived in.
    - **Gym:** the row that measures it, or the row it needs.

The key before the colon is the play's id: the phase, a dot, a word. `When`, `Play`,
`Says who`, `Basis` and `Engine` are required.

`Basis` is one or more of:

- `measured`: counted from scored games, with the count and the tool that reproduces it.
- `owner`: Jamie's own statement.
- `player`: a named tournament player's own words about their own play.
- `coach`: taught in a lesson.
- `estimate`: worked out from the others. Nobody has measured it or said it.

`player` is new here; PLAY.md and `play-levels.json` use the other four.

## A question

In `QUESTIONS.md`, each question is a section:

    ## Q6: A row across, or kubbs in depth?

    - **Status:** open
    - **Asks:** the question, with what each side says.
    - **So far:** what the sources and the Gym have said since. Optional.
    - **Recommendation:** the working answer, and why.
    - **Settle by:** what would close it: a rule, a count, a Gym comparison, a source.
    - **Touches:** the plays or files an answer would change.

`Status` starts with `open` or `answered`. A question is `answered` only when what
`Settle by` names has been done, with a pointer to the result; an accepted recommendation
is still `open`. Numbers are never reused.

## Taking in a source

1. Add it to `sources.json` as `found`.
2. Read or watch all of it. Write `observations/<id>.md`. Set `status` to `observed`.
3. Someone else checks three entries against the original.
4. For each entry that bears on a choice, add to a play or write a new one. If it
   contradicts a play, add a question instead.
5. Run `make refcheck`.
