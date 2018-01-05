--- Helper class for ScreenCover
-- @classmod ScreenCoverBuilder


local ScreenCoverBuilder = {}
ScreenCoverBuilder.__index = ScreenCoverBuilder
ScreenCoverBuilder.ClassName = "ScreenCoverBuilder"

function ScreenCoverBuilder.new(Template)
	local self = setmetatable({}, ScreenCoverBuilder)

	self.Template = Template or error("No Template")

	return self
end

function ScreenCoverBuilder:CreateFrame()
	local template = self.Template or error("No template")

	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = template.BackgroundColor3
	frame.BackgroundTransparency = 0
	frame.ZIndex = template.ZIndex
	frame.Active = true
	frame.Name = "Frame"

	return frame
end

function ScreenCoverBuilder:CreateSquare(squareData)
	local frame = self:CreateFrame()

	frame.Name = "SquareFrame"
	frame.AnchorPoint = squareData.AnchorPoint
	frame.Position = squareData.Position

	return frame
end

return ScreenCoverBuilder