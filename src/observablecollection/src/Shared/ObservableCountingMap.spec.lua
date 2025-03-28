--[[
	@class ObservableCountingMap.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ObservableCountingMap = require("ObservableCountingMap")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ObservableCountingMap.new()", function()
	local observableCountingMap = ObservableCountingMap.new()

	it("should return 0 for unset values", function()
		expect(observableCountingMap:Get("a")).toEqual(0)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(0)
	end)

	it("should allow you to add to a value", function()
		expect(observableCountingMap:Get("a")).toEqual(0)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(0)
		observableCountingMap:Add("a", 5)
		expect(observableCountingMap:Get("a")).toEqual(5)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
	end)

	it("should allow you to add to a value that is already defined", function()
		expect(observableCountingMap:Get("a")).toEqual(5)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
		observableCountingMap:Add("a", 5)
		expect(observableCountingMap:Get("a")).toEqual(10)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
	end)

	it("should clean up", function()
		observableCountingMap:Destroy()
	end)
end)