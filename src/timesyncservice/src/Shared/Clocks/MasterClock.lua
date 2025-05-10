--!strict
--[=[
	Master clock on the server
	@class MasterClock
]=]

local require = require(script.Parent.loader).load(script)

local BaseClock = require("BaseClock")
local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Rx = require("Rx")

local MasterClock = setmetatable({}, BaseObject)
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

export type MasterClock = typeof(setmetatable(
	{} :: {
		_remoteEvent: RemoteEvent,
		_remoteFunction: RemoteFunction,
		_clockFunction: BaseClock.ClockFunction,
	},
	{} :: typeof({ __index = MasterClock })
)) & BaseObject.BaseObject & BaseClock.BaseClock

--[=[
	Constructs a new MasterClock

	@param remoteEvent RemoteEvent
	@param remoteFunction RemoteFunction
	@return MasterClock
]=]
function MasterClock.new(remoteEvent: RemoteEvent, remoteFunction: RemoteFunction): MasterClock
	local self: MasterClock = setmetatable(BaseObject.new() :: any, MasterClock)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteFunction = remoteFunction or error("No remoteFunction")

	self._remoteFunction.OnServerInvoke = function(_, timeThree)
		return self:_handleDelayRequest(timeThree)
	end
	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(player)
		self._remoteEvent:FireClient(player, self:GetTime())
	end))

	local alive = true
	self._maid:GiveTask(function()
		alive = false
	end)

	self._clockFunction = function()
		return self:GetTime()
	end

	task.delay(5, function()
		while alive do
			self:_forceSync()
			task.wait(5)
		end
	end)

	return self
end

--[=[
	Gets a function that can be used as a clock, like `time` and `tick` are.

	@return function
]=]
function MasterClock.GetClockFunction(self: MasterClock): BaseClock.ClockFunction
	return self._clockFunction
end

--[=[
	Observes how much ping the clock has

	@return Observable<number>
]=]
function MasterClock.ObservePing(_self: MasterClock): Observable.Observable<number>
	return Rx.of(0) :: any
end

--[=[
	Returns true if the manager has synced with the server
	@return boolean
]=]
function MasterClock.IsSynced(_self: MasterClock): boolean
	return true
end

--[=[
	Returns estimated ping in seconds
	@return number
]=]
function MasterClock.GetPing(_self: MasterClock): number
	return 0
end

--[=[
	Returns the sycncronized time
	@return number
]=]
function MasterClock.GetTime(_self: MasterClock): number
	return tick()
end

function MasterClock._forceSync(self: MasterClock): ()
	-- start the sync process with all slave clocks.
	local timeOne = self:GetTime()
	self._remoteEvent:FireAllClients(timeOne)
end

function MasterClock._handleDelayRequest(self: MasterClock, timeThree: number): number
	-- Client sends back message to get the SM_Difference.
	-- returns slaveMasterDifference
	local timeFour = self:GetTime()
	return timeFour - timeThree -- -offset + SM Delay
end

return MasterClock
