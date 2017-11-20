local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")
local Spring = LoadCustomLibrary("Spring")

local SmoothPositionCamera = {}
SmoothPositionCamera.ClassName = "SmoothPositionCamera"
SmoothPositionCamera._FocusCamera = nil
SmoothPositionCamera._OriginCamera = nil

-- Intent: Lags the camera smoothly behind the position maintaining other components

function SmoothPositionCamera.new(BaseCamera)
	local self = setmetatable({}, SmoothPositionCamera)

	self.Spring = Spring.new(Vector3.new())
	self.BaseCamera = BaseCamera or error("Must have BaseCamera")
	self.Speed = 10

	return self
end

function SmoothPositionCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function SmoothPositionCamera:__newindex(Index, Value)
	if Index == "BaseCamera" then
		rawset(self, "_" .. Index, Value)
		self.Spring.Target = self.BaseCamera.CameraState.Position
		self.Spring.Position = self.Spring.Target
		self.Spring.Velocity = Vector3.new(0, 0, 0)
	elseif Index == "LastUpdateTime" or Index == "Spring" then
		rawset(self, Index, Value)
	elseif Index == "Speed" or Index == "Damper" or Index == "Velocity" or Index == "Position" then
		self:InternalUpdate()
		self.Spring[Index] = Value
	else
		error(Index .. " is not a valid member of SmoothPositionCamera")
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

function SmoothPositionCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local BaseCameraState = self.BaseCameraState

		local State = CameraState.new()
		State.FieldOfView = BaseCameraState.FieldOfView
		State.CoordinateFrame = BaseCameraState.CoordinateFrame
		State.Position = self.Position
		
		return State
	elseif Index == "Position" then
		self:InternalUpdate()
		return self.Spring.Position
	elseif Index == "Speed" or Index == "Damper" or Index == "Velocity" then
		return self.Spring[Index]
	elseif Index == "Target" then
		return self.BaseCameraState.Position
	elseif Index == "BaseCameraState" then
		return self.BaseCamera.CameraState or self.BaseCamera
	elseif Index == "BaseCamera" then
		return rawget(self, "_" .. Index) or error("Internal error: Index does not exist")
	else
		return SmoothPositionCamera[Index]
	end
end

return SmoothPositionCamera