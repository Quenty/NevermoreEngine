--[=[
	@class Vector3SerializationUtils
]=]

local Vector3SerializationUtils = {}

function Vector3SerializationUtils.isSerializedVector3(data)
	return type(data) == "table" and #data == 3
end

function Vector3SerializationUtils.serialize(vector3)
	return {
		vector3.x,
		vector3.y,
		vector3.z
	}
end

function Vector3SerializationUtils.deserialize(data)
	assert(type(data) == "table", "Bad data")
	assert(#data == 3, "Bad data")

	return Vector3.new(data[1], data[2], data[3])
end

return Vector3SerializationUtils