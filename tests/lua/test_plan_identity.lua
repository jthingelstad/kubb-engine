-- The short throw's plan is the v0.8.1 plan bit for bit (tests/lua/planref.lua):
-- a patch release may make it cheaper, never different. The same sweep runs under
-- wasmoon in tests/node/plan-identity.test.mjs.
import "tests/lua/planref"

test("plan.solve, handAt, nearTurn, carry and speedForCarry equal v0.8.1 bit for bit", function()
	local cases, first = tw.planRef.sweep()
	expect.truthy(cases > 100000, "cases: " .. cases)
	expect.eq(first, nil, "first difference")
end)
