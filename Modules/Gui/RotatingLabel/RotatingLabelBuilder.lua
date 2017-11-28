local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local RotatingLabel = LoadCustomLibrary("RotatingLabel")

--[[
class RotatingLabelBuilder

Description:
	Builds a new RotatingLabel. See RotatingLabel for more details.

API:
	RotatingLabelBuilder.new([TextLabel Template])
		Starts building a new rotating label with the template, if given

	RotatingLabelBuilder:WithTemplate(TextLabel Template)
		Sets the tempate to use, the label will get those properties

	RotatingLabelBuilder:Create()
		Creates the new label and returns it

]]

local RotatingLabelBuilder = {}
RotatingLabelBuilder.ClassName = "RotatingLabelBuilder"
RotatingLabelBuilder.__index = RotatingLabelBuilder

function RotatingLabelBuilder.new(Template)
	local self = setmetatable({}, RotatingLabelBuilder)

	if Template then
		self:WithTemplate(Template)
	end
	
	return self
end

function RotatingLabelBuilder:WithTemplate(Template)
	self.Template = Template

	self.Label = RotatingLabel.new()
	self.Label:SetTemplate(Template)

	local Frame = Instance.new("Frame")
	Frame.Name = Template.Name .. "_RotatingLabel"
	Frame.Size = Template.Size
	Frame.AnchorPoint = Template.AnchorPoint
	Frame.Position = Template.Position
	Frame.SizeConstraint = Template.SizeConstraint
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0

	local Container = Instance.new("Frame")
	Container.Name = "Container"
	Container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Container.Size = UDim2.new(1, 0, 1, 0)
	Container.BackgroundTransparency = 1
	
	Container.Parent = Frame
	Frame.Parent = Template.Parent

	return self:WithGui(Frame)
end

function RotatingLabelBuilder:WithGui(Gui)
	self.Label:SetGui(Gui)
	self.Label.TextXAlignment = self.Template.TextXAlignment.Name
	self.Label.Text = self.Template.Text

	self.Template.Parent = nil

	return self
end

function RotatingLabelBuilder:Create()
	self.Label:UpdateRender()

	return self.Label
end

return RotatingLabelBuilder