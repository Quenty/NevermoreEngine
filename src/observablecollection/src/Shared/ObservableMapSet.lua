--!strict
--[=[
	Holds a map of sets. That is, for a given key, a set of all valid entries. This is great
	for looking up something that may have duplicate keys, like configurations or other things.

	@class ObservableMapSet
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local ObservableSet = require("ObservableSet")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local _Brio = require("Brio")
local _Signal = require("Signal")
local _Table = require("Table")

local ObservableMapSet = {}
ObservableMapSet.ClassName = "ObservableMapSet"
ObservableMapSet.__index = ObservableMapSet

export type ObservableMapSet<TKey, TValue> = typeof(setmetatable(
	{} :: {
		_observableMapOfSets: any, -- ObservableMap.ObservableMap<TKey, ObservableSet.ObservableSet<TValue>>,
		_maid: Maid.Maid,
		SetAdded: _Signal.Signal<TKey>,
		SetRemoved: _Signal.Signal<TKey>,
		CountChanged: _Signal.Signal<number>,
	},
	{} :: typeof({ __index = ObservableMapSet })
))

--[=[
	Constructs a new ObservableMapSet
	@return ObservableMapSet<TKey, TValue>
]=]
function ObservableMapSet.new<TKey, TValue>(): ObservableMapSet<TKey, TValue>
	local self = setmetatable({} :: any, ObservableMapSet)

	self._maid = Maid.new()
	self._observableMapOfSets = self._maid:Add(ObservableMap.new())

	--[=[
	Fires when an item is added
	@readonly
	@prop SetAdded Signal<TKey>
	@within ObservableMapSet
]=]
	self.SetAdded = assert(self._observableMapOfSets.KeyAdded, "Bad KeyAdded") -- :Fire(key, set)

	--[=[
	Fires when an item is removed
	@readonly
	@prop SetRemoved Signal<TKey>
	@within ObservableMapSet
]=]
	self.SetRemoved = assert(self._observableMapOfSets.KeyRemoved, "Bad KeyRemoved") -- :Fire(key)

	--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableMap
]=]
	self.CountChanged = assert(self._observableMapOfSets.CountChanged, "Bad CountChanged")

	return self
end

--[=[
	Adds an entry with a dynamic key. This is great for caching things
	that need to be looked up by key.

	:::tip
	If `observeKey` emits nil then the value will be excluded from the map.
	:::

	@param entry TValue
	@param observeKey Observable<TKey> | TKey
	@return MaidTask -- Cleanup object that will remove the entry
]=]

function ObservableMapSet.Push<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	observeKey: Observable.Observable<TKey> | TKey,
	entry: TValue
): Maid.Maid
	assert(observeKey ~= nil, "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	local maid = Maid.new()

	if Observable.isObservable(observeKey) then
		maid:GiveTask((observeKey :: any):Subscribe(function(key)
			maid._currentAddValue = nil

			if key ~= nil then
				maid._currentAddValue = self:_addToSet(key, entry)
			end
		end))
	else
		maid:GiveTask(self:_addToSet(observeKey :: any, entry))
	end

	-- Ensure self-cleanup when map cleans up
	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	Adds an entry with a dynamic key. This is great for caching things
	that need to be looked up by key.

	This code is legacy code since our argument order isn't intuitive

	:::tip
	If `observeKey` emits nil then the value will be excluded from the map.
	:::

	@param entry TValue
	@param observeKey Observable<TKey> | TKey
	@return MaidTask -- Cleanup object that will remove the entry
]=]
function ObservableMapSet.Add<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	entry: TValue,
	observeKey: Observable.Observable<TKey> | TKey
): Maid.Maid
	assert(Observable.isObservable(observeKey), "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	warn(
		string.format(
			"[ObservableMapSet.Add] - This API call will swap observable key order eventually. Use ObservableMapSet.Push for now to suppress this warning.\n%s",
			debug.traceback()
		)
	)

	return self:Push(observeKey, entry)
end

--[=[
	Gets a list of all keys.
	@return { TKey }
]=]
function ObservableMapSet.GetKeyList<TKey, TValue>(self: ObservableMapSet<TKey, TValue>): { TKey }
	return self._observableMapOfSets:GetKeyList()
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMapSet.ObserveKeyList<TKey, TValue>(self: ObservableMapSet<TKey, TValue>): Observable.Observable<{ TKey }>
	return self._observableMapOfSets:ObserveKeyList()
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMapSet.ObserveKeysBrio<TKey, TValue>(self: ObservableMapSet<TKey, TValue>): Observable.Observable<_Brio.Brio<TKey>>
	return self._observableMapOfSets:ObserveKeysBrio()
