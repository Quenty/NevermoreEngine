--!strict
--[=[
	Legacy code written by AxisAngles to simulate particles with Guis

	@client
	@class ParticleEngineClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ParticleEngineConstants = require("ParticleEngineConstants")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local ServiceBag = require("ServiceBag")

local ParticleEngineClient = {}
ParticleEngineClient.ServiceName = "ParticleEngineClient"

-- 3000 if you have a good computer
ParticleEngineClient._maxParticles = 400

-- Speed of wind to simulate
ParticleEngineClient._windSpeed = 10

local function newFrame(name: string): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Name = name
	frame.Archivable = false
	return frame
end

-- Adds a new particle
-- @param p PropertiesTable
--[[
{
	Position = Vector3

	-- Optional
	Global = Bool
	Velocity = Vector3
	Gravity = Vector3
	WindResistance  = Number
	LifeTime = Number
	Size = Vector2
	Bloom = Vector2
	Transparency = Number
	Color = Color3
	Occlusion = Bool
	RemoveOnCollision = function(BasePart Hit, Vector3 Position))
	Function = function(Table ParticleProperties, Number dt, Number t)
}
--]]
export type Particle = {
	Position: Vector3,
	Global: boolean?,
	Velocity: Vector3,
	Gravity: Vector3,
	WindResistance: number?,
	LifeTime: number,
	Size: Vector2,
	Bloom: Vector2,
	Transparency: number,
	Color: Color3,
	Occlusion: boolean?,
	RemoveOnCollision: ((Particle, BasePart, Vector3, Vector3, Enum.Material) -> boolean)?,
	Function: ((Particle, number, number) -> ())?,
	_lastScreenPosition: Vector2?,
}

export type ParticleEngineClient = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_maxParticles: number,
		_windSpeed: number,
		_serviceBag: ServiceBag.ServiceBag,
		_screen: ScreenGui?,
		_remoteEvent: RemoteEvent?,
		_player: Player,
		_lastUpdateTime: number,
		_particleCount: number,
		_particles: { [Particle]: Particle },
		_particleFrames: { Frame },
		_planeSizeX: number,
		_planeSizeY: number,
		_screenSizeX: number,
		_screenSizeY: number,
	},
	{} :: typeof({ __index = ParticleEngineClient })
))

function ParticleEngineClient.Init(self: ParticleEngineClient, serviceBag: ServiceBag.ServiceBag): ()
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._screen = nil

	PromiseGetRemoteEvent(ParticleEngineConstants.REMOTE_EVENT_NAME):Then(function(remoteEvent: RemoteEvent)
		self._remoteEvent = remoteEvent

		remoteEvent.OnClientEvent:Connect(function(...)
			(self :: any):ParticleNew(...)
		end)
	end)

	self._player = Players.LocalPlayer or error("No LocalPlayer")

	self._lastUpdateTime = tick()
	self._particleCount = 0
	self._particles = {}
	self._particleFrames = {}

	for i = 1, self._maxParticles do
		self._particleFrames[i] = newFrame("_particle")
	end

	RunService.Heartbeat:Connect(function()
		debug.profilebegin("particleUpdate")
		self:_update()
		debug.profileend()
	end)
end

function ParticleEngineClient.SetScreenGui(self: ParticleEngineClient, screenGui: ScreenGui): ()
	self._screen = screenGui
end

-- Removes a particle
function ParticleEngineClient.Remove(self: ParticleEngineClient, p: Particle): ()
	if self._particles[p] then
		self._particles[p] = nil
		self._particleCount -= 1
	end
end

-- Adds a new particle
-- @param p PropertiesTable
function ParticleEngineClient.Add(self: ParticleEngineClient, p: Particle): ()
	if self._particles[p] then
		return
	end

	p.Position = p.Position or Vector3.zero
	p.Velocity = p.Velocity or Vector3.zero
	p.Size = p.Size or Vector2.new(0.2, 0.2)
	p.Bloom = p.Bloom or Vector2.zero
	p.Gravity = p.Gravity or Vector3.zero
	p.Color = p.Color or Color3.new(1, 1, 1)
	p.Transparency = p.Transparency or 0.5

	if p.Global then
		local func = p.Function
		local removeOnCollision = p.RemoveOnCollision
		p.Global = nil
		p.Function = nil
		p.RemoveOnCollision = if p.RemoveOnCollision then (true :: any) else nil

		if self._remoteEvent then
			self._remoteEvent:FireServer(p)
		else
			warn("No self._remoteEvent")
		end

		p.Function = func
		p.RemoveOnCollision = removeOnCollision
	end

	p.LifeTime = p.LifeTime and p.LifeTime + tick()

	if self._particleCount > self._maxParticles then
		local firstKey: any = next(self._particles)
		self._particles[firstKey] = nil
	else
		self._particleCount = self._particleCount + 1
	end

	self._particles[p] = p
end

-- @param p Position
local function particleWind(t: number, p: Vector3): Vector3
	local xy: number, yz: number, zx: number = p.X + p.Y, p.Y + p.Z, p.Z + p.X
	return Vector3.new(
		(math.sin(yz + t * 2) + math.sin(yz + t)) / 2 + math.sin((yz + t) / 10) / 2,
		(math.sin(zx + t * 2) + math.sin(zx + t)) / 2 + math.sin((zx + t) / 10) / 2,
		(math.sin(xy + t * 2) + math.sin(xy + t)) / 2 + math.sin((xy + t) / 10) / 2
	)
end

