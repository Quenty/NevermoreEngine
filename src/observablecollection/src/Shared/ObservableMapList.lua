--!strict
--[=[
	Holds a map of lists. This is good for list-based

	@class ObservableMapList
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local ObservableList = require("ObservableList")
local ObservableMap = require("ObservableMap")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local _Signal = require("Signal")
local _Brio = require("Brio")

local ObservableMapList = {}
ObservableMapList.ClassName = "ObservableMapList"
ObservableMapList.__index = ObservableMapList

type ObservableList<T> = any --ObservableList.ObservableList<T>

export type ObservableMapList<TKey, TValue> = typeof(setmetatable(
	{} :: {
		_observableMapOfLists: any, --ObservableMap.ObservableMap<TKey, ObservableList<TValue>>,
		_maid: Maid.Maid,

		--[=[
			Fires when an item is added
			@readonly
			@prop ListAdded Signal<TKey>
			@within ObservableMapSet
		]=]
		ListAdded: _Signal.Signal<TKey, ObservableList<TValue>>,

		--[=[
			Fires when an item is removed
			@readonly
			@prop ListRemoved Signal<TKey>
			@within ObservableMapSet
		]=]
		ListRemoved: _Signal.Signal<TKey>,

		--[=[
			Fires when the count changes.
			@prop CountChanged RBXScriptSignal
			@within ObservableMap
		]=]
		CountChanged: _Signal.Signal<number>,
	},
	{} :: typeof({ __index = ObservableMapList })
))

--[=[
	Constructs a new ObservableMapList
	@return ObservableMapList<TKey, TValue>
]=]
function ObservableMapList.new<TKey, TValue>(): ObservableMapList<TKey, TValue>
	local self: ObservableMapList<TKey, TValue> = setmetatable({} :: any, ObservableMapList)

	self._maid = Maid.new()
	self._observableMapOfLists = self._maid:Add(ObservableMap.new())

	self.ListAdded = assert(self._observableMapOfLists.KeyAdded, "Bad KeyAdded") -- :Fire(key, set)
	self.ListRemoved = assert(self._observableMapOfLists.KeyRemoved, "Bad KeyRemoved") -- :Fire(key)
	self.CountChanged = assert(self._observableMapOfLists.CountChanged, "Bad CountChanged")

	return self
end

--[=[
	Adds an entry with a dynamic key. This is great for caching things
	that need to be looked up by key.

	:::tip
	If `observeKey` emits nil then the value will be excluded from the list.
	:::

	@param entry TValue
	@param observeKey Observable<TKey>
	@return MaidTask -- Cleanup object that will remove the entry
]=]
function ObservableMapList.Push<TKey, TValue>(self: ObservableMapList<TKey, TValue>, observeKey, entry: TValue): Maid.Maid
	assert(observeKey ~= nil, "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	local maid = Maid.new()

	if Observable.isObservable(observeKey) then
		maid:GiveTask(observeKey:Subscribe(function(key)
			maid._currentAddValue = nil

			if key ~= nil then
				maid._currentAddValue = self:_addToList(key, entry)
			end
		end))
	else
		maid:GiveTask(self:_addToList(observeKey, entry))
	end

	-- Ensure self-cleanup when map cleans up
	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	Gets the first item for the given key

	@param key TKey
	@return TValue | nil
]=]
function ObservableMapList.GetFirstItemForKey<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey): TValue?
	assert(key ~= nil, "Bad key")

	local observableList = self:GetListForKey(key)
	if not observableList then
		return nil
	end

	return observableList:Get(1)
end

--[=[
	Gets the item for the given key at the index

	```
	mapList:Push("fruits", "apple")
	mapList:Push("fruits", "orange")
	mapList:Push("fruits", "banana")

	-- Print the last item
	print(mapList:GetItemForKeyAtIndex("fruits", -1)) ==> banana
	```

	@param key TKey
	@param index number
	@return TValue?
]=]
function ObservableMapList.GetItemForKeyAtIndex<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey,
	index: number
): TValue?
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	local observableList = self:GetListForKey(key)
	if not observableList then
		return nil
	end

	return observableList:Get(index)
end

--[=[
	Gets how many lists exist

	@return number
]=]
function ObservableMapList.GetListCount<TKey, TValue>(self: ObservableMapList<TKey, TValue>): number
	return self._observableMapOfLists:GetCount()
end

ObservableMapList.__len = ObservableMapList.GetListCount

--[=[
	Observes how many lists exist

	@return Observable<number>
]=]
function ObservableMapList.ObserveListCount<TKey, TValue>(self: ObservableMapList<TKey, TValue>): Observable.Observable<number>
	return self._observableMapOfLists:ObserveCount()
end

--[=[
	Gets the current value at the list index

	@param key TKey
	@param index number
	@return TValue?
]=]
function ObservableMapList.GetAtListIndex<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey, index: number): TValue?
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	local list = self._observableMapOfLists:Get(key)
	if list then
		return list:Get(index)
	else
		return nil
	end
end

