local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spritesheet = require("Spritesheet")

local Light = setmetatable({}, Spritesheet)
Light.ClassName = "Light"
Light.__index = Light

function Light.new()
	local self = setmetatable(Spritesheet.new("rbxassetid://408462759"), Light)

	self:AddSprite("ButtonX", Vector2.new(318, 481), Vector2.new(95, 95))
	self:AddSprite("ButtonY", Vector2.new(500, 587), Vector2.new(95, 95))
	self:AddSprite("ButtonA", Vector2.new(308, 587), Vector2.new(95, 95))
	self:AddSprite("ButtonB", Vector2.new(510, 481), Vector2.new(95, 95))
	self:AddSprite("ButtonR1", Vector2.new(0, 416), Vector2.new(115, 64))
	self:AddSprite("ButtonL1", Vector2.new(116, 416), Vector2.new(115, 64))
	self:AddSprite("ButtonR2", Vector2.new(616, 0), Vector2.new(105, 115))
	self:AddSprite("ButtonL2", Vector2.new(616, 328), Vector2.new(105, 115))
	self:AddSprite("ButtonR3", Vector2.new(616, 550), Vector2.new(105, 105))
	self:AddSprite("ButtonL3", Vector2.new(616, 116), Vector2.new(105, 105))
	self:AddSprite("ButtonSelect", Vector2.new(404, 587), Vector2.new(95, 95))
	self:AddSprite("DPadLeft", Vector2.new(616, 444), Vector2.new(105, 105))
	self:AddSprite("DPadRight", Vector2.new(0, 587), Vector2.new(105, 105))
	self:AddSprite("DPadUp", Vector2.new(616, 222), Vector2.new(105, 105))
	self:AddSprite("DPadDown", Vector2.new(212, 481), Vector2.new(105, 105))
	self:AddSprite("Thumbstick1", Vector2.new(0, 481), Vector2.new(105, 105))
	self:AddSprite("Thumbstick2", Vector2.new(106, 587), Vector2.new(105, 105))
	self:AddSprite("DPad", Vector2.new(106, 481), Vector2.new(105, 105))
	self:AddSprite("Controller", Vector2.new(0, 0), Vector2.new(615, 415))
	self:AddSprite("RotateThumbstick1", Vector2.new(414, 481), Vector2.new(95, 95))
	self:AddSprite("RotateThumbstick2", Vector2.new(212, 587), Vector2.new(95, 95))

	return self
end

return Light
