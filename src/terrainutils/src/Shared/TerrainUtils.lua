--!strict
--[=[
	Utility functions for manipulating terrain
	@class TerrainUtils
]=]

local require = require(script.Parent.loader).load(script)

local Region3Utils = require("Region3Utils")
local Region3int16Utils = require("Region3int16Utils")
local Vector3int16Utils = require("Vector3int16Utils")

local TerrainUtils = {}

--[=[
	Gets the terrain region from the position and size
	@param position Vector3
	@param size Vector3
	@param resolution number
	@return Region3
]=]
function TerrainUtils.getTerrainRegion3(position: Vector3, size: Vector3, resolution: number): Region3
	return Region3Utils.fromPositionSize(position, size):ExpandToGrid(resolution)
end

--[=[
	Gets the terrain region3int16 from a terrain region (in world space) at the resolution
	requested.
	@param region3 Region3
	@param resolution number
	@return Region3int16
]=]
function TerrainUtils.getTerrainRegion3int16FromRegion3(region3: Region3, resolution: number): Region3int16
	local position = region3.CFrame.Position / resolution
	local size = region3.Size / resolution

	return Region3int16Utils.createRegion3int16FromPositionSize(position, size)
end

--[=[
	Gets the corner of terrain for a region3
	@param region3 Region3
	@return Vector3
]=]
function TerrainUtils.getCorner(region3: Region3): Vector3
	local position = region3.CFrame.Position
	local halfSize = region3.Size / 2

	return position - halfSize
end

--[=[
	Gets the corner of the region in Vector3int16
	@param region3 Region3
	@param resolution number
	@return Vector3int16
]=]
function TerrainUtils.getCornerint16(region3: Region3, resolution: number): Vector3int16
	local corner = TerrainUtils.getCorner(region3)
	return Vector3int16Utils.fromVector3(corner / resolution)
end

return TerrainUtils
