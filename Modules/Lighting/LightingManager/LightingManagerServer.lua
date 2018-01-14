--- Syncronizes lighting with clients
-- classmod LightingManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local LightingManager = require("LightingManager")

local LightingManagerServer = setmetatable({}, LightingManager)
LightingManagerServer.__index = LightingManagerServer
LightingManagerServer.ClassName = "LightingManagerServer"

function LightingManagerServer.new(remoteEvent)
	local self = setmetatable(LightingManager.new(), LightingManagerServer)

	self._lastLightingSent = nil

	return self
end

function LightingManagerServer:_handlePlayer(player)
	local lastSent = self._lastLightingSent
	if not lastSent then
		return
	end
	local transitionTime = math.max(0, tick() - lastSent.EndTime)
	self._remoteEvent:FireClient(player, lastSent.PropertyTable, transitionTime)
end

function LightingManagerServer:WithRemoteEvent(remoteEvent)
	self._remoteEvent = remoteEvent or error("No remoteEvent")
	for _, player in pairs(Players:GetPlayers()) do
		self:_handlePlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_handlePlayer(player)
	end)

	return self
end

function LightingManagerServer:TweenProperties(propertyTable, transitionTime)
	assert(type(propertyTable) == "table")
	assert(type(transitionTime) == "number")

	self._lastLightingSent = {
		PropertyTable = propertyTable,
		EndTime = tick() + transitionTime;
	}
	self._remoteEvent:FireAllClients(propertyTable, time)
end

return LightingManagerServer