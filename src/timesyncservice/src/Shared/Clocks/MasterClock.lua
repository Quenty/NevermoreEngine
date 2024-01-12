--[=[
	Master clock on the server
	@class MasterClock
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")

local MasterClock = setmetatable({}, BaseObject)
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

--[=[
	Constructs a new MasterClock

	@param remoteEvent RemoteEvent
	@param remoteFunction RemoteFunction
	@return MasterClock
]=]
function MasterClock.new(remoteEvent, remoteFunction)
	local self = setmetatable(BaseObject.new(), MasterClock)

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
function MasterClock:GetClockFunction()
	return self._clockFunction
end

--[=[
	Observes how much ping the clock has

	@return Observable<number>
]=]
function MasterClock:ObservePing()
	return Rx.of(0)
end

--[=[
	Returns true if the manager has synced with the server
	@return boolean
]=]
function MasterClock:IsSynced()
	return true
end

--[=[
	Returns estimated ping in seconds
	@return number
]=]
function MasterClock:GetPing()
	return self._offset
end

--[=[
	Returns the sycncronized time
	@return number
]=]
function MasterClock:GetTime()
	return tick()
end

function MasterClock:_forceSync()
	-- start the sync process with all slave clocks.
	local timeOne = self:GetTime()
	self._remoteEvent:FireAllClients(timeOne)
end

function MasterClock:_handleDelayRequest(timeThree)
	-- Client sends back message to get the SM_Difference.
	-- returns slaveMasterDifference
	local timeFour = self:GetTime()
	return timeFour - timeThree -- -offset + SM Delay
end

return MasterClock
