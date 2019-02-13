--- Lags the camera smoothly behind the position maintaining other components
-- @classmod SmoothPositionCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local Spring = require("Spring")

local SmoothPositionCamera = {}
SmoothPositionCamera.ClassName = "SmoothPositionCamera"
SmoothPositionCamera._FocusCamera = nil
SmoothPositionCamera._OriginCamera = nil

function SmoothPositionCamera.new(baseCamera)
	local self = setmetatable({}, SmoothPositionCamera)

	self.Spring = Spring.new(Vector3.new())
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
		self.Spring.Velocity = Vector3.new(0, 0, 0)
	elseif index == "LastUpdateTime" or index == "Spring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" or index == "Position" then
		self:InternalUpdate()
		self.Spring[index] = value
	else
		error(index .. " is not a valid member of SmoothPositionCamera")
	end
end

function SmoothPositionCamera:InternalUpdate()
	local Delta
	if self.LastUpdateTime then
		Delta = tick() - self.LastUpdateTime
	end

	self.LastUpdateTime = tick()
	self.Spring.Target = self.BaseCameraState.Position

	if Delta then
		self.Spring:TimeSkip(Delta)
	end
end

function SmoothPositionCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local baseCameraState = self.BaseCameraState

		local state = CameraState.new()
		state.FieldOfView = baseCameraState.FieldOfView
		state.CFrame = baseCameraState.CFrame
		state.Position = self.Position

		return state
	elseif index == "Position" then
		self:InternalUpdate()
		return self.Spring.Position
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		return self.Spring[index]
	elseif index == "Target" then
		return self.BaseCameraState.Position
	elseif index == "BaseCameraState" then
		return self.BaseCamera.CameraState or self.BaseCamera
	elseif index == "BaseCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return SmoothPositionCamera[index]
	end
end

return SmoothPositionCamera