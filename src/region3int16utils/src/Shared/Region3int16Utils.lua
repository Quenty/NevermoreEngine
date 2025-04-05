--!strict
--[=[
	Module for working with Region3int16
	@class Region3int16Utils
]=]

local require = require(script.Parent.loader).load(script)

local Vector3int16Utils = require("Vector3int16Utils")

local Region3int16Utils = {}

function Region3int16Utils.createRegion3int16FromPositionSize(position: Vector3, size: Vector3): Region3int16
	local halfSize = size / 2
	local min = Vector3int16Utils.fromVector3(position - halfSize)
	local max = Vector3int16Utils.fromVector3(position + halfSize)
	return Region3int16.new(min, max)
end

function Region3int16Utils.fromRegion3(region3: Region3): Region3int16
	return Region3int16Utils.createRegion3int16FromPositionSize(region3.CFrame.Position, region3.Size)
end

return Region3int16Utils