--!nonstrict
--[[
	@class InputKeyMapSettingConstants.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InputKeyMapSettingConstants = require("InputKeyMapSettingConstants")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InputKeyMapSettingConstants", function()
	it("should have DEFAULT_VALUE set to default", function()
		expect(InputKeyMapSettingConstants.DEFAULT_VALUE).toEqual("default")
	end)
end)
