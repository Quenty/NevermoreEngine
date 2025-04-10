--!strict
--[=[
	A single image on a spritesheet.
	@class Sprite
]=]

--[=[
	Data used to construct a sprite.
	@interface SpriteData
	.Texture string
	.Size Vector2
	.Position Vector2
	.Name string
	@within Sprite
]=]
export type SpriteData = {
	Texture: string,
	Size: Vector2,
	Position: Vector2,
	Name: string,
}

local Sprite = {}
Sprite.ClassName = "Sprite"
Sprite.__index = Sprite

export type Sprite = typeof(setmetatable(
	{} :: {
		Texture: string,
		Size: Vector2,
		Position: Vector2,
		Name: string,
	},
	{} :: typeof({ __index = Sprite })
))

--[=[
	Constructs a new sprite
	@param data SpriteData
	@return Sprite
]=]
function Sprite.new(data: SpriteData): Sprite
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
function Sprite:Style(gui: ImageLabel | ImageButton)
	assert(typeof(gui) == "Instance" and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")), "Bad gui")

	local castGui: any = gui
	castGui.Image = self.Texture
	castGui.ImageRectOffset = self.Position
	castGui.ImageRectSize = self.Size

	return castGui
end

--[=[
	Returns a new sprite with the specified `instanceType`
	@param instanceType "ImageLabel" | "ImageButton"
	@return ImageLabel | ImageButton
]=]
function Sprite:Get(instanceType: "ImageLabel" | "ImageButton"): ImageLabel | ImageButton
	assert(type(instanceType) == "string", "Bad instanceType")

	local gui: any = Instance.new(instanceType)
	gui.Size = UDim2.new(0, self.Size.X, 0, self.Size.Y)
	gui.Name = self.Name
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 1

	self:Style(gui)

	return gui
end

return Sprite