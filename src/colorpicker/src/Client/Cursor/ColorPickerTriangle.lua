--!strict
--[=[
	Color picker triangle

	@class ColorPickerTriangle
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorPickerUtils = require("ColorPickerUtils")
local ValueObject = require("ValueObject")

local ColorPickerTriangle = setmetatable({}, BaseObject)
ColorPickerTriangle.ClassName = "ColorPickerTriangle"
ColorPickerTriangle.__index = ColorPickerTriangle

export type ColorPickerTriangle =
	typeof(setmetatable(
		{} :: {
			Gui: Frame?,
			_transparency: ValueObject.ValueObject<number>,
			_backgroundColorHint: ValueObject.ValueObject<Color3>,
			_color: ValueObject.ValueObject<Color3>,
			_sizeValue: ValueObject.ValueObject<Vector2>,
		},
		{} :: typeof({ __index = ColorPickerTriangle })
	))
	& BaseObject.BaseObject

function ColorPickerTriangle.new(): ColorPickerTriangle
	local self: ColorPickerTriangle = setmetatable(BaseObject.new() :: any, ColorPickerTriangle)

	self._transparency = self._maid:Add(ValueObject.new(0, "number"))
	self._backgroundColorHint = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))
	self._color = self._maid:Add(ValueObject.new(Color3.new(1, 1, 1), "Color3"))
	self._sizeValue = self._maid:Add(ValueObject.new(Vector2.new(0.05, 0.1), "Vector2"))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	return self
end

function ColorPickerTriangle.HintBackgroundColor(self: ColorPickerTriangle, color: Color3)
	self._backgroundColorHint.Value = color
end

function ColorPickerTriangle.GetSizeValue(self: ColorPickerTriangle): ValueObject.ValueObject<Vector2>
	return self._sizeValue
end

function ColorPickerTriangle.GetMeasureValue(self: ColorPickerTriangle): ValueObject.ValueObject<Vector2>
	return self._sizeValue
end

function ColorPickerTriangle.SetColor(self: ColorPickerTriangle, color: Color3)
	self._color.Value = color
end

function ColorPickerTriangle.SetTransparency(self: ColorPickerTriangle, transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function ColorPickerTriangle._render(self: ColorPickerTriangle)
	return Blend.New("Frame")({
		Name = "ColorPickerTriangle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		Blend.New("ImageLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = Blend.Computed(self._color, self._backgroundColorHint, function(color, backingColor)
				return ColorPickerUtils.getOutlineWithContrast(color, backingColor)
			end),
			ImageTransparency = self._transparency,
			Image = "rbxassetid://9291514809",
		}),

		Blend.New("UIAspectRatioConstraint")({
			AspectRatio = Blend.Computed(self._sizeValue, function(size)
				if size.x <= 0 or size.y <= 0 then
					return 1
				else
					return size.x / size.y
				end
			end),
		}),
	})
end

return ColorPickerTriangle
