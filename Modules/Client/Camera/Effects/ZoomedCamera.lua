--- Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script
-- Intended to be used with a SummedCamera, relative.
-- @classmod ZoomedCamera
-- @usage
-- local Zoom = ZoomedCamera.new()
-- Zoom.Zoom = 30 -- Distance from original point
-- Zoom.MaxZoom = 100 -- max distance away
-- Zoom.MinZoom = 0.5 -- min distance away
-- Assigning .Zoom will automatically clamp

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local ZoomedCamera = {}
ZoomedCamera.ClassName = "ZoomedCamera"
ZoomedCamera._MaxZoom = 100
ZoomedCamera._MinZoom = 0.5
ZoomedCamera._zoom = 10

function ZoomedCamera.new()
	local self = setmetatable({}, ZoomedCamera)

	return self
end

function ZoomedCamera:__add(other)
	return SummedCamera.new(self, other)
end

function ZoomedCamera:ZoomIn(value, min, max)
	if min or max then
		self.Zoom = self.Zoom - math.clamp(value, min or -math.huge, max or math.huge)
	else
		self.Zoom = self.Zoom - value
	end
end

function ZoomedCamera:__newindex(index, value)
	if index == "Zoom" or index == "TargetZoom" then
		self._zoom = math.clamp(value, self.MinZoom, self.MaxZoom)
	elseif index == "MaxZoom" then
		assert(value > self.MinZoom, "MaxZoom can't be less than MinZoom")

		self._MaxZoom = value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	elseif index == "MinZoom" then
		assert(value < self.MaxZoom, "MinZoom can't be greater than MinZoom")

		self._MinZoom = value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	else
		rawset(self, index, value)
	end
end

function ZoomedCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local State = CameraState.new()
		State.Position = Vector3.new(0, 0, self.Zoom)
		return State
	elseif index == "Zoom" or index == "TargetZoom" then
		return self._zoom
	elseif index == "MaxZoom" then
		return self._MaxZoom
	elseif index == "MinZoom" then
		return self._MinZoom
	else
		return ZoomedCamera[index]
	end
end

return ZoomedCamera