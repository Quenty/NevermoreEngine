--!strict
--[[
	@class UnifiedChangedSpanTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local UnifiedChangedSpanTracker = require("UnifiedChangedSpanTracker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("UnifiedChangedSpanTracker", function()
	describe("new", function()
		it("should start with no effective spans", function()
			local tracker = UnifiedChangedSpanTracker.new()
			local result = tracker:ComputeEffectiveSpans(0, 0)
			expect(#result).toEqual(0)
		end)
	end)

	describe("LogAdd", function()
		it("should cover from added index to end when adding one item", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogAdd(2)

			local result = tracker:ComputeEffectiveSpans(3, 4)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
		end)

		it("should only cover the added index when adding at end", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogAdd(4)

			local result = tracker:ComputeEffectiveSpans(3, 4)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
		end)

		it("should cover entire shifted range when adding three at beginning", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogAdd(1)
			tracker:LogAdd(2)
			tracker:LogAdd(3)

			local result = tracker:ComputeEffectiveSpans(3, 6)

			for i = 1, 6 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)
	end)

	describe("LogRemove", function()
		it("should cover from removed index to old end when removing one item", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)

			local result = tracker:ComputeEffectiveSpans(4, 3)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
		end)

		it("should only cover the removed index when removing from end", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(4)

			local result = tracker:ComputeEffectiveSpans(4, 3)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
		end)

		it("should cover all indices when removing from beginning", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)

			local result = tracker:ComputeEffectiveSpans(4, 3)

			for i = 1, 4 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)

		it("should extend to old count when removing two adjacent items", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)
			tracker:LogRemove(2)

			local result = tracker:ComputeEffectiveSpans(5, 3)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			for i = 2, 5 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)

		it("should cover full range when three consecutive removes from same position", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(3)
			tracker:LogRemove(3)
			tracker:LogRemove(3)

			local result = tracker:ComputeEffectiveSpans(7, 4)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			for i = 4, 7 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)

		it("should cover full range when multiple removes from index 1", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)
			tracker:LogRemove(1)
			tracker:LogRemove(1)

			local result = tracker:ComputeEffectiveSpans(5, 2)

			for i = 1, 5 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)

		it("should cover full tail when two removes from end decrease count", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(5)
			tracker:LogRemove(4)

			local result = tracker:ComputeEffectiveSpans(5, 3)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
		end)
	end)

	describe("LogMove", function()
		it("should cover only the move range for a narrow resort", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(2, 4)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(false)
		end)

		it("should cover entire list for a resort from start to end", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(1, 5)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			for i = 1, 5 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)

		it("should handle a no-op move", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(3, 3)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(false)
		end)
	end)

	describe("combined add and remove", function()
		it("should cover only the replaced index when removing and adding at same position", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)
			tracker:LogAdd(2)

			local result = tracker:ComputeEffectiveSpans(4, 4)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(false)
		end)

		it("should cover the range between remove and add positions", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)
			tracker:LogAdd(4)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(false)
		end)

		it("should cover range when removing two and adding two at different positions", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)
			tracker:LogRemove(3)
			tracker:LogAdd(2)
			tracker:LogAdd(4)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(false)
		end)

		it("should cover full range between distant remove and add when count is unchanged", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)
			tracker:LogAdd(10)

			local result = tracker:ComputeEffectiveSpans(10, 10)

			for i = 1, 10 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)
	end)

	describe("combined move and add", function()
		it("should extend to new count when a move and add happen together", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(2, 4)
			tracker:LogAdd(3)

			local result = tracker:ComputeEffectiveSpans(5, 6)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			for i = 3, 6 do
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, i)).toEqual(true)
			end
		end)
	end)

	describe("edge cases", function()
		it("should handle add to empty list", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogAdd(1)

			local result = tracker:ComputeEffectiveSpans(0, 1)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(true)
		end)

		it("should handle remove last item from list", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)

			local result = tracker:ComputeEffectiveSpans(1, 0)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(true)
		end)

		it("should return no spans when nothing happened", function()
			local tracker = UnifiedChangedSpanTracker.new()
			local result = tracker:ComputeEffectiveSpans(5, 5)
			expect(#result).toEqual(0)
		end)

		it("should clear state after ComputeEffectiveSpans", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogAdd(2)

			local result1 = tracker:ComputeEffectiveSpans(3, 4)
			expect(#result1 > 0).toEqual(true)

			local result2 = tracker:ComputeEffectiveSpans(4, 4)
			expect(#result2).toEqual(0)
		end)
	end)

	describe("coordinate system edge cases", function()
		it(
			"should cover index 5 when two end-removes collapse to same recorded index and count is unchanged",
			function()
				local tracker = UnifiedChangedSpanTracker.new()
				tracker:LogRemove(4)
				tracker:LogRemove(4)
				tracker:LogAdd(2)
				tracker:LogAdd(4)

				local result = tracker:ComputeEffectiveSpans(5, 5)

				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
				expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
			end
		)

		it("should only cover edges when removing first and last and replacing at edges", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)
			tracker:LogRemove(4)
			tracker:LogAdd(1)
			tracker:LogAdd(5)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(false)
		end)

		it("should produce two separate spans for non-overlapping moves when count is unchanged", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(2, 3)
			tracker:LogMove(8, 9)

			local result = tracker:ComputeEffectiveSpans(10, 10)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 7)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 8)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 9)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 10)).toEqual(false)
		end)

		it("should not dirty index 3 when removing two and adding two leaves c at index 3", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(2)
			tracker:LogRemove(3)
			tracker:LogAdd(2)
			tracker:LogAdd(4)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(false)
		end)

		it("should not dirty middle indices when removing first and last and adding at edges", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(1)
			tracker:LogRemove(4)
			tracker:LogAdd(1)
			tracker:LogAdd(5)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
		end)

		it("should not dirty index 3 when two opposite-end moves leave middle unchanged", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogMove(1, 2)
			tracker:LogMove(5, 4)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
		end)

		it("should dirty index 5 when two removes from end collapse and adds shift content", function()
			local tracker = UnifiedChangedSpanTracker.new()
			tracker:LogRemove(4)
			tracker:LogRemove(4)
			tracker:LogAdd(2)
			tracker:LogAdd(3)

			local result = tracker:ComputeEffectiveSpans(5, 5)

			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 1)).toEqual(false)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 2)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 3)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 4)).toEqual(true)
			expect(UnifiedChangedSpanTracker.isIndexInSpan(result, 5)).toEqual(true)
		end)
	end)
end)
