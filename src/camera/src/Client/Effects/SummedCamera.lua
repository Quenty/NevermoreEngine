--[=[
	Add two cameras together
	@class SummedCamera
]=]

local require = require(script.Parent.loader).load(script)

local QFrame = require("QFrame")
local CameraState = require("CameraState")
local CameraFrame = require("CameraFrame")

local SummedCamera = {}
SummedCamera.ClassName = "SummedCamera"

--[=[
	Construct a new summed camera

	@param cameraA CameraEffect -- A CameraState or another CameraEffect to be used
	@param cameraB CameraEffect -- A CameraState or another CameraEffect to be used
	@return SummedCamera
]=]
function SummedCamera.new(cameraA, cameraB)
	local self = setmetatable({}, SummedCamera)

	self._mode = "World"
	self._cameraA = cameraA or error("No cameraA")
	self._cameraB = cameraB or error("No cameraB")

	return self
end

--[=[
	Sets the summation mode. If "World", then it just adds positions.
	If "Relative", then it moves position relative to cameraA's CFrame.

	@param mode "World" | "Relative" -- Mode to set
	@return SummedCamera
]=]
function SummedCamera:SetMode(mode)
	assert(mode == "World" or mode == "Relative", "Bad mode")
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
	if index == "CameraState" then
		if self._mode == "World" then
			-- TODO: fix this
			-- return self.CameraAState + self.CameraBState
			error("not implemented")
		else
			local a = self.CameraAState
			local b = self.CameraBState

			local newQFrame = QFrame.fromCFrameClosestTo(a.CFrame*b.CFrame, a.CameraFrame.QFrame)
			local cameraFrame = CameraFrame.new(newQFrame, a.FieldOfView + b.FieldOfView)

			-- TODO: compute derivative velocity more correctly of this non-linear thing
			local newQFrameVelocity = QFrame.fromCFrameClosestTo(
				a.CameraFrameDerivative.CFrame*b.CameraFrameDerivative.CFrame,
				a.CameraFrameDerivative.QFrame)
			local cameraFrameVelocity = CameraFrame.new(newQFrameVelocity,
				a.CameraFrameDerivative.FieldOfView + b.CameraFrameDerivative.FieldOfView)

			local result = CameraState.new(cameraFrame, cameraFrameVelocity)
			-- result.CFrame =
			-- result.Position = a.CFrame * b.Position
			return result
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