--!strict
--[=[
	Lock camera to only XZPlane, preventing TrackerCameras from making players sick.
	@class XZPlaneLockCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local getRotationInXZPlane = require("getRotationInXZPlane")

local XZPlaneLockCamera = {}
XZPlaneLockCamera.ClassName = "XZPlaneLockCamera"

export type XZPlaneLockCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		_camera: CameraEffectUtils.CameraLike,
	},
	{} :: typeof({ __index = XZPlaneLockCamera })
)) & CameraEffectUtils.CameraEffect

function XZPlaneLockCamera.new(camera: CameraEffectUtils.CameraLike): XZPlaneLockCamera
	local self: XZPlaneLockCamera = setmetatable({} :: any, XZPlaneLockCamera)

	self._camera = assert(camera, "No camera")

	return self
end

function XZPlaneLockCamera.__add(
	self: XZPlaneLockCamera,
	other: CameraEffectUtils.CameraEffect
): SummedCamera.SummedCamera
	return SummedCamera.new(self, other)
end

function XZPlaneLockCamera.__index(self: XZPlaneLockCamera, index)
	if index == "CameraState" then
		local state: CameraState.CameraState = (self._camera :: any).CameraState or self._camera

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
