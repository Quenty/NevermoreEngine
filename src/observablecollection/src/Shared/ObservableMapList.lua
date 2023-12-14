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

local ObservableMapList = {}
ObservableMapList.ClassName = "ObservableMapList"
ObservableMapList.__index = ObservableMapList

--[=[
	Constructs a new ObservableMapList
	@return ObservableMapList<TKey, TValue>
]=]
function ObservableMapList.new()
	local self = setmetatable({}, ObservableMapList)

	self._maid = Maid.new()
	self._observableMapOfLists = self._maid:Add(ObservableMap.new())

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
function ObservableMapList:Push(observeKey, entry)
	assert(observeKey ~= nil, "Bad observeKey")
	assert(entry ~= nil, "Bad entry")

	if not Observable.isObservable(observeKey) then
		observeKey = Rx.of(observeKey)
	end

	local maid = Maid.new()

	maid:GiveTask(observeKey:Subscribe(function(key)
		maid._currentAddValue = nil

		if key ~= nil then
			maid._currentAddValue = self:_addToList(key, entry)
		end
	end))

	-- Ensure self-cleanup when map cleans up
	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	Gets how many lists exist
	@return number
]=]
function ObservableMapList:GetListCount()
	return self._observableMapOfLists:GetCount()
end

--[=[
	Observes how many lists exist
	@return Observable<number>
]=]
function ObservableMapList:ObserveListCount()
	return self._observableMapOfLists:ObserveCount()
end

--[=[
	Gets the current value at the list index

	@param key TKey
	@param index number
	@return Observable<TValue?>
]=]
function ObservableMapList:GetAtListIndex(key, index)
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
function ObservableMapList:ObserveAtListIndex(key, index)
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	return self._observableMapOfLists:ObserveAtKey(key):Pipe({
		Rx.switchMap(function(list)
			if list then
				return list:ObserveAtIndex(index)
			else
				return Rx.of(nil)
			end
		end);
	})
end

--[=[
	Gets a list of all keys

	@return { TKey }
]=]
function ObservableMapList:GetKeyList()
	return self._observableMapOfLists:GetKeyList()
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMapList:ObserveKeyList()
	return self._observableMapOfLists:ObserveKeyList()
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMapList:ObserveKeysBrio()
	return self._observableMapOfLists:ObserveKeysBrio()
end

--[=[
	Observes the current value at the index

	@param key TKey
	@param index number
	@return Observable<Brio<TValue>>
]=]
function ObservableMapList:ObserveAtListIndexBrio(key, index)
	assert(key ~= nil, "Bad key")
	assert(type(index) == "number", "Bad index")

	return self._observableMapOfLists:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(list)
			return list:ObserveAtIndexBrio(index)
		end);
		RxBrioUtils.toBrio();
		RxBrioUtils.where(function(value)
			return value ~= nil
		end)
	})
end

--[=[
	Observes all items at the given key

	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMapList:ObserveItemsForKeyBrio(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKeyBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(list)
			if list then
				return list:ObserveItemsBrio()
			else
				return Rx.EMPTY
			end
		end);
	})
end

--[=[
	Gets a list for a given key.

	@param key TKey
	@return { TValue }
]=]
function ObservableMapList:GetListFromKey(key)
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
function ObservableMapList:GetListForKey(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:Get(key)
end

function ObservableMapList:ObserveList(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKey(key)
end

function ObservableMapList:ObserveListBrio(key)
	assert(key ~= nil, "Bad key")

	return self._observableMapOfLists:ObserveAtKeyBrio(key)
end

function ObservableMapList:ObserveCountForKey(key)
	assert(key ~= nil, "Bad key")

	return self:ObserveListBrio(key):Pipe({
		RxBrioUtils.switchMapBrio(function(observableList)
			return observableList:ObserveCount()
		end);
		RxBrioUtils.emitOnDeath(0);
	})
end

function ObservableMapList:_addToList(key, entry)
	local list = self:_getOrCreateList(key)
	return list:Add(entry)
end

function ObservableMapList:_removeList(list)
	self._maid[list] = nil
end

function ObservableMapList:_getOrCreateList(key)
	local existing = self._observableMapOfLists:Get(key)
	if existing then
		return existing
	end

	local maid = Maid.new()
	local list = maid:Add(ObservableList.new(nil))

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
function ObservableMapList:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end


return ObservableMapList