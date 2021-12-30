--[=[
	A spritesheet that is animated. See [AnimatedSpritesheetPlayer] for playback.
	@class AnimatedSpritesheet
]=]

local require = require(script.Parent.loader).load(script)

local Spritesheet = require("Spritesheet")

local AnimatedSpritesheet = setmetatable({}, Spritesheet)
AnimatedSpritesheet.ClassName = "AnimatedSpritesheet"
AnimatedSpritesheet.__index = AnimatedSpritesheet

--[=[
	@interface AnimatedSpritesheetOptions
	.texture string
	.frames number
	.spritesPerRow number
	.spriteSize Vector2
	.framesPerSecond number
	@within AnimatedSpritesheet
]=]

--[=[
	Constructs a new AnimatedSpritesheet
	@param options AnimatedSpritesheetOptions
	@return AnimatedSpritesheet
]=]
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

--[=[
	Gets the sprite size
	@return Vector2
]=]
function AnimatedSpritesheet:GetSpriteSize()
	return self._options.spriteSize
end

--[=[
	Gets the frames per a second
	@return number
]=]
function AnimatedSpritesheet:GetFramesPerSecond()
	return self._options.framesPerSecond
end

--[=[
	Gets the play time for the animated sheet
	@return number
]=]
function AnimatedSpritesheet:GetPlayTime()
	return self._options.frames/self._options.framesPerSecond
end

--[=[
	Retrieves the frames for the sprite sheet.
	@return frames
]=]
function AnimatedSpritesheet:GetFrames()
	return self._options.frames
end

return AnimatedSpritesheet