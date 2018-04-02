--- Construct a rounded backing with a shadow
-- @classmod RoundedBackingBuilder

local RoundedBackingBuilder = {}
RoundedBackingBuilder.__index = RoundedBackingBuilder
RoundedBackingBuilder.ClassName = "RoundedBackingBuilder"

function RoundedBackingBuilder.new()
	local self = setmetatable({}, RoundedBackingBuilder)

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
	backing.Image = "rbxassetid://735637144"
	backing.SliceCenter = Rect.new(4, 4, 16, 16)
	backing.ImageColor3 = gui.BackgroundColor3
	backing.ScaleType = Enum.ScaleType.Slice
	backing.BackgroundTransparency = 1
	backing.ZIndex = math.max(2, gui.ZIndex - 1)
	backing.Parent = gui

	gui.BackgroundTransparency = 1

	return backing
end

--- Only top two corners are rounded
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

--- Only bottom two corners are rounded
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
	shadow.Image = "rbxassetid://735644155"
	shadow.SliceCenter = Rect.new(16, 16, 64, 64)
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.BackgroundTransparency = 1
	shadow.ImageTransparency = 0.7
	shadow.ZIndex = backing.ZIndex - 1
	shadow.Parent = backing.Parent

	return shadow
end

return RoundedBackingBuilder