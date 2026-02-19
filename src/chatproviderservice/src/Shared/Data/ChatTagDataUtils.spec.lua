--!nonstrict
--[[
	@class ChatTagDataUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ChatTagDataUtils = require("ChatTagDataUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ChatTagDataUtils.isChatTagData(data)", function()
	it("should return true for valid chat tag data", function()
		local data = {
			TagText = "VIP",
			TagPriority = 1,
			TagColor = Color3.new(1, 0, 0),
		}
		expect(ChatTagDataUtils.isChatTagData(data)).toEqual(true)
	end)

	it("should return false for nil", function()
		expect(ChatTagDataUtils.isChatTagData(nil)).toEqual(false)
	end)

	it("should return false for a table missing TagText", function()
		local data = {
			TagPriority = 1,
			TagColor = Color3.new(1, 0, 0),
		}
		expect(ChatTagDataUtils.isChatTagData(data)).toEqual(false)
	end)
end)
