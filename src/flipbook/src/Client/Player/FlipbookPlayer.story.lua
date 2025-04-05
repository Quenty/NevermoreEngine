--[[
	@class Flipbook.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Flipbook = require("Flipbook")
local FlipbookPlayer = require("FlipbookPlayer")
local Maid = require("Maid")
local UICornerUtils = require("UICornerUtils")

local function makeLabel(maid: Maid.Maid, flipbook: Flipbook.Flipbook, target: Instance, isBoomarang: boolean)
	local size = flipbook:GetImageRectSize()

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.BackgroundTransparency = 0
	imageLabel.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	imageLabel.Size = UDim2.fromOffset(size.x, size.y)
	imageLabel.BorderSizePixel = 0
	maid:GiveTask(imageLabel)

	UICornerUtils.fromOffset(8, imageLabel)

	local flipbookPlayer = FlipbookPlayer.new(imageLabel)
	flipbookPlayer:SetFlipbook(flipbook)
	maid:GiveTask(flipbookPlayer)

	if isBoomarang then
		flipbookPlayer:SetIsBoomarang(true)
	end

	flipbookPlayer:Play()

	imageLabel.Parent = target

	return imageLabel
end

local function makeButton(maid, flipbook, target, isBoomarang)
	local size = flipbook:GetImageRectSize()

	local imageButton = Instance.new("ImageButton")
	imageButton.BackgroundTransparency = 0
	imageButton.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	imageButton.Size = UDim2.fromOffset(size.x, size.y)
	imageButton.BorderSizePixel = 0
	maid:GiveTask(imageButton)

	UICornerUtils.fromOffset(8, imageButton)

	local flipbookPlayer = FlipbookPlayer.new(imageButton)
	flipbookPlayer:SetFlipbook(flipbook)
	maid:GiveTask(flipbookPlayer)

	if isBoomarang then
		flipbookPlayer:SetIsBoomarang(true)
	end

	maid:GiveTask(imageButton.Activated:Connect(function()
		flipbookPlayer:PromisePlayOnce()
	end))

	imageButton.Parent = target

	return imageButton
end

return function(target: Instance)
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

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://5085366281";
		rows = 6;
		columns = 6;
		frameCount = 34;
		imageRectSize = Vector2.new(85.33333, 85.33333);
		frameRate = 20;
		restFrame = 1;
	}), container, false)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://5085366281";
		rows = 6;
		columns = 6;
		frameCount = 34;
		imageRectSize = Vector2.new(85.33333, 85.33333);
		frameRate = 20;
		restFrame = 1;
	}), container, true)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://8966463176";
		rows = 6;
		columns = 6;
		imageRectSize = Vector2.new(170, 170);
		frameRate = 50;
		restFrame = 1;
	}), container, false)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://9234616869";
		rows = 10;
		columns = 10;
		frameCount = 92;
		imageRectSize = Vector2.new(102, 102);
		frameRate = 50;
		restFrame = 1;
	}), container, false)

	makeButton(maid, Flipbook.new({
		image = "rbxassetid://9234616869";
		rows = 10;
		columns = 10;
		frameCount = 92;
		imageRectSize = Vector2.new(102, 102);
		frameRate = 60;
		restFrame = 1;
	}), container, false)

	makeButton(maid, Flipbook.new({
		image = "rbxassetid://5085366281";
		rows = 6;
		columns = 6;
		frameCount = 34;
		imageRectSize = Vector2.new(85.33333, 85.33333);
		frameRate = 20;
		restFrame = 1;
	}), container, true)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://9234616869";
		rows = 10;
		columns = 10;
		frameCount = 92;
		imageRectSize = Vector2.new(102, 102);
		frameRate = 50;
		restFrame = 1;
	}), container, false)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://12273540121";
		rows = 7;
		columns = 7;
		frameCount = 45;
		imageRectSize = Vector2.new(146, 146);
		frameRate = 30;
		restFrame = 1;
	}), container, false)

	makeLabel(maid, Flipbook.new({
		image = "rbxassetid://9234650028";
		columns = 9;
		rows = 8;
		frameCount = 66;
		imageRectSize = Vector2.new(113, 113);
		frameRate = 60;
		restFrame = 1;
	}), container, false)

	return function()
		maid:DoCleaning()
	end
end