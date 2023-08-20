--[=[
	Builds a pill backing for Guis
	@class PillBackingBuilder
]=]

local PillBackingBuilder = {}
PillBackingBuilder.__index = PillBackingBuilder
PillBackingBuilder.ClassName = "PillBackingBuilder"
PillBackingBuilder.CIRCLE_IMAGE_ID = "rbxassetid://633244888" -- White circle
PillBackingBuilder.CIRCLE_SIZE = Vector2.new(256, 256)
PillBackingBuilder.SHADOW_IMAGE_ID = "rbxassetid://707852973"
PillBackingBuilder.SHADOW_SIZE = Vector2.new(128, 128)
PillBackingBuilder.PILL_SHADOW_IMAGE_ID = "rbxassetid://1304004290"
PillBackingBuilder.PILL_SHADOW_SIZE = Vector2.new(256, 128)
PillBackingBuilder.SHADOW_OFFSET_Y = UDim.new(0.05, 0)
PillBackingBuilder.SHADOW_TRANSPARENCY = 0.85

local SLICE_SCALE_DEFAULT = 1024 -- Arbitrary large number to scale against so we're always a pill

function PillBackingBuilder.new(options)
	local self = setmetatable({}, PillBackingBuilder)

	self._options = options or {}

	return self
end

function PillBackingBuilder:CreateSingle(gui, options)
	options = self:_configureOptions(gui, options)

	local pillBacking = Instance.new("ImageLabel")
	pillBacking.AnchorPoint = Vector2.new(0.5, 0.5)
	pillBacking.BackgroundTransparency = 1
	pillBacking.ImageColor3 = options.BackgroundColor3
	pillBacking.BorderSizePixel = 0
	pillBacking.Name = "PillBacking"
	pillBacking.Position = UDim2.new(0.5, 0, 0.5, 0)
	pillBacking.Size = UDim2.new(1, 0, 1, 0)
	pillBacking.ZIndex = options.ZIndex
	pillBacking.ScaleType = Enum.ScaleType.Slice
	pillBacking.SliceScale = SLICE_SCALE_DEFAULT
	pillBacking.SliceCenter = Rect.new(
		self.CIRCLE_SIZE.x/2, self.CIRCLE_SIZE.x/2, self.CIRCLE_SIZE.y/2, self.CIRCLE_SIZE.y/2)
	pillBacking.Image = self.CIRCLE_IMAGE_ID

	gui.BackgroundTransparency = 1
	pillBacking.Parent = gui

	return pillBacking
end

function PillBackingBuilder:Create(gui, options)
	warn("Use CreateSingle" .. debug.traceback())
	options = self:_configureOptions(gui, options)
	local diameter = gui.Size.Y

	local pillBacking = Instance.new("Frame")
	pillBacking.AnchorPoint = Vector2.new(0.5, 0.5)
	pillBacking.BackgroundColor3 = options.BackgroundColor3
	pillBacking.BorderSizePixel = 0
	pillBacking.Name = "PillBacking"
	pillBacking.Position = UDim2.new(0.5, 0, 0.5, 0)
	pillBacking.Size = UDim2.new(1 - diameter.Scale, -diameter.Offset, 1, 0)
	pillBacking.ZIndex = options.ZIndex

	-- Prevent negative sizes (for circles)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(math.huge, math.huge)
	sizeConstraint.MinSize = Vector2.zero
	sizeConstraint.Parent = pillBacking

	local left = self:_createLeft(options)
	local right = self:_createRight(options)
	right.Parent = pillBacking
	left.Parent = pillBacking

	gui.BackgroundTransparency = 1
	pillBacking.Parent = gui

	return pillBacking
end

function PillBackingBuilder:CreateVertical(gui, options)
	warn("Use CreateSingle" .. debug.traceback())
	options = self:_configureOptions(gui, options)
	local diameter = gui.Size.X

	local pillBacking = Instance.new("Frame")
	pillBacking.SizeConstraint = Enum.SizeConstraint.RelativeXX
	pillBacking.AnchorPoint = Vector2.new(0.5, 0.5)
	pillBacking.BackgroundColor3 = options.BackgroundColor3
	pillBacking.BorderSizePixel = 0
	pillBacking.Name = "PillBacking"
	pillBacking.Position = UDim2.new(0.5, 0, 0.5, 0)
	pillBacking.Size = UDim2.new(1, 0, 1 - diameter.Scale, -diameter.Offset)
	pillBacking.ZIndex = options.ZIndex

	-- Prevent negative sizes (for circles)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(math.huge, math.huge)
	sizeConstraint.MinSize = Vector2.zero
	sizeConstraint.Parent = pillBacking

	local top = self:_createTop(options)
	top.Parent = pillBacking

	local bottom = self:_createBottom(options)
	bottom.Parent = pillBacking

	gui.BackgroundTransparency = 1
	pillBacking.Parent = gui

	return pillBacking
