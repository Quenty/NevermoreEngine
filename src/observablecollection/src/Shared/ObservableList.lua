--[=[
	A list that can be observed for blend and other components
	@class ObservableList
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local Symbol = require("Symbol")
local ValueObject = require("ValueObject")
local Rx = require("Rx")

local ObservableList = {}
ObservableList.ClassName = "ObservableList"
ObservableList.__index = ObservableList

--[=[
	Constructs a new ObservableList
	@return ObservableList<T>
]=]
function ObservableList.new()
	local self = setmetatable({}, ObservableList)

	self._maid = Maid.new()

	self._keyList = {} -- { [number]: Symbol }
	self._contents = {} -- { [Symbol]: T }
	self._indexes = {} -- { [Symbol]: number }

	self._keyObservables = {} -- { [Symbol]: { Subscription } }

	self._countValue = ValueObject.new(0, "number")
	self._maid:GiveTask(self._countValue)

--[=[
	Fires when an item is added
	@readonly
	@prop ItemAdded Signal<T, number, Symbol>
	@within ObservableList
]=]
	self.ItemAdded = Signal.new()
	self._maid:GiveTask(self.ItemAdded)

--[=[
	Fires when an item is removed.
	@readonly
	@prop ItemRemoved Signal<T, Symbol>
	@within ObservableList
]=]
	self.ItemRemoved = Signal.new()
	self._maid:GiveTask(self.ItemRemoved)

--[=[
	Fires when the count changes.
	@prop CountChanged RBXScriptSignal
	@within ObservableList
]=]
	self.CountChanged = self._countValue.Changed

	return self
end

--[=[
	Returns whether the value is an observable list
	@param value any
	@return boolean
]=]
function ObservableList.isObservableList(value)
	return type(value) == "table" and getmetatable(value) == ObservableList
end

--[=[
	Observes the list, allocating a new list in the process.

	@return Observable<{ T }>
]=]
function ObservableList:Observe()
	return Rx.combineLatest({
		Rx.fromSignal(self.ItemAdded):Pipe({ Rx.startWith({ true }) });
		Rx.fromSignal(self.ItemRemoved):Pipe({ Rx.startWith({ true }) });
	}):Pipe({
		Rx.throttleDefer();
		Rx.map(function()
			return self:GetList();
		end);
	})
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T>>
]=]
function ObservableList:ObserveItemsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItem(item, _index, includeKey)
			local brio = Brio.new(item, includeKey)
			maid[includeKey] = brio
			sub:Fire(brio)
		end

		maid:GiveTask(self.ItemAdded:Connect(handleItem))
		maid:GiveTask(self.ItemRemoved:Connect(function(_item, includeKey)
			maid[includeKey] = nil
		end))

		for index, key in pairs(self._keyList) do
			handleItem(self._contents[key], index, key)
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
	Observes the index as it changes, until the entry at the existing
	index is removed.

	@param indexToObserve number
	@return Observable<number>
]=]
function ObservableList:ObserveIndex(indexToObserve)
	assert(type(indexToObserve) == "number", "Bad indexToObserve")

	local key = self._keyList[indexToObserve]
	if not key then
		error(("No entry at index %q, cannot observe changes"):format(indexToObserve))
	end

	return self:ObserveIndexByKey(key)
end

--[=[
	Removes the first instance found in contents

	@param value T
	@return boolean
]=]
function ObservableList:RemoveFirst(value)
	for key, item in pairs(self._contents) do
		if item == value then
			self:RemoveByKey(key)
			return true
		end
	end

	return false
end

--[=[
	Returns an IntValue that represents the CountValue

	@return IntValue
]=]
function ObservableList:GetCountValue()
	return self._countValue
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number>
]=]
function ObservableList:ObserveIndexByKey(key)
	assert(type(key) == "userdata", "Bad key")

	return Observable.new(function(sub)
		local currentIndex = self._indexes[key]
		if not currentIndex then
			sub:Complete()
			return
		end

		local maid = Maid.new()
		self._keyObservables[key] = self._keyObservables[key] or {}
		table.insert(self._keyObservables[key], sub)

		sub:Fire(currentIndex)

		maid:GiveTask(function()
			local list = self._keyObservables[key]
			if not list then
				return
			end

			local index = table.find(list, sub)
			if index then
				table.remove(list, index)
				if #list == 0 then
					self._keyObservables[key] = nil
				end
			end
		end)

		return maid
	end)
end

--[=[
	Gets the current index from the key

	@param key Symbol
	@return number
]=]
function ObservableList:GetIndexByKey(key)
	local currentIndex = self._indexes[key]
	if currentIndex then
		return currentIndex
	else
		return nil
	end
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function ObservableList:GetCount()
	return self._countValue.Value or 0
