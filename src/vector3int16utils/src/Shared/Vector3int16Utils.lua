--[=[
	Module for working with Vector3int16.
	@class Vector3int16Utils
]=]

local Vector3int16Utils = {}

--[=[
	Creates a Vector3int16 from a Vector3
	@param vector3 Vector3
	@return Vector3int16
]=]
function Vector3int16Utils.fromVector3(vector3)
	return Vector3int16.new(vector3.x, vector3.y, vector3.z)
end

return Vector3int16Utils