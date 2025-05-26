--!strict
--[=[
	Helper functions for the TimeSyncService.
	@class TimeSyncUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")

local TimeSyncUtils = {}

--[=[
	Given a clock, returns a promise that resolves when the clock is syncronized.

	@param clock MasterClock | SlaveClock
	@return Promise<MasterClock | SlaveClock>
]=]
function TimeSyncUtils.promiseClockSynced(clock: any): Promise.Promise<any>
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
