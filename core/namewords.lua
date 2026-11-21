-- The words generated names are made of (core/namegen, docs/NAMES.md). Pure data:
-- no playdate.*.
--
-- Every name a player can have is one of these words joined to another, so the
-- lists ARE the safety policy: there is no free text to filter. A word goes in only
-- if it is friendly at any age, says nothing about a body, a people, a faith or a
-- health condition, and joins safely with every word it can meet. That last test is
-- `make names`: it writes every name the lists can make to tests/names/, and the
-- diff of a pull request shows each new name a new word makes.
--
-- Rules for changing a list (docs/NAMES.md "Changing the words"):
--   * Add at the end or anywhere; order does not matter (names are text, never an index).
--   * Removing a word makes names that hold it invalid. Remove only for safety, and
--     say so in the pull request.
--   * One word per entry, letters only, capitalised. Lengths are checked by the tests.
--
-- Lineage: `adjectives` begins with the 2012 Planet Kubb Name Generator's own list,
-- and the "-kubb" nouns in `teams` are the best of its dictionary blends.
import "core/tw"

local words = {}

-- Bump when a list changes, so a client can tell a host it holds other words.
words.version = 1

-- Before a wood (players) or a team noun (teams).
words.adjectives = {
	-- From the Planet Kubb Name Generator (2012).
	"Agreeable", "Brave", "Calm", "Delightful", "Eager", "Faithful", "Gentle", "Happy",
	"Jolly", "Kind", "Lively", "Proud", "Silly", "Thankful", "Victorious", "Witty",
	"Zealous", "Mighty", "Magnificent",
	-- Throwing Wood.
	"Bold", "Breezy", "Bright", "Bouncy", "Brisk", "Busy",
	"Careful", "Cheery", "Clever", "Cosy", "Crafty", "Curious",
	"Dapper", "Daring", "Dashing", "Dizzy", "Dreamy",
	"Early", "Epic",
	"Fancy", "Fearless", "Feisty", "Fizzy", "Frosty", "Fuzzy",
	"Gallant", "Giddy", "Glorious", "Golden", "Grand", "Grumpy",
	"Handy", "Hasty", "Hearty", "Heroic", "Honest", "Humble",
	"Jaunty", "Jazzy", "Jumpy",
	"Keen",
	"Lucky", "Loyal",
	"Mellow", "Merry", "Mossy", "Muddy",
	"Nifty", "Nimble", "Noble",
	"Patient", "Peppy", "Plucky", "Polite",
	"Quick", "Quiet", "Quirky",
	"Rapid", "Rowdy", "Royal", "Rustic", "Rusty",
	"Salty", "Sassy", "Shiny", "Sleepy", "Sly", "Snappy", "Speedy", "Spry", "Steady",
	"Stormy", "Sunny", "Super", "Swift",
	"Tidy", "Tiny", "Trusty", "Tumbling",
	"Upbeat",
	"Valiant",
	"Wandering", "Wily", "Windy", "Wobbly", "Wonky",
	"Zany", "Zesty", "Zippy",
	-- After real teams' names and the kubb press (docs/NAMES.md "Where the words come from").
	"Backyard", "Cheerful", "Midsummer", "Northern", "Sneaky", "Thundering",
}

-- A player is an adjective and a wood: "Mighty Maple". Trees and timbers only.
words.woods = {
	"Alder", "Apple", "Ash", "Aspen", "Balsa", "Banyan", "Baobab", "Birch",
	"Cedar", "Chestnut", "Cypress", "Elder", "Elm", "Fir",
	"Ginkgo", "Hazel", "Hemlock", "Hickory", "Holly", "Juniper", "Kapok", "Larch",
	"Laurel", "Linden", "Mahogany", "Maple", "Myrtle", "Oak", "Olive", "Palm",
	"Pear", "Pine", "Plum", "Poplar", "Redwood", "Sequoia",
	"Spruce", "Sumac", "Sycamore", "Tamarack", "Teak", "Walnut", "Willow", "Yew",
}

-- A team is "<adjective> <noun>", "The <noun>" or "<wood> <noun>": "Stormy Inkasters",
-- "The Lumberjacks", "Birch Batons". Plural nouns from the game and the backyard.
words.teams = {
	-- The game.
	"Batons", "Kings", "Kubbs", "Inkasters", "Drillers", "Blasters", "Helicopters", "Corners",
	"Baseliners", "Fielders", "Eights", "Stakes", "Towers", "Fences", "Toppers", "Tumblers",
	"Wobblers", "Rollers",
	-- Blends, after the 2012 generator's dictionary of "-kubb" words.
	"Kubbsters", "Kubblets", "Kubbinators", "Driftkubbs", "Ironkubbs", "Pinekubbs",
	"Firekubbs", "Wildkubbs", "Cedarkubbs", "Teakkubbs", "Torchkubbs", "Kingkubbs",
	"Kubbernauts", "Kubbcakes", "Kubbteers",
	-- Wood and the woods.
	"Lumberjacks", "Woodchucks", "Woodpiles", "Woodcutters", "Whittlers", "Carvers",
	"Splinters", "Stumps", "Timbers", "Acorns", "Pinecones", "Saplings", "Branches",
	"Twigs", "Knotholes", "Logrollers", "Owls", "Moose", "Badgers", "Foxes", "Otters",
	-- The north kubb comes from.
	"Trolls", "Longboats", "Farfars", "Cloudberries", "Kanelbullar",
	-- The backyard.
	"Picnickers", "Lawnmowers", "Sprinklers", "Hammocks", "Lanterns", "Campers",
}

tw.namewords = words
