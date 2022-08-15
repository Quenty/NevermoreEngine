--[=[
	Utilities for working with a [TintController] bound instance. For a generic utility that tints any part, see [TintableInstanceUtils].

	@class TintControllerUtils
]=]

local require = require(script.Parent.loader).load(script)

local TintControllerConstants = require("TintControllerConstants")

local TintControllerUtils = {}

--[=[
	Given some arbitrary value, attempt to convert it into a Color3.

	@within TintControllerUtils
	@private
	@param color any
	@return Color3?
]=]
local function convertToColor3(color: any): Color3?
	if typeof(color) == "Color3" then
		return color
	elseif typeof(color) == "BrickColor" then
		return color.Color
	elseif typeof(color) == "number" or typeof(color) == "string" then
		-- Assuming that this is a brickcolor swatch.
		local brickColor = BrickColor.new(color)
		return brickColor.Color
	elseif typeof(color) == "table" then
		if #color == 3 then
			local r, g, b = table.unpack(color)
			if typeof(r) == "number" and typeof(g) == "number" and typeof(b) == "number" then
				if r <= 1 and g <= 1 and b <= 1 then
					return Color3.new(r, g, b)
				else
					return Color3.fromRGB(r, g, b)
				end
			end
		end
	end
end

--[=[
	Sets the tint of this controller, and all of its tagged tintable descendants.

	@param controller Instance
	@param color any
]=]
function TintControllerUtils.setTint(controller: Instance, color: any)
	local color3 = convertToColor3(color)
	assert(color3, "Bad tintColor")

	controller:SetAttribute(TintControllerConstants.ATTRIBUTE_NAME, color3)
end

return TintControllerUtils
