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
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Rx = require("Rx")
local Signal = require("Signal")
local SortedNode = require("SortedNode")
local SortedNodeValue = require("SortedNodeValue")
local ValueObject = require("ValueObject")
local SortFunctionUtils = require("SortFunctionUtils")

local ObservableSortedList = {}
ObservableSortedList.ClassName = "ObservableSortedList"
ObservableSortedList.__index = ObservableSortedList

local function emptyIterator()
end

--[=[
	Constructs a new ObservableSortedList
	@param isReversed boolean
	@param compare function
	@return ObservableSortedList<T>
]=]
function ObservableSortedList.new(isReversed, compare)
	assert(type(isReversed) == "boolean" or isReversed == nil, "Bad isReversed")

	local self = setmetatable({}, ObservableSortedList)

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
	self.ItemRemoved = Signal.new()

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
function ObservableSortedList.isObservableSortedList(value)
	return DuckTypeUtils.isImplementation(ObservableSortedList, value)
end

--[=[
	Observes the list, allocating a new list in the process.

	@return Observable<{ T }>
]=]
function ObservableSortedList:Observe()
	return self._mainObservables:Observe("list")
end

--[=[
	Allows iteration over the observable map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableSortedList:__iter()
	if self._root then
		return self._root:IterateData()
	else
		return emptyIterator
	end
end

function ObservableSortedList:_iterateNodes()
	if self._root then
		return self._root:IterateNodes()
	else
		return emptyIterator
	end
end

function ObservableSortedList:_containsNode(node)
	assert(SortedNode.isSortedNode(node), "Bad node")

	if self._root then
		return self._root:ContainsNode(node)
	else
		return false
	end
end

function ObservableSortedList:_findNodeForDataLinearSearchSlow(data)
	if self._root then
		return self._root:FindFirstNodeForData(data)
	else
		return nil
	end
end

function ObservableSortedList:_findNodeAtIndex(index)
	assert(type(index) == "number", "Bad index")

	if self._root then
		return self._root:FindNodeAtIndex(index)
	else
		return nil
	end
end

function ObservableSortedList:_findNodeIndex(node)
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
function ObservableSortedList:FindFirstKey(content)
	return self:_findNodeForDataLinearSearchSlow(content)
end

function ObservableSortedList:PrintDebug()
	print(self._root)
end

--[=[
	Returns true if the value exists

	@param content T
	@return boolean
]=]
function ObservableSortedList:Contains(content)
	assert(content ~= nil, "Bad content")

	-- TODO: Speed up
	return self:_findNodeForDataLinearSearchSlow(content) ~= nil
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T, Symbol>>
]=]
function ObservableSortedList:ObserveItemsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		-- TODO: Optimize this so we don't have to make so many brios and connect
		-- to so many events

		local function handleItem(data, _index, node)
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
	end)
end

--[=[
	Observes the index as it changes, until the entry at the existing
	index is removed.

	@param indexToObserve number
	@return Observable<number>
]=]
function ObservableSortedList:ObserveIndex(indexToObserve)
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	local node = self:_findNodeAtIndex(indexToObserve)
	if not node then
		error(string.format("[ObservableSortedList.ObserveIndex] - No entry at index %q, cannot observe changes", indexToObserve))
	end

	return self:ObserveIndexByKey(node)
end

--[=[
	Observes the current value at a given index. This can be useful for observing
	the first entry, or matching stuff up to a given slot.

	@param indexToObserve number
	@return Observable<T>
]=]
function ObservableSortedList:ObserveAtIndex(indexToObserve)
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	return self._indexObservers:Observe(indexToObserve)
		:Pipe({
			Rx.start(function()
				return self:Get(indexToObserve)
			end);

			-- TODO: Avoid needing this
			Rx.distinct();
		})
end

--[=[
	Observes the index as it changes, until the entry at the existing
	node is removed.

	@param node SortedNode
	@return Observable<number>
]=]
function ObservableSortedList:ObserveIndexByKey(node)
	assert(SortedNode.isSortedNode(node), "Bad node")

	return self._nodeIndexObservables:Observe(node):Pipe({
		Rx.startFrom(function()
			local currentIndex = self:_findNodeIndex(node)
			if currentIndex then
				return { currentIndex }
			else
				return {}
			end
		end);
	})
