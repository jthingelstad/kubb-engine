# Generated names

Plan of 2026-11-21, with its first part built: `core/namewords.lua` (the words),
`core/namegen.lua` (names from them), `tools/names.lua` and `tests/names/` (every name,
reviewed), `tests/lua/test_namegen.lua`; and the session door, `kubbCall("names.<name>")`
(`session/names.lua`, docs/SESSION.md "Names"). The web and the iPhone call it, the
Playdate uses `core/namegen`, and the pitch server checks names; the engine's pitch
reducers still take typed names (section 8).

## 1. Why

A player types a name today, and it goes further than the device:

- to everyone in an online pitch, and into its replay, which anyone with the link can
  watch for a year;
- onto a highlight reel, a public video, and the pitch card image a shared link shows;
- into the games bucket, every document version kept.

So the iPhone's App Store answers say *"User-generated content: Yes. Players choose
display names visible to others."* Typed text needs a filter, and a filter is a losing
game: a list of bad words never ends, and a clever spelling gets past it.

The other way is to have nothing typed. **Every player and team gets a name made from
words we chose**, the player picks among them, and nothing else is a name. Then the word
lists *are* the content policy, and they are short enough to read in full.

## 2. Where it comes from

The Planet Kubb Name Generator (2012, `Planet-Kubb/pk-name-generator`) made goofy team names
as an adjective and a noun: "Jolly Inkubbator". Two text files and five lines of PHP; only
English was ever filled in. Its domain no longer answers.

This keeps its idea and its voice, not its list. The 19 adjectives it opened with are the
first entries of `adjectives` here ("Nice" and "Relieved" stayed behind). Its 1,004 nouns
were dictionary words with "cub", "sub", "pub" or "wood" swapped for "kubb": most of them
read as noise ("Kubbsidization"), and some are crude ("Kubbcock", "Suckubbus"). A dozen
of its compound woods were good, and they are here as team nouns (Driftkubbs, Ironkubbs,
Pinekubbs).

There is nothing to connect to: no service, no data beyond the two lists. The old repo
was archived on 2026-11-21, and its README points here.

## 3. The shapes

| Kind   | Shape                  | Example          | Names |
| ------ | ---------------------- | ---------------- | ----: |
| player | `<adjective> <wood>`   | Mighty Maple     | 4,133 |
| team   | `<adjective> <noun>`   | Wobbly Towers    | 4,730 |
| team   | `<wood> <noun>`        | Birch Batons     | 1,742 |
| team   | `The <noun>`           | The Lumberjacks  |    58 |

At most 16 characters (`namegen.max`), the pitch's and the reel's limit. A pairing that is
longer is not a name, and the picker skips it. So is a pair in `namewords.never`
(section 5), and a name whose second word begins with its first ("Pine Pinecones").

Why these shapes:

- **Trees for players.** Real kubb teams use "kubb" in about four names of ten, then Nordic
  and regional words. Real tree names are almost unused, so trees are our own lane, and
  they fit a game called Throwing Wood. A player is a tree with a temperament.
- **Alliteration for players, as a lean, not a rule.** A rolled player name tries for one
  letter first (`tune.alliterate`, 60%): Wonky Willow, Lucky Larch. People pick names
  with repeated sounds more often, most of all names said aloud, and too much
  repetition backfires (section 11).
- **Never a number.** Xbox's suggested gamertags padded names with digits and were
  mocked for it. Two players with one name are sorted out in the lobby (section 8).
- **Kubb words for teams.** The pieces and the plays (Batons, Kings, Eights, Towers,
  Helicopters), the woods and the woodshed (Lumberjacks, Splinters), the backyard
  (Lawnmowers, Hammocks), the north the game comes from (Trolls, Longboats,
  Kanelbullar), and the best of 2012's blends (Kubbsters, Kubblets).
- **"The ___" is rare on purpose.** It has 58 names, so `roll` draws it one time in ten,
  or a lobby would see the same one twice.

