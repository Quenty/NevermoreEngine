--- Provides utility for editing buttons
-- @module ButtonUtils

local ButtonUtils = {}

--- Gets a tinted mouse over color
-- @tparam Color3 originalColor
-- @tparam[opt=1] number factor
function ButtonUtils.getMouseOverColor(originalColor, factor)
	factor = factor or 1
	local h, s, v = Color3.toHSV(originalColor)
	return Color3.fromHSV(h, s, v-0.05*factor)
end

return ButtonUtils