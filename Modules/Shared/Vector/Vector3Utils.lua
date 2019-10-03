---
-- @module Vector3Utils

local Vector3Utils = {}

function Vector3Utils.fromVector2XY(vector2)
	return Vector3.new(vector2.x, vector2.y, 0)
end

return Vector3Utils