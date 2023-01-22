--[=[
	Holds a map of sets. That is, for a given key, a set of all valid entries. This is great
	for looking up something that may have duplicate keys, like configurations or other things.

	@class ObservableMapSet
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSet = require("ObservableSet")
local Signal = require("Signal")
local Brio = require("Brio")
local RxBrioUtils = require("RxBrioUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")

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
	self._observableSetMap = {} -- [key] = ObservableSet<TEntry>

--[=[
	Fires when an item is added
	@readonly
	@prop SetAdded Signal<TKey>
	@within ObservableMapSet
]=]
	self.SetAdded = Signal.new() -- :Fire(key, set)
	self._maid:GiveTask(self.SetAdded)

--[=[
	Fires when an item is removed
	@readonly
	@prop SetRemoved Signal<TKey>
	@within ObservableMapSet
]=]
	self.SetRemoved = Signal.new() -- :Fire(key)
	self._maid:GiveTask(self.SetRemoved)

	self._setCount = Instance.new("IntValue")
	self._setCount.Value = 0
	self._maid:GiveTask(self._setCount)

	return self
end

--[=[
	Adds an entry with a dynamic key. This is great for caching things
	that need to be looked up by key.

	@param entry TValue
	@param observeKey Observable<TKey>
]=]
function ObservableMapSet:Add(entry, observeKey)
	local maid = Maid.new()

	local lastKey = nil
	local function removeLastEntry()
		if lastKey then
			self:_removeFromObservableSet(lastKey, entry)
		end
		lastKey = nil
	end

	maid:GiveTask(observeKey:Subscribe(function(key)
		removeLastEntry()

		if key then
			self:_addToObservableSet(key, entry)
		end

		lastKey = key
	end))


	maid:GiveTask(removeLastEntry)

	-- Ensure self-cleanup when map cleans up
	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	Gets how many sets exist
	@return number
]=]
function ObservableMapSet:GetSetCount()
	return self._setCount.Value
end

--[=[
	Observes how many sets exist
	@return Observable<number>
]=]
function ObservableMapSet:ObserveSetCount()
	return RxValueBaseUtils.observeValue(self._setCount)
end

--[=[
	Observes all items for the given key
	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMapSet:ObserveItemsForKeyBrio(key)
	assert(key ~= nil, "Bad key")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function connect()
			local maid = Maid.new()

			local set = self._observableSetMap[key]
			if set then
				maid:GiveTask(set:ObserveItemsBrio():Subscribe(function(brio)
					sub:Fire(brio)
				end))
			end

			topMaid._current = maid
		end

		topMaid:GiveTask(self.SetAdded:Connect(function(addedKey)
			if addedKey == key then
				connect()
			end
		end))

		topMaid:GiveTask(self.SetRemoved:Connect(function(removedKey)
			if removedKey == key then
				connect()
			end
		end))

		connect()

		return topMaid
	end)
end

--[=[
	Gets a list for a given key
	@param key TKey
	@return { TValue }
]=]
function ObservableMapSet:GetListForKey(key)
	assert(key ~= nil, "Bad key")

	local observableSet = self._observableSetMap[key]
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

	return self._observableSetMap[key]
end

function ObservableMapSet:ObserveSetBrio(key)
	assert(key ~= nil, "Bad key")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function connect()
			local brio

			local set = self._observableSetMap[key]
			if set then
				brio = Brio.new(set)
				sub:Fire(brio)
			end

			topMaid._current = brio
		end

		topMaid:GiveTask(self.SetAdded:Connect(function(addedKey)
			if addedKey == key then
				connect()
			end
		end))

		topMaid:GiveTask(self.SetRemoved:Connect(function(removedKey)
			if removedKey == key then
				connect()
			end
		end))

		connect()

		return topMaid
	end)
end

function ObservableMapSet:ObserveCountForKey(key)
	assert(key ~= nil, "Bad key")

	return self:ObserveSetBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(observableSet)
			return observableSet:ObserveCount()
		end);
		RxBrioUtils.emitOnDeath(0);
	})
end

function ObservableMapSet:_addToObservableSet(key, entry)
	local set = self:_getOrCreateObservableSet(key)
	set:Add(entry)
end

function ObservableMapSet:_removeFromObservableSet(key, entry)
	local set = self._observableSetMap[key]
	if not set then
		return
	end

	-- This happens when we're cleaning up sometimes
	if not set.Destroy then
		return
	end

	if set:Contains(entry) then
		set:Remove(entry)
		if set:GetCount() == 0 then
			self:_removeObservableSet(key)
		end
	end
end

function ObservableMapSet:_removeObservableSet(key)
	local set = self._observableSetMap[key]
	if set then
		self._observableSetMap[key] = nil

		-- Cleanup
		self._maid[set] = nil

		if self.SetRemoved.Destroy then
			self.SetRemoved:Fire(key)
		end

		self._setCount.Value = self._setCount.Value - 1
	end
end

function ObservableMapSet:_getOrCreateObservableSet(key)
	if self._observableSetMap[key] then
		return self._observableSetMap[key]
	end

	local maid = Maid.new()
	local set = ObservableSet.new()
	maid:GiveTask(set)

	self._observableSetMap[key] = set

	self.SetAdded:Fire(key, set)
	self._setCount.Value = self._setCount.Value + 1

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