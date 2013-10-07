while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local qCFrame           = LoadCustomLibrary('qCFrame')

qSystems:Import(getfenv(0))

local lib = {}

local function PointCamera(CoordinateFrame, Focus)
	Workspace.CurrentCamera.Focus = Focus
	Workspace.CurrentCamera.CoordinateFrame = CFrame.new(CoordinateFrame.p, Focus.p)
end
lib.PointCamera = PointCamera
lib.pointCamera = PointCamera

local function SetCurrentCameraToScriptable()
	--[[local CoordinateFrame, Focus = Workspace.CurrentCamera.CoordinateFrame.p, Workspace.CurrentCamera.Focus
	Workspace.CurrentCamera:Destroy()
	wait(0)
	while not Workspace.CurrentCamera do wait(0) end
	Workspace.CurrentCamera.CameraType = "Scriptable"
	Workspace.CurrentCamera.CoordinateFrame = CFrame.new(CoordinateFrame, Focus.p)
	Workspace.CurrentCamera.Focus = Focus
	return CoordinateFrame, Focus--]]

	Workspace.CurrentCamera.CameraType = "Scriptable";
end
lib.SetCurrentCameraToScriptable = SetCurrentCameraToScriptable
lib.setCurrentCameraToScriptable = SetCurrentCameraToScriptable
lib.SetCameraToScriptable = SetCurrentCameraToScriptable
lib.setCameraToScriptable = SetCurrentCameraToScriptable


local function ShakeCamera(c0,f0,intensity,durration,opposite)
	local t = time()
	local i = (intensity/2)
	local i2 = i
	while ((time()-t) < durration) do
		if (skip) then break end
		if (opposite) then
			i = (i2*((time()-t)/durration))
		else
			i = (i*(1-((time()-t)/durration)))
		end
		Workspace.CurrentCamera.CoordinateFrame = (c0*CFrame.new((-i+(math.random()*i)),(-i+(math.random()*i)),(-i+(math.random()*i))))
		Workspace.CurrentCamera.Focus = (f0*CFrame.new((-i+(math.random()*i)),(-i+(math.random()*i)),(-i+(math.random()*i))))
		wait(0)
	end
	Workspace.CurrentCamera.CoordinateFrame = c0
	Workspace.CurrentCamera.Focus = f0
end

lib.ShakeCamera = ShakeCamera
lib.shakeCamera = ShakeCamera

local function SetPlayerControl()
	if Players.LocalPlayer.Character then
		Workspace.CurrentCamera.CameraSubject = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
	end
	Workspace.CurrentCamera.CameraType = "Custom"
end
lib.SetPlayerControl = SetPlayerControl
lib.setPlayerControl = SetPlayerControl


local TweenCameraOverideId = 0
local OpeatingTweenCamera = false;

local function TweenCamera(CoordinateFrameTarget, FocusTarget, TimeToTween, Override, RollTarget, FieldOfViewTarget)
	SetCurrentCameraToScriptable()
	Spawn(function()
		if Override and OpeatingTweenCamera then
			--print("Camera Tween: Overriding operation");
			TweenCameraOverideId = TweenCameraOverideId+1;
		elseif OpeatingTweenCamera then
			--print("Camera Tween: Did not override, old operation is continueing");
			return false;
		end
		OpeatingTweenCamera = true;

		FieldOfViewTarget = FieldOfViewTarget or Workspace.CurrentCamera.FieldOfView
		RollTarget = RollTarget or Workspace.CurrentCamera:GetRoll()

		local CurrentNumber = TweenCameraOverideId;
		local OriginalRoll = Workspace.CurrentCamera:GetRoll()
		local OriginalFieldOfView = Workspace.CurrentCamera.FieldOfView
		local CoordinateFocusStart = Workspace.CurrentCamera.Focus.p
		local CoordinateFrameStart = CFrame.new(Workspace.CurrentCamera.CoordinateFrame.p, CoordinateFocusStart)
		local CoordinateFrameFinish = CFrame.new(CoordinateFrameTarget, FocusTarget)

		local RepetitionIntervol = (1/(TimeToTween/wait(0)))
		local Repetitions

		for Index = 0, 1, RepetitionIntervol do
			local SmoothIndex = math.sin((Index - 0.5) * math.pi)/2 + 0.5
			local Focus = CoordinateFocusStart:lerp(FocusTarget, SmoothIndex)
			Workspace.CurrentCamera.CoordinateFrame = qCFrame.SlerpCFrame(CoordinateFrameStart, CoordinateFrameFinish, SmoothIndex)
			Workspace.CurrentCamera.Focus = CFrame.new(Focus)
			Workspace.CurrentCamera:SetRoll(OriginalRoll + ((RollTarget - OriginalRoll) * SmoothIndex))
			Workspace.CurrentCamera.FieldOfView = OriginalFieldOfView + ((FieldOfViewTarget - OriginalFieldOfView)) * SmoothIndex
			wait(0)

			if TweenCameraOverideId ~= CurrentNumber then
				return false;
			end
		end

		OpeatingTweenCamera = false;
		PointCamera(CFrame.new(CoordinateFrameTarget), CFrame.new(FocusTarget))
		Workspace.CurrentCamera:SetRoll(RollTarget)
		Workspace.CurrentCamera.FieldOfView = FieldOfViewTarget
		return true;
	end)
