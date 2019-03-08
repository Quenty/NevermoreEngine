--- Syncronize time between client and servers so we can use a universal timestamp
-- across the game.
-- See: www.nist.gov/el/isd/ieee/upload/tutorial-basic.pdf
-- @classmod TimeSyncManager
-- @usage Use use just require the module, it's a singleton. Load TimeSyncManager on the server to use on the clients.

local RunService = game:GetService("RunService")

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
			self:Sync()
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
function MasterClock:Sync()
	local timeOne = self:GetTime()
    self._remoteEvent:FireAllClients(timeOne)
end

--- Client sends back message to get the SM_Difference.
-- @return slaveMasterDifference
function MasterClock:_handleDelayRequest(timeThree)
    local timeFour = self:GetTime()
    return timeFour - timeThree -- -offset + SM Delay
end


local SlaveClock = {}
SlaveClock.__index = SlaveClock
SlaveClock.ClassName = "SlaveClock"
SlaveClock._offset = -1 -- Set uncalculated values to -1

function SlaveClock.new(remoteEvent, remoteFunction)
	local self = setmetatable({}, SlaveClock)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteFunction = remoteFunction or error("No remoteFunction")

	self._remoteEvent.OnClientEvent:Connect(function(timeOne)
		self:_handleSyncEvent(timeOne)
	end)

	self._remoteEvent:FireServer() -- Request server to syncronize with us

	return self
end

function SlaveClock:GetTime()
	if not self:IsSynced() then
		warn("[SlaveClock.GetTime] - Slave clock is not yet synced", debug.traceback())
		return self:_getLocalTime()
	end

	return self:_getLocalTime() - self._offset
end

function SlaveClock:IsSynced()
	return self._offset ~= -1
end

function SlaveClock:_getLocalTime()
    return tick()
end

function SlaveClock:_handleSyncEvent(timeOne)
    local timeTwo = self:_getLocalTime() -- We can't actually get hardware stuff, so we'll send T1 immediately.
    local masterSlaveDifference = timeTwo - timeOne -- We have Offst + MS Delay

    local timeThree = self:_getLocalTime()
    local slaveMasterDifference = self:_sendDelayRequest(timeThree)

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

    local offset = (masterSlaveDifference - slaveMasterDifference)/2
    local oneWayDelay = (masterSlaveDifference + slaveMasterDifference)/2

    self._offset = offset -- Estimated difference between server/client
    self._pneWayDelay = oneWayDelay -- Estimated time for network events to send. (MSDelay/SMDelay)
end

function SlaveClock:_sendDelayRequest(timeThree)
	return self._remoteFunction:InvokeServer(timeThree)
end


--- Return a singleton
local function buildClock()
	local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

	local remoteEvent = require.GetRemoteEvent("TimeSyncEvent")
	local remoteFunction = require.GetRemoteFunction("DelayedRequestEvent")

	if RunService:IsClient() and RunService:IsServer() then -- Solo test mode
		local clock = MasterClock.new(remoteEvent, remoteFunction)
		remoteEvent.OnClientEvent:Connect(function() end)
		return clock
	elseif RunService:IsClient() then
		return SlaveClock.new(remoteEvent, remoteFunction)
	else
		return MasterClock.new(remoteEvent, remoteFunction)
	end
end

return buildClock()