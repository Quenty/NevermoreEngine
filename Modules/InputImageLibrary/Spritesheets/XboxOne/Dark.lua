local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spritesheet = require("Spritesheet")

local Dark = setmetatable({}, Spritesheet)
Dark.ClassName = "Dark"
Dark.__index = Dark

function Dark.new()
	local self = setmetatable(Spritesheet.new("rbxassetid://408444495"), Dark)

	self:AddSprite("ButtonX", Vector2.new(510, 416), Vector2.new(95, 95))
	self:AddSprite("ButtonY", Vector2.new(616, 318), Vector2.new(95, 95))
	self:AddSprite("ButtonA", Vector2.new(318, 416), Vector2.new(95, 95))
	self:AddSprite("ButtonB", Vector2.new(520, 522), Vector2.new(95, 95))
	self:AddSprite("ButtonR1", Vector2.new(0, 628), Vector2.new(115, 64))
	self:AddSprite("ButtonL1", Vector2.new(116, 628), Vector2.new(115, 64))
	self:AddSprite("ButtonR2", Vector2.new(616, 414), Vector2.new(105, 115))
	self:AddSprite("ButtonL2", Vector2.new(616, 0), Vector2.new(105, 115))
	self:AddSprite("ButtonR3", Vector2.new(0, 416), Vector2.new(105, 105))
	self:AddSprite("ButtonL3", Vector2.new(0, 522), Vector2.new(105, 105))
	self:AddSprite("ButtonSelect", Vector2.new(424, 522), Vector2.new(95, 95))
	self:AddSprite("DPadLeft", Vector2.new(318, 522), Vector2.new(105, 105))
	self:AddSprite("DPadRight", Vector2.new(212, 416), Vector2.new(105, 105))
	self:AddSprite("DPadUp", Vector2.new(616, 530), Vector2.new(105, 105))
	self:AddSprite("DPadDown", Vector2.new(212, 522), Vector2.new(105, 105))
	self:AddSprite("Thumbstick1", Vector2.new(616, 116), Vector2.new(105, 105))
	self:AddSprite("Thumbstick2", Vector2.new(106, 522), Vector2.new(105, 105))
	self:AddSprite("DPad", Vector2.new(106, 416), Vector2.new(105, 105))
	self:AddSprite("Controller", Vector2.new(0, 0), Vector2.new(615, 415))
	self:AddSprite("RotateThumbstick1", Vector2.new(414, 416), Vector2.new(95, 95))
	self:AddSprite("RotateThumbstick2", Vector2.new(616, 222), Vector2.new(95, 95))

	return self
end

return Dark
