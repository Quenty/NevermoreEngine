--[=[
	@class ColorPickerUtils
]=]

local require = require(script.Parent.loader).load(script)

local LuvColor3Utils = require("LuvColor3Utils")

local ColorPickerUtils = {}

function ColorPickerUtils.getOutlineWithContrast(color, backingColor)
	assert(typeof(color) == "Color3", "Bad color")
	assert(typeof(backingColor) == "Color3", "Bad backingColor")

	local l, u, v = unpack(LuvColor3Utils.fromColor3(color))
	local _, _, bv = unpack(LuvColor3Utils.fromColor3(backingColor))

	if bv <= 50 then
		v = math.clamp(v + 80, 0, 100)
	else
		v = math.clamp(v - 80, 0, 100)
	end

	return LuvColor3Utils.toColor3({l, u, v})
end

return ColorPickerUtils