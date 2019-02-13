--- Lock camera to only XZPlane, preventing TrackerCameras from making players sick.
-- @classmod XZPlaneLockCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local getRotationInXZPlane = require("getRotationInXZPlane")

local XZPlaneLockCamera = {}
XZPlaneLockCamera.ClassName = "XZPlaneLockCamera"

function XZPlaneLockCamera.new(camera)
	local self = setmetatable({}, XZPlaneLockCamera)

	self.Camera = camera or error("No camera")

	return self
end

function XZPlaneLockCamera:__add(other)
	return SummedCamera.new(self, other)
end

function XZPlaneLockCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local state = self.Camera.CameraState or self.Camera
		local xzrot = getRotationInXZPlane(state.CFrame)

		local newState = CameraState.new()
		newState.CFrame = xzrot
		newState.FieldOfView = state.FieldOfView

		return newState
	else
		return XZPlaneLockCamera[index]
	end
end

return XZPlaneLockCamera