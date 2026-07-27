--!strict
--[[
	@class AccessStateUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("AccessStateUtils.fromFacts", function()
	it("lists every fact that granted, not just the first", function()
		local state = AccessStateUtils.fromFacts({ a = true, b = true, c = false }, { "a", "b", "c" })

		expect(state.type).toEqual("allowed")
		expect((state :: any).grantedBy).toEqual({ "a", "b" })
	end)

	it("grants on a true fact even while another is unanswered", function()
		-- An answer that already grants cannot be taken back by one that hasn't arrived, and waiting for it
		-- would keep an entitled player out for no reason.
		local state = AccessStateUtils.fromFacts({ a = true }, { "a", "neverAnswers" })

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)
	end)

	it("is unresolved, not denied, while a fact is unanswered", function()
		local state = AccessStateUtils.fromFacts({ a = false }, { "a", "neverAnswers" })

		expect(AccessStateUtils.isUnresolved(state)).toEqual(true)
	end)

	it("denies only once every answer is in", function()
		local state = AccessStateUtils.fromFacts({ a = false, b = false }, { "a", "b" })

		expect(state.type).toEqual("disallowed")
		expect((state :: any).reason).toEqual(AccessStateUtils.Reasons.NOT_GRANTED)
	end)

	it("ignores facts the feature did not declare", function()
		-- A feature only stalls on mechanisms it actually reads.
		local state = AccessStateUtils.fromFacts({ a = false, undeclared = true }, { "a" })

		expect(AccessStateUtils.isAllowed(state)).toEqual(false)
		expect(AccessStateUtils.isUnresolved(state)).toEqual(false)
	end)

	it("denies a feature that declares no facts at all", function()
		expect(AccessStateUtils.isAllowed(AccessStateUtils.fromFacts({}, {}))).toEqual(false)
	end)
end)

describe("AccessStateUtils.key", function()
	it("gives two separately-built states with the same verdict one key", function()
		expect(AccessStateUtils.key(AccessStateUtils.allowed({ "a" }))).toEqual(
			AccessStateUtils.key(AccessStateUtils.allowed({ "a" }))
		)
	end)

	it("separates denials by reason", function()
		expect(AccessStateUtils.key(AccessStateUtils.unresolved())).never.toEqual(
			AccessStateUtils.key(AccessStateUtils.disallowed("other"))
		)
	end)

	it("separates grants by which facts granted", function()
		expect(AccessStateUtils.key(AccessStateUtils.allowed({ "a" }))).never.toEqual(
			AccessStateUtils.key(AccessStateUtils.allowed({ "b" }))
		)
	end)
end)

describe("AccessStateUtils.isUnresolved", function()
	it("does not treat an ordinary denial as unresolved", function()
		expect(AccessStateUtils.isUnresolved(AccessStateUtils.disallowed(AccessStateUtils.Reasons.NOT_GRANTED))).toEqual(
			false
		)
	end)

	it("does not treat an allowed state as unresolved", function()
		expect(AccessStateUtils.isUnresolved(AccessStateUtils.allowed())).toEqual(false)
	end)
end)
