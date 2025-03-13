--!strict
--[=[
	Utility methods for Region3
	@class Region3Utils
]=]

local require = require(script.Parent.loader).load(script)

local BoundingBoxUtils = require("BoundingBoxUtils")

local Region3Utils = {}

function Region3Utils.fromPositionSize(position: Vector3, size: Vector3): Region3
	local halfSize = size / 2
	return Region3.new(position - halfSize, position + halfSize)
end

function Region3Utils.fromBox(cframe: CFrame, size: Vector3): Region3
	return Region3Utils.fromPositionSize(cframe.Position, BoundingBoxUtils.axisAlignedBoxSize(cframe, size))
end

function Region3Utils.fromRadius(position: Vector3, radius: number): Region3
	local diameterPadded = 2*radius
	local size = Vector3.new(diameterPadded, diameterPadded, diameterPadded)
	return Region3Utils.fromPositionSize(position, size)
end

return Region3Utils