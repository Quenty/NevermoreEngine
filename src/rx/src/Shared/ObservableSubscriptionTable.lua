--!strict
--[=[
	This allows the storage of subscriptions for keys, such that something
	can subscribe onto a key, and events can be invoked onto keys.
	@class ObservableSubscriptionTable
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Subscription = require("Subscription")

local ObservableSubscriptionTable = {}
ObservableSubscriptionTable.ClassName = "ObservableSubscriptionTable"
ObservableSubscriptionTable.__index = ObservableSubscriptionTable

export type ObservableSubscriptionTable<T...> = typeof(setmetatable(
	{} :: {
		_subMap: { [any]: { Subscription.Subscription<T...> } },
	},
	{} :: typeof({ __index = ObservableSubscriptionTable })
))

function ObservableSubscriptionTable.new<T...>(): ObservableSubscriptionTable<T...>
	local self: ObservableSubscriptionTable<T...> = setmetatable({} :: any, ObservableSubscriptionTable)

	self._subMap = {} -- { TKey: Subscription<TEmit> }

	return self
end

--[=[
	Fires for the current key the given value
	@param key TKey
	@param ... TEmit
]=]
function ObservableSubscriptionTable.Fire<T...>(self: ObservableSubscriptionTable<T...>, key: any, ...)
	assert(key ~= nil, "Bad key")

	local subs = self._subMap[key]
	if not subs then
		return
	end

	-- Make a copy so we don't have to worry about our last changing
	for _, sub: any in table.clone(subs) do
		if sub:IsPending() then
			-- TODO: Use connection here
			task.spawn(sub.Fire, sub, ...)
		end
	end
end

--[=[
	Returns true if subscription exists

	@param key TKey
	@return boolean
]=]
function ObservableSubscriptionTable.HasSubscriptions<T...>(self: ObservableSubscriptionTable<T...>, key: any): boolean
	return self._subMap[key] ~= nil
end

--[=[
	Completes the subscription

	@param key TKey
]=]
function ObservableSubscriptionTable.Complete<T...>(self: ObservableSubscriptionTable<T...>, key: any): ()
	local subs = self._subMap[key]
	if not subs then
		return
	end

	local subsToComplete = table.clone(subs)
	self._subMap[key] = nil

	for _, sub: any in subsToComplete do
		if sub:IsPending() then
			task.spawn(sub.Complete, sub)
		end
	end
end

--[=[
	Fails the subscription

	@param key TKey
]=]
function ObservableSubscriptionTable.Fail<T...>(self: ObservableSubscriptionTable<T...>, key: any): ()
	local subs = self._subMap[key]
	if not subs then
		return
	end

	local subsToFail = table.clone(subs)
	self._subMap[key] = nil

	for _, sub: any in subsToFail do
		if sub:IsPending() then
			task.spawn(sub.Fail, sub)
		end
	end
end

export type RetrieveInitialValue<T...> = (sub: Subscription.Subscription<T...>) -> ()

--[=[
	Observes for the key
	@param key TKey
	@param retrieveInitialValue callback -- Optional
	@return Observable<TEmit>
]=]
function ObservableSubscriptionTable.Observe<T...>(
	self: ObservableSubscriptionTable<T...>,
	key: any,
	retrieveInitialValue: RetrieveInitialValue<T...>?
): Observable.Observable<T...>
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
			local current = self._subMap[key]
			if not current then
				return
			end

			-- TODO: Linked list
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
				task.spawn(sub.Complete, sub)
			end
		end
	end)
end

--[=[
	Completes all subscriptions and removes them from the list.
]=]
function ObservableSubscriptionTable.Destroy<T...>(self: ObservableSubscriptionTable<T...>): ()
	while next(self._subMap) do
		local key, list = next(self._subMap)
		assert(key, "Key should not be nil")

		self._subMap[key] = nil

		for _, sub: any in list do
			if sub:IsPending() then
				task.spawn(sub.Complete, sub)
			end
		end
	end
end

return ObservableSubscriptionTable
