local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qCFrame           = LoadCustomLibrary("qCFrame")

qSystems:Import(getfenv(0))

-- CharacterState.lua
-- This system handle's character states, such as running, falling, etc.. 
-- @author Quenty
-- Last Modified February 3rd, 2014

--[[
February 4th, 2014
- Fixed fall state where raycast ignored invisible parts.

February 3rd, 2014
- Updated to new Nevermore System
--]]

local lib = {}

local MakeCharacterState = Class(function(CharacterState, Character)
	local Humanoid = Character:FindFirstChild("Humanoid")
	local Torso    = Character:FindFirstChild("Torso")

	local PreviousState
	local CurrentState
	local CurrentStateChange = CreateSignal()
	CharacterState.CurrentStateChange = CurrentStateChange
	local States = {}

	local function LastPointSinceAction(self)
		return tick() - self.LastPoint;
	end

	local function TimeSinceStateStart(self)
		return tick() - self.PointStart;
	end

	local function AddState(Name, CheckDuring)
		local NewState = {}
		NewState.Name                 = Name
		NewState.CheckDuring          = CheckDuring
		-- NewState.Started              = CreateSignal()
		-- NewState.Stopped              = CreateSignal()
		NewState.LastPoint            = 0;
		NewState.PointStart           = 0;
		NewState.LastPointSinceAction = LastPointSinceAction
		NewState.TimeSinceStateStart  = TimeSinceStateStart

		States[Name] = NewState;
		return NewState;
	end

	local function SetState(Name)
		-- CurrentState.Stopped:fire()
		-- CurrentState.Started:fire()
		if not States[Name] then
			error("[CharacterState] - State '"..Name.."' does not exist. ")
		elseif CurrentState and CurrentState.Name ~= Name then
			PreviousState = CurrentState
			CurrentState = States[Name];
			CurrentState.LastPoint = tick()
			CurrentState.PointStart = tick()
			CurrentStateChange:fire(Name)
		end
	end
	CharacterState.SetState = SetState

	-- States --

	local function CharacterIsFalling(CharacterData, Torso)
		return CharacterData.OnGround.DistanceOff > 1.3 and Torso.Velocity.Y < -1
	end

	local function CharacterIsIdle(Torso)
		return (Torso.Velocity - Vector3.new(0, Torso.Velocity.y, 0)).magnitude <= 1
	end

	CurrentState = AddState("Idle", function(Character, CharacterData, Torso, PreviousState)
		if CharacterIsFalling(CharacterData, Torso) then
			SetState('Fall')
		elseif not CharacterIsIdle(Torso) then
			SetState("Walking")
		end
	end)

	AddState("Walking", function(Character, CharacterData, Torso, PreviousState)
		if CharacterIsFalling(CharacterData, Torso) then
			SetState('Fall')
		elseif CharacterIsIdle(Torso) then
			SetState("Idle")
		end
	end)

	-- Crouching --

	AddState("Crouch", function(Character, CharacterData, Torso, PreviousState)
		-- When the character is moving and crouching...

		if CharacterIsFalling(CharacterData, Torso)  then
			SetState('Fall')
		elseif CharacterIsIdle(Torso) then
			SetState("IdleCrouch")
		end
	end)

	AddState("IdleCrouch", function(Character, CharacterData, Torso, PreviousState)
		-- When the character is just crouching

		if CharacterIsFalling(CharacterData, Torso) then
			SetState('Fall')
		elseif not CharacterIsIdle(Torso) then
			SetState("Crouch")
		end
	end)

	AddState("Strone", function(Character, CharacterData, Torso, PreviousState)
		-- When the character is moving and crouching...

		if CharacterIsFalling(CharacterData, Torso)  then
			SetState('Fall')
		elseif CharacterIsIdle(Torso) then
			SetState("IdleStrone")
		end
	end)

	AddState("IdleStrone", function(Character, CharacterData, Torso, PreviousState)
		-- When the character is just crouching

		if CharacterIsFalling(CharacterData, Torso) then
			SetState('Fall')
		elseif not CharacterIsIdle(Torso) then
			SetState("Strone")
		end
	end)

	AddState("Running", function(Character, CharacterData, Torso, PreviousState)
		-- When the character is just crouching

		if CharacterIsFalling(CharacterData, Torso) then
			SetState('Fall')
		elseif CharacterIsIdle(Torso) then
			SetState("Idle")
		end
	end)

	AddState("Jump", function(Character, CharacterData, Torso, PreviousState)
		if PreviousState:LastPointSinceAction() > 1 then -- If we're jumping for more than 1 second, we're falling.
			SetState("Fall")
		elseif CharacterData.OnGround.DistanceOff < 0.5 and States.Jump:LastPointSinceAction() > 0.3 then
			SetState("EndJump")
		end
	end)

	AddState("Fall", function(Character, CharacterData, Torso, PreviousState)
		if CharacterData.OnGround:LastPointSinceAction() < 0.1 and States.Fall:TimeSinceStateStart() > 0.2 then
			SetState("EndFall")
		end
	end)

	AddState("EndFall", function(Character, CharacterData, Torso, PreviousState)
		if States.Fall:LastPointSinceAction() < 0.1 then
			if (Torso.Velocity - Vector3.new(0, Torso.Velocity.y, 0)).magnitude <= 1 then
				SetState("Idle")
			else
				SetState("Walking")
			end
		end
	end)

	AddState("EndJump", function(Character, CharacterData, Torso, PreviousState)
		if States.Jump:LastPointSinceAction() < 0.1 then
			if (Torso.Velocity - Vector3.new(0, Torso.Velocity.y, 0)).magnitude <= 1 then
				SetState("Idle")
			else
				SetState("Walking")
			end
		end
	end)

	AddState("ClimbLadder", function(Character, CharacterData, Torso, PreviousState)
		if CharacterData.OnGround.DistanceOff < 1.3 then
			SetState("ClimbStairs")
		elseif CharacterData.PositiveTorsoVelocity:LastPointSinceAction() > 0.2 then
			SetState("Walking")
		end
	end)

	AddState("ClimbStairs", function(Character, CharacterData, Torso, PreviousState)
		if CharacterData.OnGround.DistanceOff > 1.3 then
			SetState("ClimbLadder")
		elseif CharacterData.PositiveTorsoVelocity:LastPointSinceAction() > 0.2 then
			SetState("Walking")
		end
	end)

	AddState("Seated", function(Character, CharacterData, Torso, PreviousState)
		if not Character.Humanoid.Sit then
			SetState("Walking")
		end
	end)


	------

	local CharacterData = {
		OnGround = {
			DistanceOff = 0;
			LastPoint = 0;
			LastPointSinceAction = LastPointSinceAction;
		};
		OffGround = {
			LastPoint = 0;
			LastPointSinceAction = LastPointSinceAction;
		};
		PositiveTorsoVelocity = {
			Value = 0;
			LastPoint = 0;
			LastPointSinceAction = LastPointSinceAction;
		};
	}


	-----

	Humanoid.Jumping:connect(function()
		SetState("Jump")
	end)

	Humanoid.Seated:connect(function()
		SetState("Seated")
	end)

	Humanoid.Climbing:connect(function()
		if CharacterData.OnGround.DistanceOff > 1.3 then
			SetState("ClimbLadder")
		else
			SetState("ClimbStairs")
		end
	end)

	local IgnoreList = {Character}
	setmetatable(IgnoreList, {__mode = "k"})
	local AdvanceRaycast = qCFrame.AdvanceRaycast

	local function Step()
		local Torso = Character.Torso
		local TorsoPosition = Torso.Position

		-- Check Distance Off Ground --
		local DistanceCheckingRay = Ray.new(Torso.Position, Vector3.new(0,-999,0))
		local Hit, Position = AdvanceRaycast(DistanceCheckingRay, IgnoreList, false, true)
		if Hit and Hit.CanCollide then
			CharacterData.LastGroundHit = Hit
			CharacterData.OnGround.DistanceOff = math.max(0, (TorsoPosition - Position).magnitude - 3)
		else
			CharacterData.OnGround.DistanceOff = 100
			CharacterData.LastGroundHit = nil
		end

		if CharacterData.OnGround.DistanceOff > 1.3 then
			CharacterData.OffGround.LastPoint = tick()
		elseif CharacterData.OnGround.DistanceOff < 0.5 then
			CharacterData.OnGround.LastPoint = tick()
		end
		-- Check Torso Velocity --
		CharacterData.PositiveTorsoVelocity.Value = Torso.Velocity.y
		if Torso.Velocity.y > 1 then
			CharacterData.PositiveTorsoVelocity.LastPoint = tick()
		end

		-- Check States --
		CurrentState.LastPoint = tick()
		CurrentState.CheckDuring(Character, CharacterData, Torso, PreviousState)
	end
	CharacterState.Step = Step
end)

