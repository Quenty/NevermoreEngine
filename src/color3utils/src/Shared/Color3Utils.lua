--!strict
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
function Color3Utils.getRelativeLuminance(color: Color3): number
	local components = { color.R, color.G, color.B }
	local vals = {}
	for i, val in components do
		if val <= 0.03928 then
			vals[i] = val / 12.92
		else
			vals[i] = ((val + 0.055) / 1.055) ^ 2.4
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
function Color3Utils.textShouldBeBlack(color: Color3): boolean
	return Color3Utils.getRelativeLuminance(color) > 0.179
end

--[=[
	Scales the value component of hsv
	@param color3 Color3
	@param percent number -- Percent scaling
	@return Color3
]=]
function Color3Utils.scaleValue(color3: Color3, percent: number): Color3
	local h, s, v = color3:ToHSV()
	return Color3.fromHSV(h, s, percent * v)
end

--[=[
	Sets the value component of hsv
	@param color3 Color3
	@param value number
	@return Color3
]=]
function Color3Utils.setValue(color3: Color3, value: number): Color3
	local h, s, _ = color3:ToHSV()
	return Color3.fromHSV(h, s, value)
end

--[=[
	Sets the hue component of hsv
	@param color3 Color3
	@param hue number
	@return Color3
]=]
function Color3Utils.setHue(color3: Color3, hue: number): Color3
	local _, s, v = color3:ToHSV()
	return Color3.fromHSV(hue, s, v)
end

--[=[
	Scales the saturation component of hsv
	@param color3 Color3
	@param percent number -- Percent scaling
	@return Color3
]=]
function Color3Utils.scaleSaturation(color3: Color3, percent: number): Color3
	local h, s, v = color3:ToHSV()
	return Color3.fromHSV(h, percent * s, v)
end

--[=[
	Sets the saturation component of hsv
	@param color3 Color3
	@param saturation number
	@return Color3
]=]
function Color3Utils.setSaturation(color3: Color3, saturation: number): Color3
	local h, _, v = color3:ToHSV()
	return Color3.fromHSV(h, saturation, v)
end

--[=[
	Compares 2 color3 values

	@param a Color3
	@param b Color3
	@param epsilon number? -- Optional
	@return boolean
]=]
function Color3Utils.areEqual(a: Color3, b: Color3, epsilon: number?): boolean
	local equalEpsilon = if epsilon then epsilon else 1e-6

	return math.abs(a.R - b.R) <= equalEpsilon
		and math.abs(a.G - b.G) <= equalEpsilon
		and math.abs(a.B - b.B) <= equalEpsilon
end

--[=[
	Converts the color3 to the actual hex integer used in web and other
	areas.

	@param color3 Color3
	@return number
]=]
function Color3Utils.toHexInteger(color3: Color3): number
	assert(typeof(color3) == "Color3", "Bad color3")

	return bit32.bor(bit32.lshift(color3.R * 0xFF, 16), bit32.lshift(color3.G * 0xFF, 8), color3.B * 0xFF)
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
function Color3Utils.toHexString(color3: Color3): string
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
function Color3Utils.toWebHexString(color3: Color3): string
	assert(typeof(color3) == "Color3", "Bad color3")

	return string.format("#%06X", Color3Utils.toHexInteger(color3))
end

return Color3Utils
