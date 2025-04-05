--!strict
--[=[
	Utility method to work with the Roblox Rect data object.

	@class RectUtils
]=]

local RectUtils = {}

--[=[
	Returns true if the position is contained within the rect

	@param position Vector2
	@return boolean
]=]
function RectUtils.contains(rect: Rect, position: Vector2): boolean
	local relativePosition = position - rect.Min

	return relativePosition.X >= 0
		and relativePosition.Y >= 0
		and relativePosition.X <= rect.Width
		and relativePosition.Y <= rect.Height
end

return RectUtils