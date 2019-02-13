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

function ImpulseCamera:__newindex(Index, Value)
	if Index == "Damper" then
		self.Spring.Damper = Value
	elseif Index == "Speed" then
		self.Spring.Speed = Value
	elseif Index == "Spring" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of impulse camera")
	end
end

function ImpulseCamera:Impulse(Velocity)
	self.Spring:Impulse(Velocity)
end

function ImpulseCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = CameraState.new()
		local Value = self.Spring.Value
		State.CFrame = CFrame.Angles(0, Value.y, 0) * CFrame.Angles(Value.x, 0, 0) * CFrame.Angles(0, 0, Value.z)
		return State
	elseif Index == "Damper" then
		return self.Spring.Damper
	elseif Index == "Speed" then
		return self.Spring.Speed
	else
		return ImpulseCamera[Index]
	end
end

return ImpulseCamera