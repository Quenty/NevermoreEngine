--[[
	@class LipsumUtils.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")

local LipsumUtils = require("LipsumUtils")
local Maid = require("Maid")
local TextServiceUtils = require("TextServiceUtils")
local UICornerUtils = require("UICornerUtils")
local UIPaddingUtils = require("UIPaddingUtils")

local function showText(text: string, maxWidth: number, optionalPadding: number?): Frame
	assert(type(text) == "string", "Bad text")
	assert(maxWidth, "Bad maxWidth")

	local padding: number = optionalPadding or 10

	local container = Instance.new("Frame")
	container.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 1, 0)

	local textLabel = Instance.new("TextLabel")
	textLabel.Text = text
	textLabel.BackgroundTransparency = 1
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.Highway
	textLabel.TextSize = 20
	textLabel.TextColor3 = Color3.new(0, 0, 0)
	textLabel.TextWrapped = true
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = container

	local uiPadding = UIPaddingUtils.fromUDim(UDim.new(0, padding))
	uiPadding.Parent = container

	UICornerUtils.fromOffset(10, container)

	local size = TextServiceUtils.getSizeForLabel(textLabel, text, maxWidth - padding * 2)
	container.Size = UDim2.new(0, size.x + 2 * padding, 0, size.y + 2 * padding)

	return container
end

local function makeTitle(title): TextLabel
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = title
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.new(0, 0, 0)
	titleLabel.TextColor3 = Color3.new(0.1, 0.1, 0.1)
	titleLabel.Font = Enum.Font.Highway
	titleLabel.Size = UDim2.new(1, -10, 0, 40)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Position = UDim2.new(0.5, 0, 0, 0)
	titleLabel.TextWrapped = true
	titleLabel.BackgroundTransparency = 1
	titleLabel.LayoutOrder = 2

	return titleLabel
end

local function makeHorizontalSection(factory: ((Frame) -> ()) -> ()): Frame
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 1, 0)

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Padding = UDim.new(0, 5)
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.Parent = container

	local maxHeight = 0
	local layoutOrder = 1
	local function add(item: Frame)
		assert(item, "Bad item")

		layoutOrder = layoutOrder + 1
		item.LayoutOrder = layoutOrder
		item.Parent = container

		maxHeight = math.max(maxHeight, item.Size.Y.Offset)
	end

	factory(add)

	container.Size = UDim2.new(1, 0, 0, maxHeight)

	return container
end

local function generate(target: Frame)
	local maid = Maid.new()

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 1, 0)
	maid:GiveTask(container)

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Padding = UDim.new(0, 5)
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.Parent = container

	local padding = 10
	local maxWidth = target.AbsoluteSize.X - padding * 2

	local uiPadding = UIPaddingUtils.fromUDim(UDim.new(0, padding))
	uiPadding.Parent = container

	local layoutOrder = 1
	local function add(item: GuiObject)
		layoutOrder = layoutOrder + 1
		item.LayoutOrder = layoutOrder
		item.Parent = container
	end

	add(makeTitle("Sentences"))
	for _ = 1, 5 do
		add(showText(LipsumUtils.sentence(), maxWidth))
	end

	add(makeTitle("Usernames"))
	add(makeHorizontalSection(function(addToSection)
		for _ = 1, 10 do
			addToSection(showText(LipsumUtils.username(), maxWidth))
		end
	end))

	add(makeTitle("Paragraph"))
	add(showText(LipsumUtils.paragraph(5), maxWidth, 20))

	add(makeTitle("Document"))
	add(showText(LipsumUtils.document(), maxWidth, 20))

	container.Parent = target

	return maid
end

return function(target)
	local maid = Maid.new()

	local scrollingFrame = maid:Add(Instance.new("ScrollingFrame"))
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 5, 0)
	scrollingFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	scrollingFrame.BackgroundTransparency = 0
	scrollingFrame.BorderSizePixel = 0

	local nextGenTime = 0

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		if nextGenTime <= os.clock() then
			maid._current = generate(scrollingFrame)
			nextGenTime = os.clock() + 1
		end
	end))

	scrollingFrame.Parent = target

	return function()
		maid:DoCleaning()
	end
end