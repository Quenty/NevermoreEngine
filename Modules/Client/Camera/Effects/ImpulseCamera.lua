--- Add another layer of effects over any other camera by allowing an "impulse"
-- to be applied. Good for shockwaves, camera shake, and recoil
-- @classmod ImpulseCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local ImpulseCamera = {}
ImpulseCamera.ClassName = "ImpulseCamera"

function ImpulseCamera.new()
	local self = setmetatable({
		_spring = Spring.new(Vector3.new(0, 0, 0))
	}, ImpulseCamera)

	self._spring.Damper = 0.5
	self._spring.Speed = 20

	return self
end

function ImpulseCamera:Impulse(velocity)
	assert(typeof(velocity) == "Vector3")

	self._spring:Impulse(velocity)
end

function ImpulseCamera:__add(other)
	return SummedCamera.new(self, other)
end

function ImpulseCamera:__newindex(index, value)
	if index == "Damper" then
		assert(type(value) == "number")
		self._spring.Damper = value
	elseif index == "Speed" then
		assert(type(value) == "number")
		self._spring.Speed = value
	else
		error(("%q is not a valid member of impulse camera"):format(tostring(index)))
	end
end

function ImpulseCamera:__index(index)
	if index == "CameraState" then
		local newState = CameraState.new()

		local position = self._spring.Value
		newState.CFrame = CFrame.Angles(0, position.y, 0)
			* CFrame.Angles(position.x, 0, 0)
			* CFrame.Angles(0, 0, position.z)

		return newState
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Spring" then
		return self._spring
	else
		return ImpulseCamera[index]
	end
end

return ImpulseCamera