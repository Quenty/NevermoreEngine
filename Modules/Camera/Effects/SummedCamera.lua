local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState       = LoadCustomLibrary("CameraState")

local SummedCamera = {}
SummedCamera.ClassName = "SummedCamera"

-- Intent: Add two cameras together

function SummedCamera.new(CameraA, CameraB)
	-- @param CameraA A CameraState or another CameraEffect to be used
	-- @param CameraB A CameraState or another CameraEffect to be used
	
	local self = setmetatable({}, SummedCamera)

	self._CameraA = CameraA or error("No CameraA")
	self._CameraB = CameraB or error("No CameraB")

	return self
end

function SummedCamera:__add(Other)
	return SummedCamera.new(self, Other)
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
		return self.CameraA + self.CameraB
	elseif Index == "CameraA" then
		return self._CameraA.CameraState or self._CameraA
	elseif Index == "CameraB" then
		return self._CameraB.CameraState or self._CameraB
	else
		return SummedCamera[Index]
	end
end

return SummedCamera