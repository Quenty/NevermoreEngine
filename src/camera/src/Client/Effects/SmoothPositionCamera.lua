--[=[
	Lags the camera smoothly behind the position maintaining other components
	@class SmoothPositionCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local Spring = require("Spring")
local CameraFrame = require("CameraFrame")
local QFrame = require("QFrame")

local SmoothPositionCamera = {}
SmoothPositionCamera.ClassName = "SmoothPositionCamera"

function SmoothPositionCamera.new(baseCamera)
	local self = setmetatable({}, SmoothPositionCamera)

	self.Spring = Spring.new(Vector3.zero)
	self.BaseCamera = baseCamera or error("Must have BaseCamera")
	self.Speed = 10

	return self
end

function SmoothPositionCamera:__add(other)
	return SummedCamera.new(self, other)
end

function SmoothPositionCamera:__newindex(index, value)
	if index == "BaseCamera" then
		rawset(self, "_" .. index, value)
		self.Spring.Target = self.BaseCamera.CameraState.Position
		self.Spring.Position = self.Spring.Target
		self.Spring.Velocity = Vector3.zero
	elseif index == "_lastUpdateTime" or index == "Spring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" or index == "Position" then
		self:_internalUpdate()
		self.Spring[index] = value
	else
		error(index .. " is not a valid member of SmoothPositionCamera")
	end
end

function SmoothPositionCamera:__index(index)
	if index == "CameraState" then
		local baseCameraState = self.BaseCamera.CameraState
		local baseCameraFrame = baseCameraState.CameraFrame
		local baseCameraFrameDerivative = baseCameraState.CameraFrameDerivative

		local cameraFrame = CameraFrame.new(
			QFrame.fromVector3(self.Position, baseCameraFrame.QFrame),
			baseCameraFrame.FieldOfView)
		local cameraFrameDerivative = CameraFrame.new(
			QFrame.fromVector3(self.Velocity, baseCameraFrameDerivative.QFrame),
			baseCameraFrameDerivative.FieldOfView)

		return CameraState.new(cameraFrame, cameraFrameDerivative)
	elseif index == "Position" then
		self:_internalUpdate()
		return self.Spring.Position
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		return self.Spring[index]
	elseif index == "Target" then
		return self.BaseCamera.CameraState.Position
	elseif index == "BaseCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return SmoothPositionCamera[index]
	end
end

function SmoothPositionCamera:_internalUpdate()
	local delta
	if self._lastUpdateTime then
		delta = tick() - self._lastUpdateTime
	end

	self._lastUpdateTime = tick()
	self.Spring.Target = self.BaseCamera.CameraState.Position

	if delta then
		self.Spring:TimeSkip(delta)
	end
end

return SmoothPositionCamera