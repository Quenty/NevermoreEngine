--[=[
	Tracks pending promises
	@class PendingPromiseTracker
]=]

local PendingPromiseTracker = {}
PendingPromiseTracker.ClassName = "PendingPromiseTracker"
PendingPromiseTracker.__index = PendingPromiseTracker

--[=[
	Returns a new pending promise tracker

	@return PendingPromiseTracker<T>
]=]
function PendingPromiseTracker.new()
	local self = setmetatable({}, PendingPromiseTracker)

	self._pendingPromises = {}

	return self
end

--[=[
	Adds a new promise to the tracker. If it's not pending it will not add.

	@param promise Promise<T>
]=]
function PendingPromiseTracker:Add(promise)
	if promise:IsPending() then
		self._pendingPromises[promise] = true
		promise:Finally(function()
			self._pendingPromises[promise] = nil
		end)
	end
end

--[=[
	Gets all of the promises that are pending

	@return { Promise<T> }
]=]
function PendingPromiseTracker:GetAll()
	local promises = {}
	for promise, _ in pairs(self._pendingPromises) do
		table.insert(promises, promise)
	end
	return promises
end

return PendingPromiseTracker