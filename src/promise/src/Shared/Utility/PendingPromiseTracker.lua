--!strict
--[=[
	Tracks pending promises
	@class PendingPromiseTracker
]=]

local require = require(script.Parent.loader).load(script)

local _Promise = require("Promise")

local PendingPromiseTracker = {}
PendingPromiseTracker.ClassName = "PendingPromiseTracker"
PendingPromiseTracker.__index = PendingPromiseTracker

export type PendingPromiseTracker<T...> = typeof(setmetatable(
	{} :: {
		_pendingPromises: { [_Promise.Promise<T...>]: true },
	},
	{} :: typeof({ __index = PendingPromiseTracker })
))

--[=[
	Returns a new pending promise tracker

	@return PendingPromiseTracker<T>
]=]
function PendingPromiseTracker.new<T...>(): PendingPromiseTracker<T...>
	local self = setmetatable({}, PendingPromiseTracker)

	self._pendingPromises = {}

	return self
end

--[=[
	Adds a new promise to the tracker. If it's not pending it will not add.
]=]
function PendingPromiseTracker.Add<T...>(self: PendingPromiseTracker<T...>, promise: _Promise.Promise<T...>)
	if promise:IsPending() then
		self._pendingPromises[promise] = true
		promise:Finally(function()
			self._pendingPromises[promise] = nil
		end)
	end
end

--[=[
	Gets all of the promises that are pending
]=]
function PendingPromiseTracker.GetAll<T...>(self: PendingPromiseTracker<T...>): { _Promise.Promise<T...> }
	local promises: { _Promise.Promise<T...> } = {}
	for promise: any, _ in self._pendingPromises do
		table.insert(promises, promise)
	end
	return promises
end

return PendingPromiseTracker