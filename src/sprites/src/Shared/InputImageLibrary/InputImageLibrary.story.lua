--[[
	@class InputImageLibrary.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local InputImageLibrary = require("InputImageLibrary")
local Maid = require("Maid")
local UIPaddingUtils = require("UIPaddingUtils")
local UICornerUtils = require("UICornerUtils")
local String = require("String")

local CONSOLE = {
	Enum.KeyCode.ButtonA;
	Enum.KeyCode.ButtonB;
	Enum.KeyCode.ButtonX;
	Enum.KeyCode.ButtonY;
	Enum.KeyCode.ButtonL1;
	Enum.KeyCode.ButtonL2;
	Enum.KeyCode.ButtonR1;
	Enum.KeyCode.ButtonR2;
	Enum.KeyCode.Menu;
	Enum.KeyCode.ButtonSelect;
	Enum.KeyCode.DPadLeft;
	Enum.KeyCode.DPadRight;
	Enum.KeyCode.DPadUp;
	Enum.KeyCode.DPadDown;
	Enum.KeyCode.Thumbstick1;
	Enum.KeyCode.Thumbstick2;
	"DPad";
}

local KEYBOARD = {
	Enum.KeyCode.Left;
	Enum.KeyCode.Right;
	Enum.KeyCode.Up;
	Enum.KeyCode.Down;
	Enum.KeyCode.Space;
	Enum.KeyCode.Backspace;
	Enum.KeyCode.LeftControl;
	Enum.KeyCode.Tab;
	Enum.KeyCode.Return;
	Enum.KeyCode.Delete;
	Enum.KeyCode.Backspace;

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

local MOUSE = {
	Enum.UserInputType.MouseButton1;
	Enum.UserInputType.MouseButton3;
	Enum.UserInputType.MouseWheel;
	Enum.UserInputType.MouseButton2;
	Enum.UserInputType.MouseMovement;
}

local function createInputKey(keyCode, theme, platform, parent)
	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 1, 0)

	UICornerUtils.fromOffset(8, container)

	local padding = UIPaddingUtils.fromUDim(UDim.new(0, 5))
	padding.Parent = container

	local phaseTextLabel = Instance.new("TextLabel")
	phaseTextLabel.Text =String.removePrefix(type(keyCode) == "string" and keyCode or keyCode.Name, "Mouse")
	phaseTextLabel.TextSize = 20
	phaseTextLabel.TextTruncate = Enum.TextTruncate.AtEnd
	phaseTextLabel.Font = Enum.Font.Highway
	phaseTextLabel.TextColor3 = Color3.new(0.1, 0.1, 0.1)
	phaseTextLabel.Size = UDim2.new(1, 0, 0, 30)
	phaseTextLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseTextLabel.Position = UDim2.new(0.5, 0, 0, 0)
	phaseTextLabel.TextWrapped = false
	phaseTextLabel.BackgroundTransparency = 1
	phaseTextLabel.LayoutOrder = 2
	phaseTextLabel.Parent = container

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Parent = container

	local sprite = InputImageLibrary:GetScaledImageLabel(keyCode, theme, platform)
	sprite.Parent = container

	container.Parent = parent
end

local function makeTitle(title, parent)
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
	titleLabel.Parent = parent

	return titleLabel
end

local function makeSection(keycodes, theme, platform, parent)
	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.BackgroundColor3 = Color3.new(0.5, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y

	local uiGridLayout = Instance.new("UIGridLayout")
	uiGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiGridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	uiGridLayout.FillDirection = Enum.FillDirection.Horizontal
	uiGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiGridLayout.CellSize = UDim2.new(0, 100, 0, 130)
	uiGridLayout.Parent = container

	for _, item in keycodes do
		createInputKey(item, theme, platform, container)
	end

	container.Parent = parent

	return container
end

return function(target)
	local maid = Maid.new()

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 5, 0)
	scrollingFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	scrollingFrame.BackgroundTransparency = 0
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

	add(makeTitle("Mouse Light", scrollingFrame))
	add(makeSection(MOUSE, "Light", nil, scrollingFrame))

	add(makeTitle("Mouse Dark", scrollingFrame))
	add(makeSection(MOUSE, "Dark", nil, scrollingFrame))

	add(makeTitle("XBox Dark", scrollingFrame))
	add(makeSection(CONSOLE, "Dark", "XBox", scrollingFrame))

	add(makeTitle("XBox Light", scrollingFrame))
	add(makeSection(CONSOLE, "Light", "XBox", scrollingFrame))

	add(makeTitle("PS5 Dark", scrollingFrame))
	add(makeSection(CONSOLE, "Dark", "PlayStation", scrollingFrame))

	add(makeTitle("PS5 Light", scrollingFrame))
	add(makeSection(CONSOLE, "Light", "PlayStation", scrollingFrame))

	add(makeTitle("Keyboard Dark", scrollingFrame))
	add(makeSection(KEYBOARD, "Dark", nil, scrollingFrame))

	add(makeTitle("Keyboard Light", scrollingFrame))
	add(makeSection(KEYBOARD, "Light", nil, scrollingFrame))


	return function()
		maid:DoCleaning()
	end
end