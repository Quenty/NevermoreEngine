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
	local self = setmetatable({}, ImpulseCamera)

	self.Spring = Spring.new(Vector3.new())

	self.Damper = 0.5
	self.Speed = 20

	return self
end

function ImpulseCamera:__add(other)
	return SummedCamera.new(self, other)
end

function ImpulseCamera:__newindex(index, value)
	if index == "Damper" then
		self.Spring.Damper = value
	elseif index == "Speed" then
		self.Spring.Speed = value
	elseif index == "Spring" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of impulse camera")
	end
end

function ImpulseCamera:Impulse(Velocity)
	self.Spring:Impulse(Velocity)
end

function ImpulseCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local state = CameraState.new()
		local value = self.Spring.Value
		state.CFrame = CFrame.Angles(0, value.y, 0) * CFrame.Angles(value.x, 0, 0) * CFrame.Angles(0, 0, value.z)
		return state
	elseif index == "Damper" then
		return self.Spring.Damper
	elseif index == "Speed" then
		return self.Spring.Speed
	else
		return ImpulseCamera[index]
	end
end

return ImpulseCamera