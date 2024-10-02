--[=[
	A list that can be observed for blend and other components and maintains sorting order.

	This class is very expensive to use as it enforces maintaining order on the object. Each entries produces
	what is most likely 4-5 tables, and changing can result in O(n) table construction and deltas.

	However, for small lists that don't change frequently, such as a global leaderboard, this can be
	a nice small interactive class.

	For performance reasons this class defers firing events until the next defer() event frame.

	This class always prefers to add equivalent elements to the end of the list if they're not in the list.
	Otherwise it prefers minimal movement.

	@class ObservableSortedList
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Rx = require("Rx")
local Signal = require("Signal")
local Symbol = require("Symbol")
local ValueObject = require("ValueObject")
local DuckTypeUtils = require("DuckTypeUtils")

-- Higher numbers last
local function defaultCompare(a, b)
	-- equivalent of `return a - b` except it supports comparison of strings and stuff
	if b > a then
		return -1
	elseif b < a then
		return 1
	else
		return 0
	end
end

local ObservableSortedList = {}
ObservableSortedList.ClassName = "ObservableSortedList"
ObservableSortedList.__index = ObservableSortedList

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

	self._keyList = {} -- { [number]: Symbol } -- immutable

	self._indexObservers = self._maid:Add(ObservableSubscriptionTable.new())
	self._contentIndexObservers = self._maid:Add(ObservableSubscriptionTable.new())

	self._sortValue = {} -- { [Symbol]: number }
	self._contents = {} -- { [Symbol]: T }
	self._indexes = {} -- { [Symbol]: number }

	self._keyObservables = {} -- { [Symbol]: { Subscription } }

	self._isReversed = isReversed or false
	self._compare = compare or defaultCompare

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
	@prop ItemRemoved self._maid:Add(Signal<T, Symbol>)
	@within ObservableSortedList
]=]
	self.ItemRemoved = self._maid:Add(Signal.new())

--[=[
	Fires when an item's order changes.
	@readonly
	@prop OrderChanged self._maid:Add(Signal<T, Symbol>)
	@within ObservableSortedList
]=]
	self.OrderChanged = self._maid:Add(Signal.new())

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableSortedList
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Observes the list, allocating a new list in the process.

	@return Observable<{ T }>
]=]
function ObservableSortedList:Observe()
	return Rx.combineLatest({
		Rx.fromSignal(self.ItemAdded):Pipe({ Rx.startWith({ true }) });
		Rx.fromSignal(self.ItemRemoved):Pipe({ Rx.startWith({ true }) });
		Rx.fromSignal(self.OrderChanged):Pipe({ Rx.startWith({ true }) });
	}):Pipe({
		Rx.throttleDefer();
		Rx.map(function()
			return self:GetList();
		end);
	})
end

