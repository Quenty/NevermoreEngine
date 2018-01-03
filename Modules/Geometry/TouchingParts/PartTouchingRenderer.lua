--- Renders touching parts from the PartTouchingCalculator
-- @classmod PartTouchingRenderer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Debris = game:GetService("Debris")

local qGUI = require("qGUI")

local PartTouchingRenderer = {}
PartTouchingRenderer.__index = PartTouchingRenderer
PartTouchingRenderer.ClassName = "PartTouchingRenderer"

function PartTouchingRenderer.new()
	local self = setmetatable({}, PartTouchingRenderer)

	return self
end

function PartTouchingRenderer:RenderTouchingProps(TouchingPartList)
	for _, Part in pairs(TouchingPartList) do
		local SelectionBox = Instance.new("SelectionBox")
		SelectionBox.Name = "TouchingWarning"
		SelectionBox.LineThickness = 0.05
		SelectionBox.Color3 = Color3.new(1, 0.3, 0.3)
		SelectionBox.Transparency = 0
		SelectionBox.Adornee = Part
		SelectionBox.Parent = Part
		
		qGUI.TweenTransparency(SelectionBox, {Transparency = 1}, 0.5)
		Debris:AddItem(SelectionBox, 0.6)
	end
end


return PartTouchingRenderer