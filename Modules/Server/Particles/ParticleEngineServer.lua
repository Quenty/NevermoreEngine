--- Handles replication on the server side
-- @module ParticleEngineServer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local GetRemoteEvent = require("GetRemoteEvent")
local ParticleEngineConstants = require("ParticleEngineConstants")

local ParticleEngineServer = {}

function ParticleEngineServer:Init()
	self._remoteEvent = GetRemoteEvent(ParticleEngineConstants.REMOTE_EVENT_NAME)

	self._remoteEvent.OnServerEvent:Connect(function(player, particle)
		self:_replicate(player, particle)
	end)
end

function ParticleEngineServer:_replicate(player, particle)
	particle.Global = nil

	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			self._remoteEvent:FireClient(otherPlayer, particle)
		end
	end
end

-- @param p PropertiesTable
function ParticleEngineServer:ParticleNew(p)
	assert(self._remoteEvent)

	p.Position = p.Position or error("No Position")
	p.Velocity = p.Velocity or Vector3.new()
	p.Size = p.Size or Vector2.new(0.2,0.2)
	p.Bloom = p.Bloom or Vector2.new(0,0)
	p.Gravity = p.Gravity or Vector3.new()
	p.LifeTime = p.LifeTime;
	p.Color = p.Color or Color3.new(1,1,1)
	p.Transparency = p.Transparency or 0.5

	self._remoteEvent:FireAllClients(p)

	return p
end

return ParticleEngineServer