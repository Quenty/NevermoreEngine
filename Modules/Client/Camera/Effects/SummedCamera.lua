--- Add two cameras together
-- @classmod SummedCamera

local SummedCamera = {}
SummedCamera.ClassName = "SummedCamera"

--- Construct a new summed camera
-- @constructor
-- @param cameraA A CameraState or another CameraEffect to be used
-- @param cameraB A CameraState or another CameraEffect to be used
function SummedCamera.new(cameraA, cameraB)
	local self = setmetatable({}, SummedCamera)

	self._mode = "World"
	self._cameraA = cameraA or error("No cameraA")
	self._cameraB = cameraB or error("No cameraB")

	return self
end

---
-- @param mode Mode to set
-- If "World", then it just adds positions.
-- If "Relative", then it moves position relative to cameraA's CFrame.
function SummedCamera:SetMode(mode)
	assert(mode == "World" or mode == "Relative")
	self._mode = mode

	return self
end

function SummedCamera:__addClass(other)
	return SummedCamera.new(self, other)
end

function SummedCamera:__add(other)
	return SummedCamera.new(self, other):SetMode(self._mode)
end

function SummedCamera:__sub(camera)
	if self._cameraA == camera then
		return self._cameraA
	elseif self._cameraB == camera then
		return self._cameraB
	else
		error("Unable to subtract successfully");
	end
end

function SummedCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		if self._mode == "World" then
			return self.CameraAState + self.CameraBState
		else
			local StateA = self.CameraAState
			local StateB = self.CameraBState

			local Result = StateA + StateB
			Result.Position = StateA.CFrame * StateB.Position
			return Result
		end
	elseif index == "CameraAState" then
		return self._cameraA.CameraState or self._cameraA
	elseif index == "CameraBState" then
		return self._cameraB.CameraState or self._cameraB
	elseif SummedCamera[index] then
		return SummedCamera[index]
	else
		error(("[SummedCamera] - '%s' is not a valid member"):format(tostring(index)))
	end
end

return SummedCamera