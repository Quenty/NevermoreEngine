--- Add another layer of effects that can be faded in/out
-- @classmod FadeBetweenCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local EPSILON = 1e-4

local FadeBetweenCamera = {}
FadeBetweenCamera.ClassName = "FadeBetweenCamera"

function FadeBetweenCamera.new(cameraA, cameraB)
	local self = setmetatable({
		_spring = Spring.new(0);
		CameraA = cameraA or error("No cameraA");
		CameraB = cameraB or error("No cameraB");
	}, FadeBetweenCamera)

	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera:__newindex(index, Value)
	if index == "Damper" then
		self._spring.Damper = Value
	elseif index == "Value" then
		self._spring.Value = Value
	elseif index == "Speed" then
		self._spring.Speed = Value
	elseif index == "Target" then
		self._spring.Target = Value
	elseif index == "Velocity" then
		self._spring.Velocity = Value
	elseif index == "CameraA" or index == "CameraB" then
		rawset(self, index, Value)
	else
		error(index .. " is not a valid member of fading camera")
	end
end

function FadeBetweenCamera:__index(index)
	if index == "CameraState" then
		local value = self._spring.Value

		if math.abs(value - 1) <= EPSILON then
			return self.CameraStateB
		elseif math.abs(value) <= EPSILON then
			return self.CameraStateA
		else
			local stateA = self.CameraStateA
			local stateB = self.CameraStateB

			return stateA + (stateB - stateA)*value
		end
	elseif index == "CameraStateA" then
		return self.CameraA.CameraState or self.CameraA
	elseif index == "CameraStateB" then
		return self.CameraB.CameraState or self.CameraB
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Value" then
		return self._spring.Value
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "Velocity" then
		return self._spring.Velocity
	elseif index == "HasReachedTarget" then
		return math.abs(self.Value - self.Target) < EPSILON and math.abs(self.Velocity) < EPSILON
	elseif index == "Spring" then
		return self._spring
	else
		return FadeBetweenCamera[index]
	end
end

return FadeBetweenCamera