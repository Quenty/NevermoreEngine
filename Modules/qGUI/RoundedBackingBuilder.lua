-- Intent: Eventually to provide contextual backing with shadows
-- @author Quenty

local RoundedBackingBuilder = {}
RoundedBackingBuilder.__index = RoundedBackingBuilder
RoundedBackingBuilder.ClassName = "RoundedBackingBuilder"

function RoundedBackingBuilder.new()
	local self = setmetatable({}, RoundedBackingBuilder)
		
	return self
end

function RoundedBackingBuilder:CreateBacking(Gui)
	local Backing = Instance.new("ImageLabel")
	Backing.Name = "Backing";
	Backing.Size = UDim2.new(1, 0, 1, 0)
	Backing.Image = "rbxassetid://735637144";
	--Backing.ImageRectSize = Vector2.new(0, 20, 0, 20)
	Backing.SliceCenter = Rect.new(4, 4, 16, 16)
	Backing.ImageColor3 = Gui.BackgroundColor3
	Backing.ScaleType = Enum.ScaleType.Slice
	Backing.BackgroundTransparency = 1
	Backing.ZIndex = Gui.ZIndex - 1
	Backing.Parent = Gui
	
	Gui.BackgroundTransparency = 1
	
	return Backing
end

--- Only top two corners are rounded
function RoundedBackingBuilder:CreateTopBacking(Gui)
	local Backing = self:CreateBacking(Gui)
	Backing.ImageRectSize = Vector2.new(20, 16)
	Backing.SliceCenter = Rect.new(4, 4, 16, 16)
	
	return Backing
end

--- Only bottom two corners are rounded
function RoundedBackingBuilder:CreateBottomBacking(Gui)
	local Backing = self:CreateBacking(Gui)
	Backing.ImageRectOffset = Vector2.new(0, 4)
	Backing.ImageRectSize = Vector2.new(20, 16)
	Backing.SliceCenter = Rect.new(4, 4, 16, 16)
	
	return Backing
end


function RoundedBackingBuilder:CreateShadow(Backing)
	local Shadow = Instance.new("ImageLabel")
	Shadow.Name = "Shadow";
	Shadow.Size = UDim2.new(1, 6, 1, 6);
	Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	Shadow.Position = UDim2.new(0.5, 0, 0.5, 1)
	Shadow.Image = "rbxassetid://735644155";
	--Shadow.ImageRectSize = Vector2.new(0, 80, 0, 80)
	Shadow.SliceCenter = Rect.new(16, 16, 64, 64)
	Shadow.ImageColor3 = Color3.new(0, 0, 0)
	Shadow.ScaleType = Enum.ScaleType.Slice
	Shadow.BackgroundTransparency = 1
	Shadow.ImageTransparency = 0.7
	Shadow.ZIndex = Backing.ZIndex - 1
	Shadow.Parent = Backing.Parent
	
	return Shadow
end

function RoundedBackingBuilder:Create(Gui)
	--- Constructs the new class

	
	local Backing = self:CreateBacking(Gui)
	local Shadow = self:CreateShadow(Backing)	
	
	return Backing
end


return RoundedBackingBuilder