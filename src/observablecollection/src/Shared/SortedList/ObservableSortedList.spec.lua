--!strict
--[[
	@class ObservableSortedList.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Jest = require("Jest")
local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")
local Symbol = require("Symbol")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local NIL_VALUE = Symbol.named("nil_placeholder")

local ObservableSortedListTestUtils = {}

function ObservableSortedListTestUtils.fromList<string>(list: { string }): ObservableSortedList.ObservableSortedList<string>
	local sortedList = ObservableSortedList.new()

	for index, value in list do
		sortedList:Add(value, index)
	end

	return sortedList
end

function ObservableSortedListTestUtils.collectValues(observable: any)
	local values = {}
	local sub = observable:Subscribe(function(value: any)
		if value == nil then
			table.insert(values, NIL_VALUE)
		else
			table.insert(values, value)
		end
	end)
	return values, sub
end

describe("ObservableSortedList", function()
	describe("Add", function()
		it("should insert a value synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("b", 2)

			expect(list:Get(1)).toEqual("b")
			maid:Destroy()
		end)

		it("should accept an observable as sort value", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			-- Cast: the recursive Observable type does not unify structurally inside Add's union.
			list:Add("b", Rx.of(2) :: any)
			list:Add("a", Rx.of(1) :: any)

			expect(list:Get(1)).toEqual("a")
			expect(list:Get(2)).toEqual("b")
			maid:Destroy()
		end)

		it("should sort items by value synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("b", 2)
			list:Add("a", 1)

			expect(list:Get(1)).toEqual("a")
			expect(list:Get(2)).toEqual("b")
			maid:Destroy()
		end)

		it("should preserve insertion order for equal sort values", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 0)
			list:Add("b", 0)
			list:Add("c", 0)

			expect(list:GetList()).toEqual({ "a", "b", "c" })
			maid:Destroy()
		end)

		it("should remove items via cleanup function", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)

			removeB()

			expect(list:GetList()).toEqual({ "a", "c" })

			removeA()

			expect(list:GetList()).toEqual({ "c" })
			maid:Destroy()
		end)

		it("should re-sort when sort value changes", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValueA = maid:Add(ValueObject.new(1, "number"))
			local sortValueB = maid:Add(ValueObject.new(2, "number"))
			local sortValueC = maid:Add(ValueObject.new(3, "number"))

			list:Add("a", sortValueA:Observe())
			list:Add("b", sortValueB:Observe())
			list:Add("c", sortValueC:Observe())

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortValueA.Value = 10

			expect(list:GetList()).toEqual({ "b", "c", "a" })

			sortValueA:Destroy()
			sortValueB:Destroy()
			sortValueC:Destroy()
			maid:Destroy()
		end)

		it("should support reversed sort order", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new(true))
			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "c", "b", "a" })
			maid:Destroy()
		end)
	end)

	describe("Get", function()
		it("should return nil for unset values", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			expect(list:Get(1)).toEqual(nil)
			maid:Destroy()
		end)
	end)

	describe("GetCount", function()
		it("should update after deferred events fire", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))

			list:_testForceFireEvents()

			expect(list:GetCount()).toEqual(2)
			maid:Destroy()
		end)
	end)

	describe("GetList", function()
		it("should return a sorted list synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("c", 3)
			list:Add("a", 1)
			list:Add("b", 2)

			local result = list:GetList()
			expect(#result).toEqual(3)
			expect(result[1]).toEqual("a")
			expect(result[2]).toEqual("b")
			expect(result[3]).toEqual("c")
			maid:Destroy()
		end)
	end)

	describe("Contains", function()
		it("should return true for items in the list synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))

			expect(list:Contains("a")).toEqual(true)
			expect(list:Contains("b")).toEqual(true)
			expect(list:Contains("c")).toEqual(false)
			maid:Destroy()
		end)
	end)

	describe("ObserveCount", function()
		it("should fire on add and remove", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local seenCounts, sub = ObservableSortedListTestUtils.collectValues(list:ObserveCount())

			local removeA = list:Add("a", 1)
			list:_testForceFireEvents()

			list:Add("b", 2)
			list:_testForceFireEvents()

			removeA()
			list:_testForceFireEvents()

			sub:Destroy()

			expect(seenCounts[1]).toEqual(0)
			expect(seenCounts[2]).toEqual(1)
			expect(seenCounts[3]).toEqual(2)
			expect(seenCounts[4]).toEqual(1)
			maid:Destroy()
		end)
	end)

	describe("ObserveIndex", function()
		it("should fire for adjacent element on removal", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local seenIndices, sub = ObservableSortedListTestUtils.collectValues(list:ObserveIndex(3))

			expect(#seenIndices).toEqual(1)
			expect(seenIndices[1]).toEqual(3)

			removeB()
			list:_testForceFireEvents()

			sub:Destroy()

			expect(#seenIndices).toEqual(2)
			expect(seenIndices[2]).toEqual(2)
			maid:Destroy()
		end)

		it("should fire for all elements after a removed element", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			expect(list:GetCount()).toEqual(5)

			local seenIndicesForE, sub = ObservableSortedListTestUtils.collectValues(list:ObserveIndex(5))

			expect(#seenIndicesForE).toEqual(1)
			expect(seenIndicesForE[1]).toEqual(5)

			removeB()
			list:_testForceFireEvents()

			expect(list:GetCount()).toEqual(4)
			expect(list:GetList()).toEqual({ "a", "c", "d", "e" })

			expect(#seenIndicesForE).toEqual(2)
			expect(seenIndicesForE[2]).toEqual(4)

			sub:Destroy()
			maid:Destroy()
		end)
	end)

	describe("ObserveAtIndex", function()
		it("should fire when item at position changes", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local seenItems, sub = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))

			expect(#seenItems).toEqual(1)
			expect(seenItems[1]).toEqual("b")

			removeB()
			list:_testForceFireEvents()

			sub:Destroy()

			expect(#seenItems).toEqual(2)
			expect(seenItems[2]).toEqual("c")
			maid:Destroy()
		end)
	end)

	describe("ObserveItemsBrio", function()
		it("should fire for existing and new items", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))
			list:_testForceFireEvents()

			local seenBrios, sub = ObservableSortedListTestUtils.collectValues(list:ObserveItemsBrio())

			expect(#seenBrios).toEqual(2)

			list:Add("c", 3)
			list:_testForceFireEvents()

			expect(#seenBrios).toEqual(3)

			sub:Destroy()
			maid:Destroy()
		end)

		it("should kill brio when item is removed", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			list:_testForceFireEvents()

			local seenBrios: { Brio.Brio<string, any> } = {}
			local sub = list:ObserveItemsBrio():Subscribe(function(brio)
				table.insert(seenBrios, brio)
			end)

			expect(#seenBrios).toEqual(1)
			expect(seenBrios[1]:IsDead()).toEqual(false)

			removeA()
			list:_testForceFireEvents()

			expect(seenBrios[1]:IsDead()).toEqual(true)

			sub:Destroy()
			maid:Destroy()
		end)
	end)

	describe("isObservableSortedList", function()
		it("should return true for an ObservableSortedList", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			expect(ObservableSortedList.isObservableSortedList(list)).toEqual(true)
			maid:Destroy()
		end)

		it("should return false for other values", function()
			expect(ObservableSortedList.isObservableSortedList({})).toEqual(false)
			expect(ObservableSortedList.isObservableSortedList(nil)).toEqual(false)
			expect(ObservableSortedList.isObservableSortedList("hello")).toEqual(false)
		end)
	end)

	describe("Observe", function()
		it("should fire with the full list on change", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local seen: { { string } } = {}
			local sub = list:Observe():Subscribe(function(items)
				table.insert(seen, items)
			end)

			list:Add("b", 2)
			list:_testForceFireEvents()

			list:Add("a", 1)
			list:_testForceFireEvents()

			sub:Destroy()

			expect(#seen).toEqual(3)
			expect(#seen[1]).toEqual(0)
			expect(seen[2][1]).toEqual("b")
			expect(seen[3][1]).toEqual("a")
			expect(seen[3][2]).toEqual("b")
			maid:Destroy()
		end)
	end)

	describe("IterateRange", function()
		it("should iterate a subset of the list synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b", "c" }))
			list:Add("d", 4)

			-- selene: allow(manual_table_clone)
			local result = {}
			for index, value in list:IterateRange(2, 3) do
				result[index] = value
			end

			expect(result[2]).toEqual("b")
			expect(result[3]).toEqual("c")
			expect(result[1]).toEqual(nil)
			expect(result[4]).toEqual(nil)
			maid:Destroy()
		end)
	end)

	describe("FindFirstKey", function()
		it("should return the node for existing data", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))

			local node = list:FindFirstKey("a")
			expect(node).never.toEqual(nil)

			local missing = list:FindFirstKey("c")
			expect(missing).toEqual(nil)
			maid:Destroy()
		end)
	end)

	describe("GetIndexByKey", function()
		it("should return the index for a node synchronously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b", "c" }))

			local node = list:FindFirstKey("b")
			assert(node ~= nil, "Expected to find node for 'b'")

			expect(list:GetIndexByKey(node)).toEqual(2)
			maid:Destroy()
		end)
	end)

	describe("RemoveByKey", function()
		it("should remove an item by its node key", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b", "c" }))

			local node = list:FindFirstKey("b")
			assert(node ~= nil, "Expected to find node for 'b'")

			list:RemoveByKey(node)

			expect(list:GetList()).toEqual({ "a", "c" })
			maid:Destroy()
		end)
	end)

	describe("ObserveIndexByKey", function()
		it("should track index of a specific node", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b", "c" }))
			list:_testForceFireEvents()

			local node = list:FindFirstKey("c")
			assert(node ~= nil, "Expected to find node for 'c'")

			local seenIndices, sub = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(node))

			expect(#seenIndices).toEqual(1)
			expect(seenIndices[1]).toEqual(3)

			sub:Destroy()
			maid:Destroy()
		end)
	end)

	describe("Destroy", function()
		it("should clean up", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)

			expect(list:Get(1)).toEqual("a")

			maid:Destroy()
		end)

		it("should kill all brios on Destroy", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))
			list:_testForceFireEvents()

			local seenBrios, sub = ObservableSortedListTestUtils.collectValues(list:ObserveItemsBrio())

			expect(#seenBrios).toEqual(2)
			expect(seenBrios[1]:IsDead()).toEqual(false)
			expect(seenBrios[2]:IsDead()).toEqual(false)

			maid:Destroy()

			expect(seenBrios[1]:IsDead()).toEqual(true)
			expect(seenBrios[2]:IsDead()).toEqual(true)
			sub:Destroy()
		end)
	end)

	describe("edge cases", function()
		it("should handle duplicate data values as separate entries", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)
			local removeSecondA = list:Add("a", 2)
			list:Add("a", 3)

			expect(list:GetList()).toEqual({ "a", "a", "a" })

			removeSecondA()

			expect(list:GetList()).toEqual({ "a", "a" })
			maid:Destroy()
		end)

		it("should handle double-remove safely", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local remove = list:Add("a", 1)

			remove()
			remove()

			expect(list:Get(1)).toEqual(nil)
			maid:Destroy()
		end)

		it("should return nil for Get on out-of-bounds indices", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a" }))

			expect(list:Get(-2)).toEqual(nil)
			expect(list:Get(100)).toEqual(nil)
			maid:Destroy()
		end)

		it("should support negative indices in Get", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))

			expect(list:Get(-1)).toEqual("b")
			expect(list:Get(-2)).toEqual("a")
			maid:Destroy()
		end)

		it("should error for Get(0)", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)

			expect(function()
				list:Get(0)
			end).toThrow()
			maid:Destroy()
		end)

		it("should return nil for FindFirstKey after removal", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local remove = list:Add("a", 1)

			expect(list:FindFirstKey("a")).never.toEqual(nil)

			remove()

			expect(list:FindFirstKey("a")).toEqual(nil)
			maid:Destroy()
		end)

		it("should return nil for GetIndexByKey after removal", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))

			local node = list:FindFirstKey("b")
			assert(node ~= nil, "Expected to find node for 'b'")

			expect(list:GetIndexByKey(node)).toEqual(2)

			list:RemoveByKey(node)

			expect(list:GetIndexByKey(node)).toEqual(nil)
			maid:Destroy()
		end)

		it("should fire nil for ObserveAtIndex when index goes out of bounds", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			list:Add("b", 2)
			list:_testForceFireEvents()

			local seenItems, sub = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))

			expect(#seenItems).toEqual(1)
			expect(seenItems[1]).toEqual("b")

			removeA()
			list:_testForceFireEvents()

			sub:Destroy()

			expect(#seenItems).toEqual(2)
			expect(seenItems[2]).toEqual(NIL_VALUE)
			maid:Destroy()
		end)

		it("should batch multiple changes into one deferred event", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValueA = maid:Add(ValueObject.new(1, "number"))
			local sortValueB = maid:Add(ValueObject.new(2, "number"))
			local sortValueC = maid:Add(ValueObject.new(3, "number"))

			list:Add("a", sortValueA:Observe())
			list:Add("b", sortValueB:Observe())
			list:Add("c", sortValueC:Observe())
			list:_testForceFireEvents()

			local fireCount = 0
			local sub = list:Observe():Subscribe(function()
				fireCount += 1
			end)

			expect(fireCount).toEqual(1)

			sortValueA.Value = 30
			sortValueB.Value = 20
			sortValueC.Value = 10

			list:_testForceFireEvents()

			expect(fireCount).toEqual(2)
			expect(list:GetList()).toEqual({ "c", "b", "a" })

			sub:Destroy()
			maid:Destroy()
		end)

		it("should complete ObserveIndex when the tracked node is removed", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			list:Add("b", 2)
			list:_testForceFireEvents()

			local completed = false
			local sub = list:ObserveIndex(1):Subscribe(function() end, function() end, function()
				completed = true
			end)

			expect(completed).toEqual(false)

			removeA()
			list:_testForceFireEvents()

			expect(completed).toEqual(true)
			sub:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveItemsBrio synchronously for existing items on subscribe", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedListTestUtils.fromList({ "a", "b" }))
			list:_testForceFireEvents()

			local seenBrios, sub = ObservableSortedListTestUtils.collectValues(list:ObserveItemsBrio())

			expect(#seenBrios).toEqual(2)

			sub:Destroy()
			maid:Destroy()
		end)

		it("should handle operations on empty list", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			expect(list:Get(1)).toEqual(nil)
			expect(list:Contains("a")).toEqual(false)
			expect(list:FindFirstKey("a")).toEqual(nil)
			expect(#list:GetList()).toEqual(0)

			-- selene: allow(manual_table_clone)
			local result = {}
			for index, value in list:IterateRange(1, 10) do
				result[index] = value
			end
			expect(next(result)).toEqual(nil)

			maid:Destroy()
		end)
	end)

	describe("resorting", function()
		it("should not fire events when sort value changes to same value", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2, "number"))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:Add("c", 3)
			list:_testForceFireEvents()

			local fireCount = 0
			local sub = list:Observe():Subscribe(function()
				fireCount += 1
			end)

			expect(fireCount).toEqual(1)

			sortValue.Value = 2
			list:_testForceFireEvents()

			expect(fireCount).toEqual(1)
			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sub:Destroy()
			maid:Destroy()
		end)

		it("should handle sort value changing multiple times in one frame", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(1, "number"))
			list:Add("a", sortValue:Observe())
			list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortValue.Value = 10 -- a goes to end
			sortValue.Value = 0 -- a goes back to start
			sortValue.Value = 5 -- a ends up in the middle

			expect(list:GetList()).toEqual({ "b", "c", "a" })

			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "b", "c", "a" })

			maid:Destroy()
		end)

		it("should handle sort value oscillating back to original value in one frame", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(1, "number"))
			list:Add("a", sortValue:Observe())
			list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local fireCount = 0
			local sub = list:Observe():Subscribe(function()
				fireCount += 1
			end)
			expect(fireCount).toEqual(1)

			sortValue.Value = 10
			sortValue.Value = 1

			expect(list:GetList()).toEqual({ "a", "b", "c" })
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sub:Destroy()
			maid:Destroy()
		end)

		it("should maintain correct order when multiple items resort simultaneously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortA = maid:Add(ValueObject.new(1, "number"))
			local sortB = maid:Add(ValueObject.new(2, "number"))
			local sortC = maid:Add(ValueObject.new(3, "number"))
			local sortD = maid:Add(ValueObject.new(4, "number"))

			list:Add("a", sortA:Observe())
			list:Add("b", sortB:Observe())
			list:Add("c", sortC:Observe())
			list:Add("d", sortD:Observe())

			expect(list:GetList()).toEqual({ "a", "b", "c", "d" })

			sortA.Value = 4
			sortB.Value = 3
			sortC.Value = 2
			sortD.Value = 1

			expect(list:GetList()).toEqual({ "d", "c", "b", "a" })
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "d", "c", "b", "a" })

			maid:Destroy()
		end)

		it("should preserve insertion order when items resort to equal values", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortA = maid:Add(ValueObject.new(1, "number"))
			local sortB = maid:Add(ValueObject.new(2, "number"))
			local sortC = maid:Add(ValueObject.new(3, "number"))

			list:Add("a", sortA:Observe())
			list:Add("b", sortB:Observe())
			list:Add("c", sortC:Observe())

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortA.Value = 5
			sortB.Value = 5
			sortC.Value = 5

			local result = list:GetList()
			expect(#result).toEqual(3)
			expect(list:Contains("a")).toEqual(true)
			expect(list:Contains("b")).toEqual(true)
			expect(list:Contains("c")).toEqual(true)

			maid:Destroy()
		end)

		it("should not move a node when value changes but position stays valid", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortB = maid:Add(ValueObject.new(5, "number"))
			list:Add("a", 1)
			list:Add("b", sortB:Observe())
			list:Add("c", 10)
			list:_testForceFireEvents()

			local seenIndices, sub = ObservableSortedListTestUtils.collectValues(list:ObserveIndex(2))
			expect(seenIndices[1]).toEqual(2)

			sortB.Value = 7
			list:_testForceFireEvents()

			expect(#seenIndices).toEqual(1)
			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sub:Destroy()
			maid:Destroy()
		end)
	end)

	describe("sort value observable edge cases", function()
		it("should not insert node when observable emits nil", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(nil :: number?))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "a", "c" })
			expect(list:Contains("b")).toEqual(false)

			sortValue.Value = 2
			expect(list:GetList()).toEqual({ "a", "b", "c" })
			expect(list:Contains("b")).toEqual(true)

			maid:Destroy()
		end)

		it("should remove node when observable emits nil after having a value", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortValue.Value = nil :: any
			expect(list:GetList()).toEqual({ "a", "c" })
			expect(list:Contains("b")).toEqual(false)

			sortValue.Value = 2
			expect(list:GetList()).toEqual({ "a", "b", "c" })

			maid:Destroy()
		end)

		it("should fire ItemRemoved when sort value becomes nil", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:_testForceFireEvents()

			local seenBrios, sub = ObservableSortedListTestUtils.collectValues(list:ObserveItemsBrio())
			expect(#seenBrios).toEqual(2)
			expect(seenBrios[1]:IsDead()).toEqual(false)
			expect(seenBrios[2]:IsDead()).toEqual(false)

			sortValue.Value = nil :: any
			list:_testForceFireEvents()

			expect(seenBrios[2]:IsDead()).toEqual(true)
			expect(seenBrios[1]:IsDead()).toEqual(false)

			sub:Destroy()
			maid:Destroy()
		end)

		it("should handle observable that never emits", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", Rx.EMPTY :: any)
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "a", "c" })
			expect(list:Contains("b")).toEqual(false)

			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "c" })

			maid:Destroy()
		end)

		it("should handle nil-value-nil-value cycle", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(nil :: number?))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "a", "c" })

			sortValue.Value = 2
			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortValue.Value = nil :: any
			expect(list:GetList()).toEqual({ "a", "c" })

			sortValue.Value = 4
			expect(list:GetList()).toEqual({ "a", "c", "b" })

			maid:Destroy()
		end)

		it("should handle sort value going nil and back in one frame", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:Add("c", 3)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			sortValue.Value = nil :: any
			sortValue.Value = 2

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			list:_testForceFireEvents()
			expect(list:GetList()).toEqual({ "a", "b", "c" })

			maid:Destroy()
		end)
	end)

	describe("add and remove timing", function()
		it("should not fire events when item is added and removed in same frame", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:Add("a", 1)
			list:_testForceFireEvents()

			local addCount = 0
			local removeCount = 0
			maid:Add(list.ItemAdded:Connect(function()
				addCount += 1
			end))
			maid:Add(list.ItemRemoved:Connect(function()
				removeCount += 1
			end))

			local remove = list:Add("b", 2)
			remove()

			list:_testForceFireEvents()

			expect(addCount).toEqual(0)
			expect(removeCount).toEqual(0)
			expect(list:GetList()).toEqual({ "a" })

			maid:Destroy()
		end)

		it("should handle removing during a sort value change", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2, "number"))
			local remove = list:Add("b", sortValue:Observe())
			list:Add("a", 1)
			list:Add("c", 3)

			expect(list:GetList()).toEqual({ "a", "b", "c" })

			remove()

			expect(list:GetList()).toEqual({ "a", "c" })

			sortValue.Value = 10
			expect(list:GetList()).toEqual({ "a", "c" })

			maid:Destroy()
		end)

		it("should handle adding items between deferred event fires", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local counts, countSub = ObservableSortedListTestUtils.collectValues(list:ObserveCount())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)

			list:_testForceFireEvents()

			expect(counts[1]).toEqual(0)
			expect(counts[2]).toEqual(3)
			expect(#counts).toEqual(2)

			countSub:Destroy()
			maid:Destroy()
		end)

		it("should handle interleaved adds and removes before events fire", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:_testForceFireEvents()

			local counts, countSub = ObservableSortedListTestUtils.collectValues(list:ObserveCount())
			expect(counts[1]).toEqual(0)

			local removeA = list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			removeA() -- remove A before events fire
			list:Add("d", 4)

			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "b", "c", "d" })
			expect(counts[2]).toEqual(3)

			countSub:Destroy()
			maid:Destroy()
		end)

		it("should handle removal via cleanup while sort value emits nil simultaneously", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2))
			local remove = list:Add("b", sortValue:Observe())
			list:Add("a", 1)

			expect(list:GetList()).toEqual({ "a", "b" })

			sortValue.Value = nil :: any
			remove()

			expect(list:GetList()).toEqual({ "a" })
			expect(list:Contains("b")).toEqual(false)

			list:_testForceFireEvents()
			expect(list:GetList()).toEqual({ "a" })

			maid:Destroy()
		end)
	end)

	describe("signal firing", function()
		it("should fire signals in correct order: count, add, remove, order", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:_testForceFireEvents()

			local events: { string } = {}

			maid:Add(list.ItemAdded:Connect(function()
				table.insert(events, "add")
			end))
			maid:Add(list.ItemRemoved:Connect(function()
				table.insert(events, "remove")
			end))
			maid:Add(list.OrderChanged:Connect(function()
				table.insert(events, "order")
			end))

			list:Add("a", 1)
			list:_testForceFireEvents()

			expect(events).toEqual({ "add", "order" })

			maid:Destroy()
		end)

		it("should fire correct count of ItemAdded events on batch add", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:_testForceFireEvents()

			local addedItems: { string } = {}
			maid:Add(list.ItemAdded:Connect(function(data)
				table.insert(addedItems, data)
			end))

			list:Add("c", 3)
			list:Add("a", 1)
			list:Add("b", 2)
			list:_testForceFireEvents()

			expect(#addedItems).toEqual(3)
			maid:Destroy()
		end)

		it("should not fire ObserveIndex when sort value changes but position is unchanged", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortB = maid:Add(ValueObject.new(5, "number"))
			list:Add("a", 1)
			list:Add("b", sortB:Observe())
			list:Add("c", 10)
			list:_testForceFireEvents()

			local indexChanges, sub = ObservableSortedListTestUtils.collectValues(list:ObserveIndex(2))
			expect(#indexChanges).toEqual(1)

			sortB.Value = 8
			list:_testForceFireEvents()

			expect(#indexChanges).toEqual(1)
			expect(list:Get(2)).toEqual("b")

			sub:Destroy()
			maid:Destroy()
		end)

		it("should update ObserveAtIndex when resort moves items", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortA = maid:Add(ValueObject.new(1, "number"))
			list:Add("a", sortA:Observe())
			list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local seenAtIndex1, sub = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			expect(seenAtIndex1[1]).toEqual("a")

			sortA.Value = 10
			list:_testForceFireEvents()

			expect(seenAtIndex1[2]).toEqual("b")

			sub:Destroy()
			maid:Destroy()
		end)

		it("should fire new brio when item is removed via nil and re-added via value", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortValue = maid:Add(ValueObject.new(2))
			list:Add("a", 1)
			list:Add("b", sortValue:Observe())
			list:_testForceFireEvents()

			local seenBrios: { Brio.Brio<string, any> } = {}
			local sub = list:ObserveItemsBrio():Subscribe(function(brio)
				table.insert(seenBrios, brio)
			end)

			expect(#seenBrios).toEqual(2)

			sortValue.Value = nil :: any
			list:_testForceFireEvents()

			expect(seenBrios[2]:IsDead()).toEqual(true)

			sortValue.Value = 2
			list:_testForceFireEvents()

			expect(#seenBrios).toEqual(3)
			expect(seenBrios[3]:IsDead()).toEqual(false)

			sub:Destroy()
			maid:Destroy()
		end)

		it("should survive listener destroying the list during event processing", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())
			list:_testForceFireEvents()

			maid:Add(list.ItemAdded:Connect(function()
				maid:Destroy()
			end))

			list:Add("a", 1)
			list:_testForceFireEvents()

			maid:Destroy()
		end)
	end)

	describe("order preservation", function()
		it("should maintain insertion order for many items with equal sort values", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local items = { "a", "b", "c", "d", "e", "f", "g", "h" }
			for _, item in items do
				list:Add(item, 0)
			end

			expect(list:GetList()).toEqual(items)
			maid:Destroy()
		end)

		it("should maintain relative order of unaffected items during resort", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortC = maid:Add(ValueObject.new(3, "number"))
			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", sortC:Observe())
			list:Add("d", 4)
			list:Add("e", 5)

			expect(list:GetList()).toEqual({ "a", "b", "c", "d", "e" })

			sortC.Value = 10

			expect(list:GetList()).toEqual({ "a", "b", "d", "e", "c" })

			sortC:Destroy()
			maid:Destroy()
		end)

		it("should preserve order with interleaved static and dynamic sort values", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortB = maid:Add(ValueObject.new(2, "number"))
			local sortD = maid:Add(ValueObject.new(4, "number"))

			list:Add("a", 1)
			list:Add("b", sortB:Observe())
			list:Add("c", 3)
			list:Add("d", sortD:Observe())
			list:Add("e", 5)

			expect(list:GetList()).toEqual({ "a", "b", "c", "d", "e" })

			sortB.Value = 4
			sortD.Value = 2

			list:_testForceFireEvents()

			expect(list:Get(2)).toEqual("d")
			expect(list:Get(4)).toEqual("b")
			expect(list:GetList()).toEqual({ "a", "d", "c", "b", "e" })

			maid:Destroy()
		end)

		it("should handle removing first, middle, and last items", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			local removeE = list:Add("e", 5)

			removeE()
			expect(list:GetList()).toEqual({ "a", "b", "c", "d" })

			removeA()
			expect(list:GetList()).toEqual({ "b", "c", "d" })

			removeC()
			expect(list:GetList()).toEqual({ "b", "d" })

			maid:Destroy()
		end)
	end)

	describe("excess event emission", function()
		it("should not fire ObserveAtIndex for distant indices on narrow resort", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortB = maid:Add(ValueObject.new(2, "number"))
			list:Add("a", 1)
			list:Add("b", sortB:Observe())
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires5, sub5 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(5))

			expect(#fires1).toEqual(1)
			expect(#fires5).toEqual(1)

			sortB.Value = 4.5
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "c", "d", "b", "e" })
			expect(#fires1).toEqual(1)
			expect(#fires5).toEqual(1)

			sub1:Destroy()
			sub5:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveIndexByKey for nodes outside changed span on resort", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortB = maid:Add(ValueObject.new(2, "number"))
			list:Add("a", 1)
			list:Add("b", sortB:Observe())
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local nodeA = list:FindFirstKey("a")
			local nodeE = list:FindFirstKey("e")
			assert(nodeA and nodeE, "Expected nodes")

			local firesA, subA = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeA))
			local firesE, subE = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeE))

			expect(#firesA).toEqual(1)
			expect(#firesE).toEqual(1)

			sortB.Value = 4.5
			list:_testForceFireEvents()

			expect(#firesA).toEqual(1)
			expect(#firesE).toEqual(1)

			subA:Destroy()
			subE:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex for earlier indices when removing from end", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			local removeE = list:Add("e", 5)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))

			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)
			expect(#fires3).toEqual(1)
			expect(#fires4).toEqual(1)

			removeE()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c", "d" })
			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)
			expect(#fires3).toEqual(1)
			expect(#fires4).toEqual(1)

			sub1:Destroy()
			sub2:Destroy()
			sub3:Destroy()
			sub4:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex for existing indices when adding at end", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))

			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)
			expect(#fires3).toEqual(1)

			list:Add("d", 4)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c", "d" })
			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)
			expect(#fires3).toEqual(1)

			sub1:Destroy()
			sub2:Destroy()
			sub3:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex for index before removed middle element", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))

			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)

			removeC()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "d", "e" })
			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)

			sub1:Destroy()
			sub2:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex for indices shifted by middle removal", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))
			expect(#fires4).toEqual(1)
			expect(fires4[1]).toEqual("d")

			removeC()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "d", "e" })
			expect(#fires4).toEqual(2)
			expect(fires4[2]).toEqual("e")

			sub4:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveIndexByKey for nodes shifted by middle removal", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local nodeD = list:FindFirstKey("d")
			local nodeE = list:FindFirstKey("e")
			assert(nodeD and nodeE, "Expected nodes")

			local firesD, subD = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeD))
			local firesE, subE = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeE))

			expect(firesD[1]).toEqual(4)
			expect(firesE[1]).toEqual(5)

			removeC()
			list:_testForceFireEvents()

			expect(#firesD).toEqual(2)
			expect(firesD[2]).toEqual(3)
			expect(#firesE).toEqual(2)
			expect(firesE[2]).toEqual(4)

			subD:Destroy()
			subE:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex for distant indices when replacing at same position", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))
			local fires5, sub5 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(5))

			expect(#fires3).toEqual(1)
			expect(#fires4).toEqual(1)
			expect(#fires5).toEqual(1)

			removeB()
			list:Add("f", 2)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "f", "c", "d", "e" })

			expect(#fires3).toEqual(1)
			expect(#fires4).toEqual(1)
			expect(#fires5).toEqual(1)

			sub3:Destroy()
			sub4:Destroy()
			sub5:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveIndexByKey for unaffected nodes when replacing at same position", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local nodeC = list:FindFirstKey("c")
			local nodeD = list:FindFirstKey("d")
			local nodeE = list:FindFirstKey("e")
			assert(nodeC and nodeD and nodeE, "Expected nodes")

			local firesC, subC = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeC))
			local firesD, subD = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeD))
			local firesE, subE = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeE))

			expect(#firesC).toEqual(1)
			expect(#firesD).toEqual(1)
			expect(#firesE).toEqual(1)

			removeB()
			list:Add("f", 2)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "f", "c", "d", "e" })
			expect(#firesC).toEqual(1)
			expect(#firesD).toEqual(1)
			expect(#firesE).toEqual(1)

			subC:Destroy()
			subD:Destroy()
			subE:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex for shifted indices when removing and adding at different positions", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			expect(#fires3).toEqual(1)
			expect(fires3[1]).toEqual("c")

			removeB()
			list:Add("f", 4.5)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "c", "d", "f", "e" })

			expect(#fires3).toEqual(2)
			expect(fires3[2]).toEqual("d")

			sub3:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveIndexByKey for shifted nodes when removing and adding at different positions", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local nodeC = list:FindFirstKey("c")
			local nodeD = list:FindFirstKey("d")
			assert(nodeC and nodeD, "Expected nodes")

			local firesC, subC = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeC))
			local firesD, subD = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeD))

			expect(firesC[1]).toEqual(3)
			expect(firesD[1]).toEqual(4)

			removeB()
			list:Add("f", 4.5)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "c", "d", "f", "e" })

			expect(#firesC).toEqual(2)
			expect(firesC[2]).toEqual(2)
			expect(#firesD).toEqual(2)
			expect(firesD[2]).toEqual(3)

			subC:Destroy()
			subD:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex correctly when removing two and adding two at different positions", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			local removeD = list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			expect(fires3[1]).toEqual("c")

			removeB()
			removeD()
			list:Add("f", 1.5)
			list:Add("g", 4.5)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "f", "c", "g", "e" })

			expect(#fires3).toEqual(1)

			sub3:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex for ALL shifted indices when removing from beginning", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))

			expect(fires1[1]).toEqual("a")
			expect(fires2[1]).toEqual("b")
			expect(fires3[1]).toEqual("c")

			removeA()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "b", "c", "d" })
			expect(#fires1).toEqual(2)
			expect(fires1[2]).toEqual("b")
			expect(#fires2).toEqual(2)
			expect(fires2[2]).toEqual("c")
			expect(#fires3).toEqual(2)
			expect(fires3[2]).toEqual("d")

			sub1:Destroy()
			sub2:Destroy()
			sub3:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex when two adjacent items are removed", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))

			expect(fires2[1]).toEqual("b")
			expect(fires3[1]).toEqual("c")
			expect(fires4[1]).toEqual("d")

			removeB()
			removeC()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "d", "e" })
			expect(#fires2).toEqual(2)
			expect(fires2[2]).toEqual("d")
			expect(#fires3).toEqual(2)
			expect(fires3[2]).toEqual("e")
			expect(#fires4).toEqual(2)
			expect(fires4[2]).toEqual(NIL_VALUE)

			sub2:Destroy()
			sub3:Destroy()
			sub4:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex when adding at beginning shifts everything", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))

			expect(fires1[1]).toEqual("b")
			expect(fires2[1]).toEqual("c")
			expect(fires3[1]).toEqual("d")

			list:Add("a", 1)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c", "d" })
			expect(#fires1).toEqual(2)
			expect(fires1[2]).toEqual("a")
			expect(#fires2).toEqual(2)
			expect(fires2[2]).toEqual("b")
			expect(#fires3).toEqual(2)
			expect(fires3[2]).toEqual("c")

			sub1:Destroy()
			sub2:Destroy()
			sub3:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveIndexByKey for all nodes when resort crosses entire list", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortA = maid:Add(ValueObject.new(1, "number"))
			list:Add("a", sortA:Observe())
			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:_testForceFireEvents()

			local nodeB = list:FindFirstKey("b")
			local nodeC = list:FindFirstKey("c")
			local nodeD = list:FindFirstKey("d")
			assert(nodeB and nodeC and nodeD, "Expected nodes")

			local firesB, subB = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeB))
			local firesC, subC = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeC))
			local firesD, subD = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeD))

			expect(firesB[1]).toEqual(2)
			expect(firesC[1]).toEqual(3)
			expect(firesD[1]).toEqual(4)

			sortA.Value = 10
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "b", "c", "d", "a" })
			expect(#firesB).toEqual(2)
			expect(firesB[2]).toEqual(1)
			expect(#firesC).toEqual(2)
			expect(firesC[2]).toEqual(2)
			expect(#firesD).toEqual(2)
			expect(firesD[2]).toEqual(3)

			subB:Destroy()
			subC:Destroy()
			subD:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex when remove+add cancel out at the same index", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			local removeB = list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))

			expect(fires1[1]).toEqual("a")
			expect(fires3[1]).toEqual("c")
			expect(fires4[1]).toEqual("d")

			removeB()
			list:Add("f", 2)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "f", "c", "d" })
			expect(#fires1).toEqual(1)
			expect(#fires3).toEqual(1)
			expect(#fires4).toEqual(1)

			sub1:Destroy()
			sub3:Destroy()
			sub4:Destroy()
			maid:Destroy()
		end)

		it("should not fire ObserveAtIndex for index 1 when only last two items swap", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortD = maid:Add(ValueObject.new(4, "number"))
			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", sortD:Observe())
			list:Add("e", 5)
			list:_testForceFireEvents()

			local fires1, sub1 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(1))
			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))

			expect(fires1[1]).toEqual("a")
			expect(fires2[1]).toEqual("b")
			expect(fires3[1]).toEqual("c")

			sortD.Value = 6
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c", "e", "d" })
			expect(#fires1).toEqual(1)
			expect(#fires2).toEqual(1)
			expect(#fires3).toEqual(1)

			sub1:Destroy()
			sub2:Destroy()
			sub3:Destroy()
			maid:Destroy()
		end)

		it(
			"should not fire ObserveIndexByKey for nodes outside range when two adjacent items are removed and two added nearby",
			function()
				local maid = Maid.new()
				local list = maid:Add(ObservableSortedList.new())

				list:Add("a", 1)
				local removeB = list:Add("b", 2)
				local removeC = list:Add("c", 3)
				list:Add("d", 4)
				list:Add("e", 5)
				list:_testForceFireEvents()

				local nodeA = list:FindFirstKey("a")
				local nodeE = list:FindFirstKey("e")
				assert(nodeA and nodeE, "Expected nodes")

				local firesA, subA = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeA))
				local firesE, subE = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeE))

				expect(firesA[1]).toEqual(1)
				expect(firesE[1]).toEqual(5)

				removeB()
				removeC()
				list:Add("f", 2)
				list:Add("g", 3)
				list:_testForceFireEvents()

				expect(list:GetList()).toEqual({ "a", "f", "g", "d", "e" })
				expect(#firesA).toEqual(1)
				expect(#firesE).toEqual(1)

				subA:Destroy()
				subE:Destroy()
				maid:Destroy()
			end
		)

		it(
			"should not fire ObserveAtIndex when item at observed index is unchanged despite surrounding mutations",
			function()
				local maid = Maid.new()
				local list = maid:Add(ObservableSortedList.new())

				local removeA = list:Add("a", 1)
				list:Add("b", 2)
				list:Add("c", 3)
				list:Add("d", 4)
				local removeE = list:Add("e", 5)
				list:_testForceFireEvents()

				local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
				local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
				local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))

				expect(fires2[1]).toEqual("b")
				expect(fires3[1]).toEqual("c")
				expect(fires4[1]).toEqual("d")

				removeA()
				removeE()
				list:Add("f", 0.5)
				list:Add("g", 5.5)
				list:_testForceFireEvents()

				expect(list:GetList()).toEqual({ "f", "b", "c", "d", "g" })
				expect(#fires2).toEqual(1)
				expect(#fires3).toEqual(1)
				expect(#fires4).toEqual(1)

				sub2:Destroy()
				sub3:Destroy()
				sub4:Destroy()
				maid:Destroy()
			end
		)

		it("should not fire ObserveAtIndex when two swaps on opposite ends leave middle unchanged", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local sortA = maid:Add(ValueObject.new(1, "number"))
			local sortE = maid:Add(ValueObject.new(5, "number"))
			list:Add("a", sortA:Observe())
			list:Add("b", 2)
			list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", sortE:Observe())
			list:_testForceFireEvents()

			local fires2, sub2 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(2))
			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))

			expect(fires2[1]).toEqual("b")
			expect(fires3[1]).toEqual("c")
			expect(fires4[1]).toEqual("d")

			sortA.Value = 2.5
			sortE.Value = 3.5
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "b", "a", "c", "e", "d" })
			expect(#fires3).toEqual(1)

			sub2:Destroy()
			sub3:Destroy()
			sub4:Destroy()
			maid:Destroy()
		end)

		it(
			"should not fire ObserveIndexByKey for a node that remains at the same index after balanced add+remove on each side",
			function()
				local maid = Maid.new()
				local list = maid:Add(ObservableSortedList.new())

				local removeA = list:Add("a", 1)
				list:Add("b", 2)
				list:Add("c", 3)
				list:Add("d", 4)
				local removeE = list:Add("e", 5)
				list:_testForceFireEvents()

				local nodeC = list:FindFirstKey("c")
				assert(nodeC, "Expected node for c")

				local firesC, subC = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeC))
				expect(firesC[1]).toEqual(3)

				removeA()
				removeE()
				list:Add("f", 0.5)
				list:Add("g", 5.5)
				list:_testForceFireEvents()

				expect(list:GetList()).toEqual({ "f", "b", "c", "d", "g" })
				expect(#firesC).toEqual(1)

				subC:Destroy()
				maid:Destroy()
			end
		)
	end)

	describe("coordinate system correctness", function()
		it("should fire ObserveAtIndex for tail index when two removes collapse recorded indices", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			local removeD = list:Add("d", 4)
			local removeE = list:Add("e", 5)
			list:_testForceFireEvents()

			local fires5, sub5 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(5))
			expect(fires5[1]).toEqual("e")

			removeD()
			removeE()
			list:Add("f", 1.5)
			list:Add("g", 2.5)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "f", "b", "g", "c" })

			expect(#fires5).toEqual(2)
			expect(fires5[2]).toEqual("c")

			sub5:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveIndexByKey for node shifted beyond recorded span", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			local removeD = list:Add("d", 4)
			local removeE = list:Add("e", 5)
			list:Add("f", 6)
			list:_testForceFireEvents()

			local nodeF = list:FindFirstKey("f")
			assert(nodeF, "Expected node for f")

			local firesF, subF = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeF))
			expect(firesF[1]).toEqual(6)

			removeD()
			removeE()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "c", "f" })

			expect(#firesF).toEqual(2)
			expect(firesF[2]).toEqual(4)

			subF:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex for all affected indices when three consecutive items are removed", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			local removeC = list:Add("c", 3)
			local removeD = list:Add("d", 4)
			local removeE = list:Add("e", 5)
			list:Add("f", 6)
			list:Add("g", 7)
			list:_testForceFireEvents()

			local fires4, sub4 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(4))
			local fires5, sub5 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(5))

			expect(fires4[1]).toEqual("d")
			expect(fires5[1]).toEqual("e")

			removeC()
			removeD()
			removeE()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "a", "b", "f", "g" })

			expect(#fires4).toEqual(2)
			expect(fires4[2]).toEqual("g")

			expect(#fires5).toEqual(2)
			expect(fires5[2]).toEqual(NIL_VALUE)

			sub4:Destroy()
			sub5:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveAtIndex when adding at beginning shifts tail beyond recorded add index", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			list:Add("a", 1)
			list:Add("b", 2)
			list:Add("c", 3)
			list:_testForceFireEvents()

			local fires3, sub3 = ObservableSortedListTestUtils.collectValues(list:ObserveAtIndex(3))
			expect(fires3[1]).toEqual("c")

			list:Add("x", 0.1)
			list:Add("y", 0.2)
			list:Add("z", 0.3)
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "x", "y", "z", "a", "b", "c" })

			expect(#fires3).toEqual(2)
			expect(fires3[2]).toEqual("z")

			sub3:Destroy()
			maid:Destroy()
		end)

		it("should fire ObserveIndexByKey when multiple removes from same position shift a distant node", function()
			local maid = Maid.new()
			local list = maid:Add(ObservableSortedList.new())

			local removeA = list:Add("a", 1)
			local removeB = list:Add("b", 2)
			local removeC = list:Add("c", 3)
			list:Add("d", 4)
			list:Add("e", 5)
			list:_testForceFireEvents()

			local nodeE = list:FindFirstKey("e")
			assert(nodeE, "Expected node for e")

			local firesE, subE = ObservableSortedListTestUtils.collectValues(list:ObserveIndexByKey(nodeE))
			expect(firesE[1]).toEqual(5)

			removeA()
			removeB()
			removeC()
			list:_testForceFireEvents()

			expect(list:GetList()).toEqual({ "d", "e" })

			expect(#firesE).toEqual(2)
			expect(firesE[2]).toEqual(2)

			subE:Destroy()
			maid:Destroy()
		end)
	end)
end)
