--[[
	@class ObservableSortedList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ObservableSortedList.new()", function()
	local observableSortedList = ObservableSortedList.new()

	it("should return nil for unset values", function()
		expect(observableSortedList:Get(1)).toEqual(nil)
	end)

	it("should allow inserting an value", function()
		expect(observableSortedList:GetCount()).toEqual(0)

		observableSortedList:Add("b", Rx.of("b"))

		StepUtils.deferWait()

		expect(observableSortedList:Get(1)).toEqual("b")
		expect(observableSortedList:GetCount()).toEqual(1)
	end)

	it("should sort the items", function()
		expect(observableSortedList:GetCount()).toEqual(1)

		observableSortedList:Add("a", Rx.of("a"))

		StepUtils.deferWait()

		expect(observableSortedList:Get(1)).toEqual("a")
		expect(observableSortedList:Get(2)).toEqual("b")
		expect(observableSortedList:GetCount()).toEqual(2)
	end)

	it("should add in order if number is the same", function()
		observableSortedList = ObservableSortedList.new()
		observableSortedList:Add("a", Rx.of(0))
		observableSortedList:Add("b", Rx.of(0))
		observableSortedList:Add("c", Rx.of(0))

		StepUtils.deferWait()

		expect(observableSortedList:Get(1)).toEqual("a")
		expect(observableSortedList:Get(2)).toEqual("b")
		expect(observableSortedList:Get(3)).toEqual("c")
		expect(observableSortedList:GetCount()).toEqual(3)
	end)
end)