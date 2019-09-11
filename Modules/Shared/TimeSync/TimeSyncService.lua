--- Syncronizes time
-- @module TimeSyncService

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local MasterClock = require("MasterClock")
local Promise = require("Promise")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local PromiseUtils = require("PromiseUtils")
local SlaveClock = require("SlaveClock")
local TimeSyncConstants = require("TimeSyncConstants")
local TimeSyncUtils = require("TimeSyncUtils")

local TimeSyncService = {}

function TimeSyncService:Init()
	assert(not self._clockPromise, "TimeSyncService is already initialized!")

	self._clockPromise = Promise.new()

	if RunService:IsServer() then
		self._clockPromise:Resolve(self:_buildMasterClock())
	end

	if RunService:IsClient() then
		-- This also handles play solo edgecase where
		self._clockPromise:Resolve(self:_promiseSlaveClock())
	end
end

function TimeSyncService:IsSynced()
	return self._clockPromise:IsResolved()
end

function TimeSyncService:WaitForSyncedClock()
	return self._clockPromise:Wait()
end

function TimeSyncService:GetSyncedClock()
	if self._clockPromise:IsResolved() then
		return self._clockPromise:Wait()
	end

	return nil
end

function TimeSyncService:PromiseSyncedClock()
	return Promise.resolved(self._clockPromise)
end

function TimeSyncService:_buildMasterClock()
	local remoteEvent = GetRemoteEvent(TimeSyncConstants.REMOTE_EVENT_NAME)
	local remoteFunction = GetRemoteFunction(TimeSyncConstants.REMOTE_FUNCTION_NAME)

	return MasterClock.new(remoteEvent, remoteFunction)
end

function TimeSyncService:_promiseSlaveClock()
	return PromiseUtils.all({
		PromiseGetRemoteEvent(TimeSyncConstants.REMOTE_EVENT_NAME);
		PromiseGetRemoteFunction(TimeSyncConstants.REMOTE_FUNCTION_NAME);
	}):Then(function(remoteEvent, remoteFunction)
		return TimeSyncUtils.promiseClockSynced(SlaveClock.new(remoteEvent, remoteFunction))
	end)
end

return TimeSyncService