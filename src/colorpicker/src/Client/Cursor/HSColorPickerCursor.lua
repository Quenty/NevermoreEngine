--[=[
	@class HSColorPickerCursor
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ColorPickerUtils = require("ColorPickerUtils")

local HSColorPickerCursor = setmetatable({}, BaseObject)
HSColorPickerCursor.ClassName = "HSColorPickerCursor"
HSColorPickerCursor.__index = HSColorPickerCursor

function HSColorPickerCursor.new()
	local self = setmetatable(BaseObject.new(), HSColorPickerCursor)

	self._backgroundColorHint = Instance.new("Color3Value")
	self._backgroundColorHint.Value = Color3.new(0, 0, 0)
	self._maid:GiveTask(self._backgroundColorHint)

	self._height = Instance.new("NumberValue")
	self._height.Value = 0.075
	self._maid:GiveTask(self._height)

	self._crossHairWidthAbs = Instance.new("NumberValue")
	self._crossHairWidthAbs.Value = 1
	self._maid:GiveTask(self._crossHairWidthAbs)

	self._verticalHairVisible = Instance.new("BoolValue")
	self._verticalHairVisible.Value = true
	self._maid:GiveTask(self._verticalHairVisible)

	self._horizontalHairVisible = Instance.new("BoolValue")
	self._horizontalHairVisible.Value = true
	self._maid:GiveTask(self._horizontalHairVisible)

	self._position = Instance.new("Vector3Value")
	self._position.Value = Vector3.new(0, 0, 0)
	self._maid:GiveTask(self._position)

	self._transparency = Instance.new("NumberValue")
	self._transparency.Value = 0
	self._maid:GiveTask(self._transparency)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self.PositionChanged = assert(self._position.Changed, "No .Changed event")

	return self
end

function HSColorPickerCursor:HintBackgroundColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._backgroundColorHint.Value = color
end

function HSColorPickerCursor:SetVerticalHairVisible(visible)
	self._verticalHairVisible.Value = visible
end

function HSColorPickerCursor:SetHorizontalHairVisible(visible)
	self._horizontalHairVisible.Value = visible
end

function HSColorPickerCursor:SetHeight(height)
	self._height.Value = height
end

function HSColorPickerCursor:SetPosition(position)
	self._position.Value = position
end

function HSColorPickerCursor:GetPosition()
	return self._position.Value
end

function HSColorPickerCursor:SetTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function HSColorPickerCursor:_render()
	return Blend.New "Frame" {
		Name = "HSColorPickerCursor";
		Size = Blend.Computed(self._height, function(height)
			return UDim2.fromScale(height, height);
		end);
		BackgroundTransparency = 1;
		AnchorPoint = Vector2.new(0.5, 0.5);
		Position = Blend.Computed(self._position, function(pos)
			return UDim2.fromScale(pos.x, pos.y)
		end);

		[Blend.Children] = {
			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = 1;
			};

			Blend.New "Frame" {
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				Visible = self._horizontalHairVisible;
				Size = Blend.Computed(self._crossHairWidthAbs, function(width)
					return UDim2.new(1, 0, 0, width)
				end);
				BackgroundColor3 = Blend.Computed(self._backgroundColorHint, function(backingColor)
					return ColorPickerUtils.getOutlineWithContrast(Color3.new(0, 0, 0), backingColor)
				end);
				BackgroundTransparency = self._transparency;

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = UDim.new(1, 0);
					};
				};
			};

			Blend.New "Frame" {
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				Visible = self._verticalHairVisible;
				Size = Blend.Computed(self._crossHairWidthAbs, function(width)
					return UDim2.new(0, width, 1, 0)
				end);
				BackgroundColor3 = Blend.Spring(Blend.Computed(self._backgroundColorHint, function(backingColor)
					return ColorPickerUtils.getOutlineWithContrast(Color3.new(0, 0, 0), backingColor)
				end), 20);
				BackgroundTransparency = self._transparency;

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = UDim.new(1, 0);
					};
				};
			};
		};
	};
end


return HSColorPickerCursor