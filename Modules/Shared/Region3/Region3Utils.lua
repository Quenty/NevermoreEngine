--- Utility methods for Region3
-- @module Region3Utils

local Region3Utils = {}

function Region3Utils.createRegion3FromPositionSize(position, size)
	local halfSize = size/2
	return Region3.new(position - halfSize, position + halfSize)
end

return Region3Utils