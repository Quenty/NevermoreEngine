---
-- @classmod AnimatedSpritesheetPlayer
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local AnimatedSpritesheetPlayer = setmetatable({}, BaseObject)
AnimatedSpritesheetPlayer.ClassName = "AnimatedSpritesheetPlayer"
AnimatedSpritesheetPlayer.__index = AnimatedSpritesheetPlayer

function AnimatedSpritesheetPlayer.new(imageLabel, spritesheet)
	local self = setmetatable(BaseObject.new(spritesheet), AnimatedSpritesheetPlayer)

	self._imageLabel = assert(imageLabel)

	if spritesheet then
		self:SetSheet(spritesheet)
	end

	return self
end

function AnimatedSpritesheetPlayer:SetSheet(spritesheet)
	assert(spritesheet)

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