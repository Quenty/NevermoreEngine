--[=[
	Construct a rounded backing with a shadow.
	@class RoundedBackingBuilder
]=]

local RoundedBackingBuilder = {}
RoundedBackingBuilder.__index = RoundedBackingBuilder
RoundedBackingBuilder.ClassName = "RoundedBackingBuilder"
RoundedBackingBuilder.DEFAULT_SHADOW_TRANSPARENCY = 0.7
RoundedBackingBuilder.BACKING_ASSET_ID = "rbxassetid://735637144"
RoundedBackingBuilder.SHADOW_ASSET_ID = "rbxassetid://735644155"

--[=[
	Initializes a new RoundedBackingBuilder

	If `options.sibling` is true, assumes sibling mode in the ScreenGui, defaults to true.
	@param options { sibling: boolean } -- Options to set
	@return RoundedBackingBuilder
]=]
function RoundedBackingBuilder.new(options)
	local self = setmetatable({}, RoundedBackingBuilder)

	self._options = options or {
		sibling = true;
	}

	return self
end

function RoundedBackingBuilder:Create(gui)
	local backing = self:CreateBacking(gui)
	self:CreateShadow(backing)

	return backing
end

function RoundedBackingBuilder:CreateBacking(gui)
	local backing = Instance.new("ImageLabel")
	backing.Name = "Backing"
	backing.Size = UDim2.new(1, 0, 1, 0)
	backing.Image = self.BACKING_ASSET_ID
	backing.SliceCenter = Rect.new(4, 4, 16, 16)
	backing.ImageColor3 = gui.BackgroundColor3
	backing.ScaleType = Enum.ScaleType.Slice
	backing.BackgroundTransparency = 1
	if self._options.sibling then
		backing.ZIndex = -1
	else
		backing.ZIndex = gui.ZIndex - 1
	end
	backing.Parent = gui

	gui.BackgroundTransparency = 1

	return backing
end

-- Only top two corners are rounded
function RoundedBackingBuilder:CreateTopBacking(gui)
	local backing = self:CreateBacking(gui)
	backing.ImageRectSize = Vector2.new(20, 16)
	backing.SliceCenter = Rect.new(4, 4, 16, 16)

	return backing
end

function RoundedBackingBuilder:CreateLeftBacking(gui)
	local backing = self:CreateBacking(gui)
	backing.ImageRectSize = Vector2.new(16, 20)
	backing.SliceCenter = Rect.new(4, 4, 16, 16)

	return backing
end

function RoundedBackingBuilder:CreateRightBacking(gui)
	local backing = self:CreateBacking(gui)
	backing.ImageRectSize = Vector2.new(16, 20)
	backing.SliceCenter = Rect.new(4, 4, 16, 16)
	backing.ImageRectOffset = Vector2.new(4, 0)

	return backing
end

-- Only bottom two corners are rounded
function RoundedBackingBuilder:CreateBottomBacking(gui)
	local backing = self:CreateBacking(gui)
	backing.ImageRectSize = Vector2.new(20, 16)
	backing.ImageRectOffset = Vector2.new(0, 4)
	backing.SliceCenter = Rect.new(4, 4, 12, 12)

	return backing
end

function RoundedBackingBuilder:CreateTopShadow(backing)
	local shadow = self:CreateShadow(backing)
	shadow.ImageRectSize = Vector2.new(80, 64)
	shadow.SliceCenter = Rect.new(16, 16, 64, 64)

	return shadow
end

function RoundedBackingBuilder:CreateShadow(backing)
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 1)
	shadow.Image = self.SHADOW_ASSET_ID
	shadow.SliceCenter = Rect.new(16, 16, 64, 64)
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.BackgroundTransparency = 1
	shadow.ImageTransparency = RoundedBackingBuilder.DEFAULT_SHADOW_TRANSPARENCY
	shadow.ZIndex = backing.ZIndex - 1
	shadow.Parent = backing.Parent

	return shadow
end

return RoundedBackingBuilder