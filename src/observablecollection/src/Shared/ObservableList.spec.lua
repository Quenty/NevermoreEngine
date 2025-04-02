--[[
	@class ObservableList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ObservableList = require("ObservableList")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ObservableList.new()", function()
	local observableList = ObservableList.new()

	it("should return nil for unset values", function()
		expect(observableList:Get(1)).toEqual(nil)
	end)

	it("should allow inserting an value", function()
		expect(observableList:GetCount()).toEqual(0)

		observableList:Add("a")

		expect(observableList:Get(1)).toEqual("a")
		expect(observableList:GetCount()).toEqual(1)
	end)

	it("should allow negative queries", function()
		expect(observableList:Get(-1)).toEqual("a")
		expect(observableList:Get(-2)).toEqual(nil)
	end)

	it("should allow false as a value", function()
		expect(observableList:Get(2)).toEqual(nil)
		observableList:Add(false)
		expect(observableList:Get(2)).toEqual(false)
	end)

	it("should allow negative queries after false", function()
		expect(observableList:Get(1)).toEqual("a")
		expect(observableList:Get(2)).toEqual(false)

		expect(observableList:Get(-1)).toEqual(false)
		expect(observableList:Get(-2)).toEqual("a")
	end)

	it("should fire off events for a specific key", function()
		local seen = {}
		local sub = observableList:ObserveIndex(1):Subscribe(function(value)
			table.insert(seen, value)
		end)
		observableList:InsertAt("c", 1)

		sub:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual(1)
		expect(seen[2]).toEqual(2)
	end)

	it("should fire off events for all keys", function()
		local seen = {}
		local sub = observableList:ObserveItemsBrio():Subscribe(function(value)
			table.insert(seen, value)
		end)
		observableList:Add("a")

		local value = seen[4]:GetValue()
		expect(#seen).toEqual(4)
		expect(value).toEqual("a")
		expect(seen[4]:IsDead()).toEqual(false)

		sub:Destroy()

		expect(#seen).toEqual(4)
		expect(seen[4]:IsDead()).toEqual(true)
	end)

	it("it should be able to observe a specific key", function()
		local seen = {}
		local sub = observableList:ObserveAtIndex(1):Subscribe(function(value)
			table.insert(seen, value)
		end)

		local originalList = observableList:GetList()
		expect(originalList[1]).toEqual("c")

		observableList:InsertAt("dragon", 1)

		sub:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual("c")
		expect(seen[2]).toEqual("dragon")
	end)

	it("it should be able to observe a specific negative key", function()
		local seen = {}
		local sub = observableList:ObserveAtIndex(-1):Subscribe(function(value)
			table.insert(seen, value)
		end)

		local originalList = observableList:GetList()
		expect(originalList[#originalList]).toEqual("a")

		observableList:Add("fire")

		sub:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual("a")
		expect(seen[2]).toEqual("fire")
	end)

	it("should fire off events on removal", function()
		local seen = {}
		local sub = observableList:ObserveIndex(2):Subscribe(function(value)
			table.insert(seen, value)
		end)
		observableList:RemoveAt(1)

		sub:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual(2)
		expect(seen[2]).toEqual(1)
	end)

	it("should clean up", function()
		observableList:Destroy()
	end)
end)