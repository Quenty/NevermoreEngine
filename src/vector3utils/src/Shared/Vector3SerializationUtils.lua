--!strict
--[=[
	@class Vector3SerializationUtils
]=]

local Vector3SerializationUtils = {}

export type SerializedVector3 = { number }

--[=[
	Returns true if this data is a serialized Vector3

	@param data any
	@return boolean
]=]
function Vector3SerializationUtils.isSerializedVector3(data: any): boolean
	return type(data) == "table" and #data == 3
end

--[=[
	Serialized a Vector3 into a Lua table, which should encode in JSON and be network safe.

	@param vector3 Vector3
	@return SerializedVector3
]=]
function Vector3SerializationUtils.serialize(vector3: Vector3): SerializedVector3
	return {
		vector3.X,
		vector3.Y,
		vector3.Z,
	}
end

--[=[
	Deserializes a Vector3 from a Lua table

	@param data SerializedVector3
	@return Vector3
]=]
function Vector3SerializationUtils.deserialize(data: SerializedVector3): Vector3
	assert(type(data) == "table", "Bad data")
	assert(#data == 3, "Bad data")

	return Vector3.new(data[1], data[2], data[3])
end

return Vector3SerializationUtils
