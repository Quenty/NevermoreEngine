--[=[
	Syncronizes time between the server and client. This creates a shared timestamp that can be used to reasonably time
	events between the server and client.

	@class TimeSyncService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local Maid = require("Maid")
local MasterClock = require("MasterClock")
local Promise = require("Promise")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local PromiseUtils = require("PromiseUtils")
local Rx = require("Rx")
local SlaveClock = require("SlaveClock")
local TimeSyncConstants = require("TimeSyncConstants")
local TimeSyncUtils = require("TimeSyncUtils")

local TimeSyncService = {}
TimeSyncService.ServiceName = "TimeSyncService"

--[=[
	Initializes the TimeSyncService
]=]
function TimeSyncService:Init()
	assert(not self._clockPromise, "TimeSyncService is already initialized!")

	self._maid = Maid.new()

	self._clockPromise = self._maid:Add(Promise.new())

	if not RunService:IsRunning() then
		-- Assume we're in server mode
		self._clockPromise:Resolve(self:_buildMasterClock())
		-- selene: allow(if_same_then_else)
	elseif RunService:IsServer() then
		self._clockPromise:Resolve(self:_buildMasterClock())
	elseif RunService:IsClient() then
		-- This also handles play solo edgecase where
		self._clockPromise:Resolve(self:_promiseSlaveClock())
	else
		error("Bad RunService state")
	end
end

--[=[
	Returns true if the clock is synced. If the clock is synced, then it can
	be retrieved.

	@return boolean
]=]
function TimeSyncService:IsSynced()
	if not RunService:IsRunning() then
		return true
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return self._clockPromise:IsFulfilled()
end

--[=[
	Waits for the synced clock, or throws an error.

	@yields
	@return MasterClock | SlaveClock
]=]
function TimeSyncService:WaitForSyncedClock()
	if not RunService:IsRunning() then
		return self:_buildMockClock()
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return self._clockPromise:Wait()
end

--[=[
	Returns a synced clock if there is one available. Otherwise, returns nil.

	@return MasterClock | SlaveClock | nil
]=]
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

--[=[
	Promises a synced clock

	@return Promise<MasterClock | SlaveClock>
]=]
function TimeSyncService:PromiseSyncedClock()
	if not RunService:IsRunning() then
		return Promise.resolved(self:_buildMockClock())
	end

	assert(self._clockPromise, "TimeSyncService is not initialized")
	return Promise.resolved(self._clockPromise)
end

function TimeSyncService:ObserveSyncedClock()
	return Rx.fromPromise(self:PromiseSyncedClock())
end

function TimeSyncService:_buildMockClock()
	local mock = {}

	function mock.IsSynced(_self)
		return true
	end

	function mock.GetTime(_self)
		return tick()
	end

	function mock.GetPing(_self)
		return 0
	end

	return mock
end

function TimeSyncService:_buildMasterClock()
	local remoteEvent = GetRemoteEvent(TimeSyncConstants.REMOTE_EVENT_NAME)
	local remoteFunction = GetRemoteFunction(TimeSyncConstants.REMOTE_FUNCTION_NAME)

	local clock = self._maid:Add(MasterClock.new(remoteEvent, remoteFunction))

	return clock
end

function TimeSyncService:_promiseSlaveClock()
	return self._maid:GivePromise(PromiseUtils.all({
		PromiseGetRemoteEvent(TimeSyncConstants.REMOTE_EVENT_NAME);
		PromiseGetRemoteFunction(TimeSyncConstants.REMOTE_FUNCTION_NAME);
	})):Then(function(remoteEvent, remoteFunction)
		local clock = self._maid:Add(SlaveClock.new(remoteEvent, remoteFunction))

		return TimeSyncUtils.promiseClockSynced(clock)
	end)
end

--[=[
	Cleans up the time syncronization service.
]=]
function TimeSyncService:Destroy()
	self._maid:DoCleaning()
end

return TimeSyncService