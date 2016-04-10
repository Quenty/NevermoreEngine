local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
	
local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera      = LoadCustomLibrary("SummedCamera")

-- For those barely used effects...

local CustomCameraEffect = {}
CustomCameraEffect.ClassName = "CustomCameraEffect"

function CustomCameraEffect.new(RetrieveState)
	local self = setmetatable({}, CustomCameraEffect)

	self.RetrieveState = RetrieveState or error()

	return self
end

function CustomCameraEffect:__add(Other)
	return SummedCamera.new(self, Other)
end

function CustomCameraEffect:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return self.RetrieveState()
	else
		return CustomCameraEffect[Index]
	end
end

return CustomCameraEffect
