--!strict
--[=[
	The actual cursor for the HSV (it's a plus). See [HSVColorPicker].

	@class HSColorPickerCursor
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorPickerUtils = require("ColorPickerUtils")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local HSColorPickerCursor = setmetatable({}, BaseObject)
HSColorPickerCursor.ClassName = "HSColorPickerCursor"
HSColorPickerCursor.__index = HSColorPickerCursor

export type HSColorPickerCursor = typeof(setmetatable(
	{} :: {
		Gui: Frame?,
		_backgroundColorHint: ValueObject.ValueObject<Color3>,
		_height: ValueObject.ValueObject<number>,
		_crossHairWidthAbs: ValueObject.ValueObject<number>,
		_verticalHairVisible: ValueObject.ValueObject<boolean>,
		_horizontalHairVisible: ValueObject.ValueObject<boolean>,
		_position: ValueObject.ValueObject<Vector2>,
		_transparency: ValueObject.ValueObject<number>,
		PositionChanged: Signal.Signal<Vector2>,
	},
	{} :: typeof({ __index = HSColorPickerCursor })
)) & BaseObject.BaseObject

function HSColorPickerCursor.new(): HSColorPickerCursor
	local self: HSColorPickerCursor = setmetatable(BaseObject.new() :: any, HSColorPickerCursor)

	self._backgroundColorHint = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))
	self._height = self._maid:Add(ValueObject.new(0.075, "number"))
	self._crossHairWidthAbs = self._maid:Add(ValueObject.new(1, "number"))
	self._verticalHairVisible = self._maid:Add(ValueObject.new(true, "boolean"))
	self._horizontalHairVisible = self._maid:Add(ValueObject.new(true, "boolean"))
	self._position = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self.PositionChanged = assert(self._position.Changed :: any, "No .Changed event")

	return self
end

--[=[
	Hints the background color so contrast can be set appropriately.

	@param color Color3
]=]
function HSColorPickerCursor.HintBackgroundColor(self: HSColorPickerCursor, color: Color3)
	assert(typeof(color) == "Color3", "Bad color")

	self._backgroundColorHint.Value = color
end

function HSColorPickerCursor.SetVerticalHairVisible(self: HSColorPickerCursor, visible)
	self._verticalHairVisible.Value = visible
end

function HSColorPickerCursor.SetHorizontalHairVisible(self: HSColorPickerCursor, visible)
	self._horizontalHairVisible.Value = visible
end

--[=[
	Sets the size of the cursor.

	@param height number
]=]
function HSColorPickerCursor.SetHeight(self: HSColorPickerCursor, height)
	self._height.Value = height
end

--[=[
	Sets the Vector2 position in scale (from 0 to 1).

	@param position Vector2
]=]
function HSColorPickerCursor.SetPosition(self: HSColorPickerCursor, position)
	assert(typeof(position) == "Vector2", "Bad position")

	self._position.Value = position
end

--[=[
	Gets the position of the cursor in scale

	@return Vector2
]=]
function HSColorPickerCursor.GetPosition(self: HSColorPickerCursor)
	return self._position.Value
end

--[=[
	Sets the transparency of the cusor

	@param transparency number
]=]
function HSColorPickerCursor.SetTransparency(self: HSColorPickerCursor, transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function HSColorPickerCursor._render(self: HSColorPickerCursor)
	return Blend.New "Frame" {
		Name = "HSColorPickerCursor",
		Size = Blend.Computed(self._height, function(height)
			return UDim2.fromScale(height, height)
		end),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Blend.Computed(self._position, function(pos)
			return UDim2.fromScale(pos.x, pos.y)
		end),

		Blend.New "UIAspectRatioConstraint" {
			AspectRatio = 1,
		},

		Blend.New "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = self._horizontalHairVisible,
			Size = Blend.Computed(self._crossHairWidthAbs, function(width)
				return UDim2.new(1, 0, 0, width)
			end),
			BackgroundColor3 = Blend.Computed(self._backgroundColorHint, function(backingColor)
				return ColorPickerUtils.getOutlineWithContrast(Color3.new(0, 0, 0), backingColor)
			end),
			BackgroundTransparency = self._transparency,

			Blend.New "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
		},

		Blend.New "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = self._verticalHairVisible,
			Size = Blend.Computed(self._crossHairWidthAbs, function(width)
				return UDim2.new(0, width, 1, 0)
			end),
			BackgroundColor3 = Blend.Spring(
				Blend.Computed(self._backgroundColorHint, function(backingColor)
					return ColorPickerUtils.getOutlineWithContrast(Color3.new(0, 0, 0), backingColor)
				end),
				20
			),
			BackgroundTransparency = self._transparency,

			Blend.New "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
		},
	}
end

return HSColorPickerCursor
