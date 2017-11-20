local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")

local InverseFader = {}
InverseFader.ClassName = "InverseFader"

-- Intent: Be the inverse of a fading camera (makes scaling in cameras easy).

function InverseFader.new(Camera, Fader)
	local self = setmetatable({}, InverseFader)

	self.Camera = Camera or error()
	self.Fader = Fader or error()

	return self
end

function InverseFader:__add(Other)
	return SummedCamera.new(self, Other)
end

function InverseFader:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return (self.Camera.CameraState or self.Camera)*(1-self.Fader.Value)
	else
		return InverseFader[Index]
	end
end

return InverseFader