end

--[=[
	Gets how many sets exist
	@return number
]=]
function ObservableMapSet.GetSetCount<TKey, TValue>(self: ObservableMapSet<TKey, TValue>): number
	return self._observableMapOfSets:GetCount()
end

ObservableMapSet.__len = ObservableMapSet.GetSetCount

--[=[
	Observes how many sets exist
	@return Observable<number>
]=]
function ObservableMapSet.ObserveSetCount<TKey, TValue>(self: ObservableMapSet<TKey, TValue>): Observable.Observable<number>
	return self._observableMapOfSets:ObserveCount()
end

--[=[
	Observes all items for the given key
	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMapSet.ObserveItemsForKeyBrio<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	key: TKey
): Observable.Observable<_Brio.Brio<TValue>>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(set)
			if set then
				return set:ObserveItemsBrio()
			else
				return Rx.EMPTY
			end
		end),
	})
end

--[=[
	Gets the first item for the given key
	@param key TKey
	@return TValue?
]=]
function ObservableMapSet.GetFirstItemForKey<TKey, TValue>(self: ObservableMapSet<TKey, TValue>, key: TKey): TValue?
	assert(key ~= nil, "Bad key")

	local observableSet: ObservableSet.ObservableSet<TValue> = self:GetObservableSetForKey(key) :: any
	if not observableSet then
		return nil
	end

	return observableSet:GetFirstItem()
end

--[=[
	Gets a list for a given key
	@param key TKey
	@return { TValue }
]=]
function ObservableMapSet.GetListForKey<TKey, TValue>(self: ObservableMapSet<TKey, TValue>, key: TKey): _Table.Array<TValue>
	assert(key ~= nil, "Bad key")

	local observableSet = self:GetObservableSetForKey(key)
	if not observableSet then
		return {}
	end

	return observableSet:GetList()
end

--[=[
	Gets the observable set for the given key
	@param key TKey
	@return ObservableSet<TValue>
]=]
function ObservableMapSet.GetObservableSetForKey<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	key: TKey
): ObservableSet.ObservableSet<TValue>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:Get(key)
end

--[=[
	Observes the observable set for the given key

	@param key TKey
	@return Observable<Brio<ObservableSet<TValue>>>
]=]
function ObservableMapSet.ObserveSetBrio<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	key: TKey
): Observable.Observable<
	_Brio.Brio<ObservableSet.ObservableSet<TValue>>
>
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:ObserveAtKeyBrio(key)
end

--[=[
	Observes the number of entries for the given key

	@param key TKey
	@return Observable<number>
]=]
function ObservableMapSet.ObserveCountForKey<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	key: TKey
): Observable.Observable<number>
	assert((key :: any) ~= nil, "Bad key")

	return self:ObserveSetBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(observableSet)
			return observableSet:ObserveCount()
		end) :: any,
		RxBrioUtils.emitOnDeath(0) :: any,
	} :: any) :: any
end

function ObservableMapSet._addToSet<TKey, TValue>(self: ObservableMapSet<TKey, TValue>, key: TKey, entry: TValue): () -> ()
	local set = self:_getOrCreateSet(key)
	return set:Add(entry)
end

function ObservableMapSet._getOrCreateSet<TKey, TValue>(
	self: ObservableMapSet<TKey, TValue>,
	key: TKey
): ObservableSet.ObservableSet<TValue>
	local existing = self._observableMapOfSets:Get(key)
	if existing then
		return existing
	end

	local maid = Maid.new()
	local set = maid:Add(ObservableSet.new())

	maid:GiveTask(set.CountChanged:Connect(function(count)
		if count <= 0 then
			self._maid[set] = nil
		end
	end))

	maid:GiveTask(self._observableMapOfSets:Set(key, set))
	self._maid[set] = maid

	return set
end

--[=[
	Cleans up the ObservableMapSet and sets the metatable to nil.
]=]
function ObservableMapSet.Destroy<TKey, TValue>(self: ObservableMapSet<TKey, TValue>)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return ObservableMapSet
