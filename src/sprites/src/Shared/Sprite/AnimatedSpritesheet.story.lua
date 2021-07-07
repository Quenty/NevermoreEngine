---
-- @module DialogSlider.story
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AnimatedSpritesheet = require("AnimatedSpritesheet")
local AnimatedSpritesheetPlayer = require("AnimatedSpritesheetPlayer")
local Maid = require("Maid")
local UICornerUtils = require("UICornerUtils")

local function makeLabel(maid, sheet, target)
	local size = sheet:GetSpriteSize()

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.BackgroundTransparency = 0
	imageLabel.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	imageLabel.Size = UDim2.fromOffset(size.x, size.y)
	imageLabel.BorderSizePixel = 0
	maid:GiveTask(imageLabel)

	UICornerUtils.fromOffset(8, imageLabel)

	local player = AnimatedSpritesheetPlayer.new(imageLabel, sheet)
	maid:GiveTask(player)

	imageLabel.Parent = target

	return imageLabel
end

return function(target)
	local maid = Maid.new()

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 0
	container.BackgroundColor3 = Color3.new(0, 0, 0)
	container.Parent = target
	maid:GiveTask(container)

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.Padding = UDim.new(0, 10)
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.Parent = container

	makeLabel(maid, AnimatedSpritesheet.new({
		texture = "rbxassetid://5085366281";
		frames = 34;
		spritesPerRow = 6;
		spriteSize = Vector2.new(85.33333, 85.33333);
		framesPerSecond = 30;
	}), container)

	return function()
		maid:DoCleaning()
	end
end