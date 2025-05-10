--!strict
--[=[
	Update on heartbeat, must GC this camera state, unlike others. This
	allows for camera effects to run on heartbeat and cache information once instead
	of potentially going deeep into a tree and getting invoked multiple times

	@class HeartbeatCamera
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local Maid = require("Maid")
local SummedCamera = require("SummedCamera")

local HeartbeatCamera = {}
HeartbeatCamera.ClassName = "HeartbeatCamera"
HeartbeatCamera.ProfileName = "HeartbeatCamera"

export type HeartbeatCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		_maid: Maid.Maid,
		_camera: CameraEffectUtils.CameraEffect,
		_currentStateCache: CameraState.CameraState,
	},
	{} :: typeof({ __index = HeartbeatCamera })
)) & CameraEffectUtils.CameraEffect

function HeartbeatCamera.new(camera: CameraEffectUtils.CameraEffect): HeartbeatCamera
	local self: HeartbeatCamera = setmetatable({} :: any, HeartbeatCamera)

	self._camera = assert(camera, "No camera")
	self._maid = Maid.new()

	self._currentStateCache = self._camera.CameraState or error("Camera state returned null")
	self._maid:GiveTask(RunService.Heartbeat:Connect(function()
		debug.profilebegin(self.ProfileName)
		self._currentStateCache = self._camera.CameraState or error("Camera state returned null")
		debug.profileend()
	end))

	return self
end

function HeartbeatCamera.__add(self: HeartbeatCamera, other: CameraEffectUtils.CameraEffect): SummedCamera.SummedCamera
	return SummedCamera.new(self, other)
end

function HeartbeatCamera.ForceUpdateCache(self: HeartbeatCamera): ()
	self._currentStateCache = self._camera.CameraState
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within HeartbeatCamera
]=]
function HeartbeatCamera.__index(self: HeartbeatCamera, index)
	if index == "CameraState" then
		return self._currentStateCache
	else
		return HeartbeatCamera[index]
	end
end

function HeartbeatCamera.Destroy(self: HeartbeatCamera)
	self._maid:DoCleaning()
end

return HeartbeatCamera
