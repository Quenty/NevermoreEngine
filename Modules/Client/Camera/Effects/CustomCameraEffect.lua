--- For effects that can be easily bound in scope
-- @classmod CustomCameraEffect

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SummedCamera = require("SummedCamera")

local CustomCameraEffect = {}
CustomCameraEffect.ClassName = "CustomCameraEffect"

--- Constructs a new custom camera effect
-- @tparam function getCurrentStateFunc to return a function state
function CustomCameraEffect.new(getCurrentStateFunc)
	local self = setmetatable({}, CustomCameraEffect)

	self._getCurrentStateFunc = getCurrentStateFunc or error("getCurrentStateFunc is required")

	return self
end

function CustomCameraEffect:__add(other)
	return SummedCamera.new(self, other)
end

function CustomCameraEffect:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		return self._getCurrentStateFunc()
	else
		return CustomCameraEffect[index]
	end
end

return CustomCameraEffect