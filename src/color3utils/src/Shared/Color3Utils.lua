--[=[
	Utility methods for Roblox Color3 values
	@class Color3Utils
]=]

local Color3Utils = {}

--[=[
	 Luminance as per W3 per sRGB colorspace normalized with 0
	 as the darkest dark, and 1 as the whitest white.

	 See https://www.w3.org/TR/WCAG20/#relativeluminancedef

	 @param color Color3 -- The Color3 to check
	 @return number -- A scalar from 0 to 1 with 0 as the darkest dark, and 1 as the whitest white

]=]
function Color3Utils.getRelativeLuminance(color)
	local components = { color.r, color.g, color.b }
	local vals = {}
	for i, val in pairs(components) do
		if val <= 0.03928 then
			vals[i] = val/12.92
		else
			vals[i] = ((val+0.055)/1.055) ^ 2.4
		end
	end

	return 0.2126 * vals[1] + 0.7152 * vals[2] + 0.0722 * vals[3]
end

--[=[
	Returns whether or not the text should be black using
	relative luminance as a metric.

	See https://stackoverflow.com/questions/3942878/

	@param color Color3 -- The Color3 to check
	@return boolean -- True if the text should be black, false if it should be good
]=]
function Color3Utils.textShouldBeBlack(color)
	return Color3Utils.getRelativeLuminance(color) > 0.179
end

--[=[
	Scales the value component of hsv
	@param color3 Color3
	@param percent number -- Percent scaling
	@return Color3
]=]
function Color3Utils.scaleValue(color3, percent)
	local h, s, v = Color3.toHSV(color3)
	return Color3.fromHSV(h, s, percent*v)
end

--[=[
	Sets the value component of hsv
	@param color3 Color3
	@param value number
	@return Color3
]=]
function Color3Utils.setValue(color3, value)
	local h, s, _ = Color3.toHSV(color3)
	return Color3.fromHSV(h, s, value)
end

--[=[
	Sets the hue component of hsv
	@param color3 Color3
	@param hue number
	@return Color3
]=]
function Color3Utils.setHue(color3, hue)
	local _, s, v = Color3.toHSV(color3)
	return Color3.fromHSV(hue, s, v)
end

--[=[
	Scales the saturation component of hsv
	@param color3 Color3
	@param percent number -- Percent scaling
	@return Color3
]=]
function Color3Utils.scaleSaturation(color3, percent)
	local h, s, v = Color3.toHSV(color3)
	return Color3.fromHSV(h, percent*s, v)
end

--[=[
	Sets the saturation component of hsv
	@param color3 Color3
	@param saturation number
	@return Color3
]=]
function Color3Utils.setSaturation(color3, saturation)
	local h, _, v = Color3.toHSV(color3)
	return Color3.fromHSV(h, saturation, v)
end

--[=[
	Compares 2 color3 values

	@param a Color3
	@param b Color3
	@param epsilon number? -- Optional
	@return boolean
]=]
function Color3Utils.areEqual(a, b, epsilon)
	if not epsilon then
		epsilon = 1e-6
	end

	return math.abs(a.r - b.r) <= epsilon
		and math.abs(a.g - b.g) <= epsilon
		and math.abs(a.b - b.b) <= epsilon
end

--[=[
	Converts the color3 to the actual hex integer used in web and other
	areas.

	@param color3 Color3
	@return number
]=]
function Color3Utils.toHexInteger(color3)
	assert(typeof(color3) == "Color3", "Bad color3")

	return bit32.bor(bit32.lshift(color3.r*0xFF, 16), bit32.lshift(color3.g*0xFF, 8), color3.b*0xFF)
end

--[=[
	Converts the color3 to the actual hex integer used in web and other
	areas.

	```
	Color3Utils.toHexString(Color3.fromRGB(0, 255, 0)) --> 00FF00
	```

	@param color3 Color3
	@return number
]=]
function Color3Utils.toHexString(color3)
	assert(typeof(color3) == "Color3", "Bad color3")

	return string.format("%06X", Color3Utils.toHexInteger(color3))
end

--[=[
	Converts the color3 to the standard web hex string

	```
	Color3Utils.toWebHexString(Color3.fromRGB(0, 255, 0)) --> #00FF00
	```

	@param color3 Color3
	@return number
]=]
function Color3Utils.toWebHexString(color3)
	assert(typeof(color3) == "Color3", "Bad color3")

	return string.format("#%06X", Color3Utils.toHexInteger(color3))
end

return Color3Utils