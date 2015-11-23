local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState       = LoadCustomLibrary("CameraState")

local SummedCamera = {}
SummedCamera.ClassName = "SummedCamera"

SummedCamera.Mode = "World" -- If World, then it just adds positions. 
                            -- If relative, then it moves position relative to CameraA's CoordinateFrame.

-- Intent: Add two cameras together

function SummedCamera.new(CameraA, CameraB)
	-- @param CameraA A CameraState or another CameraEffect to be used
	-- @param CameraB A CameraState or another CameraEffect to be used

	local self = setmetatable({}, SummedCamera)

	self._CameraA = CameraA or error("No CameraA")
	self._CameraB = CameraB or error("No CameraB")

	return self
end

function SummedCamera:SetMode(Mode)
	assert(Mode == "World" or Mode == "Relative")
	self.Mode = Mode

	return self
end

function SummedCamera:__add(Other)
	return SummedCamera.new(self, Other):SetMode(self.Mode)
end

function SummedCamera:__sub(Other)
	if self._CameraA == Other then
		return self._CameraA
	elseif self._CameraB == Other then
		return self._CameraB
	else
		error("Unable to subtract successfully");
	end
end

function SummedCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		if self.Mode == "World" then
			return self.CameraA + self.CameraB
		else
			local Result = self.CameraA + self.CameraB
			Result.qPosition = self.CameraA.CoordinateFrame * self.CameraB.qPosition
			return Result
		end
	elseif Index == "CameraA" then
		return self._CameraA.CameraState or self._CameraA
	elseif Index == "CameraB" then
		return self._CameraB.CameraState or self._CameraB
	else
		return SummedCamera[Index]
	end
end

return SummedCamera