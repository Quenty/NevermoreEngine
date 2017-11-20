local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")

-- Intent: Add two cameras together

local SummedCamera = {}
SummedCamera.ClassName = "SummedCamera"
SummedCamera.Mode = "World" -- If World, then it just adds positions. 
                            -- If relative, then it moves position relative to CameraA's CoordinateFrame.

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
			return self.CameraAState + self.CameraBState
		else
			local StateA = self.CameraAState
			local StateB = self.CameraBState
			
			local Result = StateA + StateB
			Result.qPosition = StateA.CoordinateFrame * StateB.qPosition
			return Result
		end
	elseif Index == "CameraAState" then
		return self._CameraA.CameraState or self._CameraA
	elseif Index == "CameraBState" then
		return self._CameraB.CameraState or self._CameraB
	elseif SummedCamera[Index] then
		return SummedCamera[Index]
	else
		error(("[SummedCamera] - '%s' is not a valid member"):format(tostring(Index)))
	end
end

return SummedCamera