--[=[
	For effects that can be easily bound in scope
	@class CustomCameraEffect
]=]

local require = require(script.Parent.loader).load(script)

local SummedCamera = require("SummedCamera")

local CustomCameraEffect = {}
CustomCameraEffect.ClassName = "CustomCameraEffect"

--[=[
	Constructs a new custom camera effect
	@param getCurrentStateFunc () -> CameraState -- Custom effect generator
	@return CustomCameraEffect
]=]
function CustomCameraEffect.new(getCurrentStateFunc)
	local self = setmetatable({}, CustomCameraEffect)

	self._getCurrentStateFunc = getCurrentStateFunc or error("getCurrentStateFunc is required")

	return self
end

function CustomCameraEffect:__add(other)
	return SummedCamera.new(self, other)
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within CustomCameraEffect
]=]
function CustomCameraEffect:__index(index)
	if index == "CameraState" then
		return self._getCurrentStateFunc()
	else
		return CustomCameraEffect[index]
	end
end

return CustomCameraEffect