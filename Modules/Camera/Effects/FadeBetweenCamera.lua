--- Add another layer of effects that can be faded in/out
-- @classmod FadeBetweenCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local FadeBetweenCamera = {}
FadeBetweenCamera.ClassName = "FadeBetweenCamera"

SummedCamera.addToClass(FadeBetweenCamera)

function FadeBetweenCamera.new(CameraA, CameraB)
	local self = setmetatable({}, FadeBetweenCamera)

	self.Spring = Spring.new(0)

	self.CameraA = CameraA or error("No CameraA")
	self.CameraB = CameraB or error("No CameraB")
	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera:__newindex(Index, Value)
	if Index == "Damper" then
		self.Spring.Damper = Value
	elseif Index == "Value" then
		self.Spring.Value = Value
	elseif Index == "Speed" then
		self.Spring.Speed = Value
	elseif Index == "Target" then
		self.Spring.Target = Value
	elseif Index == "Velocity" then
		self.Spring.Velocity = Value
	elseif Index == "Spring" or Index == "CameraA" or Index == "CameraB" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of fading camera")
	end
end


function FadeBetweenCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local Value = self.Spring.Value

		if math.abs(Value - 1) <= 1e-4 then
			return self.CameraStateB
		elseif math.abs(Value) <= 1e-4 then
			return self.CameraStateA
		else
			local StateA = self.CameraStateA
			local StateB = self.CameraStateB
	
			return StateA + (StateB - StateA)*Value
		end
	elseif Index == "CameraStateA" then
		return self.CameraA.CameraState or self.CameraA
	elseif Index == "CameraStateB" then
		return self.CameraB.CameraState or self.CameraB
	elseif Index == "Damper" then
		return self.Spring.Damper
	elseif Index == "Value" then
		return self.Spring.Value
	elseif Index == "Speed" then
		return self.Spring.Speed
	elseif Index == "Target" then
		return self.Spring.Target
	elseif Index == "Velocity" then
		return self.Spring.Velocity
	elseif Index == "HasReachedTarget" then
		return math.abs(self.Value - self.Target) < 1e-4 and math.abs(self.Velocity) < 1e-4
	else
		return FadeBetweenCamera[Index]
	end
end

return FadeBetweenCamera