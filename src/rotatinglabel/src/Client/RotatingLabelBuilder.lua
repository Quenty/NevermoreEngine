--!nocheck
--[=[
	Builds a new RotatingLabel. See RotatingLabel for more details.

	:::warning
	This class is not really maintained or used anymore.
	:::

	@class RotatingLabelBuilder
]=]

local require = require(script.Parent.loader).load(script)

local RotatingLabel = require("RotatingLabel")

local RotatingLabelBuilder = {}
RotatingLabelBuilder.ClassName = "RotatingLabelBuilder"
RotatingLabelBuilder.__index = RotatingLabelBuilder

-- Starts building a new rotating label with the template, if given
function RotatingLabelBuilder.new(template)
	local self = setmetatable({}, RotatingLabelBuilder)

	if template then
		self:WithTemplate(template)
	end

	return self
end

-- Sets the tempate to use, the label will get those properties
function RotatingLabelBuilder:WithTemplate(template)
	self._template = template

	self._label = RotatingLabel.new()
	self._label:SetTemplate(template)

	local frame = Instance.new("Frame")
	frame.Name = template.Name .. "_RotatingLabel"
	frame.Size = template.Size
	frame.AnchorPoint = template.AnchorPoint
	frame.Position = template.Position
	frame.SizeConstraint = template.SizeConstraint
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1

	container.Parent = frame
	frame.Parent = template.Parent

	return self:WithGui(frame)
end

function RotatingLabelBuilder:WithGui(gui)
	self._label:SetGui(gui)
	self._label.TextXAlignment = self._template.TextXAlignment.Name
	self._label.Text = self._template.Text

	self._template.Parent = nil

	return self
end

-- Creates the new label and returns it
function RotatingLabelBuilder:Create()
	self._label:UpdateRender()

	return self._label
end

return RotatingLabelBuilder