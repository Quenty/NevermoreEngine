--!strict
--[=[
	Mouse over mixin for general utility button mouse over effects
	@class MouseOverMixin
]=]

local require = require(script.Parent.loader).load(script)

local ButtonUtils = require("ButtonUtils")
local Maid = require("Maid")

local MouseOverMixin = {}

function MouseOverMixin:Add(class: any)
	assert(class, "Bad class")
	assert(not class.GetMouseOverColor, "Class already has GetMouseOverColor")

	class.GetMouseOverBoolValue = self.GetMouseOverBoolValue
	class.AddMouseOverEffect = self.AddMouseOverEffect
	class._getMouseOverTweenProperties = self._getMouseOverTweenProperties
end

function MouseOverMixin:GetMouseOverBoolValue(gui: GuiObject): (Maid.Maid, BoolValue)
	local maid = Maid.new()

	local mouseOver = Instance.new("BoolValue")
	mouseOver.Value = false
	maid:GiveTask(mouseOver)

	maid:GiveTask(gui.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			mouseOver.Value = true
		elseif inputObject.UserInputType == Enum.UserInputType.Touch then
			-- Touch and hold counts as mouse over
			local touchMaid = Maid.new()
			maid[inputObject] = touchMaid

			touchMaid:GiveTask(gui.InputEnded:Connect(function(endInputObject)
				if endInputObject == inputObject then
					maid[inputObject] = nil
					mouseOver.Value = false
				end
			end))

			task.delay(0.2, function()
				if maid[inputObject] then
					mouseOver.Value = true
				end
			end)
		end
	end))

	maid:GiveTask(gui.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			mouseOver.Value = false
		end
	end))

	return maid, mouseOver
end

function MouseOverMixin:_getMouseOverTweenProperties(gui: GuiObject): { BackgroundColor3: Color3, ImageColor3: Color3? }
	if gui:IsA("ImageButton") then
		return {
			ImageColor3 = ButtonUtils.getMouseOverColor(gui.ImageColor3, 1),
			BackgroundColor3 = ButtonUtils.getMouseOverColor(gui.BackgroundColor3, 1),
		}
	else
		return {
			BackgroundColor3 = ButtonUtils.getMouseOverColor(gui.BackgroundColor3, 1),
		}
	end
end

function MouseOverMixin:AddMouseOverEffect(gui: GuiObject, tweenProperties: { [string]: any }?)
	local tweenProps: { [string]: any } = tweenProperties or (ButtonUtils :: any)._getMouseOverTweenProperties(gui)

	if gui:IsA("GuiButton") then
		gui.AutoButtonColor = false
	end

	local maid, boolValue = (ButtonUtils :: any).getMouseOverBoolValue(gui)
	local original: { [string]: any } = {}
	for property, _ in tweenProps do
		original[property] = (gui :: any)[property]
	end

	local function update()
		for property, Value in boolValue.Value and tweenProps or original do
			(gui :: any)[property] = Value
		end
	end
	update()
	maid:GiveTask(boolValue.Changed:Connect(update))

	self._maid[boolValue] = maid

	return boolValue
end

return MouseOverMixin
