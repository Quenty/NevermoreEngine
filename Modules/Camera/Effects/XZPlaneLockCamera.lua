--- Lock camera to only XZPlane, preventing TrackerCameras from making players sick.
-- @classmod XZPlaneLockCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local qCFrame = require("qCFrame")
local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane

local XZPlaneLockCamera = {}
XZPlaneLockCamera.ClassName = "XZPlaneLockCamera"

function XZPlaneLockCamera.new(Camera)
	local self = setmetatable({}, XZPlaneLockCamera)

	self.Camera = Camera or error("No camera")

	return self
end

function XZPlaneLockCamera:__add(other)
	return SummedCamera.new(self, other)
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