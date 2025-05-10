--!strict
--[=[
	For effects that can be easily bound in scope
	@class CustomCameraEffect
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local CustomCameraEffect = {}
CustomCameraEffect.ClassName = "CustomCameraEffect"

export type ComputeCameraState = () -> CameraState.CameraState

export type CustomCameraEffect = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		_getCurrentStateFunc: ComputeCameraState,
	},
	{} :: typeof({ __index = CustomCameraEffect })
)) & CameraEffectUtils.CameraEffect

--[=[
	Constructs a new custom camera effect
	@param getCurrentStateFunc () -> CameraState -- Custom effect generator
	@return CustomCameraEffect
]=]
function CustomCameraEffect.new(getCurrentStateFunc: ComputeCameraState): CustomCameraEffect
	local self: CustomCameraEffect = setmetatable({} :: any, CustomCameraEffect)

	self._getCurrentStateFunc = getCurrentStateFunc or error("getCurrentStateFunc is required")

	return self
end

function CustomCameraEffect.__add(
	self: CustomCameraEffect,
	other: CameraEffectUtils.CameraEffect
): SummedCamera.SummedCamera
	return SummedCamera.new(self, other)
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within CustomCameraEffect
]=]
function CustomCameraEffect.__index(self: CustomCameraEffect, index)
	if index == "CameraState" then
		return self._getCurrentStateFunc()
	else
		return CustomCameraEffect[index]
	end
end

return CustomCameraEffect
