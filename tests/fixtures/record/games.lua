-- Record mode's games (docs/RECORD.md): a setup and an event log each, as a scorer's
-- app would keep them. tests/lua/session/test_record.lua checks what each one gives, and
-- tools/recordgames.lua writes each one's file for the notation gate (make test-node).
-- Names are made up. Positions are { across, depth } in the notation's frame.
local function P(a, d) return { across = a, depth = d } end
local function toss(by, result, more)
	local e = { type = "toss", by = by, result = result }
	for k, v in pairs(more or {}) do e[k] = v end
	return e
end
local function baton(by, more)
	local e = { type = "baton", by = by }
	for k, v in pairs(more or {}) do e[k] = v end
	return e
end
local function at(h, m) return { year = 2026, month = 11, day = 24, hour = h, min = m } end

local RINGERS = { name = "Ringers", players = { { name = "Kim" }, { name = "Dana" }, { name = "Ole" } } }
local STAKES = { name = "Stakes", players = { { name = "Sam" }, { name = "Lee" } } }

-- The worked example: five turns, the fifth "k:3I A k:3F d:B o:B k:B d:= o:K", with
-- players, pitch and stance captured. (d's miss is "=": with every kubb down it was a
-- throw at the king, notation-2.md "Batons".)
local function example(capture)
	return {
		setup = { teams = { A = RINGERS, B = STAKES }, first = "A", opening = "2-4-6", surface = "grass",
			wind = "light", event = "Fall Open, pool 2", location = "Riverside Park, Pitch 4",
			client = "0.1 (1.1.0)", start = at(10, 0), capture = capture },
		events = {
			-- 1. k:B d:B (Team B's base kubbs at across cells 1 and 4)
			baton("kim", { base = 1, at = { P(1.5, 4) }, stance = P(2.5, 4) }),
			baton("dana", { base = 1, at = { P(4.5, 4) }, stance = P(2.5, 4) }),
			-- 2. s:2I s:2F l:B s:B l:-
			toss("sam", "in", { at = P(1.2, 2.4) }),
			toss("sam", "in", { at = P(3.6, 1.1) }),
			baton("sam", { field = 2, at = { P(1.2, 2.4), P(3.6, 1.1) } }),
			baton("lee", { base = 1, at = { P(0.5, 4) } }),
			baton("sam", { base = 1, at = { P(2.5, 4) } }),
			baton("lee"),
			-- 3. k:4I k:2F d:F o:F k:- d:- o:-
			toss("kim", "in", { at = P(0.4, 1.5) }),
			toss("kim", "in", { at = P(2.2, 0.6) }),
			toss("kim", "in", { at = P(2.8, 0.9) }),
			toss("kim", "in", { at = P(4.1, 2.2) }),
			baton("kim", { field = 2, at = { P(2.2, 0.6), P(2.8, 0.9) } }),
			baton("dana", { field = 1, at = { P(0.4, 1.5) } }),
			baton("ole", { field = 1, at = { P(4.1, 2.2) } }),
			baton("kim"), baton("dana"), baton("ole"),
			-- 4. s:4I s:F l:F s:F l:- s:- l:- (one kubb left in Team A's half, at 3,1)
			toss("sam", "in", { at = P(0.7, 0.8) }),
			toss("sam", "in", { at = P(1.9, 1.2) }),
			toss("lee", "in", { at = P(3.4, 1.3) }),
			toss("lee", "in", { at = P(4.4, 0.5) }),
			baton("sam", { field = 1, at = { P(0.7, 0.8) } }),
			baton("lee", { field = 1, at = { P(1.9, 1.2) } }),
			baton("sam", { field = 1, at = { P(4.4, 0.5) } }),
			baton("lee"), baton("sam"), baton("lee"),
			-- 5. k:3I A k:3F d:B o:B k:B d:= o:K
			toss("kim", "in", { at = P(1.4, 1.6) }),
			toss("kim", "in", { at = P(2.3, 1.2) }),
			toss("kim", "in", { at = P(2.6, 1.7) }),
			{ type = "advantage", applies = true, meters = 2 },
			baton("kim", { field = 3, at = { P(1.4, 1.6), P(2.3, 1.2), P(2.6, 1.7) }, stance = P(2.6, 1.3) }),
			baton("dana", { base = 1, at = { P(0.5, 4) }, stance = P(2.6, 1.3) }),
			baton("ole", { base = 1, at = { P(2.5, 4) }, stance = P(2.4, 1.3) }),
			baton("kim", { base = 1, at = { P(3.5, 4) }, stance = P(2.6, 1.3) }),
			baton("dana", { stance = P(2.7, 1.3) }),
			baton("ole", { king = true, stance = P(2.5, 4), time = at(10, 42) }),
		},
	}
end

local games = {}

games.example = example({ players = true, pitch = true, stance = true })
games.example.expect = {
	winner = "A", how = "king",
	lines = {
		"1. k:B d:B",
		"^a 2.50,4.00 2.50,4.00",
		"*b 1,3 4,3",
		"2. s:2I s:2F l:B s:B l:-",
		"3. k:4I k:2F d:F o:F k:- d:- o:-",
		"4. s:2I l:2I s:F l:F s:F l:- s:- l:-",
		"5. k:3I A k:3F d:B o:B k:B d:= o:K",
		"@a 3,1s",
		"@b 1,1 2x2,1",
		"^a 2.60,1.30 2.60,1.30 2.40,1.30 2.60,1.30 2.70,1.30 2.50,4.00",
		"*b 1,1+2x2,1 0,3 2,3 3,3 - -",
		"[Pitchside:capture \"players pitch stance\"]",
		"[Pitchside:wind \"light\"]",
		"[Location \"Riverside Park, Pitch 4\"]",
		"[Scored by \"Kubb: Pitchside 0.1 (1.1.0)\"]",
		"[End \"2026-11-24 10:42\"]",
		"[Duration \"42m\"]",
	},
}

-- The same game with nothing captured but the turn lines.
games.bare = example({})
games.bare.expect = {
	winner = "A", how = "king",
	lines = { "1. B B", "2. 2I 2F B B -", "5. 3I A 3F B B B = K", "[Pitchside:capture \"turns\"]" },
	absent = { "^a", "@a", "@b", "*b", "k:" },
}

-- Switches changed between turns: players and pitch for turns 1 to 3, then stance alone;
-- lay asked for from turn 3 (taken, never written).
games.switching = example({ players = true, pitch = true })
do
	local ev = games.switching.events
	table.insert(ev, 9, { type = "capture", lay = true })                       -- before turn 3's first toss
	table.insert(ev, 19, { type = "capture", players = false, pitch = false, stance = true }) -- turn 3's last baton, then this
end
games.switching.expect = {
	winner = "A", how = "king",
	lines = { "1. k:B d:B", "*b 1,3 4,3", "3. k:4I k:2F d:F o:F k:- d:- o:-", "4. 4I F F F - - -",
		"5. 3I A 3F B B B = K", "^a 2.60,1.30 2.60,1.30 2.40,1.30 2.60,1.30 2.70,1.30 2.50,4.00",
		"[Pitchside:capture \"players pitch stance\"]" },
	absent = { "~", "@a 3,1s" },
}

-- Rule breaches, recorded as thrown and warned: a player over II.B.5's cap, a base kubb
-- felled with a field kubb standing (II.B.4a, stood back up), an advantage line observed
-- that the count says is not there, and a baton count the half cannot hold.
games.breach = {
	setup = { teams = { A = RINGERS, B = STAKES }, opening = "six", capture = { players = true } },
	events = {
		-- 1. k:3B k:- k:- d:- o:- k:- (kim throws four: cap 2 for three players)
		baton("kim", { base = 3 }), baton("kim"), baton("kim"), baton("dana"), baton("ole"), baton("kim"),
		-- 2. s:3I ... B's batons; one fells a base kubb with a field kubb still up (II.B.4a)
		toss("sam", "in"), toss("sam", "in"), toss("lee", "in"),
		{ type = "advantage", applies = true },
		baton("sam", { field = 1 }), baton("lee", { field = 1, base = 1 }), baton("sam", { field = 4 }),
		baton("lee"), baton("sam"), baton("lee"),
		-- 3. k:3I k:K ... the king shot with kubbs standing: E, Team A loses
		toss("kim", "in"), toss("kim", "in"), toss("kim", "in"),
		baton("kim", { king = true }),
	},
	expect = {
		winner = "B", how = "king toppled early",
		lines = { "1. k:3B k:- k:- d:- o:- k:-", "2. s:2I l:I s:F l:F s:F l:- s:- l:- # advantage line observed in use; b2 toppled a base kubb early; raised (II.B.4a)",
			"3. k:3I k:E X X X X X" },
		warnings = { "order", "advantage", "rule", "count", "rule" },
	},
}

-- Rethrows, a punishment kubb, a kubb on another (N), a rescue (Q) and a failed rescue
-- (Y), and a game called (W) for the team throwing.
games.called = {
	setup = { teams = { A = { name = "North", players = { "Alex" } }, B = { name = "South", players = { "Robin" } } },
		opening = "six", surface = "sand", start = at(10, 30), capture = { pitch = true } },
	events = {
		-- 1. 3B - - - - -
		baton(nil, { base = 3 }), baton(), baton(), baton(), baton(), baton(),
		-- 2. 3I2RP 2F - - - -  (one in, two out; of the rethrows one out again: P)
		toss(nil, "in", { at = P(1.5, 1.5) }), toss(nil, "out"), toss(nil, "out"),
		toss(nil, "out"), toss(nil, "in", { at = P(3.5, 0.5) }),
		{ type = "punish", at = P(2.5, 3.5) },
		baton(nil, { field = 2, at = { P(1.5, 1.5), P(3.5, 0.5) } }), baton(), baton(), baton(), baton(), baton(),
		-- 3. 2IN A 2F B - - -
		toss(nil, "in", { onTop = true, at = P(1.2, 0.5) }), toss(nil, "in", { at = P(3.2, 0.5) }),
		baton(nil, { field = 2 }), baton(nil, { base = 1 }), baton(), baton(), baton(), baton(),
		-- 4. 3IYQ F - W X X X: Robin's first kubb knocks over the punishment kubb still
		-- standing in North's half (a rescue, Q: it is thrown again), the second is a
		-- rescue that fails (Y), then the rest go in
		toss(nil, "in", { rescueAttempt = true, rescued = 1, rescuedAt = { P(2.5, 3.5) } }),
		toss(nil, "in", { rescueAttempt = true }),
		toss(nil, "in"), toss(nil, "in"),
		baton(nil, { field = 1 }), baton(),
		{ type = "call", winner = "B", time = at(11, 15) },
	},
	expect = {
		winner = "B", how = "called",
		lines = { "1. 3B - - - - -", "2. 3I2RP 2F - - - - -", "@a 1,1 3,0 2,3p", "*a 1,1+3,0 - - - - -",
			"3. 2IN A 2F B - - - -", "@a 2,3s", "4. 3IYQ F - W X X X", "[Surface \"Sand\"]",
			"[Rules \"U.S. Championship 4.0, six from the start\"]", "[Opening \"6\"]",
			"[Team A Players \"Alex (alex)\"]", "[Pitchside:capture \"pitch\"]",
			"[Duration \"45m\"]" },
	},
}

-- A game called for the team not throwing: its own line after the turn, with the
-- advantage line its half calls for.
games.calledOther = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = {
		baton(nil, { base = 1 }), baton(),
		toss(nil, "in"),
		baton(),
		{ type = "call", winner = "A" },
	},
	expect = { winner = "A", how = "called", lines = { "1. B -", "2. I -", "3. A W X X X X X" } },
}

-- A kubb thrown in that knocks the king over: Team B loses.
games.inkastKing = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = { baton(nil, { field = 0, base = 1 }), baton(), toss(nil, "in", { king = true }) },
	expect = { winner = "A", how = "king toppled by a thrown kubb",
		lines = { "2. IE X X X X # king toppled by a thrown kubb" } },
}