end
lib.TweenCamera = TweenCamera
lib.tweenCamera = TweenCamera

local AdvanceRaycast = qCFrame.AdvanceRaycast

local MakeCameraSystem = Class 'CameraSystem' (function(CameraSystem, Player)
	local CurrentState
	local States = {}

	local IgnoreList = {}
	setmetatable(IgnoreList, {__mode = "k"})

	local function SetCurrentState(Name)
		if States[Name] then
			if CurrentState.OnStop then
				CurrentState:OnStop(Player, Mouse, Camera)
			end
			CurrentState = States[Name]
			if CurrentState.OnStart then
				CurrentState:OnStart(Player, Mouse, Camera)
			end
		elseif Name == "Custom" then
			CurrentState = nil
		else
			error("State "..Name.." does not exist")
		end
	end

	do
		local SquareRootOf3 = math.sqrt(3)

		States.TopDown = {
			Configuration = {
				RotationGoal = 90;
				RotationCurrent = 90;
				Zoom = 10;
				CurrentCoordinateFrame = Workspace.CurrentCamera.CoordinateFrame.p
			};
			RaycastIgnoreList = {Character, Camera};
			Step = function(self, Player, Mouse, Camera)
				if CheckCharacter(Player) then
					local Configuration = self.Configuration
					local Tilt = RoundNumber(Configuration.RotationGoal, 90)/90%4
					local ZoomLevel = Configuration.Zoom + 10

					Configuration.RotationCurrent = Configuration.RotationCurrent - (RotationCurrent - RotationGoal) * 0.2
					local Inverse     = Configuration.RotationGoal < 180 and 180 or -180
					local PositionOne = Player.Character.Head.Position * Vector3.new(1, 0, 1);
					local PositionTwo = PositionOne + Vector3.new((Mouse.X/Mouse.ViewSizeX - 0.5) * (Inverse/90), 0, (Mouse.Y/Mouse.ViewSizeY - 0.5) * (Inverse/90)) * Vector3.new(30, 0, 30)
					local Distance    = -math.min((PositionOne - PositionTwo).magnitude, 80)/2
					local MidPoint    = CFrame.new(PositionOne, PositionTwo) * CFrame.new(Tilt % 2 == 1 and Distance or 0, 0, Tilt % 2 == 0 and Distance or 0)
					local CameraGoal  = MidPoint.p + Vector3.new(0, Player.Character.head.Position.Y + SquareRootOf3 * ZoomLevel * 0.5)
					if Tilt == 1 then
						CameraGoal = CameraGoal + Vector3.new(ZoomLevel * 0.5, 0, 0)
					elseif Tilt == 3 then
						CameraGoal = CameraGoal + Vector3.new(-ZoomLevel * 0.5, 0, 0)
					elseif Tilt == 0 then
						CameraGoal = CameraGoal + Vector3.new(0, 0, ZoomLevel * 0.5)
					elseif Tilt == 2 then
						CameraGoal = CameraGoal + Vector3.new(0, 0, -ZoomLevel * 0.5)
					end
					local RayDestination = (CameraGoal - Character.Head.Position)
					local Checker = Ray.new(Character.Head.Position, RayDestination)
					local Hit, Position = AdvanceRaycast(Ray, self.RaycastIgnoreList, true, true)
					if Hit and Position then
						CameraGoal = CameraGoal - (RayDestination.unit * 1)
					end
					Camera.CoordinateFrame = CFrame.new(Configuration.CurrentCoordinateFrame - (Configuration.CurrentCoordinateFrame - CameraGoal) * Vector3.new(0.2, 0.2, 0.2)) * CFrame.Angles(0, math.rad(Configuration.RotationCurrent), 0) * CFrame.Angles(math.rad(-60), 0, 0);
					Configuration.CurrentCoordinateFrame = Camera.CoordinateFrame.p
				else
					print("[CameraSystem] - CharacterCheck failed, resetting to custom system.")
					SetCurrentState("Custom")
				end
			end;
		}
	end

	States.FirstPerson = {
		OnStart = function(Player, Mouse, Camera)
			Player.CameraMode = "Classic";
			Player.CameraMode = "LockFirstPerson";
		end;
		OnStop = function(Player, Mouse, Camera)
			Player.CameraMode = "LockFirstPerson";
			Player.CameraMode = "Classic";
		end;
	}

	CameraSystem.SetCurrentState = SetCurrentState

	local function Step(Mouse)
		if CurrentState and CurrentState.Step then
			local Camera = Workspace.CurrentCamera
			local CoordinateFrame, Focus = CurrentState:Step(Player, Mouse, Camera) -- Returns instead of setting directly to enable tweening.
			if CoordinateFrame then
				Camera.CoordinateFrame = CoordinateFrame
			end
			if Focus then
				Camera.Focus = Focus
			end
		end
	end
	CameraSystem.Step = Step
end)

NevermoreEngine.RegisterLibrary('qCamera', lib)