--[=[
	@class ColorPickerStoryUtils
]=]

local require = require(script.Parent.loader).load(script)

local Blend = require("Blend")
local HSVColorPicker = require("HSVColorPicker")
local ValueObject = require("ValueObject")

local ColorPickerStoryUtils = {}

function ColorPickerStoryUtils.createPicker(maid, valueSync, labelText, currentVisible)
	local picker = maid:Add(HSVColorPicker.new())
	picker.Gui.AnchorPoint = Vector2.new(0.5, 1)
	picker.Gui.Position = UDim2.new(0.5, 0, 1, 0)
	picker.Gui.Size = UDim2.new(0, 150, 1, -30);
	picker.Gui.ZIndex = 2;

	maid:GiveTask(picker:SyncValue(valueSync))

	local visible = maid:Add(Instance.new("BoolValue"))
	visible.Value = false

	maid:GiveTask(visible.Changed:Connect(function()
		if visible.Value then
			currentVisible.Value = picker
		end
	end))

	maid:GiveTask(currentVisible.Changed:Connect(function(_, oldValue)
		if oldValue == picker then
			visible.Value = false
		end
	end))

	return Blend.New "ImageButton" {
		BackgroundTransparency = 0;
		AutoButtonColor = true;
		BackgroundColor3 = Color3.new(0.2, 0.2, 0.2);
		Size = Blend.Spring(Blend.Computed(visible, function(isVisible)
			if isVisible then
				return UDim2.new(0, 170, 0, 190);
			else
				return UDim2.new(0, 170, 0, 50);
			end
		end), 40);
		ClipsDescendants = false;
		[Blend.OnEvent "Activated"] = function()
			visible.Value = not visible.Value
		end;

		picker.Gui;
		Blend.New "TextLabel" {
			BackgroundTransparency = 1;
			Text = labelText;
			Position = UDim2.new(0, 35, 0, 5);
			Size = UDim2.new(1, -40, 0, 20);
			Font = Enum.Font.FredokaOne;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextScaled = true;
			TextColor3 = Color3.new(1, 1, 1);
			ZIndex = 0;
		};

		Blend.New "Frame" {
			BackgroundColor3 = valueSync;
			Size = UDim2.new(0, 20, 0, 20);
			Position = UDim2.new(0, 5, 0, 5);
			[Blend.Children] = {
				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 10);
				};
			};
		};

		Blend.New "UIPadding" {
			PaddingTop = UDim.new(0, 10);
			PaddingBottom = UDim.new(0, 10);
			PaddingLeft = UDim.new(0, 10);
			PaddingRight = UDim.new(0, 10);
		};

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 10);
		};
	}

end

function ColorPickerStoryUtils.create(maid, buildPickers)
	local currentVisible = maid:Add(ValueObject.new())

	local built = {}

	buildPickers(function(labelText, valueSync)
		table.insert(built, ColorPickerStoryUtils.createPicker(maid, valueSync, labelText, currentVisible))
	end)

	local function pickerGroup(pickers)
		return Blend.New "Frame" {
			Size = UDim2.new(1, 0, 0, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.fromScale(0.5, 0.5);
			BackgroundTransparency = 1;
			AutomaticSize = Enum.AutomaticSize.Y;

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 10);
				HorizontalAlignment = Enum.HorizontalAlignment.Left;
				VerticalAlignment = Enum.VerticalAlignment.Top;
				FillDirection = Enum.FillDirection.Horizontal;
			};

			pickers;
		};
	end

	local groups = {}
	local current = {}
	for i=1, #built do
		table.insert(current, built[i])
		if #current >= 4 then
			table.insert(groups, pickerGroup(current))
			current = {}
		end
	end

	if #current > 0 then
		table.insert(groups, pickerGroup(current))
	end

	return Blend.New "Frame" {
		Size = UDim2.new(0, 0, 0, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Position = UDim2.fromScale(0.5, 0.5);
		BackgroundTransparency = 1;
		AutomaticSize = Enum.AutomaticSize.XY;

		[Blend.OnEvent "InputBegan"] = function(inputObject, processed)
			if processed then
				return
			end

			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				currentVisible.Value = nil
			end
		end;

		Blend.New "UIListLayout" {
			Padding = UDim.new(0, 10);
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			VerticalAlignment = Enum.VerticalAlignment.Top;
			FillDirection = Enum.FillDirection.Vertical;
		};

		groups;
	};
end

return ColorPickerStoryUtils