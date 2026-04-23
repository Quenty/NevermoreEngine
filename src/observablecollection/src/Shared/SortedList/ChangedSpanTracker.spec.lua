--!strict
--[[
	@class ChangedSpanTracker.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local ChangedSpanTracker = require("ChangedSpanTracker")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ChangedSpanTracker", function()
	describe("new", function()
		it("should start with no spans", function()
			local tracker = ChangedSpanTracker.new()
			expect(#tracker:GetSpans()).toEqual(0)
		end)
	end)

	describe("span", function()
		it("should create a frozen span with startIndex and endIndex", function()
			local s = ChangedSpanTracker.span(2, 5)
			expect(s.startIndex).toEqual(2)
			expect(s.endIndex).toEqual(5)
		end)
	end)

	describe("AddSpan", function()
		it("should add a single span", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(3, 5)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(3)
			expect(spans[1].endIndex).toEqual(5)
		end)

		it("should swap reversed indices", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(10, 3)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(3)
			expect(spans[1].endIndex).toEqual(10)
		end)

		it("should handle a point span", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(5, 5)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(5)
			expect(spans[1].endIndex).toEqual(5)
		end)

		it("should keep non-overlapping spans separate", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 3)
			tracker:AddSpan(7, 9)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(2)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(3)
			expect(spans[2].startIndex).toEqual(7)
			expect(spans[2].endIndex).toEqual(9)
		end)

		it("should merge overlapping spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 5)
			tracker:AddSpan(3, 8)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(8)
		end)

		it("should merge adjacent spans (touching)", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 3)
			tracker:AddSpan(4, 6)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(6)
		end)

		it("should merge a span that bridges two existing spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 3)
			tracker:AddSpan(7, 9)
			tracker:AddSpan(3, 7)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(9)
		end)

		it("should merge a span that covers all existing spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(3, 5)
			tracker:AddSpan(8, 10)
			tracker:AddSpan(13, 15)
			tracker:AddSpan(1, 20)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(20)
		end)

		it("should insert in sorted order when adding before existing spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(10, 12)
			tracker:AddSpan(1, 3)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(2)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[2].startIndex).toEqual(10)
		end)

		it("should insert between existing non-overlapping spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 3)
			tracker:AddSpan(10, 12)
			tracker:AddSpan(6, 7)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(3)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[2].startIndex).toEqual(6)
			expect(spans[3].startIndex).toEqual(10)
		end)

		it("should extend an existing span when new span is a subset", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 10)
			tracker:AddSpan(3, 7)

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(1)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[1].endIndex).toEqual(10)
		end)
	end)

	describe("AddSpans", function()
		it("should add multiple spans at once", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpans({
				ChangedSpanTracker.span(1, 3),
				ChangedSpanTracker.span(7, 9),
			})

			local spans = tracker:GetSpans()
			expect(#spans).toEqual(2)
		end)
	end)

	describe("Clear", function()
		it("should remove all spans", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 5)
			tracker:AddSpan(10, 15)

			expect(#tracker:GetSpans()).toEqual(2)

			tracker:Clear()

			expect(#tracker:GetSpans()).toEqual(0)
		end)
	end)

	describe("GetAndClearSpans", function()
		it("should return spans and clear them", function()
			local tracker = ChangedSpanTracker.new()
			tracker:AddSpan(1, 3)
			tracker:AddSpan(7, 9)

			local spans = tracker:GetAndClearSpans()
			expect(#spans).toEqual(2)
			expect(spans[1].startIndex).toEqual(1)
			expect(spans[2].startIndex).toEqual(7)

			expect(#tracker:GetSpans()).toEqual(0)
		end)
	end)

	describe("isIndexInSpan", function()
		it("should return true for an index inside a span", function()
			local spans = { ChangedSpanTracker.span(3, 7) }

			expect(ChangedSpanTracker.isIndexInSpan(spans, 3)).toEqual(true)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 5)).toEqual(true)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 7)).toEqual(true)
		end)

		it("should return false for an index outside all spans", function()
			local spans = { ChangedSpanTracker.span(3, 7) }

			expect(ChangedSpanTracker.isIndexInSpan(spans, 1)).toEqual(false)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 2)).toEqual(false)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 8)).toEqual(false)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 100)).toEqual(false)
		end)

		it("should handle multiple spans", function()
			local spans = {
				ChangedSpanTracker.span(1, 3),
				ChangedSpanTracker.span(7, 9),
				ChangedSpanTracker.span(15, 20),
			}

			expect(ChangedSpanTracker.isIndexInSpan(spans, 2)).toEqual(true)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 5)).toEqual(false)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 8)).toEqual(true)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 12)).toEqual(false)
			expect(ChangedSpanTracker.isIndexInSpan(spans, 17)).toEqual(true)
		end)

		it("should return false for empty span list", function()
			expect(ChangedSpanTracker.isIndexInSpan({}, 5)).toEqual(false)
		end)
	end)

	describe("spanOverlaps", function()
		it("should return true for overlapping spans", function()
			local a = ChangedSpanTracker.span(1, 5)
			local b = ChangedSpanTracker.span(3, 8)
			expect(ChangedSpanTracker.spanOverlaps(a, b)).toEqual(true)
		end)

		it("should return true for spans sharing a single point", function()
			local a = ChangedSpanTracker.span(1, 5)
			local b = ChangedSpanTracker.span(5, 8)
			expect(ChangedSpanTracker.spanOverlaps(a, b)).toEqual(true)
		end)

		it("should return false for non-overlapping spans", function()
			local a = ChangedSpanTracker.span(1, 3)
			local b = ChangedSpanTracker.span(5, 8)
			expect(ChangedSpanTracker.spanOverlaps(a, b)).toEqual(false)
		end)

		it("should return false for adjacent but non-overlapping spans", function()
			local a = ChangedSpanTracker.span(1, 3)
			local b = ChangedSpanTracker.span(4, 6)
			expect(ChangedSpanTracker.spanOverlaps(a, b)).toEqual(false)
		end)

		it("should return true when one span contains the other", function()
			local a = ChangedSpanTracker.span(1, 10)
			local b = ChangedSpanTracker.span(3, 7)
			expect(ChangedSpanTracker.spanOverlaps(a, b)).toEqual(true)
			expect(ChangedSpanTracker.spanOverlaps(b, a)).toEqual(true)
		end)
	end)

	describe("spansTouches", function()
		it("should return true for overlapping spans", function()
			local a = ChangedSpanTracker.span(1, 5)
			local b = ChangedSpanTracker.span(3, 8)
			expect(ChangedSpanTracker.spansTouches(a, b)).toEqual(true)
		end)

		it("should return true for adjacent spans", function()
			local a = ChangedSpanTracker.span(1, 3)
			local b = ChangedSpanTracker.span(4, 6)
			expect(ChangedSpanTracker.spansTouches(a, b)).toEqual(true)
		end)

		it("should return false for spans with a gap", function()
			local a = ChangedSpanTracker.span(1, 3)
			local b = ChangedSpanTracker.span(5, 8)
			expect(ChangedSpanTracker.spansTouches(a, b)).toEqual(false)
		end)

		it("should be symmetric", function()
			local a = ChangedSpanTracker.span(1, 3)
			local b = ChangedSpanTracker.span(4, 6)
			expect(ChangedSpanTracker.spansTouches(a, b)).toEqual(ChangedSpanTracker.spansTouches(b, a))

			local c = ChangedSpanTracker.span(1, 3)
			local d = ChangedSpanTracker.span(6, 8)
			expect(ChangedSpanTracker.spansTouches(c, d)).toEqual(ChangedSpanTracker.spansTouches(d, c))
		end)
	end)

	describe("computeEffectiveSpans", function()
		it("should return changedSpans unchanged when no adds or removes", function()
			local changed = { ChangedSpanTracker.span(3, 5) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, {}, {}, 10, 10)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(3)
			expect(result[1].endIndex).toEqual(5)
		end)

		it("should bound shift range to add/remove points when count stays the same", function()
			-- Remove at 3, add at 3. Count unchanged. Shift span = [3, 3]
			local changed = { ChangedSpanTracker.span(3, 3) }
			local added = { ChangedSpanTracker.span(3, 3) }
			local removed = { ChangedSpanTracker.span(3, 3) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, added, removed, 10, 10)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(3)
			expect(result[1].endIndex).toEqual(3)
		end)

		it("should extend shift range between different add/remove positions when count unchanged", function()
			-- Remove at 2, add at 5. Count unchanged. Shift span = [2, 5]
			local changed = { ChangedSpanTracker.span(2, 2), ChangedSpanTracker.span(5, 5) }
			local added = { ChangedSpanTracker.span(5, 5) }
			local removed = { ChangedSpanTracker.span(2, 2) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, added, removed, 10, 10)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(2)
			expect(result[1].endIndex).toEqual(5)
		end)

		it("should extend shift range to max count when count increases", function()
			-- Add at 3, count 10 -> 11. Shift span = [3, 11]
			local changed = { ChangedSpanTracker.span(3, 3) }
			local added = { ChangedSpanTracker.span(3, 3) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, added, {}, 10, 11)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(3)
			expect(result[1].endIndex).toEqual(11)
		end)

		it("should extend shift range to previous count when count decreases", function()
			-- Remove at 5, count 10 -> 9. Shift span = [5, 10]
			local changed = { ChangedSpanTracker.span(5, 5) }
			local removed = { ChangedSpanTracker.span(5, 5) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, {}, removed, 10, 9)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(5)
			expect(result[1].endIndex).toEqual(10)
		end)

		it("should merge move spans with shift spans", function()
			-- Move from 2 to 6, plus add at 8, count 10 -> 11
			local changed = { ChangedSpanTracker.span(2, 6) }
			local added = { ChangedSpanTracker.span(6, 6), ChangedSpanTracker.span(8, 8) }
			local removed = { ChangedSpanTracker.span(2, 2) }
			local result = ChangedSpanTracker.computeEffectiveSpans(changed, added, removed, 10, 11)
			-- Shift range: min(2,6,8,2)=2, count changed → max(10,11)=11
			-- Merged: [{2, 11}]
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(2)
			expect(result[1].endIndex).toEqual(11)
		end)

		it("should handle empty changed spans with adds/removes", function()
			-- Can happen if changedSpanTracker was cleared separately
			local added = { ChangedSpanTracker.span(5, 5) }
			local result = ChangedSpanTracker.computeEffectiveSpans({}, added, {}, 10, 11)
			expect(#result).toEqual(1)
			expect(result[1].startIndex).toEqual(5)
			expect(result[1].endIndex).toEqual(11)
		end)
	end)
end)
