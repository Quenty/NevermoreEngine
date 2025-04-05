--[=[
	Cursor preview for mobile input especially
	@class ColorPickerCursorPreview
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local BasicPaneUtils = require("BasicPaneUtils")
local Math = require("Math")
local ColorPickerUtils = require("ColorPickerUtils")
local LuvColor3Utils = require("LuvColor3Utils")
local ValueObject = require("ValueObject")

local ColorPickerCursorPreview = setmetatable({}, BasicPane)
ColorPickerCursorPreview.ClassName = "ColorPickerCursorPreview"
ColorPickerCursorPreview.__index = ColorPickerCursorPreview

function ColorPickerCursorPreview.new()
	local self = setmetatable(BasicPane.new(), ColorPickerCursorPreview)

	self._backgroundColorHint = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))
	self._heightAbs = self._maid:Add(ValueObject.new(60, "number"))
	self._offsetAbs = self._maid:Add(ValueObject.new(-20, "number"))
	self._position = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))
	self._colorValue = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self.PositionChanged = assert(self._position.Changed, "No .Changed event")

	return self
end

function ColorPickerCursorPreview:HintBackgroundColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._backgroundColorHint.Value = color
end

function ColorPickerCursorPreview:SetPosition(position)
	assert(typeof(position) == "Vector2", "Bad position")

	self._position.Value = position
end

function ColorPickerCursorPreview:GetPosition()
	return self._position.Value
end

function ColorPickerCursorPreview:SetColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._colorValue.Value = color
end

function ColorPickerCursorPreview:SetTransparency(transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function ColorPickerCursorPreview:_render()
	local percentVisible = Blend.Spring(BasicPaneUtils.observePercentVisible(self), 30, 0.5)
	local transparencyTarget = Blend.Computed(BasicPaneUtils.observePercentVisible(self), self._transparency, function(visible, value)
		return Math.map(visible, 0, 1, 1, value)
	end)
	local transparency = Blend.Spring(transparencyTarget, 30)
	local isOutlineVisible = Blend.Computed(self._colorValue, self._backgroundColorHint, function(color, backingColor)
		local _, _, v = unpack(LuvColor3Utils.fromColor3(color))
		local _, _, bv = unpack(LuvColor3Utils.fromColor3(backingColor))

		return math.abs(bv - v) <= 60
	end)

	return Blend.New "Frame" {
		Name = "Preview";
		BackgroundTransparency = 1;
		Size = Blend.Computed(self._heightAbs, function(heightAbs)
			return UDim2.fromOffset(heightAbs, heightAbs)
		end);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Position = Blend.Computed(self._position, self._offsetAbs, self._heightAbs, function(pos, offsetAbs, heightAbs)
			return UDim2.new(pos.x, 0, pos.y, offsetAbs - heightAbs/2)
		end);
		ZIndex = 3;

		Blend.New "UIAspectRatioConstraint" {
			AspectRatio = 1;
		};

		Blend.New "Frame" {
			BackgroundTransparency = transparency;
			BackgroundColor3 = self._colorValue;
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.fromScale(0.5, 0.5);
			Size = UDim2.fromScale(1, 1);

			Blend.New "UIScale" {
				Scale = percentVisible;
			};

			Blend.New "UICorner" {
				CornerRadius = UDim.new(1, 0);
			};

			Blend.New "UIStroke" {
				Color = Blend.Spring(Blend.Computed(
					self._colorValue,
					self._backgroundColorHint,
					isOutlineVisible,
					function(color, backingColor, needed)
						if needed then
							return ColorPickerUtils.getOutlineWithContrast(color, backingColor)
						else
							return color
						end
					end), 20);
				Transparency = transparency;
				Thickness = Blend.Computed(percentVisible, function(percent)
					return percent*3
				end);
			};
		}
	}
end

return ColorPickerCursorPreview