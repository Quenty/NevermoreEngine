--!strict
--[=[
	Unified add, remove, and move span tracker that computes effective changed spans after a series of mutations.

	@class UnifiedChangedSpanTracker
]=]

local require = require(script.Parent.loader).load(script)

local BinarySearchUtils = require("BinarySearchUtils")

local UnifiedChangedSpanTracker = {}
UnifiedChangedSpanTracker.ClassName = "UnifiedChangedSpanTracker"
UnifiedChangedSpanTracker.__index = UnifiedChangedSpanTracker

export type ChangedSpanType = "add" | "remove" | "move"
export type ChangedSpan = {
	startIndex: number,
	endIndex: number,
	type: ChangedSpanType,
}

export type UnifiedChangedSpanTracker = typeof(setmetatable(
	{} :: {
		_sortedSpans: { ChangedSpan },
	},
	{} :: typeof({ __index = UnifiedChangedSpanTracker })
))

--[=[
	Constructs a new UnifiedChangedSpanTracker.

	@return UnifiedChangedSpanTracker
]=]
function UnifiedChangedSpanTracker.new(): UnifiedChangedSpanTracker
	local self: UnifiedChangedSpanTracker = setmetatable({} :: any, UnifiedChangedSpanTracker)

	self._sortedSpans = {}

	return self
end

--[=[
	Logs a removal at the given index.

	@param index number
]=]
function UnifiedChangedSpanTracker.LogRemove(self: UnifiedChangedSpanTracker, index: number)
	table.insert(self._sortedSpans, {
		startIndex = index,
		endIndex = index,
		type = "remove" :: ChangedSpanType,
	})
end

--[=[
	Logs an addition at the given index.

	@param index number
]=]
function UnifiedChangedSpanTracker.LogAdd(self: UnifiedChangedSpanTracker, index: number)
	table.insert(self._sortedSpans, {
		startIndex = index,
		endIndex = index,
		type = "add" :: ChangedSpanType,
	})
end

--[=[
	Logs a move from oldIndex to newIndex (an existing node changing position).

	@param oldIndex number
	@param newIndex number
]=]
function UnifiedChangedSpanTracker.LogMove(self: UnifiedChangedSpanTracker, oldIndex: number, newIndex: number)
	table.insert(self._sortedSpans, {
		startIndex = oldIndex,
		endIndex = newIndex,
		type = "move" :: ChangedSpanType,
	})
end

--[=[
	Computes the effective changed spans and clears internal state.

	@param previousCount number -- List count before mutations
	@param currentCount number -- List count after mutations
	@return { ChangedSpanTracker.ChangedSpan }
]=]
function UnifiedChangedSpanTracker.ComputeEffectiveSpans(
	self: UnifiedChangedSpanTracker,
	previousCount: number,
	currentCount: number
): { ChangedSpan }
	local ops = self._sortedSpans
	self._sortedSpans = {}

	if #ops == 0 then
		return {}
	end

	-- Simulate operations on a virtual list to determine exactly which indices changed.
	-- Each item starts as its original index (1..previousCount). New items are marked as 0.
	local items = table.create(previousCount)
	for i = 1, previousCount do
		items[i] = i
	end

	-- Track which positions are dirty. Start with positions affected by move ranges,
	-- since moves indicate the caller knows something changed in that range.
	local maxIndex = math.max(previousCount, currentCount)
	local dirty = table.create(maxIndex, false)

	for _, op in ops do
		if op.type == "remove" then
			table.remove(items, op.startIndex)
		elseif op.type == "add" then
			table.insert(items, op.startIndex, 0)
		elseif op.type == "move" then
			local lo = math.min(op.startIndex, op.endIndex)
			local hi = math.max(op.startIndex, op.endIndex)
			for i = lo, hi do
				dirty[i] = true
			end
			local item: any = table.remove(items, op.startIndex)
			table.insert(items, op.endIndex, item)
		end
	end

	-- Also mark any position where the item differs from the original
	local finalCount = #items
	for i = 1, maxIndex do
		if not dirty[i] then
			dirty[i] = i > finalCount or items[i] ~= i
		end
	end

	-- Convert dirty positions to spans
	local result: { ChangedSpan } = {}
	local spanStart: number? = nil

	for i = 1, maxIndex do
		if dirty[i] then
			if not spanStart then
				spanStart = i
			end
		else
			if spanStart then
				table.insert(
					result,
					table.freeze({
						startIndex = spanStart,
						endIndex = i - 1,
						type = "move" :: ChangedSpanType,
					})
				)
				spanStart = nil
			end
		end
	end

	if spanStart then
		table.insert(
			result,
			table.freeze({
				startIndex = spanStart,
				endIndex = maxIndex,
				type = "move" :: ChangedSpanType,
			})
		)
	end

	return result
end

function UnifiedChangedSpanTracker.isIndexInSpan(sortedSpans: { ChangedSpan }, index: number): boolean
	-- Binary search
	local low, high = BinarySearchUtils.spanSearchNodes(sortedSpans, "startIndex", index)

	if low then
		local candidateSpan = sortedSpans[low]
		if candidateSpan.startIndex <= index and candidateSpan.endIndex >= index then
			return true
		end
	end

	if high then
		local candidateSpan = sortedSpans[high]
		if candidateSpan.startIndex <= index and candidateSpan.endIndex >= index then
			return true
		end
	end

	return false
end

function UnifiedChangedSpanTracker.spanOverlaps(spanA: ChangedSpan, spanB: ChangedSpan): boolean
	return spanA.startIndex <= spanB.endIndex and spanA.endIndex >= spanB.startIndex
end

function UnifiedChangedSpanTracker.spansTouches(spanA: ChangedSpan, spanB: ChangedSpan): boolean
	return spanA.startIndex - 1 <= spanB.endIndex and spanA.endIndex + 1 >= spanB.startIndex
end

return UnifiedChangedSpanTracker
