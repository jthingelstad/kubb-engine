-- The plays the computer can carry out (docs/notes/computer-player.md, "A decision"),
-- keyed by the ids in docs/reference/plays/*.md, where each play's sources are. A
-- decision from core/cpu names one in why.play, with its facts in why.facts; `say` is
-- one plain sentence a game can show as it is, its {name}s filled from those facts
-- (cpu.text). `levels` are the levels that use the play today, `phase` the phase of
-- SITUATIONS.md it belongs to.
--
-- It holds only what 0.11.0 already does and grows one play at a time, by "How a play
-- gets in". `make refcheck` fails on an id here that is not a play in
-- docs/reference/plays/. A choice that carries out no play there (a baton at the
-- nearest base kubb, the king from the baseline) has no why.play.
import "core/tw"

local plays = {
	["inkast.corner"] = {
		phase = "inkast",
		levels = { "beginner", "club", "pro" },
		say = "Into the {basket} basket: {near} field kubbs by it, {other} by the other.",
	},
	["inkast.roll"] = {
		phase = "inkast",
		levels = { "club", "pro" },
		say = "Laid beside the kubb lying by the {basket} basket, to roll in beside it.",
	},
	["field.roles"] = {
		phase = "field",
		levels = { "beginner", "club", "pro" },
		say = "At the lane with the most kubbs: {lane} in line from the front one.",
	},
}

tw.plays = plays
