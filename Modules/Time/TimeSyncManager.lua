local RunService = game:GetService("RunService")

--[[
class TimeSyncManager

Description:
	Syncronize time between client and servers so we can use a universal timestamp
	across the game. See: www.nist.gov/el/isd/ieee/upload/tutorial-basic.pdf for more details

API:
	Use use just require the module, it's a singleton. Load TimeSyncManager on the server to use on the clients.

	number GetTime()
		Returns the sycncronized time

	bool IsSynced()
		Returns true if the manager has synced with the server

--]]

local MasterClock = {}
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

function MasterClock.new(SyncEvent, DelayedRequestFunction)
	local self = setmetatable({}, MasterClock)
	
	self.SyncEvent = SyncEvent
	self.DelayedRequestFunction = DelayedRequestFunction or error("No DelayedRequestFunction")
	
	function self.DelayedRequestFunction.OnServerInvoke(Player, TimeThree)
		return self:_handleDelayRequest(TimeThree)
	end
	
	self.SyncEvent.OnServerEvent:Connect(function(Player)
		 self.SyncEvent:FireClient(Player, self:GetTime())
	end)
	
	spawn(function()
		while true do
			wait(5)
			self:Sync()
		end
	end)
	
	return self
end

function MasterClock:IsSynced()
	return true
end

function MasterClock:GetTime()
	return tick()
end

--- Starts the sync process with all slave clocks.
function MasterClock:Sync()
	local TimeOne = self:GetTime()
    self.SyncEvent:FireAllClients(TimeOne)
end

--- Client sends back message to get the SM_Difference.
-- @return SlaveMasterDifference
function MasterClock:_handleDelayRequest(TimeThree)
    local TimeFour = self:GetTime()
    return TimeFour - TimeThree -- -Offset + SM Delay
end


local SlaveClock = {}
SlaveClock.__index = SlaveClock
SlaveClock.ClassName = "SlaveClock"
SlaveClock.Offset = -1 -- Set uncalculated values to -1

function SlaveClock.new(SyncEvent, DelayedRequestFunction)
	local self = setmetatable({}, SlaveClock)
	
	self.SyncEvent = SyncEvent
	self.DelayedRequestFunction = DelayedRequestFunction
	
	self.SyncEvent.OnClientEvent:Connect(function(TimeOne)
		self:_handleSyncEvent(TimeOne)
	end)
	
	self.SyncEvent:FireServer() -- Request server to syncronize with us
	
	return self
end

function SlaveClock:GetTime()
	if not self:IsSynced() then
		warn("[SlaveClock][GetTime] - Slave clock is not yet synced")
	end
	
	return self:_getLocalTime() - self.Offset
end

function SlaveClock:IsSynced()
	return self.Offset ~= -1
end

function SlaveClock:_getLocalTime()
    return tick()
end

function SlaveClock:_handleSyncEvent(TimeOne)
    local TimeTwo = self:_getLocalTime() -- We can't actually get hardware stuff, so we'll send T1 immediately.
    local MasterSlaveDifference = TimeTwo - TimeOne -- We have Offst + MS Delay

    local TimeThree = self:_getLocalTime()
    local SlaveMasterDifference = self:_sendDelayRequest(TimeThree)

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

    local Offset = (MasterSlaveDifference - SlaveMasterDifference)/2
    local OneWayDelay = (MasterSlaveDifference + SlaveMasterDifference)/2

    self.Offset = Offset -- Estimated difference between server/client
    self.OneWayDelay = OneWayDelay -- Estimated time for network events to send. (MSDelay/SMDelay)
end

function SlaveClock:_sendDelayRequest(TimeThree)
	return self.DelayedRequestFunction:InvokeServer(TimeThree)
end


--- Return a singleton
local function BuildClock()
	local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

	local SyncEvent = require.GetRemoteEvent("TimeSyncEvent")
	local DelayedRequestFunction = require.GetRemoteFunction("DelayedRequestEvent")

	if RunService:IsClient() and RunService:IsServer() then -- Solo test mode
		local Clock = MasterClock.new(SyncEvent, DelayedRequestFunction)
		SyncEvent.OnClientEvent:Connect(function() end)
		return Clock
	elseif RunService:IsClient() then
		return SlaveClock.new(SyncEvent, DelayedRequestFunction)
	else
		return MasterClock.new(SyncEvent, DelayedRequestFunction)
	end
end

return BuildClock()