--[=[
	A single image on a spritesheet.
	@class Sprite
]=]

local Sprite = {}
Sprite.ClassName = "Sprite"
Sprite.__index = Sprite

--[=[
	Data used to construct a sprite.
	@interface SpriteData
	.Texture string
	.Size Vector2
	.Position Vector2
	.Name string
	@within Sprite
]=]

--[=[
	Constructs a new sprite
	@param data SpriteData
	@return Sprite
]=]
function Sprite.new(data)
	assert(data.Texture, "Bad data")
	assert(data.Size, "Bad data")
	assert(data.Position, "Bad data")
	assert(data.Name, "Bad data")

	local self = setmetatable(data, Sprite)

	return self
end

--[=[
	Applies the styling to the gui
	@param gui ImageLabel | ImageButton
	@return Instance
]=]
function Sprite:Style(gui)
	assert(typeof(gui) == "Instance" and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")), "Bad gui")

	gui.Image = self.Texture
	gui.ImageRectOffset = self.Position
	gui.ImageRectSize = self.Size

	return gui
end

--[=[
	Returns a new sprite with the specified `instanceType`
	@param instanceType "ImageLabel" | "ImageButton"
	@return ImageLabel | ImageButton
]=]
function Sprite:Get(instanceType)
	assert(type(instanceType) == "string", "Bad instanceType")

	local gui = Instance.new(instanceType)
	gui.Size = UDim2.new(0, self.Size.X, 0, self.Size.Y)
	gui.Name = self.Name
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 1

	self:Style(gui)

	return gui
end

return Sprite