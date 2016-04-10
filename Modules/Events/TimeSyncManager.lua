-- MasterClock sends time to client.
-- @author Quenty

local MasterClock = {}
MasterClock.__index = MasterClock
MasterClock.ClassName = "MasterClock"

function MasterClock.new(SyncEvent, DelayedRequestFunction)
	local self = {}
	setmetatable(self, MasterClock)
	
	self.SyncEvent = SyncEvent
	self.DelayedRequestFunction = DelayedRequestFunction
	
	-- Define function calls and events.
	self.DelayedRequestFunction:Callback(function(Player, TimeThree)
		-- @return SlaveMasterDifference
		
		return self:HandleDelayRequest(TimeThree)
	end)
	
	self.SyncEvent:Listen(function(Player)
		 self.SyncEvent:SendToPlayer(Player, self:GetTime())
	end)
	
	-- Create thread.... forever! Yeah! That's right!
	spawn(function()
		while true do
			wait(5)
			self:Sync()
		end
	end)
	
	return self
end

function MasterClock:GetTime()
	return tick()
end

function MasterClock:Sync()
	--- Starts the sync process with all slave clocks.
	
	local TimeOne = self:GetTime()
	--print("[MasterClock] - Syncing all clients, TimeOne = ", TimeOne)
	
    self.SyncEvent:SendToAllPlayers(TimeOne)
end

function MasterClock:HandleDelayRequest(TimeThree)
    --- Client sends back message to get the SM_Difference.
    -- @return SlaveMasterDifference

    local TimeFour = self:GetTime()
    return TimeFour - TimeThree -- -Offset + SM Delay
end

function MasterClock:IsSynced()
	return true
end



local SlaveClock = {}
SlaveClock.__index = SlaveClock
SlaveClock.ClassName = "SlaveClock"

function SlaveClock.new(SyncEvent, DelayedRequestFunction)
	local self = {}
	setmetatable(self, SlaveClock)
	
	self.SyncEvent = SyncEvent
	self.DelayedRequestFunction = DelayedRequestFunction
	self.Offset = -1 -- Uncalculated.
	
	-- Connect
	self.SyncEvent:Listen(function(TimeOne)
		self:HandleSyncEvent(TimeOne)
	end)
	
	-- Request sync.
	self.SyncEvent:SendToServer()
	
	return self
end

function SlaveClock:IsSynced()
	return self.Offset ~= -1
end

function SlaveClock:GetLocalTime()
    return tick()
end

function SlaveClock:HandleSyncEvent(TimeOne)
    -- http://www.nist.gov/el/isd/ieee/upload/tutorial-basic.pdf
    -- We can't actually get hardware stuff, so we'll send T1 immediately. 
    local TimeTwo = self:GetLocalTime()
    local MasterSlaveDifference = TimeTwo - TimeOne -- We have Offst + MS Delay

    -- wait(1)
    local TimeThree = self:GetLocalTime()
    local SlaveMasterDifference = self:SendDelayRequest(TimeThree)

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

	--print("[SlaveClock] - Synced time at ", self.Offset, "change of ", Offset - self.Offset, ". self:GetTime() = ", self:GetTime(), "OneWayDelay time @ ", OneWayDelay)

    self.Offset = Offset -- Estimated difference between server/client
    self.OneWayDelay = OneWayDelay -- Estimated time for network events to send. (MSDelay/SMDelay)
end

function SlaveClock:SendDelayRequest(TimeThree)
	return self.DelayedRequestFunction:CallServer(TimeThree)
end

function SlaveClock:GetTime()
	if self.Offset == -1 then
		warn("[SlaveClock] - Offset is -1, may be unsynced clock!")
	end
	
	return self:GetLocalTime() - self.Offset
end


--- Actual Construction --
-- Determine what class to send back here: Singleton. 
-- Usually I wouldn't do something as... badly designed... as this, but in this case
-- I'm pretty sure these sync calls are expensive, so it's best that we do it here.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local RemoteManager     = LoadCustomLibrary("RemoteManager")

local SyncEvent         = RemoteManager:GetEvent("TimeSyncEvent")
local DelayedRequestFunction = RemoteManager:GetFunction("DelayedRequestEvent")
local Manager

if RunService:IsClient() and RunService:IsServer() then
	-- Solo test mode
	Manager = MasterClock.new(SyncEvent, DelayedRequestFunction)

	--> Solves edge case issue:
		--> Remote event invocation queue exhausted for ReplicatedStorage.NevermoreResources.EventStreamContainer.TimeSyncEvent; did you forget to implement OnClientEvent?
		-- Occurs because there is no OnClientEvent invoked for the sync thing. Will do so now.
	SyncEvent:Listen(function() end)
	
	print("[TimeSyncManager] - Studio mode enabled. MasterClock constructed.")
elseif RunService:IsClient() then
	-- Client
	Manager = SlaveClock.new(SyncEvent, DelayedRequestFunction)
	
	print("[TimeSyncManager] - Client mode enabled. SlaveClock constructed.")
else
	-- Server
	Manager = MasterClock.new(SyncEvent, DelayedRequestFunction)
	
	print("[TimeSyncManager] - Server mode enabled. MasterClock constructed.")
end

return Manager
