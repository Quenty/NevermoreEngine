--[=[
	An observable map that counts up/down and removes when the count is zero.
	@class ObservableCountingMap
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local ValueObject = require("ValueObject")
local DuckTypeUtils = require("DuckTypeUtils")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")

local ObservableCountingMap = {}
ObservableCountingMap.ClassName = "ObservableCountingMap"
ObservableCountingMap.__index = ObservableCountingMap

--[=[
	Constructs a new ObservableCountingMap
	@return ObservableCountingMap<T>
]=]
function ObservableCountingMap.new()
	local self = setmetatable({}, ObservableCountingMap)

	self._maid = Maid.new()
	self._map = {}

	self._totalKeyCountValue = self._maid:Add(ValueObject.new(0, "number"))
	self._keySubTable = self._maid:Add(ObservableSubscriptionTable.new())

--[=[
	Fires when an key is added
	@readonly
	@prop KeyAdded Signal<T>
	@within ObservableCountingMap
]=]
	self.KeyAdded = self._maid:Add(Signal.new())

--[=[
	Fires when an key is removed.
	@readonly
	@prop KeyRemoved Signal<T>
	@within ObservableCountingMap
]=]
	self.KeyRemoved = self._maid:Add(Signal.new())

--[=[
	Fires when an item count changes
	@readonly
	@prop KeyChanged Signal<T>
	@within ObservableCountingMap
]=]
	self.KeyChanged = self._maid:Add(Signal.new())

--[=[
	Fires when the total count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableCountingMap
]=]
	self.TotalKeyCountChanged = self._totalKeyCountValue.Changed

	return self
end

--[=[
	Returns whether the value is an observable counting map
	@param value any
	@return boolean
]=]
function ObservableCountingMap.isObservableMap(value)
	return DuckTypeUtils.isImplementation(ObservableCountingMap, value)
end

--[=[
	Allows iteration over the observable counting map

	@return (T) -> ((T, nextIndex: any) -> ...any, T?)
]=]
function ObservableCountingMap:__iter()
	return pairs(self._map)
end

--[=[
	Observes the current set of active keys
	@return Observable<{ T }>
]=]
function ObservableCountingMap:ObserveKeysList()
	return self:_observeDerivedDataStructureFromKeys(function()
		local list = table.create(self._totalKeyCountValue.Value)

		for key, _ in pairs(self._map) do
			table.insert(list, key)
		end

		return list
	end)
end

--[=[
	Observes the current set of active keys
	@return Observable<{ [T]: true }>
]=]
function ObservableCountingMap:ObserveKeysSet()
	return self:_observeDerivedDataStructureFromKeys(function()
		local set = {}

		for key, _ in pairs(self._map) do
			set[key] = true
		end

		return set
	end)
end

function ObservableCountingMap:_observeDerivedDataStructureFromKeys(gatherValues)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function emit()
			sub:Fire(gatherValues())
		end

		maid:GiveTask(self.KeyAdded:Connect(emit))
		maid:GiveTask(self.KeyRemoved:Connect(emit))

		emit()

		self._maid[sub] = maid
		maid:GiveTask(function()
			self._maid[sub] = nil
			sub:Complete()
		end)

		return maid
	end)
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<(T, number)>>
]=]
function ObservableCountingMap:ObservePairsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleValue(key, value)
			if value ~= 0 then
				local brio = Brio.new(key, value)
				maid[key] = brio
				sub:Fire(brio)
			else
				maid[key] = nil
			end
		end

		for key, value in pairs(self._map) do
			handleValue(key, value)
		end

		maid:GiveTask(self.KeyChanged:Connect(handleValue))

		self._maid[sub] = maid
		maid:GiveTask(function()
			self._maid[sub] = nil
			sub:Complete()
		end)

		return maid

	end)
end

--[=[
	Observes the value for the given key.

	@param key TKey
	@return Observable<TValue?>
]=]
function ObservableCountingMap:ObserveAtKey(key)
	assert(key ~= nil, "Bad key")

	return self._keySubTable:Observe(key, function(sub)
		sub:Fire(self._map[key] or 0)
	end)
end

--[=[
	Observes all keys in the map
	@return Observable<Brio<T>>
]=]
function ObservableCountingMap:ObserveKeysBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()
		local keyMaid = maid:Add(Maid.new())

		local function handleItem(key)
			-- Happens upon key added re-entrance
			if keyMaid[key] then
				return
			end

			local brio = Brio.new(key)
			keyMaid[key] = brio
			sub:Fire(brio)
		end

		maid:GiveTask(self.KeyAdded:Connect(handleItem))
		maid:GiveTask(self.KeyRemoved:Connect(function(key)
			keyMaid[key] = nil
		end))

		for key, _ in pairs(self._map) do
			handleItem(key)
		end

		self._maid[sub] = maid
		maid:GiveTask(function()
			self._maid[sub] = nil
			sub:Complete()
		end)

		return maid
	end)
end

--[=[
	Returns whether the map contains the key
	@param key T
	@return boolean
]=]
function ObservableCountingMap:Contains(key)
	assert(key ~= nil, "Bad key")

	return self._map[key] ~= nil
end

--[=[
	Returns the count for the key or 0 if there is no key
	@param key T
	@return number
]=]
function ObservableCountingMap:Get(key)
	assert(key ~= nil, "Bad key")

	return self._map[key] or 0
end

--[=[
	Gets the count of keys in the map
	@return number
]=]
function ObservableCountingMap:GetTotalKeyCount()
	return self._totalKeyCountValue.Value
end

--[=[
	Observes the count of the keys in the map
	@return Observable<number>
]=]
function ObservableCountingMap:ObserveTotalKeyCount()
	return self._totalKeyCountValue:Observe()
end

--[=[
	Sets the current value
	@param key T
	@param amount number?
	@return callback
]=]
function ObservableCountingMap:Set(key, amount)
	local current = self:Get(key)
	if current < amount then
		self:Add(-(amount - current))
	elseif current > amount then
		self:Add(current - amount)
	end
end

--[=[
	Adds the key to the map if it does not exists.
	@param key T
	@param amount number?
	@return callback
]=]
function ObservableCountingMap:Add(key, amount)
	assert(key ~= nil, "Bad key")
	assert(type(amount) == "number" or amount == nil, "Bad amount")
	amount = amount or 1

	if amount == 0 then
		return function()

		end
	end

	local oldValue = self._map[key]

	if oldValue then
		local newValue = oldValue + amount
		if newValue == 0 then
			-- Remove item
			self._map[key] = nil

			-- Fire events
			self._totalKeyCountValue.Value = self._totalKeyCountValue.Value - 1

			if self.Destroy then
				self.KeyRemoved:Fire(key)
			end

			if self.Destroy then
				self.KeyChanged:Fire(key, 0)
				self._keySubTable:Fire(key, 0)
			end
		else
			-- Update item
			self._map[key] = newValue
			self.KeyChanged:Fire(key, newValue)
			self._keySubTable:Fire(key, newValue)
		end
	else
		-- Add item
		self._map[key] = amount

		-- Fire events
		self._totalKeyCountValue.Value = self._totalKeyCountValue.Value + 1

		if self.Destroy then
			self.KeyAdded:Fire(key)
		end

		if self.Destroy then
			self.KeyChanged:Fire(key, amount)
			self._keySubTable:Fire(key, amount)
		end
	end

	local removed = false
	return function()
		if self.Destroy and not removed then
			removed = true
			self:Add(key, -amount)
		end
	end
end

--[=[
	Removes the key from the set if it exists.
	@param key T
	@param amount number?
	@return callback
]=]
function ObservableCountingMap:Remove(key, amount)
	assert(key ~= nil, "Bad key")
	assert(type(amount) == "number" or amount == nil, "Bad amount")
	amount = amount or 1

	self:Add(key, -amount)
end

--[=[
	Gets the first key
	@return T
]=]
function ObservableCountingMap:GetFirstKey()
	local value = next(self._map)
	return value
end

--[=[
	Gets a list of all keys.
	@return { T }
]=]
function ObservableCountingMap:GetKeyList()
	local list = table.create(self._totalKeyCountValue.Value)
	for key, _ in pairs(self._map) do
		table.insert(list, key)
	end
	return list
end

--[=[
	Cleans up the ObservableCountingMap and sets the metatable to nil.
]=]
function ObservableCountingMap:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableCountingMap