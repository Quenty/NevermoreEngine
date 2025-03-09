--[=[
	A list that can be observed for blend and other components
	@class ObservableMap
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Signal = require("Signal")
local ValueObject = require("ValueObject")
local RxBrioUtils = require("RxBrioUtils")
local DuckTypeUtils = require("DuckTypeUtils")

local ObservableMap = {}
ObservableMap.ClassName = "ObservableMap"
ObservableMap.__index = ObservableMap

--[=[
	Constructs a new ObservableMap
	@return ObservableMap<TKey, TValue>
]=]
function ObservableMap.new()
	local self = setmetatable({}, ObservableMap)

	self._maid = Maid.new()
	self._map = {}

	self._keySubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._countValue = self._maid:Add(ValueObject.new(0, "number"))

--[=[
	Fires when a key is added
	@readonly
	@prop KeyAdded Signal<TKey>
	@within ObservableMap
]=]
	self.KeyAdded = self._maid:Add(Signal.new()) -- :Fire(key, value)

--[=[
	Fires when a key is removed
	@readonly
	@prop KeyRemoved Signal<TKey>
	@within ObservableMap
]=]
	self.KeyRemoved = self._maid:Add(Signal.new()) -- :Fire(key)

--[=[
	Fires when a key value changes, including add and remove.
	@readonly
	@prop KeyValueChanged Signal<(TKey, TValue, TValue)>
	@within ObservableMap
]=]
	self.KeyValueChanged = self._maid:Add(Signal.new()) -- :Fire(key, value, oldValue)

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableMap
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Returns whether the set is an observable map
	@param value any
	@return boolean
]=]
function ObservableMap.isObservableMap(value)
	return DuckTypeUtils.isImplementation(ObservableMap, value)
end

--[=[
	Allows iteration over the observable map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableMap:__iter()
	return pairs(self._map)
end


--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMap:ObserveKeysBrio()
	return self:_observeKeyValueChanged(function(key, _value)
		return Brio.new(key)
	end)
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMap:ObserveValuesBrio()
	return self:_observeKeyValueChanged(function(_key, value)
		return Brio.new(value)
	end)
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<(TKey, TValue)>>
]=]
function ObservableMap:ObservePairsBrio()
	return self:_observeKeyValueChanged(function(key, value)
		return Brio.new(key, value)
	end)
end

function ObservableMap:_observeKeyValueChanged(packValue)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleValue(key, value)
			if value ~= nil then
				local brio = packValue(key, value)
				maid[key] = brio
				sub:Fire(brio)
			else
				maid[key] = nil
			end
		end

		for key, value in pairs(self._map) do
			handleValue(key, value)
		end

		local conn = self.KeyValueChanged:Connect(handleValue)

		local function cleanup()
			self._maid[sub] = nil
			conn:Disconnect()
			sub:Complete()
			maid:Destroy()
		end
		self._maid[sub] = cleanup
		return cleanup
	end)
end

--[=[
	Returns the value for the given key
	@param key TKey
	@return TValue
]=]
function ObservableMap:Get(key)
	assert(key ~= nil, "Bad key")

	return self._map[key]
end

--[=[
	Returns whether the map contains the key
	@param key TKey
	@return boolean
]=]
function ObservableMap:ContainsKey(key)
	assert(key ~= nil, "Bad key")

	return self._map[key] ~= nil
end

--[=[
	Gets the count of items in the set
	@return number
]=]
function ObservableMap:GetCount()
	return self._countValue.Value or 0
end

ObservableMap.__len = ObservableMap.GetCount

--[=[
	Observes the count of the set

	@return Observable<number>
]=]
function ObservableMap:ObserveCount()
	return self._countValue:Observe()
end

--[=[
	Observes the value for the given key.

	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMap:ObserveAtKeyBrio(key)
	assert(key ~= nil, "Bad key")

	return self:ObserveAtKey(key):Pipe({
		RxBrioUtils.switchToBrio(function(value)
			return value ~= nil
		end);
	})
end

--[=[
	Observes the value for the given key.

	@param key TKey
	@return Observable<TValue?>
]=]
function ObservableMap:ObserveAtKey(key)
	assert(key ~= nil, "Bad key")

	return self._keySubTable:Observe(key, function(sub)
		sub:Fire(self._map[key])
	end)
end

--[=[
	Observes the value for the given key. Alias for [ObservableMap.ObserveAtKey].

	@function ObserveValueForKey
	@param key TKey
	@return Observable<TValue?>
	@within ObservableMap
]=]
ObservableMap.ObserveValueForKey = ObservableMap.ObserveAtKey

--[=[
	Adds the item to the set if it does not exists.
	@param key TKey
	@param value TValue?
	@return callback -- Call to remove the value if it was added
]=]
function ObservableMap:Set(key, value)
	assert(key ~= nil, "Bad key")

	local oldValue = self._map[key]
	if oldValue == value then
		-- no removal since we never added. this is a tad messy.
		return function()

		end
	end

	self._map[key] = value

	if oldValue == nil then
		self._countValue.Value = self._countValue.Value + 1
		self.KeyAdded:Fire(key, value)
	elseif value == nil then
		self._countValue.Value = self._countValue.Value - 1
		self.KeyRemoved:Fire(key)
	end

	self.KeyValueChanged:Fire(key, value, oldValue)
	self._keySubTable:Fire(key, value)

	return self:_getRemovalCallback(key, value)
end

function ObservableMap:_getRemovalCallback(key, value)
	return function()
		if not self.Destroy then
			return
		end

		if self._map[key] == value then
			self:Remove(key)
		end
	end
end

--[=[
	Removes the item from the map if it exists.
	@param key TKey
]=]
function ObservableMap:Remove(key)
	assert(key ~= nil, "Bad key")

	self:Set(key, nil)
end

--[=[
	Gets a list of all values.
	@return { TValue }
]=]
function ObservableMap:GetValueList()
	local list = table.create(self._countValue.Value)
	for _, value in pairs(self._map) do
		table.insert(list, value)
	end
	return list
end

--[=[
	Gets a list of all keys.
	@return { TKey }
]=]
function ObservableMap:GetKeyList()
	local list = table.create(self._countValue.Value)
	for key, _ in pairs(self._map) do
		table.insert(list, key)
	end
	return list
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMap:ObserveKeyList()
	return Observable.new(function(sub)
		local topMaid = Maid.new()

		-- TODO: maybe don't allocate as much here?
		local keyList = table.create(self._countValue.Value)
		for key, _ in pairs(self._map) do
			table.insert(keyList, key)
		end

		topMaid:GiveTask(self.KeyAdded:Connect(function(addedKey)
			table.insert(keyList, addedKey)
			sub:Fire(table.clone(keyList))
		end))

		topMaid:GiveTask(self.KeyRemoved:Connect(function(removedKey)
			local index = table.find(keyList, removedKey)
			if index then
				table.remove(keyList, index)
			end
			sub:Fire(table.clone(keyList))
		end))

		sub:Fire(table.clone(keyList))

		return topMaid
	end)
end

--[=[
	Cleans up the ObservableMap and sets the metatable to nil.
]=]
function ObservableMap:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableMap