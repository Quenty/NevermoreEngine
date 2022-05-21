--[=[
	@class HSVColorPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local HSColorPicker = require("HSColorPicker")
local ValueColorPicker = require("ValueColorPicker")
local Maid = require("Maid")

local HSVColorPicker = setmetatable({}, BaseObject)
HSVColorPicker.ClassName = "HSVColorPicker"
HSVColorPicker.__index = HSVColorPicker

function HSVColorPicker.new()
	local self = setmetatable(BaseObject.new(), HSVColorPicker)

	self._hsvColorValue = Instance.new("Vector3Value")
	self._hsvColorValue.Value = Vector3.new(0, 0, 0)
	self._maid:GiveTask(self._hsvColorValue)

	self.ColorChanged = self._hsvColorValue.Changed

	self._sizeValue = Instance.new("Vector3Value")
	self._sizeValue.Value = Vector3.new(6, 4, 0)
	self._maid:GiveTask(self._sizeValue)

	self._innerPadding = Instance.new("NumberValue")
	self._innerPadding.Value = 0.2
	self._maid:GiveTask(self._innerPadding)

	self._transparency = Instance.new("NumberValue")
	self._transparency.Value = 0
	self._maid:GiveTask(self._transparency)

	self._hueSaturationPicker = HSColorPicker.new()
	self._maid:GiveTask(self._hueSaturationPicker)

	self._valuePicker = ValueColorPicker.new()
	self._maid:GiveTask(self._valuePicker)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	-- Transparency
	self._maid:GiveTask(self._transparency.Changed:Connect(function()
		self._hueSaturationPicker:SetTransparency(self._transparency.Value)
		self._valuePicker:SetTransparency(self._transparency.Value)
	end))

	-- Color
	self._maid:GiveTask(self._hsvColorValue.Changed:Connect(function()
		self._hueSaturationPicker:SetHSVColor(self._hsvColorValue.Value)
		self._valuePicker:SetHSVColor(self._hsvColorValue.Value)
	end))
	self._maid:GiveTask(self._hueSaturationPicker.ColorChanged:Connect(function()
		self._hsvColorValue.Value = self._hueSaturationPicker:GetHSVColor()
	end))
	self._maid:GiveTask(self._valuePicker.ColorChanged:Connect(function()
		self._hsvColorValue.Value = self._valuePicker:GetHSVColor()
	end))

	-- Sizing
	self._maid:GiveTask(self._hueSaturationPicker:GetSizeValue().Changed:Connect(function()
		self:_updateSize()
	end))
	self._maid:GiveTask(self._valuePicker:GetSizeValue().Changed:Connect(function()
		self:_updateSize()
	end))
	self._maid:GiveTask(self._innerPadding.Changed:Connect(function()
		self:_updateSize()
	end))
	self:_updateSize()

	return self
end

function HSVColorPicker:SetSize(height)
	assert(type(height) == "number", "Bad height")

	self._hueSaturationPicker:SetSize(height)
	self._valuePicker:SetSize(height)
end

function HSVColorPicker:SyncValue(color3Value)
	local maid = Maid.new()

	self:SetColor(color3Value.Value)

	maid:GiveTask(self.ColorChanged:Connect(function()
		color3Value.Value = self:GetColor()
	end))

	maid:GiveTask(color3Value.Changed:Connect(function()
		local currentColor = color3Value.Value

		-- Check so we don't lose h/s/v values
		-- probably should do a better check here. ah well.
		if currentColor ~= self:GetColor() then
			local h, s, v = Color3.toHSV(currentColor)
			self._hsvColorValue.Value = Vector3.new(h, s, v)
		end
	end))

	return maid
end

function HSVColorPicker:HintBackgroundColor(color)
	self._valuePicker:HintBackgroundColor(color)
end

function HSVColorPicker:SetHSVColor(hsvColor)
	assert(typeof(hsvColor) == "Vector3", "Bad hsvColor")

	self._hsvColorValue.Value = hsvColor
end

function HSVColorPicker:GetHSVColor()
	return self._hsvColorValue.Value
end

function HSVColorPicker:SetColor(color)
	local h, s, v = Color3.toHSV(color)
	self._hsvColorValue.Value = Vector3.new(h, s, v)
end

function HSVColorPicker:GetColor()
	local current = self._hsvColorValue.Value
	local h, s, v = current.x, current.y, current.z
	return Color3.fromHSV(h, s, v)
end

function HSVColorPicker:GetSizeValue()
	return self._sizeValue
end

function HSVColorPicker:SetTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function HSVColorPicker:_updateSize()
	local valueSize  = self._valuePicker:GetSizeValue().Value
	local hueSize = self._hueSaturationPicker:GetSizeValue().Value

	local width = valueSize.x + hueSize.x + self._innerPadding.Value
	local height = math.max(valueSize.y, hueSize.y)

	self._sizeValue.Value = Vector3.new(width, height)
end

function HSVColorPicker:_render()
	local function container(picker, props)
		return Blend.New "Frame" {
			AnchorPoint = props.AnchorPoint;
			Position = props.Position;
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = Blend.Computed(picker:GetIsPressedValue(), function(isPressed)
				return isPressed and 2 or 1
			end);
			[Blend.Children] = {
				picker.Gui;
				Blend.New "UIAspectRatioConstraint" {
					AspectRatio = Blend.Computed(picker:GetSizeValue(), function(size)
						if size.x == 0 or size.y == 0 then
							return 1
						else
							return size.x/size.y
						end
					end);
				};
			};
		};
	end

	return Blend.New "Frame" {
		Name = "HSVColorPicker";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		[Blend.Children] = {
			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = Blend.Computed(self._sizeValue, function(size)
					if size.x == 0 or size.y == 0 then
						return 1
					else
						return size.x/size.y
					end
				end);
			};

			container(self._hueSaturationPicker, {
				AnchorPoint = Vector2.new(0, 0);
				Position = UDim2.fromScale(0, 0);
			});
			container(self._valuePicker, {
				AnchorPoint = Vector2.new(1, 0);
				Position = UDim2.fromScale(1, 0);
			});
		};
	};
end

return HSVColorPicker