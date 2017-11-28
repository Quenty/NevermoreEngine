local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qGUI = LoadCustomLibrary("qGUI")

-- Intent: Renders touching parts from the PartTouchingCalculator

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