end

function PillBackingBuilder:CreateSingleShadow(gui, options)
	options = self:_configureOptions(gui, options)

	local diameter = gui.Size.Y
	local width = gui.Size.X

	local addedScale = 0
	if width.Scale ~= 0 then
		addedScale = diameter.Scale/width.Scale/2
	end

	local shadow = Instance.new("ImageLabel")
	shadow.SliceScale = SLICE_SCALE_DEFAULT
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.ImageTransparency = self.SHADOW_TRANSPARENCY
	shadow.Name = "PillShadow"
	shadow.Position = UDim2.new(0.5, 0, 0.5, self.SHADOW_OFFSET_Y)
	shadow.Size = UDim2.new(1 + addedScale, diameter.Offset/2, 2, 0)
	shadow.ZIndex = options.ShadowZIndex
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(self.SHADOW_SIZE.x/2, self.SHADOW_SIZE.x/2, self.SHADOW_SIZE.y/2, self.SHADOW_SIZE.y/2)
	shadow.Image = self.SHADOW_IMAGE_ID

	shadow.Parent = gui

	return shadow
end

function PillBackingBuilder:CreateShadow(gui, options)
	-- warn("Use CreateSingleShadow" .. debug.traceback())
	options = self:_configureOptions(gui, options)
	local diameter = gui.Size.Y

	local shadow = self:_createPillShadow(options)
	shadow.SizeConstraint = Enum.SizeConstraint.RelativeXY
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Name = "PillShadow"
	shadow.ImageRectSize = self.PILL_SHADOW_SIZE * Vector2.new(0.5, 1)
	shadow.ImageRectOffset = self.PILL_SHADOW_SIZE * Vector2.new(0.25, 0)
	shadow.Position = UDim2.new(UDim.new(0.5, 0), UDim.new(0.5, 0) + self.SHADOW_OFFSET_Y)
	shadow.Size = UDim2.new(1 - diameter.Scale, -diameter.Offset, 2, 0)
	shadow.ZIndex = options.ShadowZIndex

	-- Prevent negative sizes (for circles)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(math.huge, math.huge)
	sizeConstraint.MinSize = Vector2.zero
	sizeConstraint.Parent = shadow

	local left = self:_createLeftShadow(options)
	local right = self:_createRightShadow(options)
	right.Parent = shadow
	left.Parent = shadow

	shadow.Parent = gui

	return shadow
end

function PillBackingBuilder:CreateCircle(gui, options)
	options = self:_configureOptions(gui, options)
	local circle = self:_createCircle(options)

	circle.ImageTransparency = gui.BackgroundTransparency
	gui.BackgroundTransparency = 1
	circle.Parent = gui

	return circle
end

function PillBackingBuilder:CreateCircleShadow(gui, options)
	options = self:_configureOptions(gui, options)
	local shadow = Instance.new("ImageLabel")
	shadow.SliceScale = SLICE_SCALE_DEFAULT
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundTransparency = 1
	shadow.Image = self.SHADOW_IMAGE_ID
	shadow.ImageTransparency = self.SHADOW_TRANSPARENCY
	shadow.Name = "CircleShadow"
	shadow.Position = UDim2.new(UDim.new(0.5, 0), UDim.new(0.5, 0) + self.SHADOW_OFFSET_Y)
	shadow.Size = UDim2.new(2, 0, 2, 0)
	shadow.SizeConstraint = Enum.SizeConstraint.RelativeYY

	shadow.ZIndex = options.ShadowZIndex

	shadow.Parent = gui

	return shadow
end

function PillBackingBuilder:CreateLeft(gui, options)
	options = self:_configureOptions(gui, options)
	local left = self:_createLeft(options)
	left.Parent = gui
	return left
end

function PillBackingBuilder:CreateRight(gui, options)
	options = self:_configureOptions(gui, options)
	local right = self:_createRight(options)
	right.Parent = gui
	return right
end

function PillBackingBuilder:CreateTop(gui, options)
	options = self:_configureOptions(gui, options)
	local top = self:_createTop(options)
	top.Parent = gui
	return top
end

function PillBackingBuilder:CreateBottom(gui, options)
	options = self:_configureOptions(gui, options)
	local bottom = self:_createBottom(options)
	bottom.Parent = gui
	return bottom
end