Real names are a little longer: a median of 12 characters, with a tenth over 19. 16 keeps
every surface that shows a name as it is.

## 4. The engine's part

`core/namegen` is pure like the rest of the core: no `math.random`. A client passes its
own draw.

| Call                              | What it does                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `namegen.roll(kind, rand, keep?)` | A name and its parts. `rand(n)` gives 1..n. `keep` holds locked slots, `{ shape = "adj", nil, "Lumberjacks" }`; open slots draw from the words that still fit. |
| `namegen.step(kind, parts, i, d)` | The next word in slot `i` (d = 1 or -1) that fits: a slot picker, a crank.                                          |
| `namegen.parse(kind, text)`       | The parts, or nil when the text is not a name of that kind. Exact: one space, the words' own capitals.              |
| `namegen.valid(kind, text)`       | `parse(...) ~= nil`: the check.                                                                                    |
| `namegen.make(kind, parts)`       | The text for parts, or nil and why (`kind`, `shape`, `word`, `long`, `never`, `repeat`).                                             |
| `namegen.all(kind)`               | Every name, sorted: for tools and tests, not for a Playdate at play.                                               |

The web and the iPhone reach these through the session's door (docs/SESSION.md "Names"):
`names.roll` (a seed in place of `rand`: the engine draws from `plan.rng(seed)`),
`names.step`, `names.choices` (every word a slot can take), `names.make`, `names.valid`
(which also marks the engine's own default names), `names.words` (the lists, shapes and
rules, hashed, for a check outside Lua) and `names.all`. Slots there are 0-based and parts
are `{ shape, words: [...] }`.
**A name is its text, never an index.** Records, pitches and game files hold "Mighty
Maple". Adding a word changes no name anyone has. Toontown sent the server four list
indices instead, so it could only accept a name its lists made. `parse` gives the same
guarantee from the text, and text keeps game files readable, survives a list
reordered, and needs no id table kept in step across clients. The game file id is
`notation.baseId` as for any name (`mighty_maple`), and `assignIds` adds `_b` to the
second of two players with the same name, as it does now.

## 5. Safety

The lists are the policy, so the rules for a word come first. It is:

- friendly at any age, in American and British English (no "tossers", "randy", "spunky"),
  and said aloud ("Knotty", "Bad Ash");
- not about bodies, peoples, faiths, health or ability (no "chubby", "crazy", "savage");
- not violence, drink or drugs (no "killers", "sharpshooters", "sixpack");
- nobody else's (no franchises or brands; real teams love "Kubbra Kai" and "R Kubb D2");
- **safe beside every word it can meet**, which is the hard part. "Hard" is a fine word,
  and "Morning" is a fine word.

Four checks hold the line:

1. **Every name is committed.** `make names` writes `tests/names/player.txt` and
   `team.txt`, and `make names-check` (in `make test`) fails when they are stale. A pull
   request that adds one word shows every name it makes, and a person reads them.
2. **A blocklist under the lists.** `tests/names/blocklist.txt` holds whole words, whole
   phrases ("morning wood", "pitch slap") and **runs**: fragments looked for in the name
   with its spaces taken out, so a word hidden across the join is caught. No name may
   hold one (`test_namegen`).
3. **Pairs that never are.** `namewords.never` lists whole names `namegen` refuses
   though each word is fine: "Salty Walnut" (a nut joke), "Holly Rollers" (a jibe at a
   faith), "Royal Oak" (a brand), "Dashing Ash" (runs into "gash"). Then one bad
   partner does not cost a good word. A test checks each pair is one the lists could
   make, so the list never fills with dead entries.
4. **A full read before release.** Someone who did not write the lists reads every name,
   aloud and run together, in English and with the Nordic and German ears kubb's crowd
   has. The first read (2026-11-21) is why the table below is long.

