--[=[
	Master clock on the server
	@class MasterClock
]=]

local MasterClock = {}
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

--[=[
	Constructs a new MasterClock

	@param remoteEvent RemoteEvent
	@param remoteFunction RemoteFunction
	@return MasterClock
]=]
function MasterClock.new(remoteEvent, remoteFunction)
	local self = setmetatable({}, MasterClock)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteFunction = remoteFunction or error("No remoteFunction")

	self._remoteFunction.OnServerInvoke = function(_, timeThree)
		return self:_handleDelayRequest(timeThree)
	end
	self._remoteEvent.OnServerEvent:Connect(function(player)
		 self._remoteEvent:FireClient(player, self:GetTime())
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			self:_forceSync()
		end
	end)

	return self
end

--[=[
	Returns true if the manager has synced with the server
	@return boolean
]=]
function MasterClock:IsSynced()
	return true
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
