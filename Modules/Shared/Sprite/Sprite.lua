---
-- @classmod Sprite

local Sprite = {}
Sprite.ClassName = "Sprite"
Sprite.__index = Sprite

function Sprite.new(data)
	assert(data.Texture)
	assert(data.Size)
	assert(data.Position)
	assert(data.Name)

	local self = setmetatable(data, Sprite)

	return self
end

function Sprite:Style(gui)
	gui.Size = UDim2.new(0, self.Size.X, 0, self.Size.Y)
	gui.ImageRectOffset = self.Position
	gui.ImageRectSize = self.Size

	return gui
end

function Sprite:Get(instanceType)
	local gui = Instance.new(instanceType)
	gui.Name = self.Name
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 1
	gui.Image = self.Texture

	self:Style(gui)

	return gui
end

return Sprite