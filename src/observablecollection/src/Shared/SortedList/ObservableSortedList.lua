--strict
--[=[
	A list that can be observed for blend and other components and maintains sorting order.

	This allows you to observe both an index, observe a value at an index, and more.

	This class is a red-black binary sorted tree. Unlike previous iterations of this class, we can add
	values in log(n) time, and remove in log(n) time, and it uses less memory.

	Previously we'd use O(n^2) processing time when constructing this class.

	We reuse the node itself as the indexing key.

	This class always prefers to add equivalent elements to the end of the list if they're not in the list.
	Otherwise it prefers minimal movement.

	@class ObservableSortedList
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local DuckTypeUtils = require("DuckTypeUtils")
local ListIndexUtils = require("ListIndexUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Rx = require("Rx")
local Signal = require("Signal")
local SortedNode = require("SortedNode")
local SortedNodeValue = require("SortedNodeValue")
local SortFunctionUtils = require("SortFunctionUtils")
local ValueObject = require("ValueObject")

local ObservableSortedList = {}
ObservableSortedList.ClassName = "ObservableSortedList"
ObservableSortedList.__index = ObservableSortedList

export type CompareFunction<T> = (T, T) -> number

export type ObservableSortedList<T> = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_root: SortedNode.SortedNode<T>?,
		_nodesAdded: { [SortedNode.SortedNode<T>]: boolean },
		_nodesRemoved: { [SortedNode.SortedNode<T>]: boolean },
		_lowestIndexChanged: number?,
		_compare: CompareFunction<T>,
		_countValue: ValueObject.ValueObject<number>,
		_indexObservers: any,
		_nodeIndexObservables: any,
		_mainObservables: any,
		ItemAdded: Signal.Signal<T, number, SortedNode.SortedNode<T>>,
		ItemRemoved: Signal.Signal<T, SortedNode.SortedNode<T>>,
		OrderChanged: Signal.Signal<()>,
		CountChanged: Signal.Signal<number>,
	},
	{} :: typeof({ __index = ObservableSortedList })
))

--[=[
	Constructs a new ObservableSortedList
	@param isReversed boolean
	@param compare function
	@return ObservableSortedList<T>
]=]
function ObservableSortedList.new<T>(isReversed: boolean?, compare: CompareFunction<T>): ObservableSortedList<T>
	assert(type(isReversed) == "boolean" or isReversed == nil, "Bad isReversed")

	local self = setmetatable({} :: any, ObservableSortedList)

	self._maid = Maid.new()

	self._indexObservers = self._maid:Add(ObservableSubscriptionTable.new())
	self._nodeIndexObservables = self._maid:Add(ObservableSubscriptionTable.new())

	self._mainObservables = self._maid:Add(ObservableSubscriptionTable.new())

	self._nodesAdded = {}
	self._nodesRemoved = {}
	self._lowestIndexChanged = nil

	self._compare = if isReversed then SortFunctionUtils.reverse(compare) else compare

	self._countValue = self._maid:Add(ValueObject.new(0, "number"))

	--[=[
	Fires when an item is added

	@readonly
	@prop ItemAdded Signal<T, number, Symbol>
	@within ObservableSortedList
]=]
	self.ItemAdded = self._maid:Add(Signal.new())

	--[=[
	Fires when an item is removed.

	@readonly
	@prop ItemRemoved Signal<T, Symbol>
	@within ObservableSortedList
]=]
	self.ItemRemoved = self._maid:Add(Signal.new())

	--[=[
	Fires when the order could have changed

	@readonly
	@prop OrderChanged Signal
	@within ObservableSortedList
]=]
	self.OrderChanged = self._maid:Add(Signal.new())

	--[=[
	Fires when the count changes

	@readonly
	@prop CountChanged Signal<number>
	@within ObservableSortedList
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Returns whether the value is an observable list
	@param value any
	@return boolean
]=]
function ObservableSortedList.isObservableSortedList(value: any): boolean
	return DuckTypeUtils.isImplementation(ObservableSortedList, value)
end

--[=[
	Observes the list, allocating a new list in the process.

	@return Observable<{ T }>
]=]
function ObservableSortedList.Observe<T>(self: ObservableSortedList<T>): Observable.Observable<{ T }>
	return self._mainObservables:Observe("list"):Pipe({
		Rx.start(function()
			return self:GetList()
		end),
	})
end