--[[
local MakeCharacterState = Class 'CharacterState' (function(CharacterState, Character)
	local Humanoid = WaitForChild(Character, "Humanoid")
	--local Torso = WaitForChild(Character, "Torso")
	local CurrentState = "Idle"
	local StateChanged = CreateSignal()

	local function SetState(NewState, ...)
		if CurrentState ~= NewState then
			CurrentState = NewState
			StateChanged:fire(NewState, ...)
		end
	end

	Humanoid.Died:connect(function(...) SetState("Died", ...) end)
	Humanoid.Running:connect(function(...) SetState("Running", ...) end)
	Humanoid.Jumping:connect(function(...) SetState("Jumping", ...) end)
	Humanoid.Climbing:connect(function(...) SetState("Climbing", ...) end)
	Humanoid.GettingUp:connect(function(...) SetState("GettingUp", ...) end)
	Humanoid.FreeFalling:connect(function(...) SetState("FreeFalling", ...) end)
	Humanoid.FallingDown:connect(function(...) SetState("FallingDown", ...) end)
	Humanoid.Seated:connect(function(...) SetState("Seated", ...) end)
	Humanoid.PlatformStanding:connect(function(...) SetState("PlatformStanding", ...) end)
	Humanoid.Swimming:connect(function(...) SetState("Swimming", ...) end)
end)--]]
lib.MakeCharacterState = MakeCharacterState

return lib