--!strict
--[=[
	A list that can be observed for blend and other components
	@class ObservableList
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local RxBrioUtils = require("RxBrioUtils")
local Signal = require("Signal")
local Symbol = require("Symbol")
local ValueObject = require("ValueObject")
local DuckTypeUtils = require("DuckTypeUtils")
local ListIndexUtils = require("ListIndexUtils")
local _SortFunctionUtils = require("SortFunctionUtils")

local ObservableList = {}
ObservableList.ClassName = "ObservableList"
ObservableList.__index = ObservableList

export type ObservableList<T> = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_keyList: { Symbol.Symbol },
		_contents: { [Symbol.Symbol]: T },
		_indexes: { [Symbol.Symbol]: number },
		_indexObservers: any; -- ObservableSubscriptionTable.ObservableSubscriptionTable<T?>,
		_keyIndexObservables: any; -- ObservableSubscriptionTable.ObservableSubscriptionTable<number?>,
		_countValue: ValueObject.ValueObject<number>,

		--[=[
			Fires when an item is added
			@readonly
			@prop ItemAdded Signal<T, number, Symbol>
			@within ObservableList
		]=]
		ItemAdded: Signal.Signal<T, number, Symbol.Symbol>,

		--[=[
			Fires when an item is removed.
			@readonly
			@prop ItemRemoved Signal<T, Symbol>
			@within ObservableList
		]=]
		ItemRemoved: Signal.Signal<T, Symbol.Symbol>,

		--[=[
			Fires when the count changes.
			@prop CountChanged Signal.Signal<number>,
			@within ObservableList
		]=]
		CountChanged: Signal.Signal<number>,
	},
	{} :: typeof({ __index = ObservableList })
))

--[=[
	Constructs a new ObservableList
	@return ObservableList<T>
]=]
function ObservableList.new<T>(): ObservableList<T>
	local self: ObservableList<T> = setmetatable({} :: any, ObservableList)

	self._maid = Maid.new()

	self._keyList = {} -- { [number]: Symbol }
	self._contents = {} -- { [Symbol]: T }
	self._indexes = {} -- { [Symbol]: number }

	self._indexObservers = self._maid:Add(ObservableSubscriptionTable.new())
	self._keyIndexObservables = self._maid:Add(ObservableSubscriptionTable.new())
	self._countValue = self._maid:Add(ValueObject.new(0, "number"))

	self.ItemAdded = self._maid:Add(Signal.new() :: any)
	self.ItemRemoved = self._maid:Add(Signal.new() :: any)
	self.CountChanged = self._countValue.Changed :: any

	return self
end

--[=[
	Returns whether the value is an observable list
	@param value any
	@return boolean
]=]
function ObservableList.isObservableList(value: any): boolean
	return DuckTypeUtils.isImplementation(ObservableList, value)
end

--[=[
	Observes the list, allocating a new list in the process.

	@return Observable<{ T }>
]=]
function ObservableList.Observe<T>(self: ObservableList<T>): Observable.Observable<{ T }>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function queueFire()
			if maid._queue then
				return
			end

			maid._queue = task.defer(function()
				maid._queue = nil
				sub:Fire(self:GetList())
			end)
		end

		maid:GiveTask(self.ItemAdded:Connect(queueFire))
		maid:GiveTask(self.ItemRemoved:Connect(queueFire))

		return maid
	end) :: any
end

--[=[
	Allows iteration over the observable map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableList.__iter<T>(self: ObservableList<T>): _SortFunctionUtils.WrappedIterator<number, T>
	return coroutine.wrap(function()
		for index, value in self._keyList do
			coroutine.yield(index, self._contents[value])
		end
	end)
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T>>
]=]
function ObservableList.ObserveItemsBrio<T>(self: ObservableList<T>): Observable.Observable<Brio.Brio<T>>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItem(item: T, _index, includeKey)
			local brio = Brio.new(item, includeKey)
			maid[includeKey] = brio
			sub:Fire(brio)
		end

		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(_item, includeKey)
			maid[includeKey] = nil
		end))

		for index, key in self._keyList do
			handleItem(self._contents[key], index, key)
		end

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
	@return Observable<number?>
]=]
function ObservableList.ObserveIndex<T>(self: ObservableList<T>, indexToObserve: number): Observable.Observable<number?>
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	local key = self._keyList[indexToObserve]
	if not key then
		error(string.format("No entry at index %d, cannot observe changes", indexToObserve))
	end

	return self:ObserveIndexByKey(key)
end

--[=[
	Observes the current value at a given index. This can be useful for observing
	the first entry, or matching stuff up to a given slot.

	```
	list:ObserveAtIndex(1):Subscribe(print) --> prints first item
	list:ObserveAtIndex(-1):Subscribe(print) --> prints last item
	```

	@param indexToObserve number
	@return Observable<T?>
]=]
function ObservableList.ObserveAtIndex<T>(self: ObservableList<T>, indexToObserve: number): Observable.Observable<T?>
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	return self._indexObservers:Observe(indexToObserve, function(sub)
		sub:Fire(self:Get(indexToObserve))
	end)
end

--[=[
	Observes the current value at a given index. This can be useful for observing
	the first entry, or matching stuff up to a given slot.

	@param indexToObserve number
	@return Observable<Brio<T>>
]=]
function ObservableList.ObserveAtIndexBrio<T>(
	self: ObservableList<T>,
	indexToObserve: number
): Observable.Observable<Brio.Brio<T>>
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	return self:ObserveAtIndex(indexToObserve):Pipe({
		RxBrioUtils.toBrio(),
		RxBrioUtils.onlyLastBrioSurvives(),
	}) :: any
end

--[=[
	Removes the first instance found in contents

	@param value T
	@return boolean
]=]
function ObservableList.RemoveFirst<T>(self: ObservableList<T>, value: T): boolean
	for key, item in self._contents do
		if item == value then
			self:RemoveByKey(key)
			return true
		end
	end

	return false
end

--[=[
	Returns an ValueObject that represents the CountValue

	@return ValueObject<number>
]=]
function ObservableList.GetCountValue<T>(self: ObservableList<T>): ValueObject.ValueObject<number>
	return self._countValue
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number?>
]=]
function ObservableList.ObserveIndexByKey<T>(self: ObservableList<T>, key: Symbol.Symbol): Observable.Observable<number?>
	assert(Symbol.isSymbol(key), "Bad key")

	return self._keyIndexObservables:Observe(key, function(sub)
		sub:Fire(self:GetIndexByKey(key))
	end) :: any
end

--[=[
	Gets the current index from the key

	@param key Symbol
	@return number?
]=]
function ObservableList.GetIndexByKey<T>(self: ObservableList<T>, key: Symbol.Symbol): number?
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
function ObservableList.GetCount<T>(self: ObservableList<T>): number
	return self._countValue.Value or 0
end

ObservableList.__len = ObservableList.GetCount

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function ObservableList.ObserveCount<T>(self: ObservableList<T>): Observable.Observable<number>
	return self._countValue:Observe()
end

--[=[
	Adds the item to the list at the specified index
	@param item T
	@return callback -- Call to remove
]=]
function ObservableList.Add<T>(self: ObservableList<T>, item: T): () -> ()
	return self:InsertAt(item, #self._keyList + 1)
end

--[=[
	Gets the current item at the index, or nil if it is not defined.
	@param index number
	@return T?
]=]
function ObservableList.Get<T>(self: ObservableList<T>, index: number): T?
	assert(type(index) == "number", "Bad index")

	index = ListIndexUtils.toPositiveIndex(#self._keyList, index)

	local key = self._keyList[index]
	if not key then
		return nil
	end

	return self._contents[key]
end

--[=[
	Adds the item to the list at the specified index
	@param item T
	@param index number?
	@return callback -- Call to remove
]=]
function ObservableList.InsertAt<T>(self: ObservableList<T>, item: T, index: number?): () -> ()
	assert(item ~= nil, "Bad item")
	assert(type(index) == "number", "Bad index")

	index = math.clamp(index, 1, #self._keyList + 1)

	local key = Symbol.named("entryKey")

	self._contents[key] = item
	self._indexes[key] = index

	local changed = {}

	local n = #self._keyList
	for i = n, index, -1 do
		local nextKey = self._keyList[i]
		self._indexes[nextKey] = i + 1
		self._keyList[i + 1] = nextKey

		table.insert(changed, {
			key = nextKey,
			newIndex = i + 1,
		})
	end

	self._keyList[index] = key
	local listLength = #self._keyList

	-- Fire off count
	self._countValue.Value = self._countValue.Value + 1

	-- Fire off add
	self.ItemAdded:Fire(item, index, key)

	-- Fire off the index change on the value
	self._keyIndexObservables:Fire(key, index)
	self._indexObservers:Fire(index, item)
	self._indexObservers:Fire(ListIndexUtils.toNegativeIndex(listLength, index), item)

	for _, data in changed do
		if self._indexes[data.key] == data.newIndex then
			self._indexObservers:Fire(data.newIndex, self._contents[data.key])
			self._indexObservers:Fire(ListIndexUtils.toNegativeIndex(listLength, index), self._contents[data.key])
			self._keyIndexObservables:Fire(data.key, data.newIndex)
		end
	end

	return function()
		if self.Destroy then
			self:RemoveByKey(key)
		end
	end
end

--[=[
	Removes the item at the index
	@param index number
	@return T
]=]
function ObservableList.RemoveAt<T>(self: ObservableList<T>, index: number): T?
	assert(type(index) == "number", "Bad index")

	local key = self._keyList[index]
	if not key then
		return nil
	end

	return self:RemoveByKey(key)
end

--[=[
	Removes the item from the list if it exists.
	@param key Symbol
	@return T
]=]
function ObservableList.RemoveByKey<T>(self: ObservableList<T>, key): T?
	assert(key ~= nil, "Bad key")

	local index = self._indexes[key]
	if not index then
		return nil
	end

	local item = self._contents[key]
	if item == nil then
		return nil
	end

	self._indexes[key] = nil
	self._contents[key] = nil

	local changed = {}

	-- shift everything down
	local n = #self._keyList
	for i = index, n - 1 do
		local nextKey = self._keyList[i + 1]
		self._indexes[nextKey] = i
		self._keyList[i] = nextKey

		table.insert(changed, {
			key = nextKey,
			newIndex = i,
		})
	end
	self._keyList[n] = nil
	local listLength = #self._keyList

	-- Fire off that count changed
	self._countValue.Value = self._countValue.Value - 1

	if self.Destroy then
		self.ItemRemoved:Fire(item, key)
	end

	-- Fire off the index change on the value
	self._keyIndexObservables:Complete(key)
	self._indexObservers:Fire(listLength, nil)

	if listLength == 0 then
		self._indexObservers:Fire(-1, nil)
	end

	-- Fire off index change on each key list (if the data isn't stale)
	for _, data in changed do
		if self._indexes[data.key] == data.newIndex then
			self._indexObservers:Fire(data.newIndex, self._contents[data.key])
			self._indexObservers:Fire(ListIndexUtils.toNegativeIndex(listLength, index), self._contents[data.key])
			self._keyIndexObservables:Fire(data.key, data.newIndex)
		end
	end

	return item
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableList.GetList<T>(self: ObservableList<T>): { T }
	local list = table.create(#self._keyList)
	for index, key in self._keyList do
		list[index] = self._contents[key]
	end
	return list
end

--[=[
	Cleans up the ObservableList and sets the metatable to nil.
]=]
function ObservableList.Destroy<T>(self: ObservableList<T>)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return ObservableList