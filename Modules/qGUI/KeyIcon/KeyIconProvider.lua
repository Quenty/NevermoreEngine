local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local KeyIcon           = LoadCustomLibrary("KeyIcon")
local LabeledKeyIcon    = LoadCustomLibrary("LabeledKeyIcon")

-- KeyIconProvider.lua
-- @author Quenty
-- Provides default KeyIcons for freeeee!
-- Does a lot of specific things for different input types

local KeyIconProvider     = {}
KeyIconProvider.__index   = KeyIconProvider
KeyIconProvider.ClassName = "KeyIconProvider"

KeyIconProvider.KeyCodeToText = {
	[Enum.KeyCode.Zero]  = "0";
	[Enum.KeyCode.One]   = "1";
	[Enum.KeyCode.Two]   = "2";
	[Enum.KeyCode.Three] = "3";
	[Enum.KeyCode.Four]  = "4";
	[Enum.KeyCode.Five]  = "5";
	[Enum.KeyCode.Six]   = "6";
	[Enum.KeyCode.Seven] = "7";
	[Enum.KeyCode.Eight] = "8";
	[Enum.KeyCode.Nine]  = "9";
	-- [Enum.KeyCode.ButtonA] = "A";
	-- [Enum.KeyCode.ButtonB] = "B";
	-- [Enum.KeyCode.ButtonX] = "X";
	-- [Enum.KeyCode.ButtonY] = "Y";
	[Enum.KeyCode.LeftControl] = "CTRL";
	[Enum.KeyCode.RightControl] = "CTRL";
}

function KeyIconProvider.new(DefaultIconBar)
	-- Constructs for a specific DefaultIconBar, making the icon bar optional.

	local self = {}
	setmetatable(self, KeyIconProvider)

	self.DefaultIconBar = DefaultIconBar or error("No DefaultIconBar")

	return self
end

function KeyIconProvider:GetIconBar()
	return self.DefaultIconBar
end

function KeyIconProvider:GetKeycodeText(KeyCode)
	-- @return The KeyCode
	return self.KeyCodeToText[KeyCode] or KeyCode.Name
end

function KeyIconProvider:GetIcon(KeyCode, KeyIconBar)
	--- Creates a new KeyIcon to fit the KeyIconBar.
	-- @param KeyCode Enum, The KeyCode 
	-- @param [KeyIconBar] The icon bar to make the icon sized to. Considers the height.

	KeyIconBar       = KeyIconBar or self.DefaultIconBar or error("No KeyIconBar")

	local Height     = KeyIconBar:GetHeight()
	local Text       = self:GetKeycodeText(KeyCode):upper()
	
	local NewIcon    = KeyIcon.NewDefault(Height)
	NewIcon.GUI.Text = Text
	NewIcon:RescaleWidth()

	return NewIcon
end

function KeyIconProvider:GetLabeledKey(KeyCode, LabelText, KeyIconBar)
	-- Creates a new labeled key sized to the KeyIconBar
	-- @param [KeyIconBar] The icon bar to make the icon sized to. Considers the height.

	KeyIconBar = KeyIconBar or self.DefaultIconBar or error("No KeyIconBar")

	local NewIcon = self:GetIcon(KeyCode, KeyIconBar)

	local NewLabeledIcon = LabeledKeyIcon.FromKeyIcon(NewIcon, LabelText)
	NewLabeledIcon.GUI.Name = KeyCode.Name .. "_" .. NewLabeledIcon.GUI.Name

	return NewLabeledIcon
end

return KeyIconProvider