--[=[
	Observes the current value at the index

	@param key TKey
	@param index number
	@return Observable<TValue?>
]=]
function ObservableMapList.ObserveAtListIndex<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey,
	index: number
): Observable.Observable<TValue?>
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	return self._observableMapOfLists:ObserveAtKey(key):Pipe({
		Rx.switchMap(function(list): any
			if list then
				return list:ObserveAtIndex(index)
			else
				return Rx.of(nil)
			end
		end) :: any,
	}) :: any
end

--[=[
	Gets a list of all keys

	@return { TKey }
]=]
function ObservableMapList.GetKeyList<TKey, TValue>(self: ObservableMapList<TKey, TValue>): { TKey }
	return self._observableMapOfLists:GetKeyList()
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMapList.ObserveKeyList<TKey, TValue>(self: ObservableMapList<TKey, TValue>): Observable.Observable<{ TKey }>
	return self._observableMapOfLists:ObserveKeyList()
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMapList.ObserveKeysBrio<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>
): Observable.Observable<_Brio.Brio<TKey>>
	return self._observableMapOfLists:ObserveKeysBrio()
end

--[=[
	Observes the current value at the index

	@param key TKey
	@param index number
	@return Observable<Brio<TValue>>
]=]
function ObservableMapList.ObserveAtListIndexBrio<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey,
	index: number
): Observable.Observable<_Brio.Brio<TValue>>
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	return self._observableMapOfLists:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(list)
			return list:ObserveAtIndexBrio(index)
		end) :: any,
		RxBrioUtils.toBrio() :: any,
		RxBrioUtils.where(function(value)
			return value ~= nil
		end) :: any,
	}) :: any
end

--[=[
	Observes all items at the given key

	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMapList.ObserveItemsForKeyBrio<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey
): Observable.Observable<_Brio.Brio<TValue>>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(list): any
			if list then
				return list:ObserveItemsBrio()
			else
				return Rx.EMPTY
			end
		end) :: any,
	}) :: any
end

--[=[
	Gets a list for a given key.

	@param key TKey
	@return { TValue }
]=]
function ObservableMapList.GetListFromKey<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey): { TValue }
	assert(key ~= nil, "Bad key")

	local observableList = self:GetListForKey(key)
	if not observableList then
		return {}
	end

	return observableList:GetList()
end

--[=[
	Gets the observable list for the given key
	@param key TKey
	@return ObservableList<TValue>
]=]
function ObservableMapList.GetListForKey<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey): any
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:Get(key)
end

--[=[
	Gets a list of all of the entries at the given index, if it exists

	@param index number
	@return { TValue}
]=]
function ObservableMapList.GetListOfValuesAtListIndex<TKey, TValue>(self: ObservableMapList<TKey, TValue>, index: number): { TValue }
	assert(type(index) == "number", "Bad index")

	local list = table.create(self._observableMapOfLists:GetCount())

	for _, observableList in self._observableMapOfLists:GetValueList() do
		local value = observableList:Get(index)
		if value ~= nil then
			table.insert(list, value)
		end
	end

	return list
end

--[=[
	Observes the observable list for the given key

	@param key TKey
	@return Observable<ObservableList<TValue>>
]=]
function ObservableMapList.ObserveList<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey
): Observable.Observable<ObservableList<TValue>>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKey(key)
end

--[=[
	Observes the observable list for the given key

	@param key TKey
	@return Observable<Brio<ObservableList<TValue>>>
]=]
function ObservableMapList.ObserveListBrio<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey
): Observable.Observable<_Brio.Brio<ObservableList<TValue>>>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKeyBrio(key)
end

--[=[
	Observes all observable lists in the map.

	@return Observable<Brio<ObservableList<TValue>>>
]=]
function ObservableMapList.ObserveListsBrio<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>
): Observable.Observable<_Brio.Brio<ObservableList<TValue>>>
	return self._observableMapOfLists:ObserveValuesBrio()
end

--[=[
	Observes the number of entries for the given key

	@param key TKey
	@return Observable<number>
]=]
function ObservableMapList.ObserveCountForKey<TKey, TValue>(
	self: ObservableMapList<TKey, TValue>,
	key: TKey
): Observable.Observable<number>
	assert(key ~= nil, "Bad key")

	return self:ObserveListBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(observableList)
			return observableList:ObserveCount()
		end) :: any,
		RxBrioUtils.emitOnDeath(0) :: any,
	}) :: any
end

function ObservableMapList._addToList<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey, entry: TValue): () -> ()
	local list = self:_getOrCreateList(key)
	return list:Add(entry)
end

function ObservableMapList._getOrCreateList<TKey, TValue>(self: ObservableMapList<TKey, TValue>, key: TKey): ObservableList<TValue>
	local existing = self._observableMapOfLists:Get(key)
	if existing then
		return existing
	end

	local maid = Maid.new()
	local list = maid:Add(ObservableList.new())

	maid:GiveTask(list.CountChanged:Connect(function(count)
		if count <= 0 then
			self._maid[list] = nil
		end
	end))

	maid:GiveTask(self._observableMapOfLists:Set(key, list))
	self._maid[list] = maid

	return list
end

--[=[
	Cleans up the ObservableMapList and sets the metatable to nil.
]=]
function ObservableMapList.Destroy<TKey, TValue>(self: ObservableMapList<TKey, TValue>)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end


return ObservableMapList