end

--[=[
	Gets the current index from the node

	@param node SortedNode
	@return number
]=]
function ObservableSortedList:GetIndexByKey(node)
	assert(SortedNode.isSortedNode(node), "Bad node")

	return self:_findNodeIndex(node)
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function ObservableSortedList:GetCount()
	return self._countValue.Value or 0
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableSortedList:GetList()
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
function ObservableSortedList:ObserveCount()
	return self._countValue:Observe()
end

--[=[
	Adds the item to the list at the specified index
	@param data T
	@param observeValue Observable<Comparable> | Comparable
	@return callback -- Call to remove
]=]
function ObservableSortedList:Add(data, observeValue)
	assert(data ~= nil, "Bad data")
	assert(Observable.isObservable(observeValue) or observeValue ~= nil, "Bad observeValue")

	local node = SortedNode.new(data)

	-- TODO: Store maid in node to prevent lookup of node -> index
	local maid = Maid.new()

	if Observable.isObservable(observeValue) then
		maid:GiveTask(observeValue:Subscribe(function(sortValue)
			self:_assignSortValue(node, sortValue)
		end))
	elseif observeValue ~= nil then
		self:_assignSortValue(node, observeValue)
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

function ObservableSortedList:_assignSortValue(node, value)
	if SortedNodeValue.isSortedNodeValue(node.value) then
		if node.value:GetValue() == value then
			return
		end
	elseif node.value == value then
		return
	end

	if value == nil then
		if self._root and self._root:ContainsNode(node) then
			self._nodesRemoved[node] = true
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
		value = SortedNodeValue.new(value, self._compare)
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

function ObservableSortedList:_applyLowestIndexChanged(index)
	if self._lowestIndexChanged == nil then
		self._lowestIndexChanged = index
		return
	end

	if index < self._lowestIndexChanged then
		self._lowestIndexChanged = index
	end
end

function ObservableSortedList:_queueFireEvents()
	if self._maid._fireEvents then
		return
	end

	self._maid._fireEvents = task.defer(function()
		self._maid._fireEvents = nil
		self:_fireEvents()
	end)
end

function ObservableSortedList:_fireEvents()
	-- print(self._root)

	local lowestIndexChanged = self._lowestIndexChanged
	self._lowestIndexChanged = nil

	local nodesAdded = self._nodesAdded
	self._nodesAdded = {}

	local nodesRemoved = self._nodesRemoved
	self._nodesRemoved = {}

	-- Fire count changed first
	if self._root then
		self._countValue.Value = self._root.descendantCount
	else
		self._countValue.Value = 0
	end

	for node in nodesAdded do
		-- TODO: O(n log(n)) operation
		-- TODO: Prevent Rx.of(itemAdded) stuff in our UI
		local index = self:_findNodeIndex(node)
		self.ItemAdded:Fire(node.data, index, node)
	end

	for node in nodesRemoved do
		self.ItemRemoved:Fire(node.data, node)
	end

	self.OrderChanged:Fire()

	-- TODO: Iterate from this nth node to the end
	do
		-- TODO: not this O(n^2)
		-- TODO: Handle negative observations to avoid refiring upon insertion

		for index, node in self:_iterateNodes() do
			self._nodeIndexObservables:Fire(node, index)
		end
	end

	if self._mainObservables:HasSubscriptions("list") then
		local list = self:GetList()
		self._mainObservables:Fire("list", list)
	end
end

function ObservableSortedList:_insertNode(node)
	assert(SortedNode.isSortedNode(node), "Bad SortedNode")

	if self._root == nil then
		node:MarkBlack()
		self._root = node
	else
		self._root = self._root:InsertNode(node)
	end
end

function ObservableSortedList:_removeNode(nodeToRemove)
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
function ObservableSortedList:Get(index)
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
function ObservableSortedList:RemoveByKey(node)
	assert(SortedNode.isSortedNode(node), "Bad node")

	self._maid[node] = nil
end

--[=[
	Cleans up the ObservableSortedList and sets the metatable to nil.
]=]
function ObservableSortedList:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableSortedList