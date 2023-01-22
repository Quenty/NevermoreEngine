--[=[
	A list that can be observed for blend and other components and maintains sorting order.

	This class is very expensive to use as it enforces maintaining order on the object. Each entries produces
	what is most likely 4-5 tables, and changing can result in O(n) table construction and deltas.

	However, for small lists that don't change frequently, such as a global leaderboard, this can be
	a nice small interactive class.

	For performance reasons this class defers firing events until the next defer() event frame.

	@class ObservableSortedList
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Symbol = require("Symbol")

-- Higher numbers last
local function defaultCompare(a, b)
	return a < b
end

local ObservableSortedList = {}
ObservableSortedList.ClassName = "ObservableSortedList"
ObservableSortedList.__index = ObservableSortedList

--[=[
	Constructs a new ObservableSortedList
	@param compare callback?
	@return ObservableSortedList<T>
]=]
function ObservableSortedList.new(compare)
	local self = setmetatable({}, ObservableSortedList)

	self._maid = Maid.new()

	self._keyList = {} -- { [number]: Symbol } -- immutable

	self._sortValue = {} -- { [Symbol]: number }
	self._contents = {} -- { [Symbol]: T }
	self._indexes = {} -- { [Symbol]: number }

	self._keyObservables = {} -- { [Symbol]: { Subscription } }

	self._compare = compare or defaultCompare
	self._countValue = Instance.new("IntValue")
	self._countValue.Value = 0
	self._maid:GiveTask(self._countValue)

--[=[
	Fires when an item is added
	@readonly
	@prop ItemAdded Signal<T, number, Symbol>
	@within ObservableSortedList
]=]
	self.ItemAdded = Signal.new()
	self._maid:GiveTask(self.ItemAdded)

--[=[
	Fires when an item is removed.
	@readonly
	@prop ItemRemoved Signal<T, Symbol>
	@within ObservableSortedList
]=]
	self.ItemRemoved = Signal.new()
	self._maid:GiveTask(self.ItemRemoved)

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
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
	return type(value) == "table" and getmetatable(value) == ObservableSortedList
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T>>
]=]
function ObservableSortedList:ObserveItemsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItem(item, _index, includeKey)
			local brio = Brio.new(item, includeKey)
			maid[includeKey] = brio
			sub:Fire(brio)
		end

		for index, key in pairs(self._keyList) do
			handleItem(self._contents[key], index, key)
		end

		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(_item, includeKey)
			maid[includeKey] = nil
		end))

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

	local key = self._keyList[indexToObserve]
	if not key then
		error(("No entry at index %q, cannot observe changes"):format(indexToObserve))
	end

	return self:ObserveIndexByKey(key)
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number>
]=]
function ObservableSortedList:ObserveIndexByKey(key)
	assert(type(key) == "userdata", "Bad key")

	return Observable.new(function(sub)
		local maid = Maid.new()
		self._keyObservables[key] = self._keyObservables[key] or {}
		table.insert(self._keyObservables[key], sub)

		local currentIndex = self._indexes[key]
		if currentIndex then
			sub:Fire(currentIndex)
		end

		maid:GiveTask(function()
			local list = self._keyObservables[key]
			if not list then
				return
			end

			local index = table.find(list, sub)
			if index then
				table.remove(list, index)
				if #list == 0 then
					self._keyObservables[key] = nil
				end
			end
		end)

		return maid
	end)
end

--[=[
	Gets the current index from the key

	@param key Symbol
	@return number
]=]
function ObservableSortedList:GetIndexByKey(key)
	local currentIndex = self._indexes[key]
	if currentIndex then
		return currentIndex
	else
		return nil
	end
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function ObservableSortedList:GetCount()
	return self._countValue.Value
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableSortedList:GetList()
	local list = {}
	for _, key in pairs(self._keyList) do
		table.insert(list, self._contents[key])
	end
	return list
end

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function ObservableSortedList:ObserveCount()
	return RxValueBaseUtils.observeValue(self._countValue)
end

--[=[
	Adds the item to the list at the specified index
	@param item T
	@param observeValue Observable<Comparable>
	@return callback -- Call to remove
]=]
function ObservableSortedList:Add(item, observeValue)
	assert(item ~= nil, "Bad item")
	assert(Observable.isObservable(observeValue), "Bad observeValue")

	local key = Symbol.named("entryKey")
	local maid = Maid.new()

	self._contents[key] = item

	maid:GiveTask(observeValue:Subscribe(function(sortValue)
		self._sortValue[key] = sortValue

		if sortValue ~= nil then
			local currentIndex = self._indexes[key]
			local targetIndex = self:_findCorrectIndex(sortValue, currentIndex)
			self:_updateIndex(key, item, targetIndex)
		else
			local observableSubs = self._keyObservables[key]

			-- calling this also may unsubscribe some observables.
			self:_removeItemByKey(key, item)

			if observableSubs then
				-- fire nil index
				self:_fireSubs(observableSubs, nil)
			end
		end
	end))

	maid:GiveTask(function()
		local observableSubs = self._keyObservables[key]
		self._keyObservables[key] = nil

		self:_removeItemByKey(key, item)

		-- Fire off the index change on the value
		if observableSubs then
			self:_completeSubs(observableSubs)
		end

		self._contents[key] = nil
		self._sortValue[key] = nil
	end)

	self._maid[key] = maid

	return function()
		self._maid[key] = nil
	end
end

--[=[
	Gets the current item at the index, or nil if it is not defined.
	@param index number
	@return T?
]=]
function ObservableSortedList:Get(index)
	assert(type(index) == "number", "Bad index")

	local key = self._keyList[index]
	if not key then
		return nil
	end

	return self._contents[key]
end