-- @param p ParticleProperties
-- @param dt ChangeInTime
function ParticleEngineClient._updatePosVel(self: ParticleEngineClient, p: Particle, dt: number, t: number): ()
	p.Position = p.Position + p.Velocity * dt

	local wind
	if p.WindResistance then
		wind = (particleWind(t, p.Position) * self._windSpeed - p.Velocity) * p.WindResistance
	else
		wind = Vector3.zero
	end

	p.Velocity = p.Velocity + (p.Gravity + wind) * dt
end

-- Handles both priority and regular particles
-- @return boolean alive, true if still fine
function ParticleEngineClient._updateParticle(self: ParticleEngineClient, particle: Particle, t: number, dt: number): boolean
	if particle.LifeTime - t <= 0 then
		return false
	end

	-- Call this first, so any changes are reflected immediately
	if particle.Function then
		particle.Function(particle, dt, t)
	end

	local lastPos = particle.Position
	self:_updatePosVel(particle, dt, t)

	if not particle.RemoveOnCollision then
		return true
	end

	local displacement = particle.Position - lastPos
	local distance = displacement.Magnitude
	if distance > 999 then
		displacement = displacement * (999 / distance)
	end

	local ray = Ray.new(lastPos, displacement)
	local hit, position, normal, material = Workspace:FindPartOnRay(ray, self._player.Character, true)
	if not hit then
		return true
	end

	if type(particle.RemoveOnCollision) == "function" then
		if not particle.RemoveOnCollision(particle, hit, position, normal, material) then
			return false
		end
	else
		return false
	end

	return true
end

function ParticleEngineClient._update(self: ParticleEngineClient): ()
	local t = tick()
	local dt = t - self._lastUpdateTime
	self._lastUpdateTime = t

	local toRemove = {}

	-- Update particles
	for particle in pairs(self._particles) do
		if not self:_updateParticle(particle, t, dt) then
			toRemove[particle] = true
		end
	end

	-- Remove tagged particles
	for particle in pairs(toRemove) do
		self:Remove(particle)
	end

	-- Update render
	self:_updateRender()
end

function ParticleEngineClient._updateRender(self: ParticleEngineClient): ()
	local camera: Camera = Workspace.CurrentCamera :: Camera
	self:_updateScreenInfo(camera)

	local cameraInverse = camera.CFrame:Inverse()
	local cameraPosition = camera.CFrame.Position

	local frameIndex, frame = next(self._particleFrames)
	for particle in pairs(self._particles) do
		if frame and self:_particleRender(cameraPosition, cameraInverse, frame, particle) then
			frame.Parent = self._screen
			frameIndex, frame = next(self._particleFrames, frameIndex)
		end
	end

	-- Cleanup remaining frames that are parented
	while frameIndex and frame and frame.Parent do
		frame.Parent = nil
		frameIndex, frame = next(self._particleFrames, frameIndex)
	end
end

-- @param f frame
-- @param cameraInverse The inverse camera cframe
function ParticleEngineClient._particleRender(
	self: ParticleEngineClient,
	cameraPosition: Vector3,
	cameraInverse: CFrame,
	frame: Frame,
	particle: Particle
): boolean
	local rp: Vector3 = cameraInverse * particle.Position
	local lsp: Vector2? = particle._lastScreenPosition

	if not (rp.Z < -1 and lsp) then
		if rp.Z > 0 then
			particle._lastScreenPosition = nil
		else
			local sp = rp / rp.Z
			particle._lastScreenPosition = Vector2.new(
				(0.5 - sp.X / self._planeSizeX) * self._screenSizeX,
				(0.5 + sp.Y / self._planeSizeY) * self._screenSizeY
			)
		end

		return false
	end

	local sp = rp / rp.Z
	local b: Vector2 = particle.Bloom
	local bgt: number = particle.Transparency
	local px: number = (0.5 - sp.X / self._planeSizeX) * self._screenSizeX
	local py: number = (0.5 + sp.Y / self._planeSizeY) * self._screenSizeY
	local preSizeY = -particle.Size.Y / rp.Z * self._screenSizeY / self._planeSizeY
	local sx: number = -particle.Size.X / rp.Z * self._screenSizeY / self._planeSizeY + b.X
	local rppx, rppy = px - lsp.X, py - lsp.Y
	local sy = preSizeY + math.sqrt(rppx * rppx + rppy * rppy) + b.Y
	particle._lastScreenPosition = Vector2.new(px, py)

	if particle.Occlusion then
		local vec = particle.Position - cameraPosition
		local mag = vec.Magnitude
		if mag > 999 then
			vec = vec * (999 / mag)
		end

		if Workspace:FindPartOnRay(Ray.new(cameraPosition, vec), self._player.Character, true) then
			return false
		end
	end

	frame.Position = UDim2.fromOffset((px + lsp.X - sx) / 2, (py + lsp.Y - sy) / 2)
	frame.Size = UDim2.fromOffset(sx, sy)
	frame.Rotation = 90 + math.atan2(rppy, rppx) * 57.295779513082
	frame.BackgroundColor3 = particle.Color
	frame.BackgroundTransparency = bgt + (1 - bgt) * (1 - preSizeY / sy)

	return true
end

function ParticleEngineClient._updateScreenInfo(self: ParticleEngineClient, camera: Camera): ()
	local screen = self._screen
	if not screen then
		return
	end
	self._screenSizeX = screen.AbsoluteSize.X
	self._screenSizeY = screen.AbsoluteSize.Y
	self._planeSizeY = 2 * math.tan(camera.FieldOfView * 0.0087266462599716)
	self._planeSizeX = self._planeSizeY * self._screenSizeX / self._screenSizeY
end

return ParticleEngineClient
