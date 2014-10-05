local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary('qSystems')
local qCFrame           = LoadCustomLibrary('qCFrame')

qSystems:Import(getfenv(1))

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


return lib