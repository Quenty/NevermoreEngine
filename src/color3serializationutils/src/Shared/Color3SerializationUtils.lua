--- Utility functions to help serialize Color3 values
-- @module Color3SerializationUtils
-- @author Quenty

local Color3SerializationUtils = {}

function Color3SerializationUtils.serialize(color3)
	return {
		math.floor(color3.r*255),
		math.floor(color3.g*255),
		math.floor(color3.b*255)
	}
end

function Color3SerializationUtils.isSerializedColor3(color3)
	return type(color3) == "table" and #color3 == 3
end

function Color3SerializationUtils.fromRGB(r, g, b)
	assert(type(r) == "number", "Bad r")
	assert(type(g) == "number", "Bad g")
	assert(type(b) == "number", "Bad b")

	return {
		r,
		g,
		b
	}
end

function Color3SerializationUtils.deserialize(color3)
	assert(type(color3) == "table", "Bad color3")
	assert(#color3 == 3, "Bad color3")

	return Color3.fromRGB(color3[1], color3[2], color3[3])
end

return Color3SerializationUtils