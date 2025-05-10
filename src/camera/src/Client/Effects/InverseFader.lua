--!strict
--[=[
	Be the inverse of a fading camera (makes scaling in cameras easy).
	@class InverseFader
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local FadingCamera = require("FadingCamera")
local SummedCamera = require("SummedCamera")

local InverseFader = {}
InverseFader.ClassName = "InverseFader"

export type InverseFader = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		_camera: CameraEffectUtils.CameraEffect,
		_fader: FadingCamera.FadingCamera,
	},
	{} :: typeof({ __index = InverseFader })
)) & CameraEffectUtils.CameraEffect

function InverseFader.new(camera: CameraEffectUtils.CameraEffect, fader: FadingCamera.FadingCamera)
	local self: InverseFader = setmetatable({} :: any, InverseFader)

	self._camera = camera or error("No camera")
	self._fader = fader or error("No fader")

	return self
end

function InverseFader.__add(self: InverseFader, other)
	return SummedCamera.new(self, other)
end

function InverseFader.__index(self: InverseFader, index)
	if index == "CameraState" then
		local cameraState: CameraState.CameraState = (self._camera.CameraState :: any) or (self._camera :: any)

		-- TODO: I think this is actually wrong
		return (cameraState :: any) * (1 - self._fader.Value)
	else
		return InverseFader[index]
	end
end

return InverseFader
