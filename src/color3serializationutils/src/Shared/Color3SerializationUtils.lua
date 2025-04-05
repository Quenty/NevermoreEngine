--!strict
--[=[
	Utility functions to help serialize Color3 values
	@class Color3SerializationUtils
]=]

local Color3SerializationUtils = {}

--[=[
	@type SerializedColor3 { [1]: number, [2]: number, [3]: number }
	@within Color3SerializationUtils
]=]
export type SerializedColor3 = { number }

--[=[
	Serializes a Color3 into a JSON or DataStore safe value.
	@param color3 Color3
	@return SerializedColor3
]=]
function Color3SerializationUtils.serialize(color3: Color3): SerializedColor3
	return {
		math.floor(color3.R * 255),
		math.floor(color3.G * 255),
		math.floor(color3.B * 255),
	}
end

--[=[
	Returns whether a value is a serialized Color3
	@param color3 any
	@return boolean
]=]
function Color3SerializationUtils.isSerializedColor3(color3: any): boolean
	return type(color3) == "table" and #color3 == 3
end

--[=[
	Creates a SerializedColor3 from r g b (0, 255)
	@param r number
	@param g number
	@param b number
	@return SerializedColor3
]=]
function Color3SerializationUtils.fromRGB(r: number, g: number, b: number): SerializedColor3
	assert(type(r) == "number", "Bad r")
	assert(type(g) == "number", "Bad g")
	assert(type(b) == "number", "Bad b")

	return {
		r,
		g,
		b,
	}
end

--[=[
	Deserializes the color into a Color3
	@param color3 Color3
	@return SerializedColor3
]=]
function Color3SerializationUtils.deserialize(color3: SerializedColor3): Color3
	assert(type(color3) == "table", "Bad color3")
	assert(#color3 == 3, "Bad color3")

	return Color3.fromRGB(color3[1], color3[2], color3[3])
end

return Color3SerializationUtils