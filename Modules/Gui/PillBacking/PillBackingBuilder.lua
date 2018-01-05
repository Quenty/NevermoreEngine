--- Builds a pill backing for Guis
-- @classmod PillBackingBuilder

local PillBackingBuilder = {}
PillBackingBuilder.__index = PillBackingBuilder
PillBackingBuilder.ClassName = "PillBackingBuilder"

function PillBackingBuilder.new()
	local self = setmetatable({}, PillBackingBuilder)

	return self
end

function PillBackingBuilder:CreateRoundedParts(gui, options)
	options = options or {}

	local left = Instance.new("ImageLabel")
	left.SizeConstraint = Enum.SizeConstraint.RelativeYY
	left.Size = UDim2.new(0.5, 0, 1, 0)
	left.AnchorPoint = Vector2.new(1, 0.5)
	left.Position = UDim2.new(0, 0, 0.5, 0)
	left.Image = "rbxassetid://633244888"
	left.ImageColor3 = gui.BackgroundColor3
	left.ImageRectSize = Vector2.new(128, 256) -- Half circle
	left.Name = "HalfCircle"
	left.ZIndex = options.ZIndex or (gui.ZIndex - 1)
	left.BackgroundTransparency = 1

	local right = left:Clone()
	right.AnchorPoint = Vector2.new(0, 0.5)
	right.Position = UDim2.new(1, 0, 0.5, 0)
	right.ImageRectOffset = Vector2.new(128, 0)

	right.Parent = gui
	left.Parent = gui

	return {left, right}
end

function PillBackingBuilder:Create(gui, options)
	options = options or {}

	local zindex = options.ZIndex or (gui.ZIndex - 1)
	local diameter = gui.Size.Y

	local background = Instance.new("Frame")
	background.Name = "RoundedBackground"
	background.BackgroundColor3 = gui.BackgroundColor3
	background.BorderSizePixel = 0
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.Position = UDim2.new(0.5, 0, 0.5, 0)
	background.Size = UDim2.new(1 - diameter.Scale, -diameter.Offset, 1, 0)
	background.ZIndex = zindex

	self:CreateRoundedParts(background, {
		ZIndex = zindex;
	})

	gui.BackgroundTransparency = 1
	background.Parent = gui

	return background
end

return PillBackingBuilder