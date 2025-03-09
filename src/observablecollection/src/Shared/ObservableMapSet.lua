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

local ObservableMapSet = {}
ObservableMapSet.ClassName = "ObservableMapSet"
ObservableMapSet.__index = ObservableMapSet

--[=[
	Constructs a new ObservableMapSet
	@return ObservableMapSet<TKey, TValue>
]=]
function ObservableMapSet.new()
	local self = setmetatable({}, ObservableMapSet)

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

function ObservableMapSet:Push(observeKey, entry)
	assert(observeKey ~= nil, "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	local maid = Maid.new()

	if Observable.isObservable(observeKey) then
		maid:GiveTask(observeKey:Subscribe(function(key)
			maid._currentAddValue = nil

			if key ~= nil then
				maid._currentAddValue = self:_addToSet(key, entry)
			end
		end))
	else
		maid:GiveTask(self:_addToSet(observeKey, entry))
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
function ObservableMapSet:Add(entry, observeKey)
	assert(Observable.isObservable(observeKey), "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	warn(string.format("[ObservableMapSet.Add] - This API call will swap observable key order eventually. Use ObservableMapSet.Push for now to suppress this warning.\n%s",
		debug.traceback()))

	return self:Push(observeKey, entry)
end

--[=[
	Gets a list of all keys.
	@return { TKey }
]=]
function ObservableMapSet:GetKeyList()
	return self._observableMapOfSets:GetKeyList()
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMapSet:ObserveKeyList()
	return self._observableMapOfSets:ObserveKeyList()
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMapSet:ObserveKeysBrio()
	return self._observableMapOfSets:ObserveKeysBrio()
end

--[=[
	Gets how many sets exist
	@return number
]=]
function ObservableMapSet:GetSetCount()
	return self._observableMapOfSets:GetCount()
end

ObservableMapSet.__len = ObservableMapSet.GetSetCount

--[=[
	Observes how many sets exist
	@return Observable<number>
]=]
function ObservableMapSet:ObserveSetCount()
	return self._observableMapOfSets:ObserveCount()
end

--[=[
	Observes all items for the given key
	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMapSet:ObserveItemsForKeyBrio(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(set)
			if set then
				return set:ObserveItemsBrio()
			else
				return Rx.EMPTY
			end
		end);
	})
end

--[=[
	Gets the first item for the given key
	@param key TKey
	@return TValue | nil
]=]
function ObservableMapSet:GetFirstItemForKey(key)
	assert(key ~= nil, "Bad key")

	local observableSet = self:GetObservableSetForKey(key)
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
function ObservableMapSet:GetListForKey(key)
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
function ObservableMapSet:GetObservableSetForKey(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:Get(key)
end

--[=[
	Observes the observable set for the given key

	@param key TKey
	@return Observable<Brio<ObservableSet<TValue>>>
]=]
function ObservableMapSet:ObserveSetBrio(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfSets:ObserveAtKeyBrio(key)
end

--[=[
	Observes the number of entries for the given key

	@param key TKey
	@return Observable<number>
]=]
function ObservableMapSet:ObserveCountForKey(key)
	assert(key ~= nil, "Bad key")

	return self:ObserveSetBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(observableSet)
			return observableSet:ObserveCount()
		end);
		RxBrioUtils.emitOnDeath(0);
	})
end


function ObservableMapSet:_addToSet(key, entry)
	local set = self:_getOrCreateSet(key)
	return set:Add(entry)
end

function ObservableMapSet:_getOrCreateSet(key)
	local existing = self._observableMapOfSets:Get(key)
	if existing then
		return existing
	end

	local maid = Maid.new()
	local set = maid:Add(ObservableSet.new(nil))

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
function ObservableMapSet:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end


return ObservableMapSet