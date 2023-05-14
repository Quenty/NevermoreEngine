--[[
	Generated Gestures with Python
	@class Gestures
]]

local parent = script:FindFirstAncestorWhichIsA("ModuleScript")
local require = require(parent.Parent.loader).load(parent)

local Spritesheet = require("Spritesheet")

local Gestures = setmetatable({}, Spritesheet)
Gestures.ClassName = "Gestures"
Gestures.__index = Gestures

function Gestures.new()
	local self = setmetatable(Spritesheet.new("rbxassetid://1244652786"), Gestures)

	self:AddSprite("DoubleRotate", Vector2.zero, Vector2.new(102, 139))
	self:AddSprite("DoubleTap", Vector2.new(102, 0), Vector2.new(100, 100))
	self:AddSprite("FingerFront", Vector2.new(202, 0), Vector2.new(100, 100))
	self:AddSprite("FingerSide", Vector2.new(302, 0), Vector2.new(100, 100))
	self:AddSprite("FullCircle", Vector2.new(402, 0), Vector2.new(100, 137))
	self:AddSprite("HalfCircle", Vector2.new(502, 0), Vector2.new(76, 141))
	self:AddSprite("Hold", Vector2.new(578, 0), Vector2.new(100, 100))
	self:AddSprite("QuarterCircle", Vector2.new(678, 0), Vector2.new(87, 110))
	self:AddSprite("ScrollDown", Vector2.new(765, 0), Vector2.new(71, 105))
	self:AddSprite("ScrollLeft", Vector2.new(836, 0), Vector2.new(109, 63))
	self:AddSprite("ScrollRight", Vector2.new(0, 141), Vector2.new(106, 63))
	self:AddSprite("ScrollUp", Vector2.new(106, 141), Vector2.new(71, 102))
	self:AddSprite("SwipeBottom", Vector2.new(177, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeBottomLeft", Vector2.new(277, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeBottomRight", Vector2.new(377, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeLeft", Vector2.new(477, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeRight", Vector2.new(577, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeTopLeft", Vector2.new(677, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeTopRight", Vector2.new(777, 141), Vector2.new(100, 100))
	self:AddSprite("SwipeUp", Vector2.new(877, 141), Vector2.new(100, 100))
	self:AddSprite("Tap", Vector2.new(0, 243), Vector2.new(100, 100))
	self:AddSprite("ZoomIn", Vector2.new(100, 243), Vector2.new(114, 106))
	self:AddSprite("ZoomOut", Vector2.new(214, 243), Vector2.new(154, 105))

	return self
end

return Gestures
