--[=[
	@class RadialImage
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local Math = require("Math")
local Observable = require("Observable")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local RadialImage = setmetatable({}, BaseObject)
RadialImage.ClassName = "RadialImage"
RadialImage.__index = RadialImage

function RadialImage.new()
	local self = setmetatable(BaseObject.new(), RadialImage)

	self._image = Instance.new("StringValue")
	self._image.Value = ""
	self._maid:GiveTask(self._image)

	self._percent = Instance.new("NumberValue")
	self._percent.Value = 1
	self._maid:GiveTask(self._percent)

	self._transparency = Instance.new("NumberValue")
	self._transparency.Value = 0
	self._maid:GiveTask(self._transparency)

	self._enabledTransparency = Instance.new("NumberValue")
	self._enabledTransparency.Value = 0
	self._maid:GiveTask(self._enabledTransparency)

	self._disabledTransparency = Instance.new("NumberValue")
	self._disabledTransparency.Value = 1
	self._maid:GiveTask(self._disabledTransparency)

	self._enabledColor = Instance.new("Color3Value")
	self._enabledColor.Value = Color3.new(1, 1, 1)
	self._maid:GiveTask(self._enabledColor)

	self._disabledColor = Instance.new("Color3Value")
	self._disabledColor.Value = Color3.new(1, 1, 1)
	self._maid:GiveTask(self._disabledColor)

	self._absoluteSize = ValueObject.new(Vector2.new(0, 0))
	self._maid:GiveTask(self._absoluteSize)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	return self
end

function RadialImage.blend(props)
	assert(type(props) == "table", "Bad props")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local viewport = RadialImage.new()

		local function bindObservable(propName, callback)
			if props[propName] then
				local observe = Blend.toPropertyObservable(props[propName])
				if observe then
					maid:GiveTask(observe:Subscribe(function(value)
						callback(value)
					end))
				else
					callback(props[propName])
				end
			end
		end

		bindObservable("Image", function(value)
			viewport:SetImage(value)
		end)

		bindObservable("Percent", function(value)
			viewport:SetPercent(value)
		end)
		bindObservable("EnabledTransparency", function(value)
			viewport:SetEnabledTransparency(value)
		end)
		bindObservable("DisabledTransparency", function(value)
			viewport:SetDisabledTransparency(value)
		end)
		bindObservable("EnabledColor", function(value)
			viewport:SetEnabledColor(value)
		end)
		bindObservable("DisabledColor", function(value)
			viewport:SetDisabledColor(value)
		end)
		bindObservable("Transparency", function(value)
			viewport:SetTransparency(value)
		end)

		bindObservable("Size", function(value)
			viewport.Gui.Size = value
		end)
		bindObservable("Position", function(value)
			viewport.Gui.Position = value
		end)
		bindObservable("AnchorPoint", function(value)
			viewport.Gui.AnchorPoint = value
		end)

		sub:Fire(viewport.Gui)

		return maid
	end)
end

--[=[
	Sets the image to use for this radial image
	@param image string
]=]
function RadialImage:SetImage(image)
	assert(type(image) == "string", "Bad image")

	self._image.Value = image
end

--[=[
	Sets the percent we're at
	@param percent number
]=]
function RadialImage:SetPercent(percent)
	assert(type(percent) == "number", "Bad percent")

	self._percent.Value = percent
end

--[=[
	Sets the total transparency of the radial image
	@param transparency number
]=]
function RadialImage:SetTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._transparency.Value = transparency
end

--[=[
	Sets the enabled transparency for the radial image
	@param transparency number
]=]
function RadialImage:SetEnabledTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._enabledTransparency.Value = transparency
end

--[=[
	Sets the disabled transparency
	@param transparency number
]=]
function RadialImage:SetDisabledTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._disabledTransparency.Value = transparency
end

--[=[
	Sets the enabled color
	@param enabledColor Color3
]=]
function RadialImage:SetEnabledColor(enabledColor)
	assert(typeof(enabledColor) == "Color3", "Bad enabledColor")

	self._enabledColor.Value = enabledColor
end

--[=[
	Sets the disabled color
	@param disabledColor Color3
]=]
function RadialImage:SetDisabledColor(disabledColor)
	assert(typeof(disabledColor) == "Color3", "Bad disabledColor")

	self._disabledColor.Value = disabledColor
end

function RadialImage:_render()
	return Blend.New "Frame" {
		Name = "RadialImage";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		[Blend.OnChange("AbsoluteSize")] = self._absoluteSize;

		[Blend.Children] = {
			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = 1;
			};

			Blend.New "Frame" {
				Name = "LeftFrame";
				Size = Blend.Computed(self._absoluteSize, function(size)
					-- hack: ensures when we're 24.5 wide or something we don't end
					-- up with a split in the middle.
					-- this is an issue because clips descendants tends towards floor
					-- pixel clipping.
					if size.x % 2 ~= 0 then
						return UDim2.new(0.5, 1, 1, 0);
					else
						return UDim2.new(0.5, 0, 1, 0);
					end
				end);
				Position = UDim2.new(0, 0, 0, 0);
				BackgroundTransparency = 1;
				ClipsDescendants = true;

				[Blend.Children] = {
					Blend.New "ImageLabel" {
						Size = UDim2.new(2, 0, 1, 0);
						BackgroundTransparency = 1;
						ImageTransparency = self._transparency;
						Image = self._image;

						[Blend.Children] = {
							Blend.New "UIGradient" {
								Transparency = Blend.Computed(
									self._enabledTransparency,
									self._disabledTransparency,
									function(enabled, disabled)
										return NumberSequence.new({
											NumberSequenceKeypoint.new(0, disabled);
											NumberSequenceKeypoint.new(0.5, disabled);
											NumberSequenceKeypoint.new(0.5001, enabled);
											NumberSequenceKeypoint.new(1, enabled);
										});
									end);
								Color = Blend.Computed(
									self._enabledColor,
									self._disabledColor,
									function(enabled, disabled)
										return ColorSequence.new({
											ColorSequenceKeypoint.new(0, disabled);
											ColorSequenceKeypoint.new(0.5, disabled);
											ColorSequenceKeypoint.new(0.5001, enabled);
											ColorSequenceKeypoint.new(1, enabled);
										});
									end);
								Rotation = Blend.Computed(self._percent, function(percent)
									local mapped = math.clamp(Math.map(percent, 0.5, 1, 0, 1), 0, 1)
									return mapped*180
								end);
							};
						};
					};
				};
			};

			Blend.New "Frame" {
				Name = "RightFrame";
				Size = UDim2.new(0.5, 0, 1, 0);
				Position = UDim2.new(0.5, 0, 0, 0);
				BackgroundTransparency = 1;
				ClipsDescendants = true;

				[Blend.Children] = {
					Blend.New "ImageLabel" {
						Size = UDim2.new(2, 0, 1, 0);
						AnchorPoint = Vector2.new(1, 0);
						Position = UDim2.new(1, 0, 0, 0);
						BackgroundTransparency = 1;
						ImageTransparency = self._transparency;
						Image = self._image;

						[Blend.Children] = {
							Blend.New "UIGradient" {
								Transparency = Blend.Computed(
									self._enabledTransparency,
									self._disabledTransparency,
									function(enabled, disabled)
										return NumberSequence.new({
											NumberSequenceKeypoint.new(0, disabled);
											NumberSequenceKeypoint.new(0.5, disabled);
											NumberSequenceKeypoint.new(0.5001, enabled);
											NumberSequenceKeypoint.new(1, enabled);
										});
									end);
								Color = Blend.Computed(
									self._enabledColor,
									self._disabledColor,
									function(enabled, disabled)
										return ColorSequence.new({
											ColorSequenceKeypoint.new(0, disabled);
											ColorSequenceKeypoint.new(0.5, disabled);
											ColorSequenceKeypoint.new(0.5001, enabled);
											ColorSequenceKeypoint.new(1, enabled);
										});
									end);
								Rotation = Blend.Computed(self._percent, function(percent)
									local mapped = math.clamp(Math.map(percent, 0, 0.5, 0, 1), 0, 1)
									return 180 + mapped*180
								end);
							};
						};
					};
				};
			};
		};
	};
end

return RadialImage