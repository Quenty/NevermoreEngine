--- Utility functions for UI padding
-- @module UIPaddingUtils

local UIPaddingUtils = {}

function UIPaddingUtils.fromUDim(udim)
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingBottom = udim
	uiPadding.PaddingTop = udim
	uiPadding.PaddingLeft = udim
	uiPadding.PaddingRight = udim

	return uiPadding
end

return UIPaddingUtils