end

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function ObservableList:ObserveCount()
	return self._countValue:Observe()
end

--[=[
	Adds the item to the list at the specified index
	@param item T
	@return callback -- Call to remove
]=]
function ObservableList:Add(item)
	return self:InsertAt(item, #self._keyList + 1)
end

--[=[
	Gets the current item at the index, or nil if it is not defined.
	@param index number
	@return T?
]=]
function ObservableList:Get(index)
	assert(type(index) == "number", "Bad index")

	local key = self._keyList[index]
	if not key then
		return nil
	end

	return self._contents[key]
end

--[=[
	Adds the item to the list at the specified index
	@param item T
	@param index number?
	@return callback -- Call to remove
]=]
function ObservableList:InsertAt(item, index)
	assert(item ~= nil, "Bad item")
	assert(type(index) == "number", "Bad index")

	index = math.clamp(index, 1, #self._keyList + 1)

	local key = Symbol.named("entryKey")

	self._contents[key] = item
	self._indexes[key] = index

	local changed = {}

	local n = #self._keyList
	for i=n, index, -1 do
		local nextKey = self._keyList[i]
		self._indexes[nextKey] = i + 1
		self._keyList[i + 1] = nextKey

		local subs = self._keyObservables[nextKey]
		if subs then
			table.insert(changed, {
				key = nextKey;
				newIndex = i + 1;
				subs = subs;
			})
		end
	end

	self._keyList[index] = key

	-- Fire off count
	self._countValue.Value = self._countValue.Value + 1

	-- Fire off add
	self.ItemAdded:Fire(item, index, key)

	-- Fire off the index change on the value
	do
		local subs = self._keyObservables[key]
		if subs then
			table.insert(changed, {
				key = key;
				newIndex = index;
				subs = subs;
			})
		end
	end


	-- Fire off index change on each key list (if the data isn't stale)
	for _, data in pairs(changed) do
		if self._indexes[data.key] == data.newIndex then
			self:_fireSubs(data.subs, data.newIndex)
		end
	end

	return function()
		if self.Destroy then
			self:RemoveByKey(key)
		end
	end
end

--[=[
	Removes the item at the index
	@param index number
	@return T
]=]
function ObservableList:RemoveAt(index)
	assert(type(index) == "number", "Bad index")

	local key = self._keyList[index]
	if not key then
		return nil
	end

	return self:RemoveByKey(key)
end

--[=[
	Removes the item from the list if it exists.
	@param key Symbol
	@return T
]=]
function ObservableList:RemoveByKey(key)
	assert(key ~= nil, "Bad key")

	local index = self._indexes[key]
	if not index then
		return nil
	end

	local item = self._contents[key]
	if item == nil then
		return nil
	end

	local observableSubs = self._keyObservables[key]
	self._keyObservables[key] = nil
	self._indexes[key] = nil
	self._contents[key] = nil

	local changed = {}

	-- shift everything down
	local n = #self._keyList
	for i=index, n - 1 do
		local nextKey = self._keyList[i+1]
		self._indexes[nextKey] = i
		self._keyList[i] = nextKey

		local subs = self._keyObservables[nextKey]
		if subs then
			table.insert(changed, {
				key = nextKey;
				newIndex = i;
				subs = subs;
			})
		end
	end
	self._keyList[n] = nil

	-- Fire off that count changed
	self._countValue.Value = self._countValue.Value - 1

	if self.Destroy then
		self.ItemRemoved:Fire(item, key)
	end

	-- Fire off the index change on the value
	if observableSubs then
		self:_completeSubs(observableSubs)
	end

	-- Fire off index change on each key list (if the data isn't stale)
	for _, data in pairs(changed) do
		if self._indexes[data.key] == data.newIndex then
			self:_fireSubs(data.subs, data.newIndex)
		end
	end

	return item
end

function ObservableList:_fireSubs(list, index)
	for _, sub in pairs(list) do
		if sub:IsPending() then
			task.spawn(function()
				sub:Fire(index)
			end)
		end
	end
end

function ObservableList:_completeSubs(list)
	for _, sub in pairs(list) do
		if sub:IsPending() then
			sub:Fire(nil)
			sub:Complete()
		end
	end
end

--[=[
	Gets a list of all entries.
	@return { T }
]=]
function ObservableList:GetList()
	local list = {}
	for _, key in pairs(self._keyList) do
		table.insert(list, self._contents[key])
	end
	return list
end

--[=[
	Cleans up the ObservableList and sets the metatable to nil.
]=]
function ObservableList:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ObservableList