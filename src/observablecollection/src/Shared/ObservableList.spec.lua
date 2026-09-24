--!strict
--[[
	@class ObservableList.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local ObservableList = require("ObservableList")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function observe(observableList, index: number): ({ { any } }, any)
	local seen: { { any } } = {}
	local sub = observableList:ObserveAtIndex(index):Subscribe(function(value)
		table.insert(seen, { value })
	end)

	return seen, sub
end

local function last(seen: { { any } }): any
	return seen[#seen][1]
end

local function values(seen: { { any } }): { any }
	local result = {}
	for i, entry in seen do
		result[i] = entry[1]
	end
	return result
end

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

	it("should check if the list contains a value", function()
		expect(observableList:Contains("a")).toEqual(true)
	end)

	it("should allow false as a value", function()
		expect(observableList:Get(2)).toEqual(nil)
		observableList:Add(false :: any)
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

describe("ObservableList negative index observation", function()
	it("moves the last item back when a later item is added", function()
		local observableList = ObservableList.new()
		observableList:Add("a")

		local seenLast, subLast = observe(observableList, -1)
		local seenSecondLast, subSecondLast = observe(observableList, -2)

		observableList:Add("b")

		expect(last(seenLast)).toEqual("b")
		expect(last(seenSecondLast)).toEqual("a")

		subLast:Destroy()
		subSecondLast:Destroy()
		observableList:Destroy()
	end)

	it("reveals the previous item when the last item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")

		local seen, sub = observe(observableList, -1)
		expect(last(seen)).toEqual("b")

		removeB()

		expect(last(seen)).toEqual("a")
		expect(#seen).toEqual(2)

		sub:Destroy()
		observableList:Destroy()
	end)

	it("emits nil for the most negative index once it falls off the end", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen, sub = observe(observableList, -2)
		expect(last(seen)).toEqual("a")

		removeA()

		expect(last(seen)).toEqual(nil)
		expect(#seen).toEqual(2)

		sub:Destroy()
		observableList:Destroy()
	end)

	it("leaves the last item alone when an earlier item is removed", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen, sub = observe(observableList, -1)
		removeA()

		expect(last(seen)).toEqual("b")
		expect(#seen).toEqual(1)

		sub:Destroy()
		observableList:Destroy()
	end)

	it("emits nil for the vacated positive index when the last item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")

		local seenFirst, subFirst = observe(observableList, 1)
		local seenSecond, subSecond = observe(observableList, 2)

		removeB()

		expect(#seenFirst).toEqual(1)
		expect(last(seenFirst)).toEqual("a")
		expect(last(seenSecond)).toEqual(nil)

		subFirst:Destroy()
		subSecond:Destroy()
		observableList:Destroy()
	end)
end)

describe("ObservableList negative index observation around the middle", function()
	it("shifts earlier items when an item is inserted in the middle", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen4, sub4 = observe(observableList, -4)
		local seen3, sub3 = observe(observableList, -3)
		local seen2, sub2 = observe(observableList, -2)
		local seen1, sub1 = observe(observableList, -1)

		observableList:InsertAt("x", 2)

		expect(#seen4).toEqual(2)
		expect(seen4[1][1]).toEqual(nil)
		expect(seen4[2][1]).toEqual("a")
		expect(values(seen3)).toEqual({ "a", "x" })
		expect(values(seen2)).toEqual({ "b" })
		expect(values(seen1)).toEqual({ "c" })

		sub4:Destroy()
		sub3:Destroy()
		sub2:Destroy()
		sub1:Destroy()
		observableList:Destroy()
	end)

	it("shifts earlier items when a middle item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")
		observableList:Add("c")

		local seen3, sub3 = observe(observableList, -3)
		local seen2, sub2 = observe(observableList, -2)
		local seen1, sub1 = observe(observableList, -1)

		removeB()

		expect(#seen3).toEqual(2)
		expect(seen3[1][1]).toEqual("a")
		expect(seen3[2][1]).toEqual(nil)
		expect(values(seen2)).toEqual({ "b", "a" })
		expect(values(seen1)).toEqual({ "c" })

		sub3:Destroy()
		sub2:Destroy()
		sub1:Destroy()
		observableList:Destroy()
	end)

	it("emits only the shifted value for a positive slot when an earlier item is removed", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen, sub = observe(observableList, 2)

		removeA()

		expect(values(seen)).toEqual({ "b", "c" })

		sub:Destroy()
		observableList:Destroy()
	end)

	it("emits the final value when a subscriber mutates the list reentrantly", function()
		local observableList = ObservableList.new()
		observableList:Add("a")

		local seenLast, subLast = observe(observableList, -1)

		local added = false
		local subSecondLast = observableList:ObserveAtIndex(-2):Subscribe(function(value)
			if value == "a" and not added then
				added = true
				observableList:Add("c")
			end
		end)

		observableList:Add("b")

		expect(observableList:GetList()).toEqual({ "a", "b", "c" })
		expect(last(seenLast)).toEqual("c")

		subLast:Destroy()
		subSecondLast:Destroy()
		observableList:Destroy()
	end)
end)

describe("ObservableList destroyed from its own handlers", function()
	it("survives Destroy from an ItemAdded handler", function()
		local observableList = ObservableList.new()
		observableList.ItemAdded:Connect(function()
			observableList:Destroy()
		end)

		expect(function()
			observableList:Add("a")
		end).never.toThrow()
	end)

	it("survives Destroy from an ItemRemoved handler", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList.ItemRemoved:Connect(function()
			observableList:Destroy()
		end)

		expect(function()
			removeA()
		end).never.toThrow()
	end)
end)

describe("ObservableList emission cost", function()
	local function countFires(callback: () -> ()): number
		local originalFire = ObservableSubscriptionTable.Fire
		local count = 0
		ObservableSubscriptionTable.Fire = function(...)
			count += 1
			return originalFire(...)
		end

		local ok, err = pcall(callback :: () -> any)
		ObservableSubscriptionTable.Fire = originalFire

		if not ok then
			error(err)
		end

		return count
	end

	local ITEMS = 100

	it("fires a bounded number of observers per Add with a last-item observer", function()
		local observableList = ObservableList.new()
		local _, sub = observe(observableList, -1)

		local fires = countFires(function()
			for i = 1, ITEMS do
				observableList:Add(i)
			end
		end)

		expect(fires).toBeLessThanOrEqual(4 * ITEMS)

		sub:Destroy()
		observableList:Destroy()
	end)

	it("fires a bounded number of observers per pop from the back with a last-item observer", function()
		local observableList = ObservableList.new()
		local removers = {}
		for i = 1, ITEMS do
			removers[i] = observableList:Add(i)
		end
		local _, sub = observe(observableList, -1)

		local fires = countFires(function()
			for i = ITEMS, 1, -1 do
				removers[i]()
			end
		end)

		expect(fires).toBeLessThanOrEqual(4 * ITEMS)

		sub:Destroy()
		observableList:Destroy()
	end)
end)

describe("ObservableList positive index observation (mirrors ObservableSortedList)", function()
	it("does not fire existing indices when adding at the end", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen1, sub1 = observe(observableList, 1)
		local seen2, sub2 = observe(observableList, 2)
		local seen3, sub3 = observe(observableList, 3)

		observableList:Add("d")

		expect(observableList:GetList()).toEqual({ "a", "b", "c", "d" })
		expect(values(seen1)).toEqual({ "a" })
		expect(values(seen2)).toEqual({ "b" })
		expect(values(seen3)).toEqual({ "c" })

		sub1:Destroy()
		sub2:Destroy()
		sub3:Destroy()
		observableList:Destroy()
	end)

	it("does not fire indices before a removed middle element", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		local removeC = observableList:Add("c")
		observableList:Add("d")
		observableList:Add("e")

		local seen1, sub1 = observe(observableList, 1)
		local seen2, sub2 = observe(observableList, 2)
		local seen4, sub4 = observe(observableList, 4)

		removeC()

		expect(observableList:GetList()).toEqual({ "a", "b", "d", "e" })
		expect(values(seen1)).toEqual({ "a" })
		expect(values(seen2)).toEqual({ "b" })
		expect(values(seen4)).toEqual({ "d", "e" })

		sub1:Destroy()
		sub2:Destroy()
		sub4:Destroy()
		observableList:Destroy()
	end)

	it("fires every index when inserting at the beginning", function()
		local observableList = ObservableList.new()
		observableList:Add("b")
		observableList:Add("c")
		observableList:Add("d")

		local seen1, sub1 = observe(observableList, 1)
		local seen2, sub2 = observe(observableList, 2)
		local seen3, sub3 = observe(observableList, 3)
		local seen4, sub4 = observe(observableList, 4)

		observableList:InsertAt("a", 1)

		expect(observableList:GetList()).toEqual({ "a", "b", "c", "d" })
		expect(values(seen1)).toEqual({ "b", "a" })
		expect(values(seen2)).toEqual({ "c", "b" })
		expect(values(seen3)).toEqual({ "d", "c" })
		expect(#seen4).toEqual(2)
		expect(seen4[2][1]).toEqual("d")

		sub1:Destroy()
		sub2:Destroy()
		sub3:Destroy()
		sub4:Destroy()
		observableList:Destroy()
	end)

	it("fires nil when a positive index goes out of bounds", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen, sub = observe(observableList, 2)
		expect(values(seen)).toEqual({ "b" })

		removeA()

		expect(#seen).toEqual(2)
		expect(seen[2][1]).toEqual(nil)

		sub:Destroy()
		observableList:Destroy()
	end)
end)
