---
-- @classmod RotatingCharacterBuilder

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RotatingCharacter = require("RotatingCharacter")

local RotatingCharacterBuilder = {}
RotatingCharacterBuilder.__index = RotatingCharacterBuilder
RotatingCharacterBuilder.ClassName = "RotatingCharacterBuilder"

function RotatingCharacterBuilder.new()
	local self = setmetatable({}, RotatingCharacterBuilder)

	return self
end

function RotatingCharacterBuilder:WithTemplate(TextLabelTemplate)
	self.TextLabelTemplate = TextLabelTemplate

	return self
end

function RotatingCharacterBuilder:Generate(Parent)
	local Template = self.TextLabelTemplate or error("Must set TextLabelTemplate")

	local Container = Instance.new("Frame")
	Container.Name = "RotatingCharacterContainer";
	Container.ClipsDescendants = true
	Container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Container.Size = UDim2.new(1, 0, 1, 0)
	Container.BackgroundTransparency = Template.BackgroundTransparency
	Container.ZIndex = Template.ZIndex
	Container.BorderSizePixel = Template.BorderSizePixel
	Container.BackgroundColor3 = Template.BackgroundColor3

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "Label"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, 0, 1, 0)
	TextLabel.ZIndex = Template.ZIndex
	TextLabel.Font = Template.Font
	TextLabel.TextSize = Template.TextSize
	TextLabel.TextScaled = Template.TextScaled
	TextLabel.TextColor3 = Template.TextColor3
	TextLabel.TextTransparency = Template.TextTransparency
	TextLabel.TextStrokeTransparency = Template.TextStrokeTransparency
	TextLabel.TextXAlignment = Enum.TextXAlignment.Center
	TextLabel.TextYAlignment = Enum.TextYAlignment.Center
	TextLabel.Text = ""

	TextLabel.Parent = Container

	local Second = Container.Label:Clone()
	Second.Name = "SecondLabel"
	Second.Position = UDim2.new(0, 0, 1, 0)
	Second.SizeConstraint = Enum.SizeConstraint.RelativeXY
	Second.Parent = Container.Label

	Container.Parent = Parent or error("No parent")

	return self:WithGui(Container)
end

function RotatingCharacterBuilder:WithGui(Gui)
	self.Gui = Gui or error("No GUI")

	self.Char = RotatingCharacter.new(self.Gui)

	return self
end

function RotatingCharacterBuilder:WithCharacter(Char)
	self.Char.TargetCharacter = Char
	self.Char.Character = self.Char.TargetCharacter

	return self
end

function RotatingCharacterBuilder:Create()
	self.Char:UpdateRender()
	return self.Char or error("No character spawned")
end

return RotatingCharacterBuilder