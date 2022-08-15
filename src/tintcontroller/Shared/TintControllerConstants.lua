--[=[
	@class TintControllerConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	TAG_NAME = "Tint",
	COLOR_ATTRIBUTE_NAME = "TintColor",
	BLEND_ATTRIBUTE_NAME = "TintBlend",
})
