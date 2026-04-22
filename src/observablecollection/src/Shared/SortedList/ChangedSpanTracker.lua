--!strict
--[=[
	Tracks changed index spans and merges overlapping or adjacent spans together.
	Used by [ObservableSortedList] to efficiently determine which index observers
	need to be notified after mutations.

	@class ChangedSpanTracker
]=]

local require = require(script.Parent.loader).load(script)

local BinarySearchUtils = require("BinarySearchUtils")

local ChangedSpanTracker = {}
ChangedSpanTracker.ClassName = "ChangedSpanTracker"
ChangedSpanTracker.__index = ChangedSpanTracker

--[=[
	A span representing a contiguous range of changed indices.

	@interface ChangedSpan
	@within ChangedSpanTracker
	.startIndex number
	.endIndex number
]=]
export type ChangedSpan = {
	startIndex: number,
	endIndex: number,
}

export type ChangedSpanTracker = typeof(setmetatable(
	{} :: {
		_sortedSpans: { ChangedSpan },
	},
	{} :: typeof({ __index = ChangedSpanTracker })
))

--[=[
	Constructs a new ChangedSpanTracker with no spans.

	@return ChangedSpanTracker
]=]
function ChangedSpanTracker.new(): ChangedSpanTracker
	local self: ChangedSpanTracker = setmetatable({} :: any, ChangedSpanTracker)

	self._sortedSpans = {}

	return self
end

--[=[
	Clears all tracked spans.
]=]
function ChangedSpanTracker.Clear(self: ChangedSpanTracker)
	self._sortedSpans = {}
end

--[=[
	Returns the current list of merged spans.

	@return { ChangedSpan }
]=]
function ChangedSpanTracker.GetSpans(self: ChangedSpanTracker): { ChangedSpan }
	return self._sortedSpans
end

--[=[
	Adds multiple spans at once, merging as needed.

	@param spans { ChangedSpan }
]=]
function ChangedSpanTracker.AddSpans(self: ChangedSpanTracker, spans: { ChangedSpan })
	for _, span in spans do
		self:AddSpan(span.startIndex, span.endIndex)
	end
end

