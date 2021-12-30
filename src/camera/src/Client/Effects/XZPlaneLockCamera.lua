--[=[
	Lock camera to only XZPlane, preventing TrackerCameras from making players sick.
	@class XZPlaneLockCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local getRotationInXZPlane = require("getRotationInXZPlane")

local XZPlaneLockCamera = {}
XZPlaneLockCamera.ClassName = "XZPlaneLockCamera"

function XZPlaneLockCamera.new(camera)
	local self = setmetatable({}, XZPlaneLockCamera)

	self._camera = camera or error("No camera")

	return self
end

function XZPlaneLockCamera:__add(other)
	return SummedCamera.new(self, other)
end

function XZPlaneLockCamera:__index(index)
	if index == "CameraState" then
		local state = self._camera.CameraState or self._camera
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