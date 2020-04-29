--- Utility functions for manipulating terrain
-- @module TerrainUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Region3Utils = require("Region3Utils")
local Region3int16Utils = require("Region3int16Utils")
local Vector3int16Utils = require("Vector3int16Utils")

local TerrainUtils = {}

function TerrainUtils.getTerrainRegion3(position, size, resolution)
	return Region3Utils.fromPositionSize(position, size)
		:ExpandToGrid(resolution)
end

function TerrainUtils.getTerrainRegion3int16FromRegion3(region3, resolution)
	local position = region3.CFrame.p/resolution
	local size = region3.Size/resolution

	return Region3int16Utils.createRegion3int16FromPositionSize(position, size)
end

function TerrainUtils.getCorner(region3)
	local position = region3.CFrame.p
	local halfSize = region3.Size/2

	return position - halfSize
end

function TerrainUtils.getCornerint16(region3, resolution)
	local corner = TerrainUtils.getCorner(region3)
	return Vector3int16Utils.fromVector3(corner/resolution)
end

return TerrainUtils