--[=[
	Adds a span from startIndex to endIndex, merging with any existing
	spans that touch or overlap. Handles reversed indices.

	@param startIndex number
	@param endIndex number
]=]
function ChangedSpanTracker.AddSpan(self: ChangedSpanTracker, startIndex: number, endIndex: number)
	-- TODO: Maybe try to avoid allocating so much here for performance
	if startIndex > endIndex then
		endIndex, startIndex = startIndex, endIndex
	end

	-- Find first span that could touch with our startIndex
	local lowIndex = BinarySearchUtils.spanSearchNodes(self._sortedSpans, "startIndex", startIndex - 1)
	-- Find last span that could touch with our endIndex
	local highIndex = BinarySearchUtils.spanSearchNodes(self._sortedSpans, "startIndex", endIndex + 1)
	local span = ChangedSpanTracker.span(startIndex, endIndex)

	assert(lowIndex == nil or highIndex == nil or lowIndex <= highIndex, "Inconsistent indices found")

	if lowIndex and lowIndex == highIndex then
		-- Equal nodes
		local node = self._sortedSpans[lowIndex]
		if ChangedSpanTracker.spansTouches(node, span) then
			self._sortedSpans[lowIndex] =
				ChangedSpanTracker.span(math.min(node.startIndex, startIndex), math.max(node.endIndex, endIndex))
		elseif startIndex > node.endIndex then
			table.insert(self._sortedSpans, lowIndex + 1, span)
		else
			table.insert(self._sortedSpans, lowIndex, span)
		end
	elseif lowIndex and highIndex then
		-- Multiple spans in range - need to check which ones actually touch
		-- Find the actual first and last touching spans
		local firstOverlap = nil
		local lastOverlap = nil

		for i = lowIndex, highIndex do
			if ChangedSpanTracker.spansTouches(self._sortedSpans[i], span) then
				if not firstOverlap then
					firstOverlap = i
				end
				lastOverlap = i
			end
		end

		if firstOverlap and lastOverlap then
			-- Merge all touching spans
			local firstSpan = self._sortedSpans[firstOverlap]
			local lastSpan = self._sortedSpans[lastOverlap]

			local mergedSpan: ChangedSpan = {
				startIndex = math.min(firstSpan.startIndex, startIndex),
				endIndex = math.max(lastSpan.endIndex, endIndex),
			}

			-- Check if merged span touches spans after lastOverlap
			local finalOverlap = lastOverlap
			for i = lastOverlap + 1, #self._sortedSpans do
				if ChangedSpanTracker.spansTouches(self._sortedSpans[i], mergedSpan) then
					finalOverlap = i
					mergedSpan.endIndex = math.max(mergedSpan.endIndex, self._sortedSpans[i].endIndex)
				else
					break
				end
			end

			self._sortedSpans[firstOverlap] = table.freeze(mergedSpan)

			-- Remove all other touching spans
			local numToRemove = finalOverlap - firstOverlap
			if numToRemove > 0 then
				table.move(self._sortedSpans, finalOverlap + 1, #self._sortedSpans, firstOverlap + 1)
				for i = #self._sortedSpans - numToRemove + 1, #self._sortedSpans do
					self._sortedSpans[i] = nil
				end
			end
		elseif lowIndex < highIndex then
			-- No overlaps, insert somewhere in the middle
			-- Find correct insertion position
			for i = lowIndex, highIndex do
				if startIndex < self._sortedSpans[i].startIndex then
					table.insert(self._sortedSpans, i, span)
					return
				end
			end
			table.insert(self._sortedSpans, highIndex + 1, span)
		else
			-- Single span, no overlap - shouldn't happen but handle it
			table.insert(self._sortedSpans, lowIndex + 1, span)
		end
	elseif lowIndex then
		local lowSpan = self._sortedSpans[lowIndex]
		if ChangedSpanTracker.spansTouches(lowSpan, span) then
			self._sortedSpans[lowIndex] =
				ChangedSpanTracker.span(math.min(lowSpan.startIndex, startIndex), math.max(lowSpan.endIndex, endIndex))
		else
			table.insert(self._sortedSpans, lowIndex + 1, span)
		end
	elseif highIndex then
		local highSpan = self._sortedSpans[highIndex]
		if ChangedSpanTracker.spansTouches(highSpan, span) then
			local mergedSpan: ChangedSpan = {
				startIndex = math.min(highSpan.startIndex, startIndex),
				endIndex = math.max(highSpan.endIndex, endIndex),
			}

			-- Check if merged span also touches spans before highIndex
			local firstOverlap = highIndex
			for i = highIndex - 1, 1, -1 do
				if ChangedSpanTracker.spansTouches(self._sortedSpans[i], mergedSpan) then
					firstOverlap = i
					mergedSpan.startIndex = math.min(mergedSpan.startIndex, self._sortedSpans[i].startIndex)
					mergedSpan.endIndex = math.max(mergedSpan.endIndex, self._sortedSpans[i].endIndex)
				else
					break
				end
			end

			self._sortedSpans[firstOverlap] = table.freeze(mergedSpan)

			-- Remove absorbed spans
			local numToRemove = highIndex - firstOverlap
			if numToRemove > 0 then
				table.move(self._sortedSpans, highIndex + 1, #self._sortedSpans, firstOverlap + 1)
				for i = #self._sortedSpans - numToRemove + 1, #self._sortedSpans do
					self._sortedSpans[i] = nil
				end
			end
		else
			table.insert(self._sortedSpans, highIndex, span)
		end
	else
		if #self._sortedSpans == 0 then
			table.insert(self._sortedSpans, span)
			return
		end

		local firstNode = self._sortedSpans[1]
		if endIndex < firstNode.startIndex then
			table.insert(self._sortedSpans, 1, span)
		else
			table.insert(self._sortedSpans, span)
		end
	end
end

--[=[
	Returns the current spans and clears the tracker.

	@return { ChangedSpan }
]=]
function ChangedSpanTracker.GetAndClearSpans(self: ChangedSpanTracker): { ChangedSpan }
	local copy = self._sortedSpans
	self._sortedSpans = {}
	return copy
end

--[=[
	Creates a frozen ChangedSpan from the given indices.

	@param startIndex number
	@param endIndex number
	@return ChangedSpan
]=]
function ChangedSpanTracker.span(startIndex: number, endIndex: number): ChangedSpan
	return table.freeze({
		startIndex = startIndex,
		endIndex = endIndex,
	})
end

--[=[
	Returns true if the given index falls within any of the spans.

	@param span { ChangedSpan }
	@param index number
	@return boolean
]=]
function ChangedSpanTracker.isIndexInSpan(span: { ChangedSpan }, index: number): boolean
	-- Binary search
	local low, high = BinarySearchUtils.spanSearchNodes(span, "startIndex", index)

	if low then
		local candidateSpan = span[low]
		if candidateSpan.startIndex <= index and candidateSpan.endIndex >= index then
			return true
		end
	end

	if high then
		local candidateSpan = span[high]
		if candidateSpan.startIndex <= index and candidateSpan.endIndex >= index then
			return true
		end
	end

	return false
end

--[=[
	Returns true if the two spans overlap (share at least one index).

	@param spanA ChangedSpan
	@param spanB ChangedSpan
	@return boolean
]=]
function ChangedSpanTracker.spanOverlaps(spanA: ChangedSpan, spanB: ChangedSpan): boolean
	return spanA.startIndex <= spanB.endIndex and spanA.endIndex >= spanB.startIndex
end

--[=[
	Returns true if the two spans touch or overlap (adjacent spans count).

	@param spanA ChangedSpan
	@param spanB ChangedSpan
	@return boolean
]=]
function ChangedSpanTracker.spansTouches(spanA: ChangedSpan, spanB: ChangedSpan): boolean
	return spanA.startIndex - 1 <= spanB.endIndex and spanA.endIndex + 1 >= spanB.startIndex
end

return ChangedSpanTracker
