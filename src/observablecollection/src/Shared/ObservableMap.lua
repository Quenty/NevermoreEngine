--!strict
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
local _SortFunctionUtils = require("SortFunctionUtils")

local ObservableMap = {}
ObservableMap.ClassName = "ObservableMap"
ObservableMap.__index = ObservableMap

export type ObservableMap<TKey, TValue> = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_map: { [TKey]: TValue },
		_keySubTable: any, -- ObservableSubscriptionTable.ObservableSubscriptionTable<TKey>,
		_countValue: ValueObject.ValueObject<number>,

		--[=[
			Fires when a key is added
			@readonly
			@prop KeyAdded Signal<TKey, TValue?>
			@within ObservableMap
		]=]
		KeyAdded: Signal.Signal<(TKey, TValue)>,

		--[=[
			Fires when a key is removed
			@readonly
			@prop KeyRemoved Signal<TKey>
			@within ObservableMap
		]=]
		KeyRemoved: Signal.Signal<TKey>,

		--[=[
			Fires when a key value changes, including add and remove.
			@readonly
			@prop KeyValueChanged Signal<(TKey, TValue?, TValue?)>
			@within ObservableMap
		]=]
		KeyValueChanged: Signal.Signal<(TKey, TValue?, TValue?)>,

		--[=[
			Fires when the count changes.
			@prop CountChanged Signal.Signal<number>
			@within ObservableMap
		]=]
		CountChanged: Signal.Signal<number>,
	},
	{} :: typeof({ __index = ObservableMap })
))

--[=[
	Constructs a new ObservableMap
	@return ObservableMap<TKey, TValue>
]=]
function ObservableMap.new<TKey, TValue>(): ObservableMap<TKey, TValue>
	local self: any = setmetatable({} :: any, ObservableMap)

	self._maid = Maid.new()
	self._map = {}

	self._keySubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._countValue = self._maid:Add(ValueObject.new(0, "number"))

	self.KeyAdded = self._maid:Add(Signal.new()) -- :Fire(key, value)
	self.KeyRemoved = self._maid:Add(Signal.new()) -- :Fire(key)
	self.KeyValueChanged = self._maid:Add(Signal.new()) -- :Fire(key, value, oldValue)
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Returns whether the set is an observable map
	@param value any
	@return boolean
]=]
function ObservableMap.isObservableMap(value: any): boolean
	return DuckTypeUtils.isImplementation(ObservableMap, value)
end

--[=[
	Allows iteration over the observable map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableMap.__iter<TKey, TValue>(self: ObservableMap<TKey, TValue>): ...any
	return pairs(self._map)
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMap.ObserveKeysBrio<TKey, TValue>(self: ObservableMap<TKey, TValue>): Observable.Observable<Brio.Brio<TKey>>
	return self:_observeKeyValueChanged(function(key: TKey, _value: TValue)
		return Brio.new(key)
	end) :: any
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<TKey>>
]=]
function ObservableMap.ObserveValuesBrio<TKey, TValue>(self: ObservableMap<TKey, TValue>): Observable.Observable<Brio.Brio<TValue>>
	return self:_observeKeyValueChanged(function(_key: TKey, value: TValue)
		return Brio.new(value)
	end) :: any
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<(TKey, TValue)>>
]=]
function ObservableMap.ObservePairsBrio<TKey, TValue>(
	self: ObservableMap<TKey, TValue>
): Observable.Observable<Brio.Brio<(TKey, TValue)>>
	return self:_observeKeyValueChanged(function(key: TKey, value: TValue)
		return Brio.new(key, value)
	end) :: any
end

function ObservableMap._observeKeyValueChanged<TKey, TValue>(
	self: ObservableMap<TKey, TValue>,
	packValue: (TKey, TValue) -> any
): Observable.Observable<Brio.Brio<(TKey, TValue)>>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleValue(key: TKey, value: TValue?, _oldValue: TValue?)
			if value ~= nil then
				local brio = packValue(key, value)
				maid[key :: any] = brio
				sub:Fire(brio)
			else
				maid[key :: any] = nil
			end
		end

		for key, value in self._map do
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
	end) :: any
end

