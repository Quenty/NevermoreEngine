--!strict
--[[
    @class ChangedSpanTracker.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local ChangedSpanTracker = require("ChangedSpanTracker")

local function encodeSpans(spans: { ChangedSpanTracker.ChangedSpan }): string
	local encodedSpans = {}
	for _, span in spans do
		table.insert(encodedSpans, `{span.startIndex}-{span.endIndex}`)
	end
	return `[{table.concat(encodedSpans, ", ")}]`
end

local function areEqualSpans(
	actual: { ChangedSpanTracker.ChangedSpan },
	expected: { ChangedSpanTracker.ChangedSpan },
	message: string?
): (boolean, string?)
	local encodedActual = encodeSpans(actual)
	local encodedExpected = encodeSpans(expected)
	local areEqual = encodedActual == encodedExpected
	if areEqual then
		return true
	else
		return false, `{message or "Spans not equal:"}\
Expected: {encodedExpected}\
Received: {encodedActual}`
	end
end

local function it(_name: string, fn: () -> ())
	fn()
end

local span = ChangedSpanTracker.span

return function(_target: Instance)
	it("should handle 2 spans of size 1 next to each other", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(1, 1)
		changedSpanTracker:AddSpan(2, 2)

		-- Adjacent single points should merge
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(1, 2),
		}, "Should merge adjacent single point spans"))
	end)

	it("Should added overlapping spans correctly", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(1, 5)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(1, 5) }))

		changedSpanTracker:AddSpan(1, 5)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(1, 5) }))

		changedSpanTracker:AddSpan(3, 8)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(1, 8) }))
	end)

	it("Should compute overlaps properly", function()
		assert(ChangedSpanTracker.spanOverlaps(span(1, 5), span(3, 8)), "Expected overlap")
		assert(ChangedSpanTracker.spanOverlaps(span(3, 8), span(1, 5)), "Expected overlap")
		assert(not ChangedSpanTracker.spanOverlaps(span(1, 2), span(3, 4)), "Expected no overlap")
		assert(not ChangedSpanTracker.spanOverlaps(span(3, 4), span(1, 2)), "Expected no overlap")

		assert(ChangedSpanTracker.spanOverlaps(span(3, 4), span(3, 5)), "Expected no overlap")

		-- Edge cases
		assert(ChangedSpanTracker.spanOverlaps(span(1, 5), span(5, 10)), "Expected overlap at edge")
		assert(ChangedSpanTracker.spanOverlaps(span(5, 10), span(1, 5)), "Expected overlap at edge")

		-- Negative indices
		assert(ChangedSpanTracker.spanOverlaps(span(-10, -5), span(-7, -3)), "Expected overlap with negatives")
		assert(not ChangedSpanTracker.spanOverlaps(span(-10, -8), span(-7, -5)), "Expected no overlap with negatives")
	end)

	it("Should compute touching properly", function()
		assert(ChangedSpanTracker.spansTouches(span(1, 5), span(5, 10)), "Expected touching at edge")
		assert(ChangedSpanTracker.spansTouches(span(5, 10), span(1, 5)), "Expected touching at edge")
		assert(not ChangedSpanTracker.spansTouches(span(1, 4), span(6, 10)), "Expected no touching")
		assert(not ChangedSpanTracker.spansTouches(span(6, 10), span(1, 4)), "Expected no touching")

		-- Negative indices
		assert(ChangedSpanTracker.spansTouches(span(-10, -5), span(-5, 0)), "Expected touching with negatives")
		assert(not ChangedSpanTracker.spansTouches(span(-10, -7), span(-5, -1)), "Expected no touching with negatives")
	end)

	it("Should merge spans properly", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(1, 2)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(1, 2) }))

		changedSpanTracker:AddSpan(5, 10)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(1, 2), span(5, 10) }))
	end)

	it("Case: lowIndex == highIndex with overlap", function()
		-- Adding a span that overlaps with a single existing span
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 20)
		changedSpanTracker:AddSpan(15, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 25) }, "Should extend existing span"))

		-- Extend left
		changedSpanTracker:AddSpan(5, 12)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(5, 25) }, "Should extend left"))

		-- Span completely inside
		changedSpanTracker:AddSpan(10, 15)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(5, 25) }, "Should not change when inside"))
	end)

	it("Case: lowIndex == highIndex without overlap", function()
		-- Adding a span that doesn't overlap but falls within the same index range
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(20, 25)

		-- Add between them (no overlap)
		changedSpanTracker:AddSpan(17, 18)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(17, 18),
			span(20, 25),
		}, "Should insert new span between existing ones"))
	end)

	it("Case: lowIndex and highIndex both present, overlap both", function()
		-- Span overlaps multiple existing spans and merges them
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(20, 25)
		changedSpanTracker:AddSpan(30, 35)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
			span(30, 35),
		}, "Initial spans should be correct"))

		-- Merge first and second
		changedSpanTracker:AddSpan(12, 22)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 25),
			span(30, 35),
		}, "Should merge overlapping spans"))

		-- Merge all remaining
		changedSpanTracker:AddSpan(24, 32)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 35) }, "Should merge all spans"))
	end)

	it("Case: lowIndex and highIndex both present, overlap only low", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(30, 35)

		-- Overlaps low but not high
		changedSpanTracker:AddSpan(12, 20)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 20),
			span(30, 35),
		}, "Should extend low span only"))
	end)

	it("Case: lowIndex and highIndex both present, overlap only high", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(30, 35)

		-- Overlaps high but not low
		changedSpanTracker:AddSpan(25, 32)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(25, 35),
		}, "Should extend high span only"))
	end)

	it("Case: lowIndex and highIndex both present, no overlap", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(30, 35)

		-- Insert in middle with no overlap
		changedSpanTracker:AddSpan(20, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
			span(30, 35),
		}, "Should insert in middle"))
	end)

	it("Case: only lowIndex with overlap", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)

		-- Overlap and extend to the right
		changedSpanTracker:AddSpan(13, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 25) }, "Should extend low span right"))
	end)

	it("Case: only lowIndex without overlap", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)

		-- No overlap, add after
		changedSpanTracker:AddSpan(20, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
		}, "Should add new span after existing"))
	end)

	it("Case: only highIndex with overlap", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(20, 25)

		-- Overlap and extend to the left
		changedSpanTracker:AddSpan(10, 22)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 25) }, "Should extend high span left"))
	end)

	it("Case: only highIndex without overlap", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(20, 25)

		-- No overlap, add before
		changedSpanTracker:AddSpan(10, 15)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
		}, "Should insert before existing span"))
	end)

	it("Case: neither lowIndex nor highIndex (empty list)", function()
		local changedSpanTracker = ChangedSpanTracker.new()

		-- First span added to empty list
		changedSpanTracker:AddSpan(10, 15)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 15) }, "Should add first span"))

		-- Add another at the end
		changedSpanTracker:AddSpan(20, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
		}, "Should add at end"))
	end)

	it("Case: adjacent spans (touching at edges)", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)

		-- Add span that touches at edge (inclusive overlap)
		changedSpanTracker:AddSpan(15, 20)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 20) }, "Should merge adjacent spans"))

		-- Add another touching span
		changedSpanTracker:AddSpan(20, 25)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 25) }, "Should merge all adjacent spans"))
	end)

	it("Case: complex merge scenario with multiple spans", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:AddSpan(20, 25)

		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
		}, "Initial spans should be correct"))

		changedSpanTracker:AddSpan(30, 35)
		changedSpanTracker:AddSpan(40, 45)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(20, 25),
			span(30, 35),
			span(40, 45),
		}, "Initial spans should be correct"))

		-- Merge middle two spans
		changedSpanTracker:AddSpan(18, 32)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(10, 15),
			span(18, 35),
			span(40, 45),
		}, "Should merge middle spans"))

		-- Merge everything
		changedSpanTracker:AddSpan(15, 40)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 45) }, "Should merge all spans"))
	end)

	it("Case: single point spans", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 10)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 10) }, "Should handle single point"))

		changedSpanTracker:AddSpan(10, 10)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(10, 10) }, "Should handle duplicate single point"))

		changedSpanTracker:AddSpan(9, 11)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), { span(9, 11) }, "Should expand from single point"))

		-- Test adjacent single points (should merge)
		changedSpanTracker:AddSpan(11, 11)
		assert(
			areEqualSpans(changedSpanTracker:GetSpans(), { span(9, 11) }, "Should merge adjacent single point at edge")
		)
	end)

	it("Case: negative indices", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(-10, -6)
		changedSpanTracker:AddSpan(-3, 2)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(-10, -6),
			span(-3, 2),
		}, "Should handle negative indices"))

		changedSpanTracker:AddSpan(-4, -2)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(-10, -6),
			span(-4, 2),
		}, "Should extend with negative indices"))
	end)

	it("should handle multiple adjacent multi-point spans", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(1, 3)
		changedSpanTracker:AddSpan(3, 5)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(1, 5),
		}, "Should merge adjacent multi-point spans"))

		-- Add another adjacent span
		changedSpanTracker:AddSpan(5, 8)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(1, 8),
		}, "Should merge all adjacent multi-point spans"))

		-- Add non-adjacent span
		changedSpanTracker:AddSpan(10, 12)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(1, 8),
			span(10, 12),
		}, "Should not merge non-adjacent spans"))

		-- Bridge the gap
		changedSpanTracker:AddSpan(8, 10)
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {
			span(1, 12),
		}, "Should merge spans when bridging gap"))
	end)

	it("Should clear spans", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(1, 5)
		changedSpanTracker:AddSpan(10, 15)
		changedSpanTracker:Clear()
		assert(areEqualSpans(changedSpanTracker:GetSpans(), {}, "Should clear all spans"))
	end)

	it("Should check if index is in span", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(10, 20)
		changedSpanTracker:AddSpan(30, 40)
		changedSpanTracker:AddSpan(50, 60)

		local spans = changedSpanTracker:GetSpans()

		-- Test indices within spans
		assert(ChangedSpanTracker.isIndexInSpan(spans, 10), "Should find index at start of span")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 15), "Should find index in middle of span")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 20), "Should find index at end of span")

		assert(ChangedSpanTracker.isIndexInSpan(spans, 30), "Should find index in second span")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 35), "Should find index in middle of second span")

		assert(ChangedSpanTracker.isIndexInSpan(spans, 50), "Should find index in third span")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 60), "Should find index at end of third span")

		-- Test indices outside spans
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 5), "Should not find index before first span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 9), "Should not find index just before first span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 21), "Should not find index just after first span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 25), "Should not find index between spans")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 45), "Should not find index between second and third span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 61), "Should not find index after last span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 100), "Should not find index far after last span")
	end)

	it("Should check if index is in span with single point spans", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(5, 5)
		changedSpanTracker:AddSpan(10, 10)

		local spans = changedSpanTracker:GetSpans()

		-- Test single point spans
		assert(ChangedSpanTracker.isIndexInSpan(spans, 5), "Should find index in single point span")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 10), "Should find index in second single point span")

		-- Test adjacent indices
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 4), "Should not find index before single point")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 6), "Should not find index after single point")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 9), "Should not find index before second single point")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 11), "Should not find index after second single point")
	end)

	it("Should check if index is in span with negative indices", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		changedSpanTracker:AddSpan(-20, -10)
		changedSpanTracker:AddSpan(-5, 5)
		changedSpanTracker:AddSpan(10, 20)

		local spans = changedSpanTracker:GetSpans()

		-- Test negative indices
		assert(ChangedSpanTracker.isIndexInSpan(spans, -20), "Should find negative index at start")
		assert(ChangedSpanTracker.isIndexInSpan(spans, -15), "Should find negative index in middle")
		assert(ChangedSpanTracker.isIndexInSpan(spans, -10), "Should find negative index at end")

		-- Test span crossing zero
		assert(ChangedSpanTracker.isIndexInSpan(spans, -5), "Should find negative index in span crossing zero")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 0), "Should find zero in span crossing zero")
		assert(ChangedSpanTracker.isIndexInSpan(spans, 5), "Should find positive index in span crossing zero")

		-- Test outside spans
		assert(not ChangedSpanTracker.isIndexInSpan(spans, -25), "Should not find index before negative span")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, -8), "Should not find index in gap")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 7), "Should not find index in gap after zero")
	end)

	it("Should check if index is in empty span list", function()
		local changedSpanTracker = ChangedSpanTracker.new()
		local spans = changedSpanTracker:GetSpans()

		-- Test empty span list
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 0), "Should not find index in empty list")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, 10), "Should not find any index in empty list")
		assert(not ChangedSpanTracker.isIndexInSpan(spans, -10), "Should not find negative index in empty list")
	end)

	print("Done running tests")

	return function() end
end
