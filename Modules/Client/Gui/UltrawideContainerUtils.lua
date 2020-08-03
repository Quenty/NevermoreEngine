---
-- @module UltrawideContainerUtils
-- @author Quenty

local UltrawideContainerUtils = {}

function UltrawideContainerUtils.createContainer(parent)
	local frame = Instance.new("Frame")
	frame.Name = "UltrawideContainer"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BorderSizePixel = 0
	frame.Transparency = 1
	frame.Size = UDim2.new(1, 0, 1, 0)

	local uiSizeConstraint = Instance.new("UISizeConstraint")
	uiSizeConstraint.MaxSize = Vector2.new(1920, 1080)
	uiSizeConstraint.MinSize = Vector2.new(0, 0)
	uiSizeConstraint.Parent = frame

	frame.Parent = parent

	return frame, uiSizeConstraint
end

function UltrawideContainerUtils.scaleSizeConstraint(container, uiSizeConstraint, scale)
	if scale ~= 0 then
		container.Size = UDim2.new(1/scale, 0, 1/scale, 0)
		uiSizeConstraint.MaxSize = Vector2.new(1920/scale, 1080/scale)
	end
end

return UltrawideContainerUtils