---
-- @module TimeSyncUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Maid = require("Maid")

local TimeSyncUtils = {}

function TimeSyncUtils.promiseClockSynced(clock)
	if clock:IsSynced() then
		return Promise.resolved(clock)
	end

	assert(clock.SyncedEvent, "Somehow master clock isn't synced") -- Client clock only

	local promise = Promise.new()
	local maid = Maid.new()

	maid:GiveTask(clock.SyncedEvent:Connect(function()
		if clock:IsSynced() then
			promise:Resolve(clock)
		end
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

return TimeSyncUtils