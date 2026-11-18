--!strict
--[[
	@class ObservableList.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local ObservableList = require("ObservableList")
local ObservableSpy = require("ObservableSpy")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")

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
		local seen = ObservableSpy.new(observableList:ObserveIndex(1))
		observableList:InsertAt("c", 1)

		seen:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual(1)
		expect(seen[2]).toEqual(2)
	end)

	it("should fire off events for all keys", function()
		local seen = ObservableSpy.new(observableList:ObserveItemsBrio())
		observableList:Add("a")

		local value = seen[4]:GetValue()
		expect(#seen).toEqual(4)
		expect(value).toEqual("a")
		expect(seen[4]:IsDead()).toEqual(false)

		seen:Destroy()

		expect(#seen).toEqual(4)
		expect(seen[4]:IsDead()).toEqual(true)
	end)

	it("it should be able to observe a specific key", function()
		local seen = ObservableSpy.new(observableList:ObserveAtIndex(1))

		local originalList = observableList:GetList()
		expect(originalList[1]).toEqual("c")

		observableList:InsertAt("dragon", 1)

		seen:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual("c")
		expect(seen[2]).toEqual("dragon")
	end)

	it("it should be able to observe a specific negative key", function()
		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		local originalList = observableList:GetList()
		expect(originalList[#originalList]).toEqual("a")

		observableList:Add("fire")

		seen:Destroy()

		expect(#seen).toEqual(2)
		expect(seen[1]).toEqual("a")
		expect(seen[2]).toEqual("fire")
	end)

	it("should fire off events on removal", function()
		local seen = ObservableSpy.new(observableList:ObserveIndex(2))
		observableList:RemoveAt(1)

		seen:Destroy()

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

		local seenLast = ObservableSpy.new(observableList:ObserveAtIndex(-1))
		local seenSecondLast = ObservableSpy.new(observableList:ObserveAtIndex(-2))

		observableList:Add("b")

		expect(seenLast:GetLastValue()).toEqual("b")
		expect(seenSecondLast:GetLastValue()).toEqual("a")

		seenLast:Destroy()
		seenSecondLast:Destroy()
		observableList:Destroy()
	end)

	it("reveals the previous item when the last item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")

		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-1))
		expect(seen:GetLastValue()).toEqual("b")

		removeB()

		expect(seen:GetLastValue()).toEqual("a")
		expect(#seen).toEqual(2)

		seen:Destroy()
		observableList:Destroy()
	end)

	it("emits nil for the most negative index once it falls off the end", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-2))
		expect(seen:GetLastValue()).toEqual("a")

		removeA()

		expect(seen:GetLastValue()).toEqual(nil)
		expect(#seen).toEqual(2)

		seen:Destroy()
		observableList:Destroy()
	end)

	it("leaves the last item alone when an earlier item is removed", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-1))
		removeA()

		expect(seen:GetLastValue()).toEqual("b")
		expect(#seen).toEqual(1)

		seen:Destroy()
		observableList:Destroy()
	end)

	it("emits nil for the vacated positive index when the last item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")

		local seenFirst = ObservableSpy.new(observableList:ObserveAtIndex(1))
		local seenSecond = ObservableSpy.new(observableList:ObserveAtIndex(2))

		removeB()

		expect(#seenFirst).toEqual(1)
		expect(seenFirst:GetLastValue()).toEqual("a")
		expect(seenSecond:GetLastValue()).toEqual(nil)

		seenFirst:Destroy()
		seenSecond:Destroy()
		observableList:Destroy()
	end)
end)

describe("ObservableList negative index observation around the middle", function()
	it("shifts earlier items when an item is inserted in the middle", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen4 = ObservableSpy.new(observableList:ObserveAtIndex(-4))
		local seen3 = ObservableSpy.new(observableList:ObserveAtIndex(-3))
		local seen2 = ObservableSpy.new(observableList:ObserveAtIndex(-2))
		local seen1 = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		observableList:InsertAt("x", 2)

		expect(#seen4).toEqual(2)
		expect(seen4[1]).toEqual(nil)
		expect(seen4[2]).toEqual("a")
		expect(seen3.Values).toEqual({ "a", "x" })
		expect(seen2.Values).toEqual({ "b" })
		expect(seen1.Values).toEqual({ "c" })

		seen4:Destroy()
		seen3:Destroy()
		seen2:Destroy()
		seen1:Destroy()
		observableList:Destroy()
	end)

	it("shifts earlier items when a middle item is removed", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		local removeB = observableList:Add("b")
		observableList:Add("c")

		local seen3 = ObservableSpy.new(observableList:ObserveAtIndex(-3))
		local seen2 = ObservableSpy.new(observableList:ObserveAtIndex(-2))
		local seen1 = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		removeB()

		expect(#seen3).toEqual(2)
		expect(seen3[1]).toEqual("a")
		expect(seen3[2]).toEqual(nil)
		expect(seen2.Values).toEqual({ "b", "a" })
		expect(seen1.Values).toEqual({ "c" })

		seen3:Destroy()
		seen2:Destroy()
		seen1:Destroy()
		observableList:Destroy()
	end)

	it("emits only the shifted value for a positive slot when an earlier item is removed", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen = ObservableSpy.new(observableList:ObserveAtIndex(2))

		removeA()

		expect(seen.Values).toEqual({ "b", "c" })

		seen:Destroy()
		observableList:Destroy()
	end)

	it("emits the final value when a subscriber mutates the list reentrantly", function()
		local observableList = ObservableList.new()
		observableList:Add("a")

		local seenLast = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		local added = false
		local subSecondLast = observableList:ObserveAtIndex(-2):Subscribe(function(value)
			if value == "a" and not added then
				added = true
				observableList:Add("c")
			end
		end)

		observableList:Add("b")

		expect(observableList:GetList()).toEqual({ "a", "b", "c" })
		expect(seenLast:GetLastValue()).toEqual("c")

		seenLast:Destroy()
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
		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		local fires = countFires(function()
			for i = 1, ITEMS do
				observableList:Add(i)
			end
		end)

		expect(fires).toBeLessThanOrEqual(4 * ITEMS)

		seen:Destroy()
		observableList:Destroy()
	end)

	it("fires a bounded number of observers per pop from the back with a last-item observer", function()
		local observableList = ObservableList.new()
		local removers = {}
		for i = 1, ITEMS do
			removers[i] = observableList:Add(i)
		end
		local seen = ObservableSpy.new(observableList:ObserveAtIndex(-1))

		local fires = countFires(function()
			for i = ITEMS, 1, -1 do
				removers[i]()
			end
		end)

		expect(fires).toBeLessThanOrEqual(4 * ITEMS)

		seen:Destroy()
		observableList:Destroy()
	end)
end)

describe("ObservableList positive index observation (mirrors ObservableSortedList)", function()
	it("does not fire existing indices when adding at the end", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		observableList:Add("c")

		local seen1 = ObservableSpy.new(observableList:ObserveAtIndex(1))
		local seen2 = ObservableSpy.new(observableList:ObserveAtIndex(2))
		local seen3 = ObservableSpy.new(observableList:ObserveAtIndex(3))

		observableList:Add("d")

		expect(observableList:GetList()).toEqual({ "a", "b", "c", "d" })
		expect(seen1.Values).toEqual({ "a" })
		expect(seen2.Values).toEqual({ "b" })
		expect(seen3.Values).toEqual({ "c" })

		seen1:Destroy()
		seen2:Destroy()
		seen3:Destroy()
		observableList:Destroy()
	end)

	it("does not fire indices before a removed middle element", function()
		local observableList = ObservableList.new()
		observableList:Add("a")
		observableList:Add("b")
		local removeC = observableList:Add("c")
		observableList:Add("d")
		observableList:Add("e")

		local seen1 = ObservableSpy.new(observableList:ObserveAtIndex(1))
		local seen2 = ObservableSpy.new(observableList:ObserveAtIndex(2))
		local seen4 = ObservableSpy.new(observableList:ObserveAtIndex(4))

		removeC()

		expect(observableList:GetList()).toEqual({ "a", "b", "d", "e" })
		expect(seen1.Values).toEqual({ "a" })
		expect(seen2.Values).toEqual({ "b" })
		expect(seen4.Values).toEqual({ "d", "e" })

		seen1:Destroy()
		seen2:Destroy()
		seen4:Destroy()
		observableList:Destroy()
	end)

	it("fires every index when inserting at the beginning", function()
		local observableList = ObservableList.new()
		observableList:Add("b")
		observableList:Add("c")
		observableList:Add("d")

		local seen1 = ObservableSpy.new(observableList:ObserveAtIndex(1))
		local seen2 = ObservableSpy.new(observableList:ObserveAtIndex(2))
		local seen3 = ObservableSpy.new(observableList:ObserveAtIndex(3))
		local seen4 = ObservableSpy.new(observableList:ObserveAtIndex(4))

		observableList:InsertAt("a", 1)

		expect(observableList:GetList()).toEqual({ "a", "b", "c", "d" })
		expect(seen1.Values).toEqual({ "b", "a" })
		expect(seen2.Values).toEqual({ "c", "b" })
		expect(seen3.Values).toEqual({ "d", "c" })
		expect(#seen4).toEqual(2)
		expect(seen4[2]).toEqual("d")

		seen1:Destroy()
		seen2:Destroy()
		seen3:Destroy()
		seen4:Destroy()
		observableList:Destroy()
	end)

	it("fires nil when a positive index goes out of bounds", function()
		local observableList = ObservableList.new()
		local removeA = observableList:Add("a")
		observableList:Add("b")

		local seen = ObservableSpy.new(observableList:ObserveAtIndex(2))
		expect(seen.Values).toEqual({ "b" })

		removeA()

		expect(#seen).toEqual(2)
		expect(seen[2]).toEqual(nil)

		seen:Destroy()
		observableList:Destroy()
	end)
end)
