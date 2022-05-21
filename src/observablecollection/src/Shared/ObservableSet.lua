--[=[
	A list that can be observed for blend and other components
	@class ObservableSet
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxValueBaseUtils = require("RxValueBaseUtils")

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

	self._countValue = Instance.new("IntValue")
	self._countValue.Value = 0
	self._maid:GiveTask(self._countValue)

--[=[
	Fires when an item is added
	@readonly
	@prop ItemAdded Signal<T>
	@within ObservableSet
]=]
	self.ItemAdded = Signal.new()
	self._maid:GiveTask(self.ItemAdded)

--[=[
	Fires when an item is removed.
	@readonly
	@prop ItemRemoved Signal<T>
	@within ObservableSet
]=]
	self.ItemRemoved = Signal.new()
	self._maid:GiveTask(self.ItemRemoved)

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableSet
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Returns whether the value is an observable set
	@param value any
	@return boolean
]=]
function ObservableSet.isObservableSet(value)
	return type(value) == "table" and getmetatable(value) == ObservableSet
end

--[=[
	Observes all items in the set
	@return Observable<Brio<T>>
]=]
function ObservableSet:ObserveItemsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItem(item)
			local brio = Brio.new(item)
			maid[item] = brio
			sub:Fire(brio)
		end

		for item, _ in pairs(self._set) do
			handleItem(item)
		end

		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(item)
			maid[item] = nil
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
	return self._countValue.Value
end

--[=[
	Observes the count of the set
	@return Observable<number>
]=]
function ObservableSet:ObserveCount()
	return RxValueBaseUtils.observeValue(self._countValue)
end

--[=[
	Adds the item to the set if it does not exists.
	@param item T
	@return callback -- Call to remove
]=]
function ObservableSet:Add(item)
	assert(item ~= nil, "Bad item")

	if not self._set[item] then
		self._countValue.Value = self._countValue.Value + 1
		self._set[item] = true
		self.ItemAdded:Fire(item)
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
		self._countValue.Value = self._countValue.Value - 1
		self._set[item] = nil

		if self.Destroy then
			self.ItemRemoved:Fire(item)
		end
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
	local list = {}
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
	local set = {}
	for item, _ in pairs(self._set) do
		set[item] = true
	end
	return set
end

--[=[
	Cleans up the ObservableSet and sets the metatable to nil.
]=]
function ObservableSet:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableSet