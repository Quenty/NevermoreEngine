--[=[
	Plays an [AnimatedSpritesheet] for an given image label.
	@class AnimatedSpritesheetPlayer
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local AnimatedSpritesheetPlayer = setmetatable({}, BaseObject)
AnimatedSpritesheetPlayer.ClassName = "AnimatedSpritesheetPlayer"
AnimatedSpritesheetPlayer.__index = AnimatedSpritesheetPlayer

--[=[
	Constructs a new AnimatedSpritesheetPlayer
	@param imageLabel ImageLabel
	@param spritesheet AnimatedSpritesheet?
	@return AnimatedSpritesheetPlayer
]=]
function AnimatedSpritesheetPlayer.new(imageLabel, spritesheet)
	local self = setmetatable(BaseObject.new(spritesheet), AnimatedSpritesheetPlayer)

	self._imageLabel = assert(imageLabel, "Bad imageLabel")

	if spritesheet then
		self:SetSheet(spritesheet)
	end

	return self
end

--[=[
	Sets the current sheet and starts play if needed
	@param spritesheet AnimatedSpritesheet
]=]
function AnimatedSpritesheetPlayer:SetSheet(spritesheet)
	assert(spritesheet, "Bad spritesheet")

	self._spritesheet = spritesheet
	self:_play()
end

function AnimatedSpritesheetPlayer:_play()
	local maid = Maid.new()

	local fps = self._spritesheet:GetFramesPerSecond()
	local frames = self._spritesheet:GetFrames()

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		local frame = (math.floor(tick()*fps)%frames)+1
		self._spritesheet:GetSprite(frame):Style(self._imageLabel)
	end))

	self._maid._play = maid
end

return AnimatedSpritesheetPlayer