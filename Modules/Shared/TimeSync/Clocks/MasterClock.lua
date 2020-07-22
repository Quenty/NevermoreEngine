--- Slave clock on the server
-- @classmod MasterClock on the server

local MasterClock = {}
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

function MasterClock.new(remoteEvent, remoteFunction)
	local self = setmetatable({}, MasterClock)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteFunction = remoteFunction or error("No remoteFunction")

	self._remoteFunction.OnServerInvoke = function(player, timeThree)
		return self:_handleDelayRequest(timeThree)
	end
	self._remoteEvent.OnServerEvent:Connect(function(player)
		 self._remoteEvent:FireClient(player, self:GetTime())
	end)

	spawn(function()
		while true do
			wait(5)
			self:_forceSync()
		end
	end)

	return self
end

--- Returns true if the manager has synced with the server
-- @treturn boolean
function MasterClock:IsSynced()
	return true
end

--- Returns the sycncronized time
-- @treturn number current time
function MasterClock:GetTime()
	return tick()
end

--- Starts the sync process with all slave clocks.
function MasterClock:_forceSync()
	local timeOne = self:GetTime()
	self._remoteEvent:FireAllClients(timeOne)
end

--- Client sends back message to get the SM_Difference.
-- @return slaveMasterDifference
function MasterClock:_handleDelayRequest(timeThree)
	local timeFour = self:GetTime()
	return timeFour - timeThree -- -offset + SM Delay
end

return MasterClock