function ObservableSortedList:Contains(value)
	-- TODO: Binary search
	for _, item in pairs(self._contents) do
		if item == value then
			return true
		end
	end

	return false
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
	Observes all items in the list
	@return Observable<Brio<T, Symbol>>
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
	Gets the first key for a given symbol

	@param content T
	@return Symbol
]=]
function ObservableSortedList:FindFirstKey(content)
	for key, item  in pairs(self._contents) do
		if item == content then
			return key
		end
	end

	return nil
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
		error(string.format("No entry at index %q, cannot observe changes", indexToObserve))
	end

	return self:ObserveIndexByKey(key)
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
		})
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number>
]=]
function ObservableSortedList:ObserveIndexByKey(key)
	assert(Symbol.isSymbol(key), "Bad key")

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
	return self._countValue.Value or 0
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableSortedList:GetList()
	local list = table.create(#self._keyList)
	for index, key in pairs(self._keyList) do
		list[index] = self._contents[key]
	end
	return list
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
		self:_debugVerifyIntegrity()

		if sortValue ~= nil then
			local currentIndex = self._indexes[key]
			local targetIndex = self:_findCorrectIndex(sortValue, currentIndex)

			self._sortValue[key] = sortValue
			self:_updateIndex(key, item, targetIndex, sortValue)
		else
			local observableSubs = self._keyObservables[key]

			-- calling this also may unsubscribe some observables.
			self:_removeItemByKey(key, item)

			if observableSubs then
				-- fire nil index
				self:_fireSubs(observableSubs, nil)
			end
		end

		self:_debugVerifyIntegrity()
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

function ObservableSortedList:_updateIndex(key, item, newIndex)
	assert(item ~= nil, "Bad item")
	assert(type(newIndex) == "number", "Bad newIndex")

	local prevIndex = self._indexes[key]
	if prevIndex == newIndex then
		return
	end

	self._indexes[key] = newIndex

	local changed = {}

	if not prevIndex then
		-- shift everything up to fit this space
		local n = #self._keyList
		for i=n, newIndex, -1 do
			local nextKey = self._keyList[i]
			self._indexes[nextKey] = i + 1
			self._keyList[i + 1] = nextKey

			table.insert(changed, {
				key = nextKey;
				newIndex = i + 1;
			})
		end
	elseif newIndex > prevIndex then
		-- we're shifting down
		for i=prevIndex + 1, newIndex do
			local nextKey = self._keyList[i]
			self._indexes[nextKey] = i - 1
			self._keyList[i - 1] = nextKey

			table.insert(changed, {
				key = nextKey;
				newIndex = i - 1;
			})
		end
	elseif newIndex < prevIndex then
		-- we're shifting up

		for i=prevIndex-1, newIndex, -1 do
			local belowKey = self._keyList[i]
			self._indexes[belowKey] = i + 1
			self._keyList[i + 1] = belowKey
			table.insert(changed, {
				key = belowKey;
				newIndex = i + 1;
			})
		end
	else
		error("Bad state")
	end

	local itemAdded = table.freeze({
		key = key;
		newIndex = newIndex;
		item = item;
	})

	-- ensure ourself is considered changed
	table.insert(changed, itemAdded)

	self._keyList[newIndex] = key

	-- Fire off our count value changed
	-- still O(n^2) but at least we prevent emitting O(n^2) events
	if prevIndex == nil then
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

	local itemRemoved = table.freeze({
		key = key;
		item = item;
		previousIndex = index;
	})

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
	if self._deferredChange then
		return
	end

	self._deferredChange = {
		countChange = 0;
		indexChanges = {};
		itemsAdded = {};
		itemsRemoved = {};
	}

	self._maid._currentDefer = task.defer(function()
		local snapshot = self._deferredChange
		self._deferredChange = nil

		task.spawn(function()
			self._maid._currentDefer = nil
			local changed = false

			self._countValue.Value = self._countValue.Value + snapshot.countChange

			-- Fire off last adds
			for _, lastAdded in pairs(snapshot.itemsAdded) do
				if not self.ItemAdded.Destroy then
					break
				end

				changed = true
				self.ItemAdded:Fire(lastAdded.item, lastAdded.newIndex, lastAdded.key)

				-- Item adds are included in indexChanges.
			end

			for _, lastRemoved in pairs(snapshot.itemsRemoved) do
				if not self.ItemRemoved.Destroy then
					break
				end

				changed = true
				self.ItemRemoved:Fire(lastRemoved.item, lastRemoved.key)

				-- Fire only if we aren't handled by an index change.
				if self._keyList[lastRemoved.previousIndex] == nil then
					self._indexObservers:Fire(lastRemoved.previousIndex, nil)
				end
			end

			-- Fire off index change on each key list (if the data isn't stale)
			for _, lastChange in pairs(snapshot.indexChanges) do
				if self._indexes[lastChange.key] == lastChange.newIndex then
					changed = true

					local subs = self._keyObservables[lastChange.key]
					if subs then
						self:_fireSubs(subs, lastChange.newIndex)
					end

					self._indexObservers:Fire(lastChange.newIndex, self._contents[lastChange.key])
				end
			end

			if changed then
				self.OrderChanged:Fire()
			end
		end)
	end)
end

function ObservableSortedList:_findCorrectIndex(sortValue, currentIndex)
	local highInsertionIndex = self:_highBinarySearch(sortValue)

	-- we're inserting, so always insert at end
	if not currentIndex then
		return highInsertionIndex
	end

	local lowInsertionIndex = self:_lowBinarySearch(sortValue)

	-- remember we get insertion index so we need to subtract one
	if highInsertionIndex > currentIndex then
		highInsertionIndex = highInsertionIndex - 1
	end
	if lowInsertionIndex > currentIndex then
		lowInsertionIndex = lowInsertionIndex - 1
	end

	-- prioritize the smallest potential movement
	if currentIndex < lowInsertionIndex then
		return lowInsertionIndex
	elseif currentIndex > highInsertionIndex then
		return highInsertionIndex
	else
		return currentIndex
	end
end

function ObservableSortedList:_highBinarySearch(sortValue)
	if #self._keyList == 0 then
		return 1
	end

	local minIndex = 1
	local maxIndex = #self._keyList
	while true do
		local mid = math.floor((minIndex + maxIndex) / 2)
		local compareValue = self._compare(self._sortValue[self._keyList[mid]], sortValue)
		if type(compareValue) ~= "number" then
			error(string.format("Bad compareValue, expected number, got %q", type(compareValue)))
		end

		if self._isReversed then
			compareValue = -compareValue
		end

		if compareValue > 0 then
			maxIndex = mid - 1
			if minIndex > maxIndex then
				return mid
			end
		else
			minIndex = mid + 1
			if minIndex > maxIndex then
				return mid + 1
			end
		end
	end
end

function ObservableSortedList:_lowBinarySearch(sortValue)
	if #self._keyList == 0 then
		return 1
	end

	local minIndex = 1
	local maxIndex = #self._keyList
	while true do
		local mid = math.floor((minIndex + maxIndex) / 2)
		local compareValue = self._compare(self._sortValue[self._keyList[mid]], sortValue)
		assert(type(compareValue) == "number", "Expecting number")

		if self._isReversed then
			compareValue = -compareValue
		end

		if compareValue < 0 then
			minIndex = mid + 1
			if minIndex > maxIndex then
				return mid + 1
			end
		else
			maxIndex = mid - 1
			if minIndex > maxIndex then
				return mid
			end
		end
	end
end

function ObservableSortedList:_debugSortValuesToString()
	local values = {}

	for _, key in pairs(self._keyList) do
		table.insert(values, string.format("%4d", self._sortValue[key]))
	end

	return table.concat(values, ", ")
end

function ObservableSortedList:_debugVerifyIntegrity()
	for i=2, #self._keyList do
		local compare = self._compare(self._sortValue[self._keyList[i-1]], self._sortValue[self._keyList[i]])
		if self._isReversed then
			compare = -compare
		end
		if compare > 0 then
			warn(string.format("Bad sorted list state %s at index %d", self:_debugSortValuesToString(), i))
		end
	end

	for i=1, #self._keyList do
		if self._indexes[self._keyList[i]] ~= i then
			warn(string.format("Index is out of date for %d for %s", i, self:_debugSortValuesToString()))
		end
	end
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