--!strict
--[=[
	Data model for sprite sheets
	@class Spritesheet
]=]

local require = require(script.Parent.loader).load(script)

local Sprite = require("Sprite")

local Spritesheet = {}
Spritesheet.ClassName = "Spritesheet"
Spritesheet.__index = Spritesheet

export type Spritesheet = typeof(setmetatable(
	{} :: {
		_texture: string,
		_sprites: { [any]: Sprite.Sprite },
	},
	{} :: typeof({ __index = Spritesheet })
))

--[=[
	Constructs a new Spritesheet
	@param texture string
	@return Spritesheet
]=]
function Spritesheet.new(texture: string): Spritesheet
	local self = setmetatable({}, Spritesheet)

	self._texture = texture or error("no texture")
	self._sprites = {}

	return self
end

--[=[
	Retrieves the preload asset ids to use
	@return string
]=]
function Spritesheet:GetPreloadAssetId(): string
	return self._texture
end

--[=[
	@param keyCode any
	@param position Vector2
	@param size Vector2

	Adds a named sprite at the given keyCode
]=]
function Spritesheet:AddSprite(keyCode: any, position: Vector2, size: Vector2): Sprite.Sprite
	assert(not self._sprites[keyCode], "Already exists")

	local sprite = Sprite.new({
		Texture = self._texture,
		Position = position,
		Size = size,
		Name = tostring(keyCode),
	})

	self._sprites[keyCode] = sprite
	return sprite
end

--[=[
	Retrieves the sprite for the given keyCode
	@param keyCode any | EnumItem
	@return Sprite?
]=]
function Spritesheet:GetSprite(keyCode: any): Sprite.Sprite?
	if not keyCode then
		warn("[Spritesheet.GetSprite] - Image name cannot be nil")
		return nil
	end

	local sprite = self._sprites[keyCode]
	if sprite then
		return sprite
	end

	if typeof(keyCode) == "EnumItem" then
		sprite = self._sprites[keyCode.Name]
	end

	return sprite
end

--[=[
	Returns true if the sprite exists
	@param keyCode any | EnumItem
	@return boolean
]=]
function Spritesheet:HasSprite(keyCode: any): boolean
	return self:GetSprite(keyCode) ~= nil
end

return Spritesheet
