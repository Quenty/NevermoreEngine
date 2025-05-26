--[=[
	A HSV color picker component which can be used to select colors using
	an interface standard to Roblox Studio.

	@client
	@class HSVColorPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local HSColorPicker = require("HSColorPicker")
local Maid = require("Maid")
local ValueColorPicker = require("ValueColorPicker")
local ValueObject = require("ValueObject")

local HSVColorPicker = setmetatable({}, BaseObject)
HSVColorPicker.ClassName = "HSVColorPicker"
HSVColorPicker.__index = HSVColorPicker

--[=[
	Creates a new color picker!

	```lua
	local picker = HSVColorPicker.new()
	picker:SetColor(Color3.new(0.5, 0.5, 0.5))
	picker.Gui.Parent = screenGui
	```

	@return HSVColorPicker
]=]
function HSVColorPicker.new()
	local self = setmetatable(BaseObject.new(), HSVColorPicker)

	self._hsvColorValue = self._maid:Add(ValueObject.new(Vector3.zero, "Vector3"))
	self._sizeValue = self._maid:Add(ValueObject.new(Vector2.new(6, 4), "Vector2"))
	self._innerPadding = self._maid:Add(ValueObject.new(0.2, "number"))
	self._transparency = self._maid:Add(ValueObject.new(0, "number"))
	self._hueSaturationPicker = self._maid:Add(HSColorPicker.new())
	self._valuePicker = self._maid:Add(ValueColorPicker.new())

	self.ColorChanged = self._hsvColorValue.Changed

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

--[=[
	Sets the height of the HSVColorPicker. This impacts the [GetSizeValue] return
	size. This is a general interface to size things.

	@param height number
]=]
function HSVColorPicker:SetSize(height: number)
	assert(type(height) == "number", "Bad height")

	self._hueSaturationPicker:SetSize(height)
	self._valuePicker:SetSize(height)
end

--[=[
	Syncs the color picker with the Color3Value.

	@param color3Value Color3Value
	@return maid
]=]
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

--[=[
	Hints what the background color of the HSVColorPicker. This impacts
	some UI elements to ensure proper contrast.

	@param color Color3
]=]
function HSVColorPicker:HintBackgroundColor(color)
	self._valuePicker:HintBackgroundColor(color)
end

--[=[
	Set the current color in HSV formet.

	@param hsvColor Vector3
]=]
function HSVColorPicker:SetHSVColor(hsvColor)
	assert(typeof(hsvColor) == "Vector3", "Bad hsvColor")

	self._hsvColorValue.Value = hsvColor
end

--[=[
	Get the current color in HSV formet as a Vector3.

	@return Vector3
]=]
function HSVColorPicker:GetHSVColor()
	return self._hsvColorValue.Value
end

--[=[
	Set the current color.

	@param color Color3
]=]
function HSVColorPicker:SetColor(color: Color3)
	local h, s, v = Color3.toHSV(color)
	self._hsvColorValue.Value = Vector3.new(h, s, v)
end

--[=[
	Get the current color.

	@return Color3
]=]
function HSVColorPicker:GetColor(): Color3
	local current = self._hsvColorValue.Value
	local h, s, v = current.x, current.y, current.z
	return Color3.fromHSV(h, s, v)
end

--[=[
	A size value that defines the aspect ratio and size of this picker. See [SetSize]
	@return ValueObject<Vector2>
]=]
function HSVColorPicker:GetSizeValue(): ValueObject.ValueObject<Vector2>
	return self._sizeValue
end

function HSVColorPicker:GetMeasureValue(): ValueObject.ValueObject<Vector2>
	return self._sizeValue
end

--[=[
	Sets the transparency of the color

	@param transparency number
]=]
function HSVColorPicker:SetTransparency(transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

function HSVColorPicker:_updateSize()
	local valueSize = self._valuePicker:GetSizeValue().Value
	local hueSize = self._hueSaturationPicker:GetSizeValue().Value

	local width = valueSize.x + hueSize.x + self._innerPadding.Value
	local height = math.max(valueSize.y, hueSize.y)

	self._sizeValue.Value = Vector2.new(width, height)
end

function HSVColorPicker:_render()
	local function container(picker, props)
		return Blend.New("Frame")({
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = Blend.Computed(picker:ObserveIsPressed(), function(isPressed)
				return isPressed and 2 or 1
			end),

			picker.Gui,

			Blend.New("UIAspectRatioConstraint")({
				AspectRatio = Blend.Computed(picker:GetSizeValue(), function(size)
					if size.x <= 0 or size.y <= 0 then
						return 1
					else
						return size.x / size.y
					end
				end),
			}),
		})
	end

	return Blend.New("Frame")({
		Name = "HSVColorPicker",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,

		Blend.New("UIAspectRatioConstraint")({
			AspectRatio = Blend.Computed(self._sizeValue, function(size)
				if size.x <= 0 or size.y <= 0 then
					return 1
				else
					return size.x / size.y
				end
			end),
		}),

		container(self._hueSaturationPicker, {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromScale(0, 0),
		}),

		container(self._valuePicker, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
		}),
	})
end

return HSVColorPicker
