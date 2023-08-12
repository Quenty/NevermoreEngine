--[=[
	This allows the storage of subscriptions for keys, such that something
	can subscribe onto a key, and events can be invoked onto keys.
	@class ObservableSubscriptionTable
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")

local ObservableSubscriptionTable = {}
ObservableSubscriptionTable.ClassName = "ObservableSubscriptionTable"
ObservableSubscriptionTable.__index = ObservableSubscriptionTable

function ObservableSubscriptionTable.new()
	local self = setmetatable({}, ObservableSubscriptionTable)

	self._subMap = {} -- { TKey: Subscription<TEmit> }

	return self
end

--[=[
	Fires for the current key the given value
	@param key TKey
	@param ... TEmit
]=]
function ObservableSubscriptionTable:Fire(key, ...)
	assert(key ~= nil, "Bad key")

	local subs = self._subMap[key]
	if not subs then
		return
	end

	-- Make a copy so we don't have to worry about our last changing
	for _, sub in pairs(table.clone(subs)) do
		task.spawn(sub.Fire, sub, ...)
	end
end

function ObservableSubscriptionTable:Complete(key, ...)
	local subs = self._subMap[key]
	if not subs then
		return
	end

	local subsToComplete = table.clone(subs)
	self._subMap[key] = nil

	for _, sub in pairs(subsToComplete) do
		task.spawn(sub.Complete, sub, ...)
	end
end

--[=[
	Observes for the key
	@param key TKey
	@param retrieveInitialValue callback -- Optional
	@return Observable<TEmit>
]=]
function ObservableSubscriptionTable:Observe(key, retrieveInitialValue)
	assert(key ~= nil, "Bad key")

	return Observable.new(function(sub)
		if not self._subMap[key] then
			self._subMap[key] = { sub }
		else
			table.insert(self._subMap[key], sub)
		end

		if retrieveInitialValue then
			retrieveInitialValue(sub)
		end

		return function()
			if not self._subMap[key] then
				return
			end

			local current = self._subMap[key]
			local index = table.find(current, sub)
			if not index then
				return
			end

			table.remove(current, index)
			if #current == 0 then
				self._subMap[key] = nil
			end

			-- Complete the subscription
			if sub:IsPending() then
				task.spawn(function()
					sub:Complete()
				end)
			end
		end
	end)
end

--[=[
	Completes all subscriptions and removes them from the list.
]=]
function ObservableSubscriptionTable:Destroy()
	while next(self._subMap) do
		local key, list = next(self._subMap)
		self._subMap[key] = nil

		for _, sub in pairs(list) do
			if sub:IsPending() then
				task.spawn(function()
					sub:Complete()
				end)
			end
		end
	end
end


return ObservableSubscriptionTable