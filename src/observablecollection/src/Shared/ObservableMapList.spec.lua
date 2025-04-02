--[[
	@class ObservableMapList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ObservableMapList = require("ObservableMapList")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ObservableMapList.new()", function()
	local observableMapList = ObservableMapList.new()

	it("should return nil for unset values", function()
		expect(observableMapList:GetAtListIndex("dragon", 1)).toEqual(nil)
	end)

	it("should allow additions", function()
		observableMapList:Push("hello", "dragon")
		expect(observableMapList:GetAtListIndex("hello", 1)).toEqual("dragon")
		expect(observableMapList:GetAtListIndex("hello", -1)).toEqual("dragon")
		expect(observableMapList:GetAtListIndex("fire", 1)).toEqual(nil)
	end)
end)