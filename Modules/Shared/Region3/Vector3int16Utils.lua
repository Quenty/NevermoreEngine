--- Module for working with Vector3int16
-- @module Vector3int16Utils

local Vector3int16Utils = {}

function Vector3int16Utils.fromVector3(vector3)
	return Vector3int16.new(vector3.x, vector3.y, vector3.z)
end

return Vector3int16Utils