The runs work. Drafting these lists, they caught names no word list would: Bamboo with
B- nouns (b**oob**atons), Rowan with K- nouns (ro**wank**ings), Sturdy with A- woods
(s**turd**yalder). The full read caught worse that the drafting missed: "Inkasters" after
any word ending in -ch, -d or -k hides two ethnic slurs once the spaces go, and "Yew" said aloud, as many Nordic speakers say an English "j",
is "Jew", which beside Wandering, Sly or Crafty is an antisemitic trope.

When a review finds a near miss: remove the word if it is the problem with every
partner, or add the pair to `never` if it is one partner; then put the near miss in the
blocklist so it cannot come back.

Others learned this the slow way. Terraform's pet names (adjective and nature noun, our
shape) made "massive-woodcock" and "throbbing-tulip" before it checked every word at
build time and dropped woodcock, peacock and cockatoo. Docker's container names lost
"kickass" and "cocky" over the years, then froze. The UK's plate office reads every
combination, sound-alikes included, before each release. Our space is small enough to
read in full, so we do.

### Words taken out

| Word    | List       | Why                                                  |
| ------- | ---------- | ---------------------------------------------------- |
| Bamboo  | woods      | "bamboo" + B- nouns runs into "boob"                 |
| Rowan   | woods      | "rowan" + K- nouns runs into "wank"                  |
| Sturdy  | adjectives | "sturdy" + A- woods runs into "turd"                 |
| Cherry  | woods      | slang                                                |
| Ebony   | woods      | slang, and a word used about people                  |
| Prickly | adjectives | "prick"                                              |
| Pecan   | woods      | said aloud                                           |
| Drillas | teams      | not the game's word: real players say drilling, drillers |
| Inkasters | teams    | run together after -ch, -d, -k: two ethnic slurs, "kink", "stink" |
| Yew     | woods      | said aloud, "Jew": "Wandering Yew", "Sly Yew"; "grandyew" |
| Knotholes | teams    | an insult, and innuendo with most adjectives        |
| Sassy   | adjectives | "Sassy Ash", "Sassy Birch" said aloud; the only "ass" run |
| Tiny    | adjectives | "Tiny Willow" said aloud; a size word a child is teased with |
| Palm    | woods      | a body part, and "Handy Palm"                        |
| Banyan  | woods      | "Banyan Kings" runs into "yanking"                   |
| Lanterns | teams     | run together: "klan", and an anti-Asian slur         |
| Apple   | woods      | a brand, and "-l Apple" runs into a slur for the Sami |
| Super   | adjectives | "Super Kings", a cricket team                        |
| Bouncy  | adjectives | "Bouncy Pear" said aloud                             |
| Hemlock | woods      | the poison                                           |
| Tumblers | teams     | drinking: "Fizzy Tumblers", "Wobbly Tumblers"        |
| Woodpiles | teams    | a racist idiom                                       |
| Picnickers | teams   | a racist false etymology, and "pick knickers" aloud  |
| Farfars | teams      | Swedish for "grandpa's", not "grandpas"              |

None of these was ever released: the first ones went while the lists were drafted, the
rest after the first full read.

## 6. The check at every boundary

A client offers only generated names, but a client is not proof: anyone can send a pitch
any text (the web repo's docs/ROOMS.md, "What is not protected", written for the rooms
server the pitch server replaced). So each place that shows a
name to someone else checks it, and shows a default when it fails:

