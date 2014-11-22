local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qCFrame           = LoadCustomLibrary("qCFrame")


local lib = {}

local function PointCamera(CoordinateFrame, Focus)
	workspace.CurrentCamera.Focus = Focus
	workspace.CurrentCamera.CoordinateFrame = CFrame.new(CoordinateFrame.p, Focus.p)
end
lib.PointCamera = PointCamera
lib.pointCamera = PointCamera

local function SetCurrentCameraToScriptable()
	--[[local CoordinateFrame, Focus = workspace.CurrentCamera.CoordinateFrame.p, workspace.CurrentCamera.Focus
	workspace.CurrentCamera:Destroy()
	wait(0)
	while not workspace.CurrentCamera do wait(0) end
	workspace.CurrentCamera.CameraType = "Scriptable"
	workspace.CurrentCamera.CoordinateFrame = CFrame.new(CoordinateFrame, Focus.p)
	workspace.CurrentCamera.Focus = Focus
	return CoordinateFrame, Focus--]]

	workspace.CurrentCamera.CameraType = "Scriptable";
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
		if (opposite) then
			i = (i2*((time()-t)/durration))
		else
			i = (i*(1-((time()-t)/durration)))
		end
		workspace.CurrentCamera.CoordinateFrame = (c0*CFrame.new((-i+(math.random()*i)),(-i+(math.random()*i)),(-i+(math.random()*i))))
		workspace.CurrentCamera.Focus = (f0*CFrame.new((-i+(math.random()*i)),(-i+(math.random()*i)),(-i+(math.random()*i))))
		wait(0)
	end
	workspace.CurrentCamera.CoordinateFrame = c0
	workspace.CurrentCamera.Focus = f0
end

lib.ShakeCamera = ShakeCamera
lib.shakeCamera = ShakeCamera

local function SetPlayerControl()
	if Players.LocalPlayer.Character then
		workspace.CurrentCamera.CameraSubject = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
	end
	workspace.CurrentCamera.CameraType = "Custom"
end
lib.SetPlayerControl = SetPlayerControl
lib.setPlayerControl = SetPlayerControl


local TweenCameraOverideId = 0
local OpeatingTweenCamera = false;

local function TweenCamera(CoordinateFrameTarget, FocusTarget, TimeToTween, Override, RollTarget, FieldOfViewTarget)
	SetCurrentCameraToScriptable()
	spawn(function()
		if Override and OpeatingTweenCamera then
			--print("Camera Tween: Overriding operation");
			TweenCameraOverideId = TweenCameraOverideId+1;
		elseif OpeatingTweenCamera then
			--print("Camera Tween: Did not override, old operation is continueing");
			return false;
		end
		OpeatingTweenCamera = true;

		FieldOfViewTarget = FieldOfViewTarget or workspace.CurrentCamera.FieldOfView
		RollTarget = RollTarget or workspace.CurrentCamera:GetRoll()

		local CurrentNumber = TweenCameraOverideId;
		local OriginalRoll = workspace.CurrentCamera:GetRoll()
		local OriginalFieldOfView = workspace.CurrentCamera.FieldOfView
		local CoordinateFocusStart = workspace.CurrentCamera.Focus.p
		local CoordinateFrameStart = CFrame.new(workspace.CurrentCamera.CoordinateFrame.p, CoordinateFocusStart)
		local CoordinateFrameFinish = CFrame.new(CoordinateFrameTarget, FocusTarget)

		local RepetitionIntervol = (1/(TimeToTween/wait(0)))
		local Repetitions

		for Index = 0, 1, RepetitionIntervol do
			local SmoothIndex = math.sin((Index - 0.5) * math.pi)/2 + 0.5
			local Focus = CoordinateFocusStart:lerp(FocusTarget, SmoothIndex)
			workspace.CurrentCamera.CoordinateFrame = qCFrame.SlerpCFrame(CoordinateFrameStart, CoordinateFrameFinish, SmoothIndex)
			workspace.CurrentCamera.Focus = CFrame.new(Focus)
			workspace.CurrentCamera:SetRoll(OriginalRoll + ((RollTarget - OriginalRoll) * SmoothIndex))
			workspace.CurrentCamera.FieldOfView = OriginalFieldOfView + ((FieldOfViewTarget - OriginalFieldOfView)) * SmoothIndex
			wait(0)

			if TweenCameraOverideId ~= CurrentNumber then
				return false;
			end
		end

		OpeatingTweenCamera = false;
		PointCamera(CFrame.new(CoordinateFrameTarget), CFrame.new(FocusTarget))
		workspace.CurrentCamera:SetRoll(RollTarget)
		workspace.CurrentCamera.FieldOfView = FieldOfViewTarget
		return true;
	end)
end
lib.TweenCamera = TweenCamera
lib.tweenCamera = TweenCamera


return lib