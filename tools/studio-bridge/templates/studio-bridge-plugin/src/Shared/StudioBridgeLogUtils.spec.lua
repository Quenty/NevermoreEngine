--!strict
--[[
	@class StudioBridgeLogUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local StudioBridgeLogUtils = require("StudioBridgeLogUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("StudioBridgeLogUtils.setVerbose()", function()
	it("should start quiet", function()
		expect(StudioBridgeLogUtils.isVerbose()).toEqual(false)
	end)

	it("should toggle verbose output", function()
		StudioBridgeLogUtils.setVerbose(true)
		expect(StudioBridgeLogUtils.isVerbose()).toEqual(true)

		StudioBridgeLogUtils.setVerbose(false)
		expect(StudioBridgeLogUtils.isVerbose()).toEqual(false)
	end)
end)
