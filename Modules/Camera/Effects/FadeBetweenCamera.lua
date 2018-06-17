--- Add another layer of effects that can be faded in/out
-- @classmod FadeBetweenCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local FadeBetweenCamera = {}
FadeBetweenCamera.ClassName = "FadeBetweenCamera"

function FadeBetweenCamera.new(CameraA, CameraB)
	local self = setmetatable({}, FadeBetweenCamera)

	self.Spring = Spring.new(0)

	self.CameraA = CameraA or error("No CameraA")
	self.CameraB = CameraB or error("No CameraB")
	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera:__newindex(index, Value)
	if index == "Damper" then
		self.Spring.Damper = Value
	elseif index == "Value" then
		self.Spring.Value = Value
	elseif index == "Speed" then
		self.Spring.Speed = Value
	elseif index == "Target" then
		self.Spring.Target = Value
	elseif index == "Velocity" then
		self.Spring.Velocity = Value
	elseif index == "Spring" or index == "CameraA" or index == "CameraB" then
		rawset(self, index, Value)
	else
		error(index .. " is not a valid member of fading camera")
	end
end

function FadeBetweenCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local value = self.Spring.Value

		if math.abs(value - 1) <= 1e-4 then
			return self.CameraStateB
		elseif math.abs(value) <= 1e-4 then
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
		return self.Spring.Damper
	elseif index == "Value" then
		return self.Spring.Value
	elseif index == "Speed" then
		return self.Spring.Speed
	elseif index == "Target" then
		return self.Spring.Target
	elseif index == "Velocity" then
		return self.Spring.Velocity
	elseif index == "HasReachedTarget" then
		return math.abs(self.Value - self.Target) < 1e-4 and math.abs(self.Velocity) < 1e-4
	else
		return FadeBetweenCamera[index]
	end
end

return FadeBetweenCamera