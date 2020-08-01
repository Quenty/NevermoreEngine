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

	if not RunService:IsRunning() then
		error("Cannot initialize in test mode")
	elseif RunService:IsServer() then
		self._clockPromise:Resolve(self:_buildMasterClock())
	elseif RunService:IsClient() then
		-- This also handles play solo edgecase where
		self._clockPromise:Resolve(self:_promiseSlaveClock())
	else
		error("Bad RunService state")
	end
end

function TimeSyncService:IsSynced()
	if not RunService:IsRunning() then
		return true
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return self._clockPromise:IsFulfilled()
end

function TimeSyncService:WaitForSyncedClock()
	if not RunService:IsRunning() then
		return self:_buildMockClock()
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return self._clockPromise:Wait()
end

function TimeSyncService:GetSyncedClock()
	if not RunService:IsRunning() then
		return self:_buildMockClock()
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	if self._clockPromise:IsFulfilled() then
		return self._clockPromise:Wait()
	end

	return nil
end

function TimeSyncService:PromiseSyncedClock()
	if not RunService:IsRunning() then
		return Promise.resolved(self:_buildMockClock())
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return Promise.resolved(self._clockPromise)
end

function TimeSyncService:_buildMockClock()
	local mock = {}

	function mock.IsSynced(_self)
		return true
	end

	function mock.GetTime(_self)
		return tick()
	end

	return mock
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