--!nocheck
--[=[
	@class RotatingCharacterBuilder
]=]

local require = require(script.Parent.loader).load(script)

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

	local container = Instance.new("Frame")
	container.Name = "RotatingCharacterContainer"
	container.ClipsDescendants = true
	container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = Template.BackgroundTransparency
	container.ZIndex = Template.ZIndex
	container.BorderSizePixel = Template.BorderSizePixel
	container.BackgroundColor3 = Template.BackgroundColor3

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.ZIndex = Template.ZIndex
	textLabel.Font = Template.Font
	textLabel.TextSize = Template.TextSize
	textLabel.TextScaled = Template.TextScaled
	textLabel.TextColor3 = Template.TextColor3
	textLabel.TextTransparency = Template.TextTransparency
	textLabel.TextStrokeTransparency = Template.TextStrokeTransparency
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Text = ""

	textLabel.Parent = container

	local second = container.Label:Clone()
	second.Name = "SecondLabel"
	second.Position = UDim2.new(0, 0, 1, 0)
	second.SizeConstraint = Enum.SizeConstraint.RelativeXY
	second.Parent = container.Label

	container.Parent = Parent or error("No parent")

	return self:WithGui(container)
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