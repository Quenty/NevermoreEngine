--[=[
	Utility functions to deal with Roblox's mobile jump button and its position
	@class JumpButtonUtils
]=]

local JumpButtonUtils = {}

--[=[
	Computes the jump button's position and size based upon Roblox's logic.
	@param screenGuiAbsSize Vector2
	@return Vector2 -- Position
	@return number -- Width
]=]
function JumpButtonUtils.getJumpButtonPositionAndSize(screenGuiAbsSize)
	local minAxis = math.min(screenGuiAbsSize.x, screenGuiAbsSize.y)

	-- This is Roblox's logic for the jump button
	local position, width
	if minAxis <= 500 then
		width = 70
		position = UDim2.new(1, -(width*1.5-10), 1, -width - 20)
	else
        width = 120
        position = UDim2.new(1, -(width*1.5-10), 1, -width * 1.75)
    end

	return position, width
end

return JumpButtonUtils