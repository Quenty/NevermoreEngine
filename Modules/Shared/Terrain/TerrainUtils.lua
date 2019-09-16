---
-- @module TerrainUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Region3Utils = require("Region3Utils")

local TerrainUtils = {}

function TerrainUtils.getTerrainRegion3(position, size, resolution)
	return Region3Utils.createRegion3FromPositionSize(position, size)
		:ExpandToGrid(resolution)
end

return TerrainUtils