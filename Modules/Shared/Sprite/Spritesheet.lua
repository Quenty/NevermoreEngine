--- Data model for sprite sheets
-- @classmod Spritesheet

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Sprite = require("Sprite")

local Spritesheet = {}
Spritesheet.ClassName = "Spritesheet"
Spritesheet.__index = Spritesheet

function Spritesheet.new(texture)
	local self = setmetatable({}, Spritesheet)

	self._texture = texture or error("no texture")
	self._sprites = {}

	return self
end

function Spritesheet:AddSprite(index, position, size)
	assert(not self._sprites[index])

	local sprite = Sprite.new({
		Texture = self._texture;
		Position = position;
		Size = size;
		Name = tostring(index);
	})

	self._sprites[index] = sprite
end

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

function Spritesheet:HasSprite(index)
	return self:GetSprite(index) ~= nil
end


return Spritesheet
