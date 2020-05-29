---
-- @module DialogSlider.story
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputImageLibrary = require("InputImageLibrary")
local Maid = require("Maid")
local UIPaddingUtils = require("UIPaddingUtils")

local XBOX = {
	Enum.KeyCode.ButtonX;
	Enum.KeyCode.ButtonY;
	Enum.KeyCode.ButtonA;
	Enum.KeyCode.ButtonB;
	Enum.KeyCode.ButtonR1;
	Enum.KeyCode.ButtonL1;
	Enum.KeyCode.ButtonR2;
	Enum.KeyCode.ButtonL2;
	Enum.KeyCode.Thumbstick1;
	Enum.KeyCode.Thumbstick2;
	-- Enum.KeyCode.ButtonStart;
	-- Enum.KeyCode.ButtonSelect;
	Enum.KeyCode.DPadLeft;
	Enum.KeyCode.DPadRight;
	Enum.KeyCode.DPadUp;
	Enum.KeyCode.DPadDown;
}

local KEYBOARD = {
	Enum.KeyCode.A;
	Enum.KeyCode.B;
	Enum.KeyCode.C;
	Enum.KeyCode.D;
	Enum.KeyCode.E;
	Enum.KeyCode.F;
	Enum.KeyCode.G;
	Enum.KeyCode.H;
	Enum.KeyCode.I;
	Enum.KeyCode.J;
	Enum.KeyCode.K;
	Enum.KeyCode.L;
	Enum.KeyCode.M;
	Enum.KeyCode.N;
	Enum.KeyCode.O;
	Enum.KeyCode.P;
	Enum.KeyCode.Q;
	Enum.KeyCode.R;
	Enum.KeyCode.S;
	Enum.KeyCode.T;
	Enum.KeyCode.U;
	Enum.KeyCode.V;
	Enum.KeyCode.W;
	Enum.KeyCode.X;
	Enum.KeyCode.Y;
	Enum.KeyCode.Z;

	Enum.KeyCode.Zero;
	Enum.KeyCode.One;
	Enum.KeyCode.Two;
	Enum.KeyCode.Three;
	Enum.KeyCode.Four;
	Enum.KeyCode.Five;
	Enum.KeyCode.Six;
	Enum.KeyCode.Seven;
	Enum.KeyCode.Eight;
	Enum.KeyCode.Nine;
}

local function create(keyCode, theme, parent)
	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 1, 0)

	local padding = UIPaddingUtils.fromUDim(UDim.new(0, 5))
	padding.Parent = container

	local phaseTextLabel = Instance.new("TextLabel")
	phaseTextLabel.Text = ("%s"):format(keyCode.Name)
	phaseTextLabel.TextSize = 13
	phaseTextLabel.Font = Enum.Font.GothamSemibold
	phaseTextLabel.Size = UDim2.new(1, 0, 0, 30)
	phaseTextLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseTextLabel.Position = UDim2.new(0.5, 0, 0, 0)
	phaseTextLabel.TextWrapped = false
	phaseTextLabel.BackgroundTransparency = 1
	phaseTextLabel.LayoutOrder = 2
	phaseTextLabel.Parent = container

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Parent = container

	local sprite = InputImageLibrary:GetScaledImageLabel(keyCode, theme)
	sprite.Parent = container

	container.Parent = parent
end

local function makeTitle(title, parent)
	local phaseTextLabel = Instance.new("TextLabel")
	phaseTextLabel.Text = title
	phaseTextLabel.TextSize = 24
	phaseTextLabel.Font = Enum.Font.GothamBlack
	phaseTextLabel.Size = UDim2.new(1, -10, 0, 40)
	phaseTextLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseTextLabel.Position = UDim2.new(0.5, 0, 0, 0)
	phaseTextLabel.TextWrapped = true
	phaseTextLabel.BackgroundTransparency = 1
	phaseTextLabel.LayoutOrder = 2
	phaseTextLabel.Parent = parent

	return phaseTextLabel
end

local function makeSection(keycodes, theme, parent)
	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 1, 0)

	local uiGridLayout = Instance.new("UIGridLayout")
	uiGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiGridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	uiGridLayout.FillDirection = Enum.FillDirection.Horizontal
	uiGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiGridLayout.CellSize = UDim2.new(0, 100, 0, 130)
	uiGridLayout.Parent = container

	for _, item in pairs(keycodes) do
		create(item, theme, container)
	end

	container.Parent = parent
	container.Size = UDim2.new(1, 0, 0, uiGridLayout.AbsoluteContentSize.y)

	return container
end

return function(target)
	local maid = Maid.new()

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 5, 0)
	scrollingFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	scrollingFrame.BorderSizePixel = 0
	maid:GiveTask(scrollingFrame)

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.Parent = scrollingFrame

	scrollingFrame.Parent = target

	local layoutOrder = 1
	local function add(item)
		layoutOrder = layoutOrder + 1
		item.LayoutOrder = layoutOrder
	end

	add(makeTitle("XBox Dark", scrollingFrame))
	add(makeSection(XBOX, "Dark", scrollingFrame))

	add(makeTitle("XBox Light", scrollingFrame))
	add(makeSection(XBOX, "Light", scrollingFrame))

	add(makeTitle("Keyboard Dark", scrollingFrame))
	add(makeSection(KEYBOARD, "Dark", scrollingFrame))

	add(makeTitle("Keyboard Light", scrollingFrame))
	add(makeSection(KEYBOARD, "Light", scrollingFrame))


	return function()
		maid:DoCleaning()
	end
end