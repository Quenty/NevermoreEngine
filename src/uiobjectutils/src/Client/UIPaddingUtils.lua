--[=[
	Utility functions for UI padding
	@class UIPaddingUtils
]=]

local UIPaddingUtils = {}

function UIPaddingUtils.fromUDim(udim)
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingBottom = udim
	uiPadding.PaddingTop = udim
	uiPadding.PaddingLeft = udim
	uiPadding.PaddingRight = udim

	return uiPadding
end

function UIPaddingUtils.getTotalPadding(uiPadding)
	return UDim2.new(uiPadding.PaddingLeft + uiPadding.PaddingRight,
		uiPadding.PaddingBottom + uiPadding.PaddingTop)
end

function UIPaddingUtils.getTotalAbsolutePadding(uiPadding, absoluteSize)
	local padding = UIPaddingUtils.getTotalPadding(uiPadding)
	return Vector2.new(
		padding.X.Offset + padding.X.Scale*absoluteSize.x,
		padding.Y.Offset + padding.Y.Scale*absoluteSize.Y
	)
end

function UIPaddingUtils.getHorizontalPadding(uiPadding)
	return uiPadding.PaddingLeft + uiPadding.PaddingRight
end


return UIPaddingUtils