--[=[
	Returns the value for the given key
	@param key TKey
	@return TValue
]=]
function ObservableMap.Get<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey): TValue?
	assert(key ~= nil, "Bad key")

	return self._map[key]
end

--[=[
	Returns whether the map contains the key
	@param key TKey
	@return boolean
]=]
function ObservableMap.ContainsKey<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey): boolean
	assert(key ~= nil, "Bad key")

	return self._map[key] ~= nil
end

--[=[
	Gets the count of items in the set
	@return number
]=]
function ObservableMap.GetCount<TKey, TValue>(self: ObservableMap<TKey, TValue>): number
	return self._countValue.Value or 0
end

ObservableMap.__len = ObservableMap.GetCount

--[=[
	Observes the count of the set

	@return Observable<number>
]=]
function ObservableMap.ObserveCount<TKey, TValue>(self: ObservableMap<TKey, TValue>): Observable.Observable<number>
	return self._countValue:Observe()
end

--[=[
	Observes the value for the given key.

	@param key TKey
	@return Observable<Brio<TValue>>
]=]
function ObservableMap.ObserveAtKeyBrio<TKey, TValue>(
	self: ObservableMap<TKey, TValue>,
	key: TKey
): Observable.Observable<Brio.Brio<TValue>>
	assert(key ~= nil, "Bad key")

	return self:ObserveAtKey(key):Pipe({
		RxBrioUtils.switchToBrio(function(value)
			return value ~= nil
		end),
	}) :: any
end

--[=[
	Observes the value for the given key.

	@param key TKey
	@return Observable<TValue?>
]=]
function ObservableMap.ObserveAtKey<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey): Observable.Observable<TValue?>
	assert(key ~= nil, "Bad key")

	return self._keySubTable:Observe(key, function(sub)
		sub:Fire(self._map[key] :: any)
	end) :: any
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
function ObservableMap.Set<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey, value: TValue?): () -> ()
	assert(key ~= nil, "Bad key")

	local oldValue: TValue? = self._map[key]
	if oldValue == value then
		-- no removal since we never added. this is a tad messy.
		return function() end
	end

	self._map[key] = value :: any

	if value == nil then
		self._countValue.Value = self._countValue.Value - 1
		self.KeyRemoved:Fire(key)
	elseif oldValue == nil then
		self._countValue.Value = self._countValue.Value + 1
		self.KeyAdded:Fire(key, value)
	end

	self.KeyValueChanged:Fire(key, value, oldValue)
	self._keySubTable:Fire(key, value)

	return self:_getRemovalCallback(key, value)
end

function ObservableMap._getRemovalCallback<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey, value: TValue?): () -> ()
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
function ObservableMap.Remove<TKey, TValue>(self: ObservableMap<TKey, TValue>, key: TKey): ()
	assert(key ~= nil, "Bad key")

	self:Set(key, nil)
end

--[=[
	Gets a list of all values.
	@return { TValue }
]=]
function ObservableMap.GetValueList<TKey, TValue>(self: ObservableMap<TKey, TValue>): { TValue }
	local list = table.create(self._countValue.Value)
	for _, value in self._map do
		table.insert(list, value)
	end
	return list
end

--[=[
	Gets a list of all keys.
	@return { TKey }
]=]
function ObservableMap.GetKeyList<TKey, TValue>(self: ObservableMap<TKey, TValue>): { TKey }
	local list = table.create(self._countValue.Value)
	for key, _ in self._map do
		table.insert(list, key)
	end
	return list
end

--[=[
	Observes the list of all keys.
	@return Observable<{ TKey }>
]=]
function ObservableMap.ObserveKeyList<TKey, TValue>(self: ObservableMap<TKey, TValue>): Observable.Observable<{ TKey }>
	return Observable.new(function(sub)
		local topMaid = Maid.new()

		-- TODO: maybe don't allocate as much here?
		local keyList = table.create(self._countValue.Value)
		for key, _ in self._map do
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
	end) :: any
end

--[=[
	Cleans up the ObservableMap and sets the metatable to nil.
]=]
function ObservableMap.Destroy<TKey, TValue>(self: ObservableMap<TKey, TValue>)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return ObservableMap