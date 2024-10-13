--[=[
	A list that can be observed for blend and other components
	@class ObservableSet
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local ValueObject = require("ValueObject")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local DuckTypeUtils = require("DuckTypeUtils")

local ObservableSet = {}
ObservableSet.ClassName = "ObservableSet"
ObservableSet.__index = ObservableSet

--[=[
	Constructs a new ObservableSet
	@return ObservableSet<T>
]=]
function ObservableSet.new()
	local self = setmetatable({}, ObservableSet)

	self._maid = Maid.new()
	self._set = {}

	self._containsObservables = self._maid:Add(ObservableSubscriptionTable.new())
	self._countValue = self._maid:Add(ValueObject.new(0, "number"))

--[=[
	Fires when an item is added
	@readonly
	@prop ItemAdded Signal<T>
	@within ObservableSet
]=]
	self.ItemAdded = self._maid:Add(Signal.new())

--[=[
	Fires when an item is removed.
	@readonly
	@prop ItemRemoved Signal<T>
	@within ObservableSet
]=]
	self.ItemRemoved = self._maid:Add(Signal.new())

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableSet
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Constructs an ObservableSet populated via an observable of Brios
	@param observable Observable<Brio<T>>
	@return ObservableSet<T>
]=]
function ObservableSet.fromObservableBrio(observable)
	local set = ObservableSet.new()

	set._maid:GiveTask(observable:Subscribe(function(value)
		assert(Brio.isBrio(value), "Observable must emit brio")

		if value:IsDead() then
			return
		end

		value:ToMaid():GiveTask(set:Add(value:GetValue()))
	end))

	return set
end

--[=[
	Returns whether the value is an observable set
	@param value any
	@return boolean
]=]
function ObservableSet.isObservableSet(value)
	return DuckTypeUtils.isImplementation(ObservableSet, value)
end

--[=[
	Observes all items in the set
	@return Observable<Brio<T>>
]=]
function ObservableSet:ObserveItemsBrio()
	return Observable.new(function(sub)
		if not self.Destroy then
			return sub:Fail("ObservableSet is already cleaned up")
		end

		local maid = Maid.new()

		local function handleItem(item)
			if maid[item] then
				-- Happens when we're re-entrance
				return
			end

			local brio = Brio.new(item)
			maid[item] = brio
			sub:Fire(brio)
		end


		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(item)
			maid[item] = nil
		end))

		for item, _ in pairs(self._set) do
			handleItem(item)
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
	Observes the current value at a given index. This can be useful for observing
	the first entry, or matching stuff up to a given slot.

	@param item T
	@return Observable<boolean>
]=]
function ObservableSet:ObserveContains(item)
	assert(item ~= nil, "Bad item")

	return Observable.new(function(sub)
		if not self.Destroy then
			return sub:Fail("ObservableSet is already cleaned up")
		end

		local maid = Maid.new()

		if self._set[item] then
			sub:Fire(true)
		else
			sub:Fire(false)
		end

		maid:GiveTask(self._containsObservables:Observe(item):Subscribe(function(doesContain)
			sub:Fire(doesContain)
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
	Returns whether the set contains the item
	@param item T
	@return boolean
]=]
function ObservableSet:Contains(item)
	assert(item ~= nil, "Bad item")

	return self._set[item] == true
end

--[=[
	Gets the count of items in the set
	@return number
]=]
function ObservableSet:GetCount()
	return self._countValue.Value or 0
end

--[=[
	Observes the count of the set
	@return Observable<number>
]=]
function ObservableSet:ObserveCount()
	return self._countValue:Observe()
end

--[=[
	Adds the item to the set if it does not exists.
	@param item T
	@return callback -- Call to remove
]=]
function ObservableSet:Add(item)
	assert(item ~= nil, "Bad item")

	if not self._set[item] then
		self._set[item] = true

		-- Fire events
		self._countValue.Value = self._countValue.Value + 1
		self.ItemAdded:Fire(item)
		self._containsObservables:Fire(item, true)
	end

	return function()
		if self.Destroy then
			self:Remove(item)
		end
	end
end

--[=[
	Removes the item from the set if it exists.
	@param item T
]=]
function ObservableSet:Remove(item)
	assert(item ~= nil, "Bad item")

	if self._set[item] then
		self._set[item] = nil

		-- Fire in reverse order
		self._containsObservables:Fire(item, false)
		if self.Destroy then
			self.ItemRemoved:Fire(item)
		end
		self._countValue.Value = self._countValue.Value - 1
	end
end

--[=[
	Gets an arbitrary item in the set (not guaranteed to be ordered)
	@return T
]=]
function ObservableSet:GetFirstItem()
	local value = next(self._set)
	return value
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableSet:GetList()
	local list = table.create(self._countValue.Value)
	for item, _ in pairs(self._set) do
		table.insert(list, item)
	end
	return list
end

--[=[
	Gets a copy of the set
	@return { [T]: true }
]=]
function ObservableSet:GetSetCopy()
	return table.clone(self._set)
end

--[=[
	Gets the raw set. Do not modify this set.
	@return { [T]: true }
]=]
function ObservableSet:GetRawSet()
	return self._set
end


--[=[
	Cleans up the ObservableSet and sets the metatable to nil.
]=]
function ObservableSet:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableSet