local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera      = LoadCustomLibrary("SummedCamera")
local qCFrame           = LoadCustomLibrary("qCFrame")

local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane

-- Intent: Lock camera to only ZZPlane, preventing TrackerCameras from making players sick.

local XZPlaneLockCamera = {}
XZPlaneLockCamera.ClassName = "XZPlaneLockCamera"

function XZPlaneLockCamera.new(Camera)
	local self = setmetatable({}, XZPlaneLockCamera)

	self.Camera = Camera or error("No camera")

	return self
end

function XZPlaneLockCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function XZPlaneLockCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = self.Camera.CameraState or self.Camera
		local XZRotation = GetRotationInXZPlane(State.CoordinateFrame)

		local NewState = CameraState.new()
		NewState.CoordinateFrame = XZRotation
		NewState.FieldOfView = State.FieldOfView

		return NewState
	else
		return XZPlaneLockCamera[Index]
	end
end

return XZPlaneLockCamera