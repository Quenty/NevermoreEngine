--- Tracks pending promises
-- @classmod PendingPromiseTracker

local PendingPromiseTracker = {}
PendingPromiseTracker.ClassName = "PendingPromiseTracker"
PendingPromiseTracker.__index = PendingPromiseTracker

function PendingPromiseTracker.new()
	local self = setmetatable({}, PendingPromiseTracker)

	self._pendingPromises = {}

	return self
end

function PendingPromiseTracker:Add(promise)
	if promise:IsPending() then
		self._pendingPromises[promise] = true
		promise:Finally(function()
			self._pendingPromises[promise] = nil
		end)
	end
end

function PendingPromiseTracker:GetAll()
	local promises = {}
	for promise, _ in pairs(self._pendingPromises) do
		table.insert(promises, promise)
	end
	return promises
end

return PendingPromiseTracker