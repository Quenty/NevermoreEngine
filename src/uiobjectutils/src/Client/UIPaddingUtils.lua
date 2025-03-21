--!strict
--[=[
	Utility functions for UI padding
	@class UIPaddingUtils
]=]

local UIPaddingUtils = {}

--[=[
	Constructs a new UIPadding from a UDim
]=]
function UIPaddingUtils.fromUDim(udim: UDim): UIPadding
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingBottom = udim
	uiPadding.PaddingTop = udim
	uiPadding.PaddingLeft = udim
	uiPadding.PaddingRight = udim

	return uiPadding
end

--[=[
	Compute the total padding for the UIPadding
]=]
function UIPaddingUtils.getTotalPadding(uiPadding: UIPadding): UDim2
	return UDim2.new(uiPadding.PaddingLeft + uiPadding.PaddingRight, uiPadding.PaddingBottom + uiPadding.PaddingTop)
end

--[=[
	Computes the total absolute padding for a UIPadding
]=]
function UIPaddingUtils.getTotalAbsolutePadding(uiPadding: UIPadding, absoluteSize: Vector2): Vector2
	local padding = UIPaddingUtils.getTotalPadding(uiPadding)
	return Vector2.new(
		padding.X.Offset + padding.X.Scale * absoluteSize.X,
		padding.Y.Offset + padding.Y.Scale * absoluteSize.Y
	)
end

--[=[
	Compute the horizontal Padding
]=]
function UIPaddingUtils.getHorizontalPadding(uiPadding: UIPadding): UDim
	return uiPadding.PaddingLeft + uiPadding.PaddingRight
end

return UIPaddingUtils
