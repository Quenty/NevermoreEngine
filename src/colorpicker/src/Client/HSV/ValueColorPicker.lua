--[=[
	Picker for value in HSV. See [HSVColorPicker] for usage.

	@client
	@class ValueColorPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ButtonDragModel = require("ButtonDragModel")
local ValueObject = require("ValueObject")
local ColorPickerCursorPreview = require("ColorPickerCursorPreview")
local ColorPickerTriangle = require("ColorPickerTriangle")

local ValueColorPicker = setmetatable({}, BaseObject)
ValueColorPicker.ClassName = "ValueColorPicker"
ValueColorPicker.__index = ValueColorPicker

function ValueColorPicker.new()
	local self = setmetatable(BaseObject.new(), ValueColorPicker)

	self._hsvColorValue = self._maid:Add(ValueObject.new(Vector3.zero, "Vector3"))
	self._backgroundColorHint = self._maid:Add(ValueObject.new(Color3.new(0, 0, 0), "Color3"))
	self._sizeValue = self._maid:Add(ValueObject.new(Vector2.new(0, 4), "Vector2"))
	self._leftWidth = self._maid:Add(ValueObject.new(0.25, "number"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))

	self._dragModel = self._maid:Add(ButtonDragModel.new())
	self._dragModel:SetClampWithinButton(true)

	self.ColorChanged = self._hsvColorValue.Changed
	-- self._cursor = HSColorPickerCursor.new()
	-- self._cursor:SetHeight(1)
	-- self._cursor:SetVerticalHairVisible(false)
	-- self._cursor:SetPosition(Vector3.new(0.5, 0, 1))
	-- self._maid:GiveTask(self._cursor)

	self._triangle = self._maid:Add(ColorPickerTriangle.new())
	self._triangle.Gui.AnchorPoint = Vector2.new(0, 0.5)
	self._triangle.Gui.Position = UDim2.fromScale(0, 1)

	self._preview = self._maid:Add(ColorPickerCursorPreview.new())

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self._maid:GiveTask(self._transparency.Changed:Connect(function()
		local transparency = self._transparency.Value
		-- self._cursor:SetTransparency(transparency)
		self._preview:SetTransparency(transparency)
		self._triangle:SetTransparency(transparency)
	end))

	-- Binding
	self._maid:GiveTask(self._dragModel.DragPositionChanged:Connect(function()
		local position = self._dragModel:GetDragPosition()
		if position then
			local current = self._hsvColorValue.Value
			local h, s = current.x, current.y
			self._hsvColorValue.Value = Vector3.new(h, s, 1 - position.y)
			-- self._cursor:SetPosition(Vector3.new(0.5, position.y, 0))
			self._triangle.Gui.Position = UDim2.fromScale(0, position.y)
		end
	end))
	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		local v = self._hsvColorValue.Value.z
		-- self._cursor:SetPosition(Vector3.new(0.5, 1 - v, 0))
		self._triangle.Gui.Position = UDim2.fromScale(0, 1 - v)
	end))

	-- Setup preview
	self._maid:GiveTask(self._dragModel:ObserveIsPressed():Subscribe(function(isDragging)
		self._preview:SetVisible(isDragging)
	end))
	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		self:_updatePreviewPosition()
	end))
	self:_updatePreviewPosition()
	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		self:_updateHintedColors()
	end))
	self:_updateHintedColors()

	-- Update hinting
	self._maid:GiveTask(self._backgroundColorHint.Changed:Connect(function()
		self._triangle:HintBackgroundColor(self._backgroundColorHint.Value)
	end))
	self._triangle:HintBackgroundColor(self._backgroundColorHint.Value)

	-- Size
	self._maid:GiveTask(self._triangle:GetSizeValue().Changed:Connect(function()
		self:_updateSize()
	end))
	self._maid:GiveTask(self._leftWidth.Changed:Connect(function()
		self:_updateSize()
	end))
	self:_updateSize()

	return self
end

--[=[
	Sets the size (height) of the value color picker

	@param height number
]=]
function ValueColorPicker:SetSize(height: number)
	assert(type(height) == "number", "Bad height")

	self:_updateSize(height)