--[=[
	Allows iteration over the observable map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableSortedList.__iter<T>(self: ObservableSortedList<T>): SortFunctionUtils.WrappedIterator<number, T>
	if self._root then
		return self._root:IterateData()
	else
		return SortFunctionUtils.emptyIterator
	end
end

--[=[
	Iterates over an index range

	@param start number
	@param finish number
	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableSortedList.IterateRange<T>(
	self: ObservableSortedList<T>,
	start: number,
	finish: number
): SortFunctionUtils.WrappedIterator<number, T>
	return coroutine.wrap(function()
		for index: number, node in self:_iterateNodesRange(start, finish) do
			coroutine.yield(index, node.data)
		end
	end) :: any
end

function ObservableSortedList._iterateNodes<T>(
	self: ObservableSortedList<T>
): SortFunctionUtils.WrappedIterator<number, SortedNode.SortedNode<T>>
	if self._root then
		return self._root:IterateNodes()
	else
		return SortFunctionUtils.emptyIterator
	end
end

function ObservableSortedList._iterateNodesRange<T>(
	self: ObservableSortedList<T>,
	start: number,
	finish: number?
): SortFunctionUtils.WrappedIterator<number, SortedNode.SortedNode<T>>
	if self._root then
		return self._root:IterateNodesRange(start, finish)
	else
		return SortFunctionUtils.emptyIterator
	end
end

function ObservableSortedList._containsNode<T>(self: ObservableSortedList<T>, node: SortedNode.SortedNode<T>): boolean
	assert(SortedNode.isSortedNode(node), "Bad node")

	if self._root then
		return self._root:ContainsNode(node)
	else
		return false
	end
end

function ObservableSortedList._findNodeForDataLinearSearchSlow<T>(
	self: ObservableSortedList<T>,
	data: T
): SortedNode.SortedNode<T>?
	if self._root then
		return self._root:FindFirstNodeForData(data)
	else
		return nil
	end
end

function ObservableSortedList._findNodeAtIndex<T>(self: ObservableSortedList<T>, index: number): SortedNode.SortedNode<T>?
	assert(type(index) == "number", "Bad index")

	if self._root then
		return self._root:FindNodeAtIndex(index)
	else
		return nil
	end
end

function ObservableSortedList._findNodeIndex<T>(self: ObservableSortedList<T>, node: SortedNode.SortedNode<T>): number?
	assert(SortedNode.isSortedNode(node), "Bad node")

	if self._root then
		return self._root:FindNodeIndex(node)
	else
		return nil
	end
end

--[=[
	Gets the first node for a given symbol

	@param content T
	@return Symbol
]=]
function ObservableSortedList.FindFirstKey<T>(self: ObservableSortedList<T>, content: T): SortedNode.SortedNode<T>?
	return self:_findNodeForDataLinearSearchSlow(content)
end

function ObservableSortedList.PrintDebug<T>(self: ObservableSortedList<T>)
	print(self._root)
end

--[=[
	Returns true if the value exists

	@param content T
	@return boolean
]=]
function ObservableSortedList.Contains<T>(self: ObservableSortedList<T>, content): boolean
	assert(content ~= nil, "Bad content")

	-- TODO: Speed up
	return self:_findNodeForDataLinearSearchSlow(content) ~= nil
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T, Symbol>>
]=]
function ObservableSortedList.ObserveItemsBrio<T>(
	self: ObservableSortedList<T>
): Observable.Observable<Brio.Brio<T, SortedNode.SortedNode<T>>>
	return Observable.new(function(sub)
		local maid = Maid.new()

		-- TODO: Optimize this so we don't have to make so many brios and connect
		-- to so many events

		local function handleItem(data: T, _index, node)
			local brio = Brio.new(data, node)
			maid[node] = brio
			sub:Fire(brio)
		end

		-- NOTE: This can modify the list...?
		for index, node in self:_iterateNodes() do
			handleItem(node.data, index, node)
		end

		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(_item, node)
			maid[node] = nil
		end))

		-- TODO: Prevent this stuff from happening too
		self._maid[sub] = maid
		maid:GiveTask(function()
			self._maid[sub] = nil
			sub:Complete()
		end)

		return maid
	end) :: any
end

--[=[
	Observes the index as it changes, until the entry at the existing
	index is removed.

	@param indexToObserve number
	@return Observable<number>
]=]
function ObservableSortedList.ObserveIndex<T>(
	self: ObservableSortedList<T>,
	indexToObserve: number
): Observable.Observable<number>
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	local node = self:_findNodeAtIndex(indexToObserve)
	if not node then
		error(
			string.format(
				"[ObservableSortedList.ObserveIndex] - No entry at index %d, cannot observe changes",
				indexToObserve
			)
		)
	end

	return self:ObserveIndexByKey(node)
