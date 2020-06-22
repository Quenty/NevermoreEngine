---
-- @module UICornerUtils
-- @author Quenty

local UICornerUtils = {}

function UICornerUtils.fromScale(scale, parent)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(scale, 0)
	uiCorner.Parent = parent
	return uiCorner
end

function UICornerUtils.fromOffset(offset, parent)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, offset)
	uiCorner.Parent = parent
	return uiCorner
end

return UICornerUtils