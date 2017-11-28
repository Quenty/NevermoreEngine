local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

-- Legacy code written by AxisAngles to simulate particles with Guis

local WIND_SPEED = 10

local sin = math.sin
local cos = math.cos
local tan = math.tan
local sqrt = math.sqrt
local insert = table.insert
local remove = table.remove
local atan2 = math.atan2
local max = math.max
local abs = math.abs
local random = math.random
local v3 = Vector3.new
local v2 = Vector2.new
local ud2 = UDim2.new
local tick = tick
local ray = Ray.new
local Dot = v3().Dot
local lib = {}

--- Required for networking....
local function MakeParticleEngineServer()

	local Engine = {}

	local RemoteEvent = NevermoreEngine.GetRemoteEvent("ParticleEventDistributor")

	local function ParticleNew(p) -- PropertiesTable
		p.Position      = p.Position or error("No Position Yo")
		p.Velocity      = p.Velocity or v3()
		p.Size          = p.Size or v2(0.2,0.2)
		p.Bloom         = p.Bloom or v2(0,0)
		p.Gravity       = p.Gravity or v3()
		p.LifeTime      = p.LifeTime;
		p.Color         = p.Color or Color3.new(1,1,1)
		p.Transparency  = p.Transparency or 0.5

		RemoteEvent:FireAllClients(p)

		return p
	end
	Engine.ParticleNew = ParticleNew

	RemoteEvent.OnServerEvent:connect(function(Player, p)
		-- print("Server -- New particle")
		p.Global = nil

		for _, PlayerX in pairs(game.Players:GetPlayers()) do
			if PlayerX ~= Player then
				RemoteEvent:FireClient(PlayerX, p)
			end
		end
	end)

	return Engine
end
lib.MakeParticleEngineServer = MakeParticleEngineServer


