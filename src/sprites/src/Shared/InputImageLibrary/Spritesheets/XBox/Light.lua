--[[
	Generated XboxOneLight with Python
	@class XboxOneLight
]]

local parent = script:FindFirstAncestorWhichIsA("ModuleScript")
local require = require(parent.Parent.loader).load(parent)

local Spritesheet = require("Spritesheet")

local XboxOneLight = setmetatable({}, Spritesheet)
XboxOneLight.ClassName = "XboxOneLight"
XboxOneLight.__index = XboxOneLight

function XboxOneLight.new()
	local self = setmetatable(Spritesheet.new("rbxassetid://5104051626"), XboxOneLight)

	self:AddSprite("DPad", Vector2.zero, Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonA, Vector2.new(100, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonB, Vector2.new(200, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonL1, Vector2.new(300, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonL2, Vector2.new(400, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonR1, Vector2.new(500, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonR2, Vector2.new(600, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonSelect, Vector2.new(700, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonX, Vector2.new(800, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.ButtonY, Vector2.new(900, 0), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.DPadDown, Vector2.new(0, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.DPadLeft, Vector2.new(100, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.DPadRight, Vector2.new(200, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.DPadUp, Vector2.new(300, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.Menu, Vector2.new(400, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.Thumbstick1, Vector2.new(500, 100), Vector2.new(100, 100))
	self:AddSprite(Enum.KeyCode.Thumbstick2, Vector2.new(600, 100), Vector2.new(100, 100))

	return self
end

return XboxOneLight
