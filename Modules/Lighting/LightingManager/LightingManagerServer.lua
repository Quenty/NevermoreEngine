--- Syncronizes lighting with clients

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Players = game:GetService("Players")

local LightingManager = require("LightingManager")

local LightingManagerServer = setmetatable({}, LightingManager)
LightingManagerServer.__index = LightingManagerServer
LightingManagerServer.ClassName = "LightingManagerServer"

function LightingManagerServer.new()
	local self = setmetatable(LightingManager.new(), LightingManagerServer)
	
	self.LastLightingSent = nil
	
	return self
end

function LightingManagerServer:WithRemoteEvent(RemoteEvent)
	self.RemoteEvent = RemoteEvent or error("No RemoteEvent")
	
	local function HandlePlayerAdded(Player)
		if self.LastLightingSent then
			self.RemoteEvent:FireClient(Player, self.LastLightingSent.Table, math.max(0, tick() - self.LastLightingSent.EndTime))
		end
	end
	for _, Player in pairs(Players:GetPlayers()) do
		HandlePlayerAdded(Player)
	end
	Players.PlayerAdded:Connect(HandlePlayerAdded)

	return self
end

function LightingManagerServer:TweenProperties(PropertyTable, Time)
	assert(type(PropertyTable) == "table")
	assert(type(Time) == "number")
	

	self.LastLightingSent = {
		Table = PropertyTable, 
		EndTime = tick() + Time;
	}
	self.RemoteEvent:FireAllClients(PropertyTable, Time)
end

return LightingManagerServer