end

--[=[
	Observes the current value at a given index. This can be useful for observing
	the first entry, or matching stuff up to a given slot.

	@param indexToObserve number
	@return Observable<(T, Key)>
]=]
function ObservableSortedList.ObserveAtIndex<T>(
	self: ObservableSortedList<T>,
	indexToObserve: number
): Observable.Observable<T, SortedNode.SortedNode<T>>
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	return self._indexObservers:Observe(indexToObserve, function(sub)
		local node = self:_findNodeAtIndex(indexToObserve)
		if node then
			sub:Fire(node.data, node)
		else
			sub:Fire(nil, nil)
		end
	end) :: any
end

--[=[
	Observes the index as it changes, until the entry at the existing
	node is removed.

	@param node SortedNode
	@return Observable<number>
]=]
function ObservableSortedList.ObserveIndexByKey<T>(
	self: ObservableSortedList<T>,
	node: SortedNode.SortedNode<T>
): Observable.Observable<number>
	assert(SortedNode.isSortedNode(node), "Bad node")

	return self._nodeIndexObservables:Observe(node, function(sub)
		local currentIndex = self:_findNodeIndex(node)
		if currentIndex then
			sub:Fire(currentIndex)
		end
	end) :: any
end

--[=[
	Gets the current index from the node

	@param node SortedNode
	@return number
]=]
function ObservableSortedList.GetIndexByKey<T>(self: ObservableSortedList<T>, node: SortedNode.SortedNode<T>): number?
	assert(SortedNode.isSortedNode(node), "Bad node")

	return self:_findNodeIndex(node)
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function ObservableSortedList.GetCount<T>(self: ObservableSortedList<T>): number
	return self._countValue.Value or 0
end

ObservableSortedList.__len = ObservableSortedList.GetCount

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableSortedList.GetList<T>(self: ObservableSortedList<T>): { T }
	local list = table.create(self._countValue.Value)
	for index, data in self:__iter() do
		list[index] = data
	end
	return table.freeze(list)
end

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function ObservableSortedList.ObserveCount<T>(self: ObservableSortedList<T>): Observable.Observable<number>
	return self._countValue:Observe()
end

--[=[
	Adds the item to the list at the specified index
	@param data T
	@param observeValue Observable<Comparable> | Comparable
	@return callback -- Call to remove
]=]
function ObservableSortedList.Add<T>(
	self: ObservableSortedList<T>,
	data: T,
	observeValue: Observable.Observable<number> | number
): () -> ()
	assert(data ~= nil, "Bad data")
	assert(Observable.isObservable(observeValue) or observeValue ~= nil, "Bad observeValue")

	local node = SortedNode.new(data)

	-- TODO: Store maid in node to prevent lookup of node -> index
	local maid = Maid.new()

	if Observable.isObservable(observeValue) then
		maid:GiveTask((observeValue :: any):Subscribe(function(sortValue: number)
			self:_assignSortValue(node, sortValue)
		end))
	elseif observeValue ~= nil then
		self:_assignSortValue(node, observeValue :: number)
	else
		error("Bad observeValue")
	end

	maid:GiveTask(function()
		-- TODO: Avoid cleaning up all these nodes when global maid cleans up
		self:_assignSortValue(node, nil)
		self._nodeIndexObservables:Complete(node)
	end)

	self._maid[node] = maid

	return function()
		self._maid[node] = nil
	end
end

function ObservableSortedList._assignSortValue<T>(
	self: ObservableSortedList<T>,
	node: SortedNode.SortedNode<T>,
	value: number?
): ()
	if SortedNodeValue.isSortedNodeValue(node.value) then
		if (node.value :: any):GetValue() == value then
			return
		end
	elseif node.value == value then
		return
	end

	if value == nil then
		if self._root and self._root:ContainsNode(node) then
			if self._nodesAdded[node] then
				self._nodesAdded[node] = nil
			else
				self._nodesRemoved[node] = true
			end

			self:_applyLowestIndexChanged(node:GetIndex())
			self:_removeNode(node)
			node.value = nil
			self:_queueFireEvents()
		else
			node.value = nil
		end

		return
	end

	if self._compare ~= nil then
		value = SortedNodeValue.new(value, self._compare) :: any
	end

	-- our value changing didn't change anything
	if not node:NeedsToMove(self._root, value) then
		node.value = value
		return
	end

	self._nodesRemoved[node] = nil

	if self._root and self._root:ContainsNode(node) then
		self:_applyLowestIndexChanged(node:GetIndex())
		self:_removeNode(node)
	else
		self._nodesAdded[node] = true
	end

	node.value = value

	self:_insertNode(node)
	self:_applyLowestIndexChanged(node:GetIndex())
	self:_queueFireEvents()
