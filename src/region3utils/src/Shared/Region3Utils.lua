--- Utility methods for Region3
-- @module Region3Utils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BoundingBoxUtils = require("BoundingBoxUtils")

local Region3Utils = {}

function Region3Utils.fromPositionSize(position, size)
	local halfSize = size/2
	return Region3.new(position - halfSize, position + halfSize)
end

function Region3Utils.fromBox(cframe, size)
	return Region3Utils.fromPositionSize(cframe.p, BoundingBoxUtils.axisAlignedBoxSize(cframe, size))
end

function Region3Utils.fromRadius(position, radius)
	local diameterPadded = 2*radius
	local size = Vector3.new(diameterPadded, diameterPadded, diameterPadded)
	return Region3Utils.fromPositionSize(position, size)
end

return Region3Utils