end

--[=[
	Hints what the background color should be to ensure contrast

	@param color
]=]
function ValueColorPicker:HintBackgroundColor(color: Color3)
	self._backgroundColorHint.Value = color
end

function ValueColorPicker:ObserveIsPressed()
	return self._dragModel:ObserveIsPressed()
end

--[=[
	Sets the HSV Color for the value picker

	@param hsvColor
]=]
function ValueColorPicker:SetHSVColor(hsvColor: Vector3)
	assert(typeof(hsvColor) == "Vector3", "Bad hsvColor")

	self._hsvColorValue.Value = hsvColor
end

--[=[
	Returns the HSV color3

	@return Vector3
]=]
function ValueColorPicker:GetHSVColor()
	return self._hsvColorValue.Value
end

--[=[
	Setes the current color

	@param color
]=]
function ValueColorPicker:SetColor(color: Color3)
	local h, s, v = Color3.toHSV(color)
	self._hsvColorValue.Value = Vector3.new(h, s, v)
end

--[=[
	Gets the current color
]=]
function ValueColorPicker:GetColor(): Color3
	local current = self._hsvColorValue.Value
	local h, s, v = current.x, current.y, current.z
	return Color3.fromHSV(h, s, v)
end

function ValueColorPicker:GetSizeValue()
	return self._sizeValue
end

function ValueColorPicker:GetMeasureValue()
	return self._sizeValue
end

function ValueColorPicker:SetTransparency(transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function ValueColorPicker:_updatePreviewPosition()
	self._preview:SetPosition(Vector2.new(0.5, 1 - self._hsvColorValue.Value.z))
end

function ValueColorPicker:_updateSize(newHeight)
	local triangleSize = self._triangle:GetSizeValue().Value
	local width = self._leftWidth.Value + triangleSize.y
	local height = newHeight or self._sizeValue.Value.y

	self._sizeValue.Value = Vector2.new(width, height)
end

function ValueColorPicker:_updateHintedColors()
	local current = self._hsvColorValue.Value
	local h, s, v = current.x, current.y, current.z
	local color = Color3.fromHSV(h, s, v)

	-- self._cursor:HintBackgroundColor(color)
	self._preview:HintBackgroundColor(color)
	self._preview:SetColor(color)
end

function ValueColorPicker:_render()
	return Blend.New "ImageButton" {
		Name = "HSColorPicker";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Active = true;

		[Blend.Instance] = function(inst)
			self._dragModel:SetButton(inst)
		end;

		Blend.New "UIAspectRatioConstraint" {
			AspectRatio = Blend.Computed(self._sizeValue, function(size)
				if size.x <= 0 or size.y <= 0 then
					return 1
				else
					return size.x/size.y
				end
			end);
		};

		Blend.New "Frame" {
			BackgroundColor3 = Color3.new(1, 1, 1);
			BackgroundTransparency = self._transparency;
			Size = Blend.Computed(self._leftWidth, self._sizeValue, function(width, sizeValue)
				if sizeValue.x == 0 then
					return UDim2.new(0, 0, 1, 0)
				end

				return UDim2.new(width/sizeValue.x, 0, 1, 0)
			end);

			Blend.New "UIGradient" {
				Color = Blend.Computed(self._hsvColorValue, function(color)
					local h, s = color.x, color.y
					local start = Color3.fromHSV(h, s, 0)
					local finish = Color3.fromHSV(h, s, 1)
					return ColorSequence.new(start, finish)
				end);
				Rotation = -90;
			};
			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 4);
			};

			self._preview.Gui;
			-- self._cursor.Gui;
		};

		Blend.New "Frame" {
			BackgroundTransparency = 1;
			Position = UDim2.fromScale(1, 0);
			AnchorPoint = Vector2.new(1, 0);
			Size = Blend.Computed(self._leftWidth, self._sizeValue, function(width, sizeValue)
				if sizeValue.x == 0 then
					return UDim2.new(0, 0, 1, 0)
				end

				return UDim2.new((sizeValue.x - width)/sizeValue.x, 0, 1, 0)
			end);

			self._triangle.Gui;
		}
	}
end

return ValueColorPicker