end

function ObservableSortedList._applyLowestIndexChanged<T>(self: ObservableSortedList<T>, index: number)
	if self._lowestIndexChanged == nil then
		self._lowestIndexChanged = index
		return
	end

	if index < self._lowestIndexChanged then
		self._lowestIndexChanged = index
	end
end

function ObservableSortedList._queueFireEvents<T>(self: ObservableSortedList<T>)
	if self._maid._fireEvents then
		return
	end

	self._maid._fireEvents = task.defer(function()
		self._maid._fireEvents = nil
		self:_fireEvents()
	end)
end

function ObservableSortedList._fireEvents<T>(self: ObservableSortedList<T>)
	-- print(self._root)

	local lowestIndexChanged = self._lowestIndexChanged
	self._lowestIndexChanged = nil

	local nodesAdded = self._nodesAdded
	self._nodesAdded = {}

	local nodesRemoved = self._nodesRemoved
	self._nodesRemoved = {}

	local lastCount = self._countValue.Value
	local newCount = if self._root then self._root.descendantCount else 0

	-- Fire count changed first
	self._countValue.Value = newCount

	if not self.Destroy then
		return
	end

	-- TODO: Prevent Rx.of(itemAdded) stuff in our UI
	for node in nodesAdded do
		-- TODO: Prevent query slow here...?
		local index = node:GetIndex()
		self.ItemAdded:Fire(node.data, index, node)
	end

	if not self.Destroy then
		return
	end

	for node in nodesRemoved do
		self.ItemRemoved:Fire(node.data, node)
	end

	if not self.Destroy then
		return
	end

	self.OrderChanged:Fire()

	if not self.Destroy then
		return
	end

	do
		local descendantCount = self._root and self._root.descendantCount or 0
		for index, node in self:_iterateNodesRange(lowestIndexChanged) do
			-- TODO: Handle negative observations to avoid refiring upon insertion
			-- TODO: Handle our state changing while we're firing
			-- TODO: Avoid looping over nodes if we don't need to (track observations in node itself?)
			local negative = ListIndexUtils.toNegativeIndex(descendantCount, index)
			self._nodeIndexObservables:Fire(node, index)
			self._indexObservers:Fire(index, node.data, node)
			self._indexObservers:Fire(negative, node.data, node)
		end

		for index = newCount + 1, lastCount do
			self._indexObservers:Fire(index, nil, nil)
		end

		-- TODO: Fire negatives beyond range
	end

	if not self.Destroy then
		return
	end

	if self._mainObservables:HasSubscriptions("list") then
		-- TODO: Reuse list
		local list = self:GetList()
		self._mainObservables:Fire("list", list)
	end
end

function ObservableSortedList._insertNode<T>(self: ObservableSortedList<T>, node: SortedNode.SortedNode<T>)
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")

	if self._root == nil then
		node:MarkBlack()
		self._root = node
	else
		self._root = self._root:InsertNode(node)
	end
end

function ObservableSortedList._removeNode<T>(self: ObservableSortedList<T>, nodeToRemove: SortedNode.SortedNode<T>)
	assert(SortedNode.isSortedNode(nodeToRemove), "Bad SortedNode")

	if self._root ~= nil then
		self._root = self._root:RemoveNode(nodeToRemove)
	end
end

--[=[
	Gets the current item at the index, or nil if it is not defined.
	@param index number
	@return T?
]=]
function ObservableSortedList.Get<T>(self: ObservableSortedList<T>, index: number): T?
	assert(type(index) == "number", "Bad index")

	local node = self:_findNodeAtIndex(index)
	if not node then
		return nil
	end

	return node.data
end

--[=[
	Removes the item from the list if it exists.
	@param node SortedNode
	@return T
]=]
function ObservableSortedList.RemoveByKey<T>(self: ObservableSortedList<T>, node: SortedNode.SortedNode<T>)
	assert(SortedNode.isSortedNode(node), "Bad node")

	self._maid[node] = nil
end

--[=[
	Cleans up the ObservableSortedList and sets the metatable to nil.
]=]
function ObservableSortedList.Destroy<T>(self: ObservableSortedList<T>)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return ObservableSortedList