--[=[
	Removes the item from the list if it exists.
	@param key Symbol
	@return T
]=]
function ObservableSortedList:RemoveByKey(key)
	assert(key ~= nil, "Bad key")

	self._maid[key] = nil
end

function ObservableSortedList:_updateIndex(key, item, index)
	assert(item ~= nil, "Bad item")
	assert(type(index) == "number", "Bad index")

	local pastIndex = self._indexes[key]
	if pastIndex == index then
		return
	end

	self._indexes[key] = index

	local changed = {}

	if not pastIndex then
		-- shift everything up to fit this space
		local n = #self._keyList
		for i=n, index, -1 do
			local nextKey = self._keyList[i]
			self._indexes[nextKey] = i + 1
			self._keyList[i + 1] = nextKey

			table.insert(changed, {
				key = nextKey;
				newIndex = i + 1;
			})
		end
	elseif index > pastIndex then
		-- we're moving up (3 -> 5), so everything shifts down to fill up the pastIndex
		for i=pastIndex + 1, index do
			local nextKey = self._keyList[i]
			self._indexes[nextKey] = i - 1
			self._keyList[i - 1] = nextKey

			table.insert(changed, {
				key = nextKey;
				newIndex = i - 1;
			})
		end
	else
		-- if index < pastIndex then
		-- we're moving down (5 -> 3) so everything shifts up to fit this space
		for i=pastIndex-1, index, -1 do
			local belowKey = self._keyList[i]
			self._indexes[belowKey] = i + 1
			self._keyList[i + 1] = belowKey
			table.insert(changed, {
				key = belowKey;
				newIndex = i + 1;
			})
		end
	end

	local itemAdded = {
		key = key;
		newIndex = index;
		item = item;
	}

	-- ensure ourself is considered changed
	table.insert(changed, itemAdded)


	self._keyList[index] = key

	-- Fire off our count value changed
	-- still O(n^2) but at least we prevent emitting O(n^2) events
	if pastIndex == nil then
		self:_deferChange(1, itemAdded, nil, changed)
	else
		self:_deferChange(0, nil, nil, changed)
	end
end

function ObservableSortedList:_removeItemByKey(key, item)
	assert(key ~= nil, "Bad key")

	local index = self._indexes[key]
	if not index then
		return
	end

	self._indexes[key] = nil
	self._sortValue[key] = nil

	local changed = {}

	-- shift everything down
	local n = #self._keyList
	for i=index, n - 1 do
		local nextKey = self._keyList[i+1]
		self._indexes[nextKey] = i
		self._keyList[i] = nextKey

		table.insert(changed, {
			key = nextKey;
			newIndex = i;
		})
	end
	self._keyList[n] = nil

	local itemRemoved = {
		key = key;
		item = item;
	}

	-- TODO: Defer item removed as a changed event?

	-- still O(n^2) but at least we prevent emitting O(n^2) events
	self:_deferChange(-1, nil, itemRemoved, changed)
end

function ObservableSortedList:_deferChange(countChange, itemAdded, itemRemoved, indexChanges)
	self:_queueDeferredChange()

	if itemAdded then
		self._deferredChange.itemsRemoved[itemAdded.key] = nil
		self._deferredChange.itemsAdded[itemAdded.key] = itemAdded
	end

	if itemRemoved then
		self._deferredChange.itemsAdded[itemRemoved.key] = nil
		self._deferredChange.itemsRemoved[itemRemoved.key] = itemRemoved
	end

	self._deferredChange.countChange += countChange

	for _, data in pairs(indexChanges) do
		self._deferredChange.indexChanges[data.key] = data
	end
end

function ObservableSortedList:_queueDeferredChange()
	if not self._deferredChange then
		self._deferredChange = {
			countChange = 0;
			indexChanges = {};
			itemsAdded = {};
			itemsRemoved = {};
		}

		task.defer(function()
			local snapshot = self._deferredChange
			self._deferredChange = nil

			self._countValue.Value = self._countValue.Value + snapshot.countChange

			if self.Destroy then
				-- Fire off last adds
				for _, lastAdded in pairs(snapshot.itemsAdded) do
					self.ItemAdded:Fire(lastAdded.item, lastAdded.newIndex, lastAdded.key)
				end

				for _, lastRemoved in pairs(snapshot.itemsRemoved) do
					self.ItemRemoved:Fire(lastRemoved.item, lastRemoved.key)
				end
			end

			-- Fire off index change on each key list (if the data isn't stale)
			for _, lastChange in pairs(snapshot.indexChanges) do
				if self._indexes[lastChange.key] == lastChange.newIndex then
					local subs = self._keyObservables[lastChange.key]
					if subs then
						self:_fireSubs(subs, lastChange.newIndex)
					end
				end
			end
		end)
	end
end

function ObservableSortedList:_findCorrectIndex(sortValue, currentIndex)
	-- todo: binary search
	-- todo: stable

	for i=#self._keyList, 1, -1 do
		local currentKey = self._keyList[i]
		if self._compare(self._sortValue[currentKey], sortValue) then

			-- include index in this
			if currentIndex and currentIndex <= i then
				return i
			end

			return i + 1
		end
	end

	return 1
end

function ObservableSortedList:_fireSubs(list, index)
	for _, sub in pairs(list) do
		if sub:IsPending() then
			task.spawn(function()
				sub:Fire(index)
			end)
		end
	end
end

function ObservableSortedList:_completeSubs(list)
	for _, sub in pairs(list) do
		if sub:IsPending() then
			sub:Fire(nil)
			sub:Complete()
		end
	end
end

--[=[
	Cleans up the ObservableSortedList and sets the metatable to nil.
]=]
function ObservableSortedList:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableSortedList