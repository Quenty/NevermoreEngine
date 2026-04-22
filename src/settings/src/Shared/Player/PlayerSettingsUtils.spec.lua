--!nonstrict
--[[
	@class PlayerSettingsUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerSettingsUtils = require("PlayerSettingsUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerSettingsUtils.encodeForNetwork(settingValue)", function()
	it("should encode nil as sentinel string", function()
		expect(PlayerSettingsUtils.encodeForNetwork(nil)).toEqual("<NIL_SETTING_VALUE>")
	end)

	it("should pass through numbers", function()
		expect(PlayerSettingsUtils.encodeForNetwork(42)).toEqual(42)
	end)

	it("should pass through strings", function()
		expect(PlayerSettingsUtils.encodeForNetwork("hello")).toEqual("hello")
	end)
end)

describe("PlayerSettingsUtils.decodeForNetwork(settingValue)", function()
	it("should decode sentinel string as nil", function()
		expect(PlayerSettingsUtils.decodeForNetwork("<NIL_SETTING_VALUE>")).toEqual(nil)
	end)

	it("should pass through numbers", function()
		expect(PlayerSettingsUtils.decodeForNetwork(42)).toEqual(42)
	end)
end)