local function RealMakeEngine(Screen)
	print("[ParticleEngine] - Creating new Particle Engine!!!!")
	assert(Screen, "Need screen")

	local Engine = {}
	Engine.Active = true

	local MaxParticles = 400 --lol 3000 if you have a good computer lol.

	--[[
	To generate a new particle
	ParticleNew{
		Position          = Vector3

		--Nonrequired 
		Global            = Bool
		Velocity          = Vector3
		Gravity           = Vector3
		WindResistance    = Number
		LifeTime          = Number
		Size              = Vector2
		Bloom             = Vector2
		Transparency      = Number
		Color             = Color3
		Occlusion         = Bool
		RemoveOnCollision = function(BasePart Hit, Vector3 Position))
		Function          = function(Table ParticleProperties, Number dt, Number t)
	}

	To remove a particle
	ParticleRemove(Table ParticleProperties)

	]]

	local Time = tick()

	local Player         = game.Players.LocalPlayer
	local RemoteEvent    = NevermoreEngine.GetRemoteEvent("ParticleEventDistributor")

	-- Screen = Screen or Instance.new("ScreenGui", Player.PlayerGui)

	local ParticleFrames = {}

	local ScreenSizeX 
	local ScreenSizeY 
	local PlaneSizeY 
	local PlaneSizeX  

	local function NewParticle(Name)
		local NewParticle           = Instance.new("Frame")
		NewParticle.BorderSizePixel = 0
		NewParticle.Name            = Name;
		NewParticle.Archivable      = false

		return NewParticle
	end

	--Generate the GUIs
	for Index=1, MaxParticles do
		ParticleFrames[Index] = NewParticle("_Particle")
	end

	local function ParticleUpdateScreenInformation(Camera)
		ScreenSizeX = Screen.AbsoluteSize.x
		ScreenSizeY = Screen.AbsoluteSize.y
		PlaneSizeY  = 2*tan(Camera.FieldOfView*0.0087266462599716)
		PlaneSizeX  = PlaneSizeY*ScreenSizeX/ScreenSizeY
	end
	ParticleUpdateScreenInformation(workspace.CurrentCamera)

	local function SetScreen(NewScreen)
		assert(NewScreen, "Must be a screen!")

		Screen = NewScreen
		print("[ParticleEngine] - NewScreen: " .. Screen:GetFullName())
	end
	Engine.SetScreen = SetScreen

	local function ParticleWind(p)--Position
		local xy,yz,zx=p.x+p.y,p.y+p.z,p.z+p.x
		return v3((sin(yz+Time*2)+sin(yz+Time))/2+sin((yz+Time)/10),(sin(zx+Time*2)+sin(zx+Time))/2+sin((zx+Time)/10),(sin(xy+Time*2)+sin(xy+Time))/2+sin((xy+Time)/10))/2
	end

	local function ParticleUpdateProperties(f,p,dt)--Frame,ParticleProperties,ChangeInTime,Time
		p.Position = p.Position+p.Velocity*dt
		local w    = p.WindResistance and (ParticleWind(p.Position)*WIND_SPEED-p.Velocity)*p.WindResistance or v3()
		p.Velocity = p.Velocity+(p.Gravity+w)*dt
	end

	local function ParticleRender(Camera, f, p, ci)--CameraInverse
		local rp=ci*p.Position
		local lsp=p.LastScreenPosition
		if rp.z<-1 and lsp then
			local sp                 = rp/rp.z
			local b                  = p.Bloom
			local bgt                = p.Transparency
			local PositionX          = (0.5-sp.x/PlaneSizeX)*ScreenSizeX
			local PositionY          = (0.5+sp.y/PlaneSizeY)*ScreenSizeY
			local PreSizeY           = -p.Size.y/rp.z*ScreenSizeY/PlaneSizeY
			local SizeX              = -p.Size.x/rp.z*ScreenSizeY/PlaneSizeY + b.x
			local rppx,rppy          = PositionX-lsp.x,PositionY-lsp.y
			local SizeY              = PreSizeY+sqrt(rppx*rppx+rppy*rppy) + b.y
			p.LastScreenPosition     = v2(PositionX,PositionY)

			local Visible = true

			if p.Occlusion then
				local c=Camera.CoordinateFrame.p
				local Vec = p.Position-c
				local Mag = Vec.magnitude
				if Mag > 999 then
					Vec = Vec * (999/Mag)
				end

				if workspace:FindPartOnRay(ray(c,Vec),Player.Character, true) then
					Visible = false
				end
			end

			if Visible then
				f.Parent                 = Screen
				f.Position               = ud2(0, (PositionX+lsp.x-SizeX)/2, 0, (PositionY+lsp.y-SizeY)/2)
				f.Size                   = ud2(0, SizeX, 0,SizeY)
				f.Rotation               = 90+atan2(rppy,rppx)*57.295779513082
				f.BackgroundColor3       = p.Color
				f.BackgroundTransparency = bgt+(1-bgt)*(1-PreSizeY/SizeY)
			else
				f.Parent = nil
			end
		else
			f.Parent = nil
			if rp.z>0 then
				p.LastScreenPosition = nil
			else
				local sp                   = rp/rp.z
				p.LastScreenPosition = Vector2.new((0.5-sp.x/PlaneSizeX)*ScreenSizeX,(0.5+sp.y/PlaneSizeY)*ScreenSizeY)
			end
		end
	end

	local NewParticles = {}
	local RemovingParticles = {}
	local Priority = {}

	local Particles = {}



	local function AddNewParticles()
		local WorkingOn = NewParticles
		local Removing = RemovingParticles
		RemovingParticles = {}
		NewParticles = {}

		local PrioritiySize = #Priority
		local ParticleSize = #Particles

		for Index = 1, #Removing do
			local Particle = Removing[Index]

			if Particle.TablePosition then
				if Particle.Priority then
					local Index = Particle.TablePosition
					while Index < PrioritiySize do
						Priority[Index] = Priority[Index + 1]
						Priority[Index].TablePosition = Index
						Index = Index + 1
					end
					Priority[PrioritiySize] = nil
					PrioritiySize = PrioritiySize - 1

					Particle.Frame:Destroy()
					Particle.Frame = nil
					Particle.TablePosition = nil
				else
					local Index = Particle.TablePosition
					while Index < ParticleSize do
						Particles[Index] = Particles[Index + 1]
						Particles[Index].TablePosition = Index
						Index = Index + 1
					end
					Particles[ParticleSize] = nil
					ParticleSize = ParticleSize - 1

					Particle.TablePosition = nil
				end
			end
		end

		for Index = 1, #WorkingOn do
			local Particle = WorkingOn[Index]
			if Particle.Priority then
				Particle.Frame = NewParticle("_PriorityParticle")

				Priority[#Priority+1] = Particle
			else
				insert(Particles, 1, Particle)
				Particles[MaxParticles] = nil
			end

			--[[local LastParticle = Particles[MaxParticles]
			if LastParticle then
				if LastParticle.Frame then
					LastParticle.Frame:Destroy()
					LastParticle.Frame = nil
				end
				Particles[MaxParticles] = nil
			end--]]
		end
	end

	local function ParticleRemove(p)
		RemovingParticles[#RemovingParticles+1] = p
	end
	Engine.ParticleRemove = ParticleRemove

	local Terrain = workspace.Terrain
	local workspace = workspace

	--- Handles both priority and regular particles
	local function HandleParticleUpdate(Camera, CameraInverse, Frame, Particle, t, dt)
		if Particle.LifeTime - t <= 0 then
			ParticleRemove(Particle)
		else
			if Particle.Function then
				-- Call this first, so any changes are reflected immediately

				Particle.Function(Particle, dt, t)
			end

			local OldPosition = Particle.Position

			ParticleUpdateProperties(Frame, Particle, dt, t)

			if Particle.RemoveOnCollision then
				local Displacement = Particle.Position - OldPosition
				local Distance = Displacement.magnitude

				if Distance > 999 then
					Displacement = Displacement * (999/Distance)
				end

				local Hit, Position = workspace:FindPartOnRay(ray(OldPosition, Displacement), Player.Character, true)
				if Hit then
					if type(Particle.RemoveOnCollision) == "function" then
						if not Particle.RemoveOnCollision(Particle, Hit, Position) then
							ParticleRemove(Particle)
						end
					else
						ParticleRemove(Particle)
					end
					
				end
			end
			
			ParticleRender(Camera, Frame, Particle, CameraInverse)
		end
	end

	--- This guy is expensive
	-- Should be in a loop, so no need for debounce
	-- _G.AverageProcessTime=0
	local function ParticleUpdate()
		local Camera = workspace.CurrentCamera

		AddNewParticles()
		ParticleUpdateScreenInformation(Camera)

		local t=tick()
		local dt=t-Time
		Time=t

		local CameraInverse = Camera.CoordinateFrame:inverse()

		for Index = 1, MaxParticles do
			local Particle = Particles[Index]
			local Frame = ParticleFrames[Index]

			if Particle then
				Particle.TablePosition = Index
				HandleParticleUpdate(Camera, CameraInverse, Frame, Particle, t, dt)
			else
				Frame.Parent = nil -- Instead of .Visible, it's faster on the rendering side. (99% sure) 
			end
		end

		for Index = 1, #Priority do
			local Particle = Priority[Index]
			local Frame = Particle.Frame

			Particle.TablePosition = Index

			HandleParticleUpdate(Camera, CameraInverse, Frame, Particle, t, dt)
		end
		-- _G.AverageProcessTime=_G.AverageProcessTime*0.95+(tick()-t)*0.05
		-- print(#Priority)
	end
	Engine.ParticleUpdate = ParticleUpdate

	local function ParticleNew(p)--PropertiesTable
		p.Position      = p.Position or v3()
		p.Velocity      = p.Velocity or v3()
		p.Size          = p.Size or v2(0.2,0.2)
		p.Bloom         = p.Bloom or v2()
		p.TablePosition = 1
		p.Gravity       = p.Gravity or v3()
		p.Color         = p.Color or Color3.new(1,1,1)
		p.Transparency  = p.Transparency or 0.5


		if p.Global then
			p.Global = nil
			local Function, RemoveOnCollision = p.Function, p.RemoveOnCollision
			p.Function, p.RemoveOnCollision = nil, (p.RemoveOnCollision and true or nil)

			RemoteEvent:FireServer(p)

			p.Function, p.RemoveOnCollision = Function, RemoveOnCollision
		end

		p.LifeTime      = p.LifeTime and p.LifeTime+tick()
		NewParticles[#NewParticles+1] = p
	end
	RemoteEvent.OnClientEvent:connect(ParticleNew)
	Engine.ParticleNew = ParticleNew

	local RenderStepped = game:GetService("RunService").RenderStepped

	local UpdateId = 0

	return Engine
end

local Engine

local function GetParticleEngine(Screen)
	assert(Screen, "Need screen!")

	if not Engine then
		Engine = RealMakeEngine(Screen)
	else
		Engine.SetScreen(Screen)
	end

	return Engine
end
lib.GetParticleEngine = GetParticleEngine

return lib