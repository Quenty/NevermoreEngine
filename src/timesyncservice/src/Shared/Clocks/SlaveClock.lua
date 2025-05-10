--!strict
--[=[
	Slave clock on the client
	@class SlaveClock
]=]

local require = require(script.Parent.loader).load(script)

local BaseClock = require("BaseClock")
local BaseObject = require("BaseObject")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local SlaveClock = setmetatable({}, BaseObject)
SlaveClock.__index = SlaveClock
SlaveClock.ClassName = "SlaveClock"
SlaveClock._offset = -1 -- Set uncalculated values to -1

export type SlaveClock = typeof(setmetatable(
	{} :: {
		_remoteEvent: RemoteEvent,
		_remoteFunction: RemoteFunction,
		_clockFunction: BaseClock.ClockFunction,
		_ping: ValueObject.ValueObject<number>,
		_offset: number,
		_pneWayDelay: number,
		_syncedBindable: BindableEvent,

		SyncedEvent: RBXScriptSignal,
	},
	{} :: typeof({ __index = SlaveClock })
)) & BaseObject.BaseObject & BaseClock.BaseClock

--[=[
	Constructs a new SlaveClock

	@param remoteEvent RemoteEvent
	@param remoteFunction RemoteFunction
	@return SlaveClock
]=]
function SlaveClock.new(remoteEvent: RemoteEvent, remoteFunction: RemoteFunction): SlaveClock
	local self: SlaveClock = setmetatable(BaseObject.new() :: any, SlaveClock)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteFunction = remoteFunction or error("No remoteFunction")
	self._ping = self._maid:Add(ValueObject.new(0, "number"))

	self._maid:GiveTask(self._remoteEvent.OnClientEvent:Connect(function(timeOne)
		self:_handleSyncEventAsync(timeOne)
	end))

	self._remoteEvent:FireServer() -- Request server to syncronize with us

	self._syncedBindable = Instance.new("BindableEvent")
	self.SyncedEvent = self._syncedBindable.Event

	self._clockFunction = function()
		return self:GetTime()
	end

	return self
end

--[=[
	Gets a function that can be used as a clock, like `time` and `tick` are.

	@return function
]=]
function SlaveClock.GetClockFunction(self: SlaveClock): BaseClock.ClockFunction
	return self._clockFunction
end

function SlaveClock.ObservePing(self: SlaveClock): Observable.Observable<number>
	return self._ping:Observe()
end

--[=[
	Converts the syncedTime to the original tick value.
	@param syncedTime number
	@return number
]=]
function SlaveClock.TickToSyncedTime(self: SlaveClock, syncedTime: number): number
	return syncedTime - self._offset
end

--[=[
	Returns the sycncronized time
	@return number
]=]
function SlaveClock.GetTime(self: SlaveClock): number
	if not self:IsSynced() then
		error("[SlaveClock.GetTime] - Slave clock is not yet synced")
	end

	return self:_getLocalTime() - self._offset
end

--[=[
	Returns true if the manager has synced with the server
	@return boolean
]=]
function SlaveClock.IsSynced(self: SlaveClock): boolean
	return self._offset ~= -1
end

function SlaveClock._getLocalTime(_self: SlaveClock)
	-- NOTE: Do not change this without changing :TickToSyncedTime
	return tick()
end

--[=[
	Returns estimated ping in seconds
	@return number
]=]
function SlaveClock.GetPing(self: SlaveClock): number
	return self._ping.Value
end

function SlaveClock._handleSyncEventAsync(self: SlaveClock, timeOne: number)
	local timeTwo = self:_getLocalTime() -- We can't actually get hardware stuff, so we'll send T1 immediately.
	local masterSlaveDifference = timeTwo - timeOne -- We have Offst + MS Delay

	local timeThree = self:_getLocalTime()

	local startTime = os.clock()
	local slaveMasterDifference = self:_sendDelayRequestAsync(timeThree)
	local ping = os.clock() - startTime

	--[[ From explination link.
		The result is that we have the following two equations:
		MS_difference = offset + MS delay
		SM_difference = ?offset + SM delay

		With two measured quantities:
		MS_difference = 90 minutes
		SM_difference = ?20 minutes

		And three unknowns:
		offset , MS delay, and SM delay

		Rearrange the equations according to the tutorial.
		-- Assuming this: MS delay = SM delay = one_way_delay

		one_way_delay = (MSDelay + SMDelay) / 2
	]]

	local offset = (masterSlaveDifference - slaveMasterDifference) / 2
	local oneWayDelay = (masterSlaveDifference + slaveMasterDifference) / 2

	self._offset = offset -- Estimated difference between server/client
	self._pneWayDelay = oneWayDelay -- Estimated time for network events to send. (MSDelay/SMDelay)
	self._ping.Value = ping

	self._syncedBindable:Fire()
end

function SlaveClock._sendDelayRequestAsync(self: SlaveClock, timeThree)
	return self._remoteFunction:InvokeServer(timeThree)
end

return SlaveClock
