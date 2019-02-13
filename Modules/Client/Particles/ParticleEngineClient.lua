--- Legacy code written by AxisAngles to simulate particles with Guis
-- @module ParticleEngine

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sin = math.sin
local sqrt = math.sqrt
local atan2 = math.atan2
local v2 = Vector2.new
local v3 = Vector3.new
local ud2 = UDim2.new

local ParticleEngineClient = {}

-- 3000 if you have a good computer
ParticleEngineClient._maxParticles = 400

-- Speed of wind to simulate
ParticleEngineClient._windSpeed = 10

local function newFrame(name)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Name = name
	frame.Archivable = false
	return frame
end

function ParticleEngineClient:Init(screen)
	self._remoteEvent = require.GetRemoteEvent("ParticleEventDistributor")
	self._screen = screen or error("No screen")
	self._player = Players.LocalPlayer or error("No LocalPlayer")

	self._remoteEvent.OnClientEvent:Connect(function(...)
		self:ParticleNew(...)
	end)

	self._lastUpdateTime = tick()
	self._particleCount = 0
	self._particles = {}
	self._particleFrames = {}

	for i=1, self._maxParticles do
		self._particleFrames[i] = newFrame("_particle")
	end

	RunService.Heartbeat:Connect(function()
		debug.profilebegin("ParticleUpdate")
		self:_update()
		debug.profileend()
	end)

	return self
end

--- Removes a particle
function ParticleEngineClient:Remove(p)
	if self._particles[p] then
		self._particles[p] = nil
		self._particleCount = self._particleCount - 1
	end
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
function ParticleEngineClient:Add(p)
	if self._particles[p] then
		return
	end

	p.Position = p.Position or Vector3.new()
	p.Velocity = p.Velocity or Vector3.new()
	p.Size = p.Size or v2(0.2,0.2)
	p.Bloom = p.Bloom or v2()
	p.Gravity = p.Gravity or Vector3.new()
	p.Color = p.Color or Color3.new(1,1,1)
	p.Transparency = p.Transparency or 0.5

	if p.Global then
		local func = p.Function
		local removeOnCollision = p.RemoveOnCollision
		p.Global = nil
		p.Function = nil
		p.RemoveOnCollision = p.RemoveOnCollision and true or nil

		self._remoteEvent:FireServer(p)

		p.Function = func
		p.RemoveOnCollision = removeOnCollision
	end

	p.LifeTime = p.LifeTime and p.LifeTime+tick()

	if self._particleCount > self._maxParticles then
		self._particles[next(self._particles)] = nil
	else
		self._particleCount = self._particleCount + 1
	end

	self._particles[p] = p
end

-- @param p Position
local function particleWind(t, p)
	local xy,yz,zx=p.x+p.y,p.y+p.z,p.z+p.x
	return v3(
		(sin(yz+t*2)+sin(yz+t))/2+sin((yz+t)/10)/2,
		(sin(zx+t*2)+sin(zx+t))/2+sin((zx+t)/10)/2,
		(sin(xy+t*2)+sin(xy+t))/2+sin((xy+t)/10)/2
	)
end

-- @param p ParticleProperties
-- @param dt ChangeInTime
function ParticleEngineClient:_updatePosVel(p, dt, t)
	p.Position = p.Position + p.Velocity*dt

	local wind
	if p.WindResistance then
		wind = (particleWind(t, p.Position)*self._windSpeed - p.Velocity)*p.WindResistance
	else
		wind = v3()
	end

	p.Velocity = p.Velocity + (p.Gravity + wind)*dt
end

--- Handles both priority and regular particles
-- @return boolean alive, true if still fine
function ParticleEngineClient:_updateParticle(particle, t, dt)
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
		displacement = displacement * (999/distance)
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

function ParticleEngineClient:_update()
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

function ParticleEngineClient:_updateRender()
	local camera = Workspace.CurrentCamera
	self:_updateScreenInfo(camera)

	local cameraInverse = camera.CFrame:inverse()
	local cameraPosition = camera.CFrame.p

	local frameIndex, frame = next(self._particleFrames)
	for particle in pairs(self._particles) do
		if self:_particleRender(cameraPosition, cameraInverse, frame, particle) then
			frame.Parent = self._screen
			frameIndex, frame = next(self._particleFrames, frameIndex)
		end
	end

	-- Cleanup remaining frames that are parented
	while frameIndex and frame.Parent do
		frame.Parent = nil
		frameIndex, frame = next(self._particleFrames, frameIndex)
	end
end

-- @param f frame
-- @param cameraInverse The inverse camera cframe
function ParticleEngineClient:_particleRender(cameraPosition, cameraInverse, frame, particle)
	local rp = cameraInverse*particle.Position
	local lsp = particle._lastScreenPosition

	if not (rp.z < -1 and lsp) then
		if rp.z > 0 then
			particle._lastScreenPosition = nil
		else
			local sp = rp/rp.z
			particle._lastScreenPosition = Vector2.new(
				(0.5-sp.x/self._planeSizeX)*self._screenSizeX,
				(0.5+sp.y/self._planeSizeY)*self._screenSizeY)
		end

		return false
	end

	local sp = rp/rp.z
	local b = particle.Bloom
	local bgt = particle.Transparency
	local px = (0.5-sp.x/self._planeSizeX)*self._screenSizeX
	local py = (0.5+sp.y/self._planeSizeY)*self._screenSizeY
	local preSizeY = -particle.Size.y/rp.z*self._screenSizeY/self._planeSizeY
	local sx = -particle.Size.x/rp.z*self._screenSizeY/self._planeSizeY + b.x
	local rppx,rppy = px-lsp.x,py-lsp.y
	local sy = preSizeY+sqrt(rppx*rppx+rppy*rppy) + b.y
	particle._lastScreenPosition = v2(px, py)

	if particle.Occlusion then
		local vec = particle.Position-cameraPosition
		local mag = vec.Magnitude
		if mag > 999 then
			vec = vec * (999/mag)
		end

		if Workspace:FindPartOnRay(Ray.new(cameraPosition, vec), self._player.Character, true) then
			return false
		end
	end

	frame.Position = ud2(0, (px+lsp.x-sx)/2, 0, (py+lsp.y-sy)/2)
	frame.Size = ud2(0, sx, 0,sy)
	frame.Rotation = 90+atan2(rppy,rppx)*57.295779513082
	frame.BackgroundColor3 = particle.Color
	frame.BackgroundTransparency = bgt+(1-bgt)*(1 - preSizeY/sy)

	return true
end

function ParticleEngineClient:_updateScreenInfo(camera)
	self._screenSizeX = self._screen.AbsoluteSize.x
	self._screenSizeY = self._screen.AbsoluteSize.y
	self._planeSizeY = 2*math.tan(camera.FieldOfView*0.0087266462599716)
	self._planeSizeX = self._planeSizeY*self._screenSizeX/self._screenSizeY
end

return ParticleEngineClient