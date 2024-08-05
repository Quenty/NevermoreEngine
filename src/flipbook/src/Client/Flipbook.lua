--[=[
	A spritesheet that is animated. See [FlipbookPlayer] for playback.
	@class Flipbook
]=]

local require = require(script.Parent.loader).load(script)

local Sprite = require("Sprite")
local DuckTypeUtils = require("DuckTypeUtils")

--[=[
	@interface FlipbookData
	.image string
	.frameCount number
	.rows number
	.columns number
	.imageRectSize Vector2
	.frameRate number
	.restFrame number | nil -- Optional reset frame
	@within Flipbook
]=]

local Flipbook = {}
Flipbook.ClassName = "Flipbook"
Flipbook.__index = Flipbook

--[=[
	Constructs a new Flipbook
	@param data FlipbookData
	@return Flipbook
]=]
function Flipbook.new(data)
	local self = setmetatable({}, Flipbook)

	self._frameSprites = {}
	self._frameRate = 60
	self._restFrame = data.restFrame

	assert(type(data.restFrame) == "number" or data.restFrame == nil, "Bad data.restFrame")

	if data.frameCount then
		self:SetFrameCount(data.frameCount)
	else
		assert(data.columns, "Bad columns")
		assert(data.rows, "Bad rows")

		self:SetFrameCount(data.rows*data.columns)
	end

	if data.frameRate then
		self:SetFrameRate(data.frameRate)
	end

	do
		local image = assert(data.image, "Bad image")
		local columns = assert(data.columns, "Bad columns")
		local imageRectSize = assert(data.imageRectSize, "Bad imageRectSize")

		self:_loadFrames(image, columns, imageRectSize)
	end

	return self
end

function Flipbook.isFlipbook(value)
	return DuckTypeUtils.isImplementation(Flipbook, value)
end

function Flipbook:_loadFrames(image, columns, imageRectSize)
	assert(type(columns) == "number", "Bad columns")
	assert(typeof(imageRectSize) == "Vector2", "Bad imageRectSize")

	self:SetImageRectSize(imageRectSize)

	for i=0, self._frameCount do
		local x = i % columns
		local y = math.floor(i / columns)
		local position = imageRectSize*Vector2.new(x, y)

		local index = i + 1
		local name = string.format("Frame_%d", index)

		self:SetSpriteAtIndex(index, Sprite.new({
			Texture = image;
			Size = imageRectSize;
			Position = position;
			Name = name;
		}))
	end
end

function Flipbook:GetRestFrame()
	return self._restFrame
end

function Flipbook:SetSpriteAtIndex(index, sprite)
	assert(type(index) == "number", "Bad index")
	assert(type(sprite) == "table", "Bad sprite")

	self._frameSprites[index] = sprite
end

function Flipbook:SetImageRectSize(imageRectSize)
	assert(typeof(imageRectSize) == "Vector2", "No imageRectSize")

	self._imageRectSize = imageRectSize
end

function Flipbook:SetFrameCount(frameCount)
	assert(type(frameCount) == "number", "Bad frameCount")

	self._frameCount = frameCount
end

function Flipbook:SetFrameRate(frameRate)
	assert(type(frameRate) == "number", "Bad frameRate")

	self._frameRate = frameRate
end

function Flipbook:GetPreloadAssetId()
	return { self._imageId }
end

function Flipbook:GetSprite(index)
	assert(type(index) == "number", "Bad index")

	return self._frameSprites[index]
end

function Flipbook:HasSprite(index)
	assert(type(index) == "number", "Bad index")

	return self._frameSprites[index] ~= nil
end

--[=[
	Gets the sprite size
	@return Vector2
]=]
function Flipbook:GetImageRectSize()
	return self._imageRectSize
end

--[=[
	Gets the frames per a second
	@return number
]=]
function Flipbook:GetFrameRate()
	return self._frameRate
end

--[=[
	Gets the play time for the animated sheet
	@return number
]=]
function Flipbook:GetPlayTime()
	return self._frameCount/self._frameRate
end

--[=[
	Retrieves the frames for the sprite sheet.
	@return frames
]=]
function Flipbook:GetFrameCount()
	return self._frameCount
end

return Flipbook