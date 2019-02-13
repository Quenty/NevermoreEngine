--- Utility methods for Roblox Color3 values
-- @module Color3Utils

local lib = {}

--- Luminance as per W3 per sRGB colorspace normalized with 0
-- as the darkest dark, and 1 as the whitest white
-- @tparam {Color3} color The Color3 to check
-- @treturn A scalar from 0 to 1 with 0 as the darkest dark, and 1 as the whitest white
-- See https://www.w3.org/TR/WCAG20/#relativeluminancedef
function lib.GetRelativeLuminance(color)
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

--- Returns whether or not the text should be black using
-- relative luminance as a metric.
-- @tparam {Color3} color The Color3 to check
-- @treturn {boolean} True if the text should be black, false if it should be good
-- See https://stackoverflow.com/questions/3942878/
function lib.TextShouldBeBlack(color)
	return lib.GetRelativeLuminance(color) > 0.179
end

return lib