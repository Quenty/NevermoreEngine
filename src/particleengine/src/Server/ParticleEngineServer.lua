--!strict
--[=[
	Handles replication on the server side

	@server
	@class ParticleEngineServer
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local GetRemoteEvent = require("GetRemoteEvent")
local ParticleEngineConstants = require("ParticleEngineConstants")

type ParticleProperties = {
	Position: Vector3?,
	Velocity: Vector3?,
	Size: Vector2?,
	Bloom: Vector2?,
	Gravity: Vector3?,
	LifeTime: number?,
	Color: Color3?,
	Transparency: number?,
	Global: any?,
}

local ParticleEngineServer = {
	ServiceName = "ParticleEngineServer",
	_remoteEvent = nil :: RemoteEvent?,
}

function ParticleEngineServer.Init(self: typeof(ParticleEngineServer))
	assert(not self._remoteEvent, "Already initialized")

	local remoteEvent = GetRemoteEvent(ParticleEngineConstants.REMOTE_EVENT_NAME)
	self._remoteEvent = remoteEvent

	remoteEvent.OnServerEvent:Connect(function(player, particle)
		self:_replicate(player, particle)
	end)
end

function ParticleEngineServer._replicate(
	self: typeof(ParticleEngineServer),
	player: Player,
	particle: ParticleProperties
)
	particle.Global = nil

	local remoteEvent = self._remoteEvent
	if remoteEvent then
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				remoteEvent:FireClient(otherPlayer, particle)
			end
		end
	end
end

-- @param p PropertiesTable
function ParticleEngineServer.ParticleNew(self: typeof(ParticleEngineServer), p: ParticleProperties): ParticleProperties
	assert(self._remoteEvent, "Not initialized")

	p.Position = p.Position or error("No Position")
	p.Velocity = p.Velocity or Vector3.zero
	p.Size = p.Size or Vector2.new(0.2, 0.2)
	p.Bloom = p.Bloom or Vector2.new(0, 0)
	p.Gravity = p.Gravity or Vector3.zero
	p.LifeTime = p.LifeTime
	p.Color = p.Color or Color3.new(1, 1, 1)
	p.Transparency = p.Transparency or 0.5

	self._remoteEvent:FireAllClients(p)

	return p
end

return ParticleEngineServer
