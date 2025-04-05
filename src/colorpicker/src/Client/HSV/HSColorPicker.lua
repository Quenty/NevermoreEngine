--[=[
	Picker for hue and Saturation in HSV. See [HSVColorPicker] for the full color picker,
	which also allows you to select "Value".

	@client
	@class HSColorPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local ButtonDragModel = require("ButtonDragModel")
local ColorPickerCursorPreview = require("ColorPickerCursorPreview")
local HSColorPickerCursor = require("HSColorPickerCursor")
local ValueObject = require("ValueObject")

local HSColorPicker = setmetatable({}, BaseObject)
HSColorPicker.ClassName = "HSColorPicker"
HSColorPicker.__index = HSColorPicker

--[=[
	@return HSColorPicker
]=]
function HSColorPicker.new()
	local self = setmetatable(BaseObject.new(), HSColorPicker)

	self._hsvColorValue = self._maid:Add(ValueObject.new(Vector3.zero, "Vector3"))
	self._sizeValue = self._maid:Add(ValueObject.new(Vector2.new(4, 4), "Vector2"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))

	self._dragModel = self._maid:Add(ButtonDragModel.new())
	self._dragModel:SetClampWithinButton(true)

	self._cursor = self._maid:Add(HSColorPickerCursor.new())
	self._preview = self._maid:Add(ColorPickerCursorPreview.new())

	self.ColorChanged = self._hsvColorValue.Changed

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	self._maid:GiveTask(self._transparency.Changed:Connect(function()
		self._cursor:SetTransparency(self._transparency.Value)
		self._preview:SetTransparency(self._transparency.Value)
	end))

	-- Binding
	self._maid:GiveTask(self._dragModel.DragPositionChanged:Connect(function()
		local position = self._dragModel:GetDragPosition()
		if position then
			local v = self._hsvColorValue.Value.z
			self._hsvColorValue.Value = Vector3.new(1 - position.x, 1 - position.y, v)
			self._cursor:SetPosition(position)
		end
	end))

	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		local current = self._hsvColorValue.Value
		local h, s = current.x, current.y
		self._cursor:SetPosition(Vector2.new(1 - h, 1 - s))
	end))

	-- Setup preview
	self._maid:GiveTask(self._dragModel:ObserveIsPressed():Subscribe(function(isDragging)
		self._preview:SetVisible(isDragging)
	end))
	self._maid:GiveTask(self._cursor.PositionChanged:Connect(function()
		self._preview:SetPosition(self._cursor:GetPosition())
	end))
	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		self:_updateHintedColors()
	end))
	self:_updateHintedColors()

	return self
end

--[=[
	Gets whether the color picker is pressed or not.

	@return BoolValue
]=]
function HSColorPicker:ObserveIsPressed()
	return self._dragModel:ObserveIsPressed()
end

function HSColorPicker:_updateHintedColors()
	local s = self._hsvColorValue.Value.y
	local h = 1 - self._cursor:GetPosition().x
	local v = 0.95

	local hinted = Color3.fromHSV(h, s, v)
	self._cursor:HintBackgroundColor(hinted)
	self._preview:HintBackgroundColor(hinted)
	self._preview:SetColor(hinted)
end

--[=[
	Sets the HSVColor as a Vector3
	@param hsvColor Vector3
]=]
function HSColorPicker:SetHSVColor(hsvColor)
	assert(typeof(hsvColor) == "Vector3", "Bad hsvColor")

	self._hsvColorValue.Value = hsvColor
end

--[=[
	Gets the color as an HSV Vector3
	@return Vector3
]=]
function HSColorPicker:GetHSVColor()
	return self._hsvColorValue.Value
end

--[=[
	Sets the color

	@param color Color3
]=]
function HSColorPicker:SetColor(color)
	local h, s, v = Color3.toHSV(color)
	self._hsvColorValue.Value = Vector3.new(h, s, v)
end

--[=[
	Gets the color

	@return Color3
]=]
function HSColorPicker:GetColor()
	local current = self._hsvColorValue.Value
	local h, s, v = current.x, current.y, current.z
	return Color3.fromHSV(h, s, v)
end

--[=[
	Gets the size value for the HSColorPicker.

	@return Vector3
]=]
function HSColorPicker:GetSizeValue()
	return self._sizeValue
end

function HSColorPicker:GetMeasureValue()
	return self._sizeValue
end

--[=[
	Sets the transparency of the HSColorPicker

	@param transparency number
]=]
function HSColorPicker:SetTransparency(transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

--[=[
	Sets the size of the color picker. This is in "line height" units.

	@param height number
]=]
function HSColorPicker:SetSize(height: number)
	assert(type(height) == "number", "Bad height")

	self._sizeValue.Value = Vector2.new(height, height)
end

function HSColorPicker:_render()
	return Blend.New "ImageButton" {
		Name = "HSColorPicker";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Active = true;
		Image = "rbxassetid://9290917908";
		ImageTransparency = self._transparency;

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

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 4);
		};

		self._preview.Gui;
		self._cursor.Gui;
	}
end

return HSColorPicker
