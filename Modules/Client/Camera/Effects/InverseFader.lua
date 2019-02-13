--- Be the inverse of a fading camera (makes scaling in cameras easy).
-- @classmod InverseFader

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SummedCamera = require("SummedCamera")

local InverseFader = {}
InverseFader.ClassName = "InverseFader"

function InverseFader.new(Camera, Fader)
	local self = setmetatable({}, InverseFader)

	self.Camera = Camera or error()
	self.Fader = Fader or error()

	return self
end

function InverseFader:__add(other)
	return SummedCamera.new(self, other)
end

function InverseFader:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		return (self.Camera.CameraState or self.Camera)*(1-self.Fader.Value)
	else
		return InverseFader[index]
	end
end

return InverseFader