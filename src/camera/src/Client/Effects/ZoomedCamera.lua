--!strict
--[=[
	Allow freedom of movement around a current place, much like the classic script works now.
	Not intended to be use with the current character script
	Intended to be used with a SummedCamera, relative.

	```lua
	local zoom = ZoomedCamera.new()
	zoom.Zoom = 30 -- Distance from original point
	zoom.MaxZoom = 100 -- max distance away
	zoom.MinZoom = 0.5 -- min distance away
	```

	Assigning .Zoom will automatically clamp

	@class ZoomedCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local ZoomedCamera = {}
ZoomedCamera.ClassName = "ZoomedCamera"
ZoomedCamera._maxZoom = 100
ZoomedCamera._minZoom = 0.5
ZoomedCamera._zoom = 10

export type ZoomedCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		Zoom: number,
		MaxZoom: number,
		MinZoom: number,

		-- Private
		_zoom: number,
		_maxZoom: number,
		_minZoom: number,
	},
	{} :: typeof({ __index = ZoomedCamera })
)) & CameraEffectUtils.CameraEffect

function ZoomedCamera.new(): ZoomedCamera
	local self: ZoomedCamera = setmetatable({} :: any, ZoomedCamera)

	return self
end

function ZoomedCamera.__add(self: ZoomedCamera, other: CameraEffectUtils.CameraEffect): SummedCamera.SummedCamera
	return SummedCamera.new(self, other)
end

function ZoomedCamera.ZoomIn(self: ZoomedCamera, value: number, min: number?, max: number?)
	if min or max then
		self.Zoom = self.Zoom - math.clamp(value, min or -math.huge, max or math.huge)
	else
		self.Zoom = self.Zoom - value
	end
end

function ZoomedCamera.__newindex(self: ZoomedCamera, index, value)
	if index == "Zoom" or index == "TargetZoom" then
		self._zoom = math.clamp(value, self.MinZoom, self.MaxZoom)
	elseif index == "MaxZoom" then
		assert(value > self.MinZoom, "MaxZoom can't be less than MinZoom")

		self._maxZoom = value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	elseif index == "MinZoom" then
		assert(value < self.MaxZoom, "MinZoom can't be greater than MinZoom")

		self._minZoom = value
		self.Zoom = self.Zoom -- Reset the zoom with new constraints.
	else
		rawset(self, index, value)
	end
end

function ZoomedCamera.__index(self: ZoomedCamera, index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.Position = Vector3.new(0, 0, self.Zoom)
		return state
	elseif index == "Zoom" or index == "TargetZoom" then
		return self._zoom
	elseif index == "MaxZoom" then
		return self._maxZoom
	elseif index == "MinZoom" then
		return self._minZoom
	else
		return ZoomedCamera[index]
	end
end

return ZoomedCamera
