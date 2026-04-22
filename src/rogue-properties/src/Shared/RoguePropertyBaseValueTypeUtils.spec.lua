--!nonstrict
--[[
	@class RoguePropertyBaseValueTypeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyBaseValueTypeUtils = require("RoguePropertyBaseValueTypeUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType(value)", function()
	it("should return false for an invalid value", function()
		expect(RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType("invalid")).toEqual(false)
	end)

	it("should return false for nil", function()
		expect(RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType(nil)).toEqual(false)
	end)
end)
