--- Builds card backings for GUI elements
-- @classmod MaterialCardBuilder

local MaterialCardBuilder = {}
MaterialCardBuilder.__index = MaterialCardBuilder
MaterialCardBuilder.ClassName = "MaterialCardBuilder"
MaterialCardBuilder.CardColor = Color3.fromRGB(235, 235, 235)
MaterialCardBuilder.ShadowColor = Color3.new(0, 0, 0)

function MaterialCardBuilder.new(Gui)
	local self = setmetatable({}, MaterialCardBuilder)

	self.Gui = Gui or error("No GUI")

	return self
end

function MaterialCardBuilder:WithZIndex(ZIndex)
	self.ZIndex = ZIndex or error("No ZIndex")

	return self
end

function MaterialCardBuilder:WithCardColor(Color)
	self.CardColor = Color or error("No color")

	return self
end

function MaterialCardBuilder:Create()
	local ZIndex = self.ZIndex or self.Gui.ZIndex

	local function SetProperties(Color, ImageLabel)
		ImageLabel.ImageColor3 = Color
		ImageLabel.BackgroundColor3 = Color
		ImageLabel.BorderSizePixel = 0
		ImageLabel.BackgroundTransparency = 1
		ImageLabel.ZIndex = ZIndex
		ImageLabel.ScaleType = Enum.ScaleType.Slice

		return ImageLabel
	end

	self.Gui.BackgroundTransparency = 1

	local Shadow = Instance.new("ImageLabel")
	Shadow.Name = "CardBacking"
	Shadow.Image = "rbxassetid://280963518"
	Shadow.Size = UDim2.new(1, 0, 1, 0)
	Shadow.ImageTransparency = 0
	Shadow.SliceCenter = Rect.new(Vector2.new(5, 5), Vector2.new(20, 20))
	SetProperties(self.ShadowColor, Shadow)

	local CardInset = 2
	local Card = Instance.new("ImageLabel")
	Card.Name = "Card"
	Card.Image = "rbxassetid://280883176"
	Card.Size = UDim2.new(1, -CardInset*2, 1, -CardInset*2)
	Card.Position = UDim2.new(0, CardInset, 0, CardInset)
	Card.SliceCenter = Rect.new(Vector2.new(2, 2), Vector2.new(8, 8))
	SetProperties(self.CardColor, Card)

	Card.Parent = Shadow
	Shadow.Parent = self.Gui

	return Shadow
end


return MaterialCardBuilder