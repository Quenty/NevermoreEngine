--!strict
--[=[
	Cursor preview for mobile input especially
	@class ColorPickerCursorPreview
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local ColorPickerUtils = require("ColorPickerUtils")
local LuvColor3Utils = require("LuvColor3Utils")
local Math = require("Math")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local ColorPickerCursorPreview = setmetatable({}, BasicPane)
ColorPickerCursorPreview.ClassName = "ColorPickerCursorPreview"
ColorPickerCursorPreview.__index = ColorPickerCursorPreview

export type ColorPickerCursorPreview = typeof(setmetatable(
	{} :: {
		Gui: Frame?,
		_transparency: ValueObject.ValueObject<number>,
		_backgroundColorHint: ValueObject.ValueObject<Color3>,
		_colorValue: ValueObject.ValueObject<Color3>,
		_heightAbs: ValueObject.ValueObject<number>,
		_offsetAbs: ValueObject.ValueObject<number>,
		_position: ValueObject.ValueObject<Vector2>,

		PositionChanged: Signal.Signal<Vector2>,
	},
	{} :: typeof({ __index = ColorPickerCursorPreview })
)) & BasicPane.BasicPane

function ColorPickerCursorPreview.new(): ColorPickerCursorPreview
	local self: ColorPickerCursorPreview = setmetatable(BasicPane.new() :: any, ColorPickerCursorPreview)

	self._backgroundColorHint = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))
	self._heightAbs = self._maid:Add(ValueObject.new(60, "number"))
	self._offsetAbs = self._maid:Add(ValueObject.new(-20, "number"))
	self._position = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))
	self._colorValue = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self.PositionChanged = assert(self._position.Changed :: any, "No .Changed event")

	return self
end

function ColorPickerCursorPreview.HintBackgroundColor(self: ColorPickerCursorPreview, color: Color3)
	assert(typeof(color) == "Color3", "Bad color")

	self._backgroundColorHint.Value = color
end

function ColorPickerCursorPreview.SetPosition(self: ColorPickerCursorPreview, position: Vector2)
	assert(typeof(position) == "Vector2", "Bad position")

	self._position.Value = position
end

function ColorPickerCursorPreview.GetPosition(self: ColorPickerCursorPreview)
	return self._position.Value
end

function ColorPickerCursorPreview.SetColor(self: ColorPickerCursorPreview, color: Color3)
	assert(typeof(color) == "Color3", "Bad color")

	self._colorValue.Value = color
end

function ColorPickerCursorPreview.SetTransparency(self: ColorPickerCursorPreview, transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function ColorPickerCursorPreview._render(self: ColorPickerCursorPreview)
	local percentVisible = Blend.Spring(BasicPaneUtils.observePercentVisible(self), 30, 0.5)
	local transparencyTarget = Blend.Computed(
		BasicPaneUtils.observePercentVisible(self),
		self._transparency,
		function(visible, value)
			return Math.map(visible, 0, 1, 1, value)
		end
	)
	local transparency = Blend.Spring(transparencyTarget, 30)
	local isOutlineVisible = Blend.Computed(self._colorValue, self._backgroundColorHint, function(color, backingColor)
		local _, _, v = unpack(LuvColor3Utils.fromColor3(color))
		local _, _, bv = unpack(LuvColor3Utils.fromColor3(backingColor))

		return math.abs(bv - v) <= 60
	end)

	return Blend.New("Frame")({
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = Blend.Computed(self._heightAbs, function(heightAbs)
			return UDim2.fromOffset(heightAbs, heightAbs)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Blend.Computed(
			self._position,
			self._offsetAbs,
			self._heightAbs,
			function(pos: Vector2, offsetAbs: number, heightAbs: number)
				return UDim2.new(pos.X, 0, pos.Y, offsetAbs - heightAbs / 2)
			end
		),
		ZIndex = 3,

		Blend.New("UIAspectRatioConstraint")({
			AspectRatio = 1,
		}),

		Blend.New("Frame")({
			BackgroundTransparency = transparency,
			BackgroundColor3 = self._colorValue,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			Blend.New("UIScale")({
				Scale = percentVisible,
			}),

			Blend.New("UICorner")({
				CornerRadius = UDim.new(1, 0),
			}),

			Blend.New("UIStroke")({
				Color = Blend.Spring(
					Blend.Computed(
						self._colorValue,
						self._backgroundColorHint,
						isOutlineVisible,
						function(color, backingColor, needed)
							if needed then
								return ColorPickerUtils.getOutlineWithContrast(color, backingColor)
							else
								return color
							end
						end
					),
					20
				),
				Transparency = transparency,
				Thickness = Blend.Computed(percentVisible, function(percent: number)
					return percent * 3
				end),
			}),
		}),
	})
end

return ColorPickerCursorPreview
