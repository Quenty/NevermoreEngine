---
-- @classmod Sprite

local Sprite = {}
Sprite.ClassName = "Sprite"
Sprite.__index = Sprite

function Sprite.new(data)
	assert(data.Texture, "Bad data")
	assert(data.Size, "Bad data")
	assert(data.Position, "Bad data")
	assert(data.Name, "Bad data")

	local self = setmetatable(data, Sprite)

	return self
end

function Sprite:Style(gui)
	gui.Image = self.Texture
	gui.ImageRectOffset = self.Position
	gui.ImageRectSize = self.Size

	return gui
end

function Sprite:Get(instanceType)
	local gui = Instance.new(instanceType)
	gui.Size = UDim2.new(0, self.Size.X, 0, self.Size.Y)
	gui.Name = self.Name
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 1

	self:Style(gui)

	return gui
end

return Sprite