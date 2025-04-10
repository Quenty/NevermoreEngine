--!strict
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
	.restFrame number? -- Optional reset frame
	@within Flipbook
]=]
export type FlipbookData = {
	image: string,
	frameCount: number,
	rows: number,
	columns: number,
	imageRectSize: Vector2,
	frameRate: number?,
	restFrame: number?,
}

local Flipbook = {}
Flipbook.ClassName = "Flipbook"
Flipbook.__index = Flipbook

export type Flipbook = typeof(setmetatable(
	{} :: {
		_frameSprites: { [number]: Sprite.Sprite? },
		_frameCount: number,
		_frameRate: number,
		_imageRectSize: Vector2,
		_restFrame: number?,
		_imageId: string,
	},
	{} :: typeof({ __index = Flipbook })
))

--[=[
	Constructs a new Flipbook
	@param data FlipbookData
	@return Flipbook
]=]
function Flipbook.new(data: FlipbookData): Flipbook
	local self: Flipbook = setmetatable({} :: any, Flipbook)

	self._frameSprites = {}
	self._frameRate = 60
	self._restFrame = data.restFrame

	assert(type(data.restFrame) == "number" or data.restFrame == nil, "Bad data.restFrame")

	if data.frameCount then
		self:SetFrameCount(data.frameCount)
	else
		assert(data.columns, "Bad columns")
		assert(data.rows, "Bad rows")

		self:SetFrameCount(data.rows * data.columns)
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

function Flipbook.isFlipbook(value: any): boolean
	return DuckTypeUtils.isImplementation(Flipbook, value)
end

function Flipbook._loadFrames(self: Flipbook, image: string, columns: number, imageRectSize: Vector2)
	assert(type(columns) == "number", "Bad columns")
	assert(typeof(imageRectSize) == "Vector2", "Bad imageRectSize")

	self:SetImageRectSize(imageRectSize)

	for i = 0, self._frameCount do
		local x = i % columns
		local y = math.floor(i / columns)
		local position = imageRectSize * Vector2.new(x, y)

		local index = i + 1
		local name = string.format("Frame_%d", index)

		self:SetSpriteAtIndex(
			index,
			Sprite.new({
				Texture = image,
				Size = imageRectSize,
				Position = position,
				Name = name,
			})
		)
	end
end

function Flipbook.GetRestFrame(self: Flipbook): number?
	return self._restFrame
end

function Flipbook.SetSpriteAtIndex(self: Flipbook, index: number, sprite: Sprite.Sprite)
	assert(type(index) == "number", "Bad index")
	assert(type(sprite) == "table", "Bad sprite")

	self._frameSprites[index] = sprite
end

function Flipbook.SetImageRectSize(self: Flipbook, imageRectSize: Vector2)
	assert(typeof(imageRectSize) == "Vector2", "No imageRectSize")

	self._imageRectSize = imageRectSize
end

function Flipbook.SetFrameCount(self: Flipbook, frameCount: number)
	assert(type(frameCount) == "number", "Bad frameCount")

	self._frameCount = frameCount
end

function Flipbook.SetFrameRate(self: Flipbook, frameRate: number)
	assert(type(frameRate) == "number", "Bad frameRate")

	self._frameRate = frameRate
end

function Flipbook.GetPreloadAssetId(self: Flipbook): { string }
	return { self._imageId }
end

function Flipbook.GetSprite(self: Flipbook, index: number): Sprite.Sprite?
	assert(type(index) == "number", "Bad index")

	return self._frameSprites[index]
end

function Flipbook.HasSprite(self: Flipbook, index: number): boolean
	assert(type(index) == "number", "Bad index")

	return self._frameSprites[index] ~= nil
end

--[=[
	Gets the sprite size
	@return Vector2
]=]
function Flipbook.GetImageRectSize(self: Flipbook): Vector2
	return self._imageRectSize
end

--[=[
	Gets the frames per a second
	@return number
]=]
function Flipbook.GetFrameRate(self: Flipbook): number
	return self._frameRate
end

--[=[
	Gets the play time for the animated sheet
	@return number
]=]
function Flipbook.GetPlayTime(self: Flipbook): number
	return self._frameCount / self._frameRate
end

--[=[
	Retrieves the frames for the sprite sheet.
	@return number
]=]
function Flipbook.GetFrameCount(self: Flipbook): number
	return self._frameCount
end

return Flipbook