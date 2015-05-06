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
}

function KeyIconProvider.new()
	local self = {}
	setmetatable(self, KeyIconProvider)

	return self
end

function KeyIconProvider:GetKeycodeText(KeyCode)
	-- @return The KeyCode
	return self.KeyCodeToText[KeyCode] or KeyCode.Name
end

function KeyIconProvider:GetIcon(KeyIconBar, KeyCode)
	--- Creates a new KeyIcon to fit the KeyIconBar.
	-- @param KeyIconBar The icon bar to make the icon sized to. Considers the height.
	-- @param KeyCode Enum, The KeyCode 

	local Height     = KeyIconBar:GetHeight()
	local Text       = self:GetKeycodeText(KeyCode):upper()
	
	local NewIcon    = KeyIcon.NewDefault(Height)
	NewIcon.GUI.Text = Text

	return NewIcon
end

function KeyIconProvider:GetLabeledKey(KeyIconBar, KeyCode, LabelText)
	-- Creates a new labeled key sized to the KeyIconBar

	local NewIcon = self:GetIcon(KeyIconBar, KeyCode)
	
	return LabeledKeyIcon.FromKeyIcon(NewIcon, LabelText)
end

return KeyIconProvider