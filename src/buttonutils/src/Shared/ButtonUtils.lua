--!strict
--[=[
	Provides utility for editing buttons
	@class ButtonUtils
]=]

local ButtonUtils = {}

--[=[
	Gets a tinted mouse over color
	@param originalColor Color3
	@param factor number? -- Defaults to 1
	@return Color3
]=]
function ButtonUtils.getMouseOverColor(originalColor: Color3, factor: number): Color3
	factor = factor or 1
	local h, s, v = Color3.toHSV(originalColor)
	return Color3.fromHSV(h, s, v-0.05*factor)
end

return ButtonUtils