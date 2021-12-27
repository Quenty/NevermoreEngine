--[=[
	Data model for sprite sheets
	@class Spritesheet
]=]

local require = require(script.Parent.loader).load(script)

local Sprite = require("Sprite")

local Spritesheet = {}
Spritesheet.ClassName = "Spritesheet"
Spritesheet.__index = Spritesheet

--[=[
	Constructs a new Spritesheet
	@param texture string
	@return Spritesheet
]=]
function Spritesheet.new(texture)
	local self = setmetatable({}, Spritesheet)

	self._texture = texture or error("no texture")
	self._sprites = {}

	return self
end

--[=[
	Retrieves the preload asset ids to use
	@return string
]=]
function Spritesheet:GetPreloadAssetId()
	return self._texture
end

--[=[
	@param index any
	@param position Vector2
	@param size Vector2

	Adds a named sprite at the given index
]=]
function Spritesheet:AddSprite(index, position, size)
	assert(not self._sprites[index], "Already exists")

	local sprite = Sprite.new({
		Texture = self._texture;
		Position = position;
		Size = size;
		Name = tostring(index);
	})

	self._sprites[index] = sprite
end

--[=[
	Retrieves the sprite for the given index
	@param index any | EnumItem
	@return Sprite?
]=]
function Spritesheet:GetSprite(index)
	if not index then
		warn("[Spritesheet.GetSprite] - Image name cannot be nil")
		return nil
	end

	local sprite = self._sprites[index]
	if sprite then
		return sprite
	end

	if typeof(index) == "EnumItem" then
		sprite = self._sprites[index.Name]
	end

	return sprite
end

--[=[
	Returns true if the sprite exists
	@param index any | EnumItem
	@return boolean
]=]
function Spritesheet:HasSprite(index)
	return self:GetSprite(index) ~= nil
end

return Spritesheet
