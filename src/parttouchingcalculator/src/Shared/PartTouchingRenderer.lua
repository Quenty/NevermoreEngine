--[=[
	Renders touching parts from the PartTouchingCalculator
	@class PartTouchingRenderer
]=]

local require = require(script.Parent.loader).load(script)

local Debris = game:GetService("Debris")

local qGUI = require("qGUI")

local PartTouchingRenderer = {}
PartTouchingRenderer.__index = PartTouchingRenderer
PartTouchingRenderer.ClassName = "PartTouchingRenderer"

function PartTouchingRenderer.new()
	local self = setmetatable({}, PartTouchingRenderer)

	return self
end

function PartTouchingRenderer:RenderTouchingProps(touchingPartList)
	for _, part in touchingPartList do
		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Name = "TouchingWarning"
		selectionBox.LineThickness = 0.05
		selectionBox.Color3 = Color3.new(1, 0.3, 0.3)
		selectionBox.Transparency = 0
		selectionBox.Adornee = part
		selectionBox.Parent = part

		qGUI.TweenTransparency(selectionBox, {Transparency = 1}, 0.5)
		Debris:AddItem(selectionBox, 0.6)
	end
end


return PartTouchingRenderer