| Boundary                        | Who runs the check                    | When it fails                        |
| ------------------------------- | ------------------------------------- | ------------------------------------ |
| A member's name in a pitch      | the pitch server, on join and `me`    | the name is dropped: "Player n"      |
| A pitch match's START           | the pitch server, from the header's players and the setup | refused with `bad-name`: the server cannot put a name right inside the start, because the snapshot is hashed and opaque to it |
| A match's snapshot a client is handed (entering a pitch match, a resync, joining part way) | the client: `restore` with `{ snap, names: "check" }`, or `names.check({ snap })` first | not shown: "This match has a name the game did not make" |
| A replay or kept match          | the client: `names.check({ replay })`, and `replayLoad` with `names: "check"` | not played, with the same sentence |
| A lobby (team names, the match's players, members) | the client: `names.check({ document, members })` | the default is shown ("Team A", "Player n") |
| A reel or a share               | the share check (it runs the engine)  | refused: "Type a name" becomes "Pick a name" |
| The pitch card image            | the card renderer                     | the team names are left off          |

**A snapshot is checked whole, by the engine** (since 0.13.4, docs/SESSION.md "Names"). A
snapshot carries each name twice (`opts.teams`, from which a match is made again, and
`save.game.teams`, from which `restore` builds it), makes the players' ids from them and
writes them into the ruling line and the score sheet. A forged start can keep generated
names in `opts` and typed ones in `save`; the pitch server treats the snapshot as opaque,
so its header and meta checks never see them, and a client that read `opts` alone (the
web's first `badNames`) passed it. `names.check` walks every string of the snapshot,
holds each to what the engine writes in that place, checks both copies of each name and
says where they disagree, so a client never has to know which fields reach the screen.
The strict `restore` and `replayLoad` refuse such a match before anything changes; the
plain ones still resume a person's own kept match with the typed names it was saved with.

The pitch server is JavaScript and knows no Kubb, so it needs the words in its own
language. `parse` is short; the web ports it beside a JSON copy of the lists that the
engine writes (`names.words`, docs/SESSION.md "Names"), checked against `tests/names/` so
the two can never disagree. `tests/node/names.test.mjs` holds such a port, written from
`names.words` alone, and proves it gives `names.valid`'s answer on every name and on
thousands of near misses; `names.words`' `hash` tells the server and a client whether they
hold the same words.

Two kinds of text pass a boundary besides generated names:

- **The engine's own defaults.** "Computer" (a computer side and its player), "Team A"
  and "Team B" (a side of several), "Player 1" to "Player 6" (a member with no name, or
  one the check dropped). The engine writes them, nobody types them, and a reel of any
  match against the computer carries "Computer". `names.valid` marks them `default`, and
  `names.words` lists them. "Player n" stops at 6, a side's most (`lobby.TEAM_MAX`):
  "Player 7" is not a default, and a check that took any number would take typed text
  such as "Player 69".
- **A player's name as a team's.** A side of one player is named after that player (the
  pitch's `matchOptions`, `renameStart`), so a team name on such a side is checked as a
  player name.

**What the check cannot tell.** `names.valid` answers from the words as they are now.
A name made from a word later taken out for safety (section 7) no longer parses, and the
check cannot tell it from typed text: both fail, and both are shown as the default. That
is the intent for a word taken out for safety, and why removing a word is for safety
only.

**Display never checks; boundaries do.** A client shows a member's name the pitch server has checked as it comes. A match's snapshot is the one thing the server cannot check, so there the client is the boundary (the table above). Then
clients on two patches of the engine can sit in one lobby even if one has more words.

What this buys outside the game:

- **Apple.** Guideline 1.2's duties (a filter, reports, blocking) are for apps where
  users "create, generate, upload, share, or otherwise contribute content". The age
  questionnaire defines user-generated content as broad distribution of content users
  created. A name built only from our words is our text. Apple has ruled on nothing
  like it that we found, so the change is defensible, not certain, and the app keeps
  its report path either way.
- **Children's privacy.** COPPA counts a first and last name as personal information,
  and letting a child make personal information public is collecting it. A typed name
  on a public reel can be exactly that. A generated name holds none by construction.
  Epic gives under-13 accounts generated display names for the same reason.
- **Google Play** has the same duties as Apple and no stated exception for preset
  content. The same answer applies when there is an Android app.

## 7. Changing the words

- Add a word anywhere in its list, run `make names`, and read the new names in the diff.
  If one is a near miss, take the word out and put the near miss in the blocklist.
- A word is one capitalised word of letters (`test_namegen`), in one list only, so a name
  parses one way.
- **Adding words is a patch.** No name changes and no throw changes. The pitch server
  takes a release's words before or with the clients that offer them.
- **Removing a word is for safety only**, and the pull request says so and adds a row
  to "Words taken out". Names holding it
  stop being valid: the pitch shows "Player n", and a client re-rolls that slot the next
  time it opens.
- `namewords.version` goes up with any change to a list.

## 8. What comes next

In order, each its own pull request:

1. **The session door.** Done (0.13.3): `kubbCall("names.roll" | "names.step" |
   "names.choices" | "names.make" | "names.valid" | "names.words" | "names.all")`
   (docs/SESSION.md "Names"). The client passes a seed, the session draws from it with
   `plan.rng`. Hash neutral: a patch release. What a client does next is in
   docs/SESSION.md "Names" (first run, the name row, layout, boundaries) and
   docs/CLIENTS.md.
2. **The pitch's check.** The web ports `parse`, takes the words from `names.words`, and
   checks names on join, `me` and START (section 6). The web's part is done: the pitch
   server checks with `backend/pitch-server/names.mjs` (its PROTOCOL.md section 6a), and
   the reels with `names.check`. The reel's and the share's checks
   call the engine they already run. In the engine's pitch reducers (not changed by
   step 1, so a pitch still takes typed names until this is staged):
   - `lineup` is the one reducer where a member's `me.name` becomes a match name. It
     would keep `cleanName`, then put `Player n` in place of a name that is neither
     generated (player kind) nor a default. A typed-name player then plays, and is
     shown to everyone, themselves included, as `Player n`; the match still starts.
   - `matchOptions` names a side of one after its player and a side of several
     `Team A`/`Team B`, so it needs no check of its own once `lineup` has one.
   - `startCheck` could report the players whose `me.name` is not generated (a list
     beside `unknown`) without refusing, so a host can say why a name became
     `Player n`. Refusing START for them would lock older clients out of every pitch.
   - `startMatch` copies names from the players the host passes into `match.players`;
     the snapshot already holds them, so it must not rewrite them (the header and the
     snapshot would disagree).
   - `cleanName`, `joinTeam`, `lobbyOf` and `replayOf` stay as they are: `joinTeam`
     moves ids, not names; `cleanName` is the frozen vectors' and the web's display
     tidy; and nothing rewrites a name already in a kept document or replay (display
     never checks).
   - Any of these is a numbered difference in docs/PITCH.md: nearly every lineup and
     START vector uses typed names ("Ann", "Hanna", emoji), so the vector test needs a
     rule that maps a non-generated name to `Player n` on those steps.
   The reducers run on clients, so they keep honest clients consistent; the pitch
   server's own check (JavaScript, from `names.words`) and the reel's are what hold.
3. **The clients.** Typed names go on the web and the iPhone; the Playdate offers both
   (section 10, decided). The three clients have the name row (the web's
   `src/ui/name-row.js`, the iPhone's `KubbRenderer/NameRow.swift`, the Playdate's Names
   screen).
   First run rolls a name, kept on the device. A name row with Shuffle,
   each word a picker (the crank on the Playdate), a lock per word: Toontown's name shop
   was scroll lists and Shuffle, and players who wanted "their" word in a pure-random
   picker asked for a way to find it. Online, the host rolls the team's name; today a team
   of several is "Team A". Two members with one name in a lobby are told apart there
   (the second shows "II"), never by changing the name. Each client measures its widest
   name in its own font (`names.all`; the Playdate `namegen.all`), as Toontown measured
   its widest name, before it ships.
4. **The App Store answers.** When no typed name is left anywhere a name can be seen,
   "User-generated content" can change on the iPhone's next submission.

## 9. Ideas for later

None of these blocks the first release.

- **Words earned by playing.** Splatoon's titles are an adjective and a subject, each
  half unlocked on its own; Fall Guys' preset nicknames come with levels and rarity. A
  name becomes a record of play: a word for a first king shot, a clean sweep, a season.
  The check stays list membership, so an unearned word sent by a hacked client is still
  a clean word; earning is the client's gate, not the server's.
- **Seasonal and event words**, as Splatoon's festival titles: Midsummer in June, frost
  words in winter, a tournament's word for its weekend.
- **Words that say something**: a level, an inkast habit, the side of the pitch.
- **Other languages.** Each list needs a native speaker's review and its own run checks
  (what3words reviews every language's words, and still tells people to move a square
  when a combination is bad). The English words need a Swedish and a German read too:
  kubb's crowd is Nordic, and German "Mist" is dung. The 2012 generator wanted eight
  languages and never got one.
- **A public team-name page** on throwingwood.com, the 2012 site's job, for real teams.

## 10. Questions for Jamie

The engine decides how names are made. What the game asks of players is Jamie's:

1. **Do typed names go on the web and the iPhone?** Decided by Jamie, 2026-11-21: yes,
   everywhere. Any solo match can be shared to a public reel, so every name on those
   clients can end up public. No typed name is left on either client: the lobby, the
   solo set-up, Settings' "Your name" and the reel's share card all take a generated
   name.
2. **The Playdate.** Decided by Jamie, 2026-11-21: it switches too, for one game
   everywhere, though its names never leave the device. The Names board rolls a name
   and the crank steps a word (`namegen.step`). Saved players keep their typed names
   until someone renames them. **Changed by Jamie, 2026-11-22:** "On the Playdate we
   should allow players to both use the generated names as well as enter their own. On
   the web we have to worry about people putting profanity in that others see. In the
   playdate nobody else can see it so we can allow profiles to have user entered names."
   So the Playdate offers both, a generated name or a typed one, wherever a name is
   made or changed; the web and the iPhone stay generated only. The rule behind it: a
   typed name is allowed where nobody else can see it. Its 10-letter limit (`core/names`) has to reach 16, so
   the Playdate client measures the widest name in its own font first; if the HUD
   cannot fit 16, the engine gets a shorter `namegen.max` for it rather than a second
   word list.
3. **The old generator.** Decided by Jamie, 2026-11-21: `Planet-Kubb/pk-name-generator`
   is archived, with a README note pointing here and a warning against reusing its
   English noun list.
4. **A public name page** on throwingwood.com for real teams (section 9). Recommended:
   later, after the game uses the names.
5. **A Swedish read of the English words.** Recommended before the first client ships:
   someone from the kubb community who speaks Swedish reads the word lists, an hour's
   work. Who reads it is Jamie's call.

## 11. Sources

- Real kubb team names: 228 from the scored games and a decade of the kubb press, read for
  their patterns. None is copied here: generated names should not take a real team's.
- The 2012 generator's lists, `Planet-Kubb/pk-name-generator`.
- Toontown's name shop and generator (open source as open-toontown):
  `toontown/makeatoon/NameGenerator.py` and `NameShop.py`.
- Terraform's pet names: github.com/dustinkirkland/golang-petname issues 14 and 19.
- Docker's names: github.com/moby/moby issue 30374 and the commits that removed
  "kickass" (2017), "cocky" (2019) and froze the list (2022).
- what3words on offensive combinations: support.what3words.com, article 1520642.
- Apple: App Store Review Guidelines 1.2 and 5.1.4; App Store Connect, "Age ratings
  values and definitions".
- COPPA: 16 CFR 312.2 (personal information, collection); the amended rule, Federal
  Register 2025-05904.
- Repeated sounds in names: Journal of Marketing (2010), reported by ScienceDaily,
  2010-10-18.
- Epic's cabined accounts; Splatoon 3's Splashtag titles; Fall Guys' nicknames.
