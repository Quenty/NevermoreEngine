--- Be the inverse of a fading camera (makes scaling in cameras easy).
-- @classmod InverseFader

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SummedCamera = require("SummedCamera")

local InverseFader = {}
InverseFader.ClassName = "InverseFader"

function InverseFader.new(camera, fader)
	local self = setmetatable({}, InverseFader)

	self._camera = camera or error("No camera")
	self._fader = fader or error("No fader")

	return self
end

function InverseFader:__add(other)
	return SummedCamera.new(self, other)
end

function InverseFader:__index(index)
	if index == "CameraState" then
		return (self._camera.CameraState or self._camera)*(1-self._fader.Value)
	else
		return InverseFader[index]
	end
end

return InverseFader