# Generated names

Plan of 2026-11-21, with its first part built: `core/namewords.lua` (the words),
`core/namegen.lua` (names from them), `tools/names.lua` and `tests/names/` (every name,
reviewed), `tests/lua/test_namegen.lua`. Nothing calls it yet: the session door, the
room's check and the clients come next (section 8).

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
stays as it is, and its README can point here.

## 3. The shapes

| Kind   | Shape                  | Example          | Names |
| ------ | ---------------------- | ---------------- | ----: |
| player | `<adjective> <wood>`   | Mighty Maple     | 4,133 |
| team   | `<adjective> <noun>`   | Wobbly Towers    | 4,730 |
| team   | `<wood> <noun>`        | Birch Batons     | 1,742 |
| team   | `The <noun>`           | The Lumberjacks  |    58 |

At most 16 characters (`namegen.max`), the room's and the reel's limit. A pairing that is
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
| `namegen.make(kind, parts)`       | The text for parts, or nil and why (`kind`, `shape`, `word`, `long`).                                              |
| `namegen.all(kind)`               | Every name, sorted: for tools and tests, not for a Playdate at play.                                               |

**A name is its text, never an index.** Records, rooms and game files hold "Mighty
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

A client offers only generated names, but a client is not proof: anyone can send a room
any text (ROOMS.md in the web repo, "What is not protected"). So each place that shows a
name to someone else checks it, and shows a default when it fails:

| Boundary                        | Who runs the check                    | When it fails                        |
| ------------------------------- | ------------------------------------- | ------------------------------------ |
| A member's name in a room       | the room server, on join and `me`     | the name is dropped: "Player n"      |
| A team's name in a room's match | the room server, on START             | "Team A" / "Team B"                  |
| A reel or a share               | the share check (it runs the engine)  | refused: "Type a name" becomes "Pick a name" |
| The pitch card image            | the card renderer                     | the team names are left off          |

The room server is JavaScript and knows no Kubb, so it needs the words in its own
language. `parse` is short; the web ports it beside a JSON copy of the lists that the
engine writes (a `names.words` call, section 8), checked against `tests/names/` so the
two can never disagree.

**Display never checks; boundaries do.** A client shows any name the room sends. Then
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
- **Adding words is a patch.** No name changes and no throw changes. The room server
  takes a release's words before or with the clients that offer them.
- **Removing a word is for safety only**, and the pull request says so and adds a row
  to "Words taken out". Names holding it
  stop being valid: the room shows "Player n", and a client re-rolls that slot the next
  time it opens.
- `namewords.version` goes up with any change to a list.

## 8. What comes next

In order, each its own pull request:

1. **The session door.** `kubbCall("names.roll" | "names.step" | "names.valid" |
   "names.words")` for the web and the iPhone. The client passes a seed, the session
   draws from it. Hash neutral: a patch release.
2. **The room's check.** The web ports `parse`, takes the words from `names.words`, and
   checks names on join, `me` and START (section 6). The reel's and the share's checks
   call the engine they already run.
3. **The clients.** Typed names go on the web, the iPhone and the Playdate (section 10,
   decided).
   First run rolls a name, kept on the device. A name row with Shuffle,
   each word a picker (the crank on the Playdate), a lock per word: Toontown's name shop
   was scroll lists and Shuffle, and players who wanted "their" word in a pure-random
   picker asked for a way to find it. Online, the host rolls the team's name; today a team
   of several is "Team A". Two members with one name in a lobby are told apart there
   (the second shows "II"), never by changing the name. Each client measures its widest
   name in its own font (`namegen.all`), as Toontown measured its widest name, before it
   ships.
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
   until someone renames them. Its 10-letter limit (`core/names`) has to reach 16, so
   the Playdate client measures the widest name in its own font first; if the HUD
   cannot fit 16, the engine gets a shorter `namegen.max` for it rather than a second
   word list.
3. **The old generator.** Recommended: a README note pointing here, then archive the repo.
   Its domain is gone.
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