-- Team B resigns on its own turn after two batons; Team A resigns while Team B throws,
-- on a line of its own; and Team A resigns before Team B's first throw, which goes on
-- Team A's own line.
games.resign = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = { baton(), baton(), baton(), baton(), { type = "resign", side = "B" } },
	expect = { winner = "A", how = "resigned", lines = { "1. - -", "2. - - G X" } },
}
games.resignOther = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = { baton(nil, { base = 1 }), baton(), toss(nil, "in"), baton(nil, { field = 1 }), { type = "resign", side = "A" } },
	expect = { winner = "B", how = "resigned", lines = { "2. I F", "3. G X X X X X" } },
}
games.resignWaiting = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = { baton(), baton(), { type = "resign", side = "A" } },
	expect = { winner = "B", how = "resigned", lines = { "1. - - G" } },
}

-- An inkast the scorer skipped: Team B's batons begin with nothing tossed (no token, the
-- notation's "not recorded"); in turn 3 one toss of three, the rest taken as in. Both warn.
games.skipped = {
	setup = { teams = { A = RINGERS, B = STAKES } },
	events = {
		baton(nil, { base = 2 }), baton(),
		baton(nil, { field = 1 }), baton(nil, { field = 1 }), baton(nil, { base = 1 }), baton(),
		toss(nil, "in"),
		baton(nil, { king = true }),
	},
	expect = { winner = "B", how = "king toppled early",
		lines = { "1. 2B -", "2. F F B -", "3. 3I E X X X X X" }, warnings = { "inkast", "inkast", "rule" } },
}

return games
