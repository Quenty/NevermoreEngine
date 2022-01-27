--[=[
	@class ObservableMapSet
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSet = require("ObservableSet")
local Signal = require("Signal")

local ObservableMapSet = {}
ObservableMapSet.ClassName = "ObservableMapSet"
ObservableMapSet.__index = ObservableMapSet

function ObservableMapSet.new()
	local self = setmetatable({}, ObservableMapSet)

	self._maid = Maid.new()
	self._observableSetMap = {} -- [key] = ObservableSet<TEntry>

	self.SetAdded = Signal.new() -- :Fire(key, set)
	self._maid:GiveTask(self.SetAdded)

	self.SetRemoved = Signal.new() -- :Fire(key)
	self._maid:GiveTask(self.SetRemoved)

	return self
end

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

function ObservableMapSet:GetListForKey(key)
	local observableSet = self._observableSetMap[key]
	if not observableSet then
		return {}
	end

	return observableSet:GetList()
end

function ObservableMapSet:GetObservableSetForKey(key)
	return self._observableSetMap[key]
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

		self.SetRemoved:Fire(key)
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