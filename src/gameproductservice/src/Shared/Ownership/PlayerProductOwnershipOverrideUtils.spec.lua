--!strict
--[[
	Unit coverage for PlayerProductOwnershipOverrideUtils -- the pure helpers behind the replicated
	ownership-override map. No instances, ServiceBag, or attributes are involved.

	@class PlayerProductOwnershipOverrideUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerProductOwnershipOverrideUtils = require("PlayerProductOwnershipOverrideUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerProductOwnershipOverrideUtils.attributeName", function()
	it("should namespace the attribute per asset type", function()
		expect(PlayerProductOwnershipOverrideUtils.attributeName("game")).toEqual("GameProductOwnershipOverride_game")
		expect(PlayerProductOwnershipOverrideUtils.attributeName("pass")).toEqual("GameProductOwnershipOverride_pass")
	end)

	it("should give different asset types different attributes", function()
		expect(PlayerProductOwnershipOverrideUtils.attributeName("game")).never.toEqual(
			PlayerProductOwnershipOverrideUtils.attributeName("subscription")
		)
	end)
end)

describe("PlayerProductOwnershipOverrideUtils.sanitizeState", function()
	it("should treat nil as an empty map", function()
		expect(next(PlayerProductOwnershipOverrideUtils.sanitizeState(nil))).toEqual(nil)
	end)

	it("should treat a non-table as an empty map", function()
		expect(next(PlayerProductOwnershipOverrideUtils.sanitizeState("garbage"))).toEqual(nil)
	end)

	it("should keep boolean entries with string keys", function()
		local state = PlayerProductOwnershipOverrideUtils.sanitizeState({
			["9705252209"] = true,
			["123"] = false,
		})
		expect(state["9705252209"]).toEqual(true)
		expect(state["123"]).toEqual(false)
	end)

	it("should drop entries whose value is not a boolean", function()
		local state = PlayerProductOwnershipOverrideUtils.sanitizeState({
			["1"] = true,
			["2"] = "yes",
			["3"] = 5,
		})
		expect(state["1"]).toEqual(true)
		expect(state["2"]).toEqual(nil)
		expect(state["3"]).toEqual(nil)
	end)

	it("should return a fresh table the caller can mutate", function()
		local source = { ["1"] = true }
		local state = PlayerProductOwnershipOverrideUtils.sanitizeState(source)
		state["2"] = false
		expect(source["2"]).toEqual(nil)
	end)
end)