function PillBackingBuilder:_createTop(options)
	local top = self:_createCircle(options)
	top.SizeConstraint = Enum.SizeConstraint.RelativeXX
	top.AnchorPoint = Vector2.new(0.5, 1)
	top.ImageRectSize = self.CIRCLE_SIZE * Vector2.new(1, 0.5)
	top.Name = "TopHalfCircle"
	top.Position = UDim2.new(0.5, 0, 0, 0)
	top.Size = UDim2.new(1, 0, 0.5, 0)

	return top
end

function PillBackingBuilder:_createBottom(options)
	local bottom = self:_createCircle(options)
	bottom.SizeConstraint = Enum.SizeConstraint.RelativeXX
	bottom.AnchorPoint = Vector2.new(0.5, 0)
	bottom.ImageRectOffset = self.CIRCLE_SIZE * Vector2.new(0, 0.5)
	bottom.ImageRectSize = self.CIRCLE_SIZE * Vector2.new(1, 0.5)
	bottom.Name = "BottomHalfCircle"
	bottom.Position = UDim2.new(0.5, 0, 1, 0)
	bottom.Size = UDim2.new(1, 0, 0.5, 0)

	return bottom
end

function PillBackingBuilder:_createLeft(options)
	local left = self:_createCircle(options)
	left.AnchorPoint = Vector2.new(1, 0.5)
	left.ImageRectSize = self.CIRCLE_SIZE * Vector2.new(0.5, 1)
	left.Name = "LeftHalfCircle"
	left.Position = UDim2.new(0, 0, 0.5, 0)
	left.Size = UDim2.new(0.5, 0, 1, 0)

	return left
end

function PillBackingBuilder:_createRight(options)
	options = self:_configureOptions(options)

	local right = self:_createCircle(options)
	right.AnchorPoint = Vector2.new(0, 0.5)
	right.ImageRectOffset = self.CIRCLE_SIZE * Vector2.new(0.5, 0)
	right.ImageRectSize = self.CIRCLE_SIZE * Vector2.new(0.5, 1)
	right.Name = "RightHalfCircle"
	right.Position = UDim2.new(1, 0, 0.5, 0)
	right.Size = UDim2.new(0.5, 0, 1, 0)

	return right
end

function PillBackingBuilder:_createLeftShadow(options)
	local left = self:_createPillShadow(options)
	left.AnchorPoint = Vector2.new(1, 0.5)
	left.ImageRectSize = self.PILL_SHADOW_SIZE * Vector2.new(0.25, 1)
	left.Name = "LeftShadow"
	left.Position = UDim2.new(0, 0, 0.5, 0)
	left.Size = UDim2.new(0.5, 0, 1, 0)

	return left
end

function PillBackingBuilder:_createRightShadow(options)
	local right = self:_createPillShadow(options)
	right.AnchorPoint = Vector2.new(0, 0.5)
	right.ImageRectOffset = self.PILL_SHADOW_SIZE * Vector2.new(0.75, 0)
	right.ImageRectSize = self.PILL_SHADOW_SIZE * Vector2.new(0.25, 1)
	right.Name = "RightShadow"
	right.Position = UDim2.new(1, 0, 0.5, 0)
	right.Size = UDim2.new(0.5, 0, 1, 0)

	return right
end

function PillBackingBuilder:_createCircle(options)
	local circle = Instance.new("ImageLabel")
	circle.BackgroundTransparency = 1
	circle.Image = self.CIRCLE_IMAGE_ID
	circle.Name = "Circle"
	circle.Size = UDim2.new(1, 0, 1, 0)
	circle.SizeConstraint = Enum.SizeConstraint.RelativeYY

	-- set options
	circle.ImageColor3 = options.BackgroundColor3
	circle.ZIndex = options.ZIndex

	return circle
end

function PillBackingBuilder:_createPillShadow(options)
	local shadow = Instance.new("ImageLabel")
	shadow.BackgroundTransparency = 1
	shadow.Image = self.PILL_SHADOW_IMAGE_ID
	shadow.ImageTransparency = self.SHADOW_TRANSPARENCY
	shadow.Name = "PillShadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.SizeConstraint = Enum.SizeConstraint.RelativeYY

	shadow.ZIndex = options.ShadowZIndex

	return shadow
end

function PillBackingBuilder:_configureOptions(gui, options)
	assert(gui, "Must pass in GUI")

	options = table.clone(options or self._options)
	options.ZIndex = options.ZIndex or gui.ZIndex
	options.ShadowZIndex = options.ShadowZIndex or options.ZIndex - 1
	options.BackgroundColor3 = options.BackgroundColor3 or gui.BackgroundColor3

	return options
end

return PillBackingBuilder