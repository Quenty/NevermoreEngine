local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")

-- Intent: Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script

-- Intended to be used with a SummedCamera, relative.

--[[ API

	local Zoom = ZoomedCamera.new()
	Zoom.Zoom = 30 -- Distance from original point
	Zoom.MaxZoom = 100 -- Max distance away
	Zoom.MinZoom = 0.5 -- Min distance away

	-- Assigning .Zoom will automatically clamp
]]

local ZoomedCamera = {}
ZoomedCamera.ClassName = "ZoomedCamera"
ZoomedCamera._MaxZoom = 100
ZoomedCamera._MinZoom = 0.5
ZoomedCamera._Zoom = 10

function ZoomedCamera.new()
	local self = setmetatable({}, ZoomedCamera)

	return self
end

function ZoomedCamera:ZoomIn(Value, Min, Max)
	if Min or Max then
		self.Zoom = self.Zoom - math.clamp(Value, Min or -math.huge, Max or math.huge)
	else
		self.Zoom = self.Zoom - Value
	end
end

function ZoomedCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function ZoomedCamera:__newindex(Index, Value)
	if Index == "Zoom" or Index == "TargetZoom" then
		self._Zoom = math.clamp(Value, self.MinZoom, self.MaxZoom)
	elseif Index == "MaxZoom" then
		assert(Value > self.MinZoom, "MaxZoom can't be less than MinZoom")

		self._MaxZoom = Value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	elseif Index == "MinZoom" then
		assert(Value < self.MaxZoom, "MinZoom can't be greater than MinZoom")

		self._MinZoom = Value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	else
		rawset(self, Index, Value)
	end
end

function ZoomedCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = CameraState.new()
		State.Position = Vector3.new(0, 0, self.Zoom)
		return State
	elseif Index == "Zoom" or Index == "TargetZoom" then
		return self._Zoom
	elseif Index == "MaxZoom" then
		return self._MaxZoom
	elseif Index == "MinZoom" then
		return self._MinZoom
	else
		return ZoomedCamera[Index]
	end
end

return ZoomedCamera