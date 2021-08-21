---
-- @classmod AnimatedSpritesheet
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Spritesheet = require("Spritesheet")

local AnimatedSpritesheet = setmetatable({}, Spritesheet)
AnimatedSpritesheet.ClassName = "AnimatedSpritesheet"
AnimatedSpritesheet.__index = AnimatedSpritesheet

function AnimatedSpritesheet.new(options)
	local self = setmetatable(Spritesheet.new(options.texture), AnimatedSpritesheet)

	self._options = assert(options, "Bad options")
	assert(self._options.texture, "Bad options.texture")
	assert(self._options.frames, "Bad options.frames")
	assert(self._options.spritesPerRow, "Bad options.spritesPerRow")
	assert(self._options.spriteSize, "Bad options.spriteSize")
	assert(self._options.framesPerSecond, "Bad options.framesPerSecond")

	for i=0, options.frames do
		local x = i % options.spritesPerRow
		local y = math.floor(i / options.spritesPerRow)
		local position = options.spriteSize*Vector2.new(x, y)

		self:AddSprite(i + 1, position, options.spriteSize)
	end

	return self
end


function AnimatedSpritesheet:GetSpriteSize()
	return self._options.spriteSize
end

function AnimatedSpritesheet:GetFramesPerSecond()
	return self._options.framesPerSecond
end

function AnimatedSpritesheet:GetPlayTime(framesPerSecond)
	return self._options.frames/framesPerSecond
end

function AnimatedSpritesheet:GetFrames()
	return self._options.frames
end

return AnimatedSpritesheet