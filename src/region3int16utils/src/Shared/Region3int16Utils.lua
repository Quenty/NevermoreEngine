--- Module for working with Region3int16
-- @module Region3int16Utils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Vector3int16Utils = require("Vector3int16Utils")

local Region3int16Utils = {}

function Region3int16Utils.createRegion3int16FromPositionSize(position, size)
	local halfSize = size/2
	local min = Vector3int16Utils.fromVector3(position - halfSize)
	local max = Vector3int16Utils.fromVector3(position + halfSize)
	return Region3int16.new(min, max)
end

function Region3int16Utils.fromRegion3(region3)
	return Region3int16Utils.createRegion3int16FromPositionSize(region3.CFrame.p, region3.Size)
end

return Region3int16Utils