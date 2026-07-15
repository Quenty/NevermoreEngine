--!strict
--[=[
	@class ColorPickerStoryUtils
]=]

local require = require(script.Parent.loader).load(script)

local Blend = require("Blend")
local HSVColorPicker = require("HSVColorPicker")
local Maid = require("Maid")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local ColorPickerStoryUtils = {}

function ColorPickerStoryUtils.createPicker(
	maid: Maid.Maid,
	valueSync: Color3Value,
	labelText: string,
	currentVisible: ValueObject.ValueObject<HSVColorPicker.HSVColorPicker?>
): Observable.Observable<Instance>
	local picker = maid:Add(HSVColorPicker.new())
	local gui = picker.Gui :: GuiObject
	gui.AnchorPoint = Vector2.new(0.5, 1)
	gui.Position = UDim2.fromScale(0.5, 1)
	gui.Size = UDim2.new(0, 150, 1, -30)
	gui.ZIndex = 2

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
		BackgroundTransparency = 0,
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(0.2, 0.2, 0.2),
		Size = Blend.Spring(
			Blend.Computed(visible, function(isVisible)
				if isVisible then
					return UDim2.fromOffset(170, 190)
				else
					return UDim2.fromOffset(170, 50)
				end
			end),
			40
		),
		ClipsDescendants = false,
		[Blend.OnEvent "Activated"] = function()
			visible.Value = not visible.Value
		end,

		picker.Gui,
		Blend.New "TextLabel" {
			BackgroundTransparency = 1,
			Text = labelText,
			Position = UDim2.fromOffset(35, 5),
			Size = UDim2.new(1, -40, 0, 20),
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 0,
		},

		Blend.New "Frame" {
			BackgroundColor3 = valueSync,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(5, 5),
			[Blend.Children] = {
				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 10),
				},
			},
		},

		Blend.New "UIPadding" {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		},

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 10),
		},
	}
end

function ColorPickerStoryUtils.create(
	maid: Maid.Maid,
	buildPickers: (addPicker: (labelText: string, valueSync: Color3Value) -> ()) -> ()
): Observable.Observable<Instance>
	local currentVisible: ValueObject.ValueObject<HSVColorPicker.HSVColorPicker?> =
		maid:Add(ValueObject.new(nil :: HSVColorPicker.HSVColorPicker?))

	local built: { Observable.Observable<Instance> } = {}

	buildPickers(function(labelText, valueSync)
		table.insert(built, ColorPickerStoryUtils.createPicker(maid, valueSync, labelText, currentVisible))
	end)

	local function pickerGroup(pickers: { Observable.Observable<Instance> }): Observable.Observable<Instance>
		return Blend.New "Frame" {
			Size = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				FillDirection = Enum.FillDirection.Horizontal,
			},

			pickers,
		}
	end

	local groups: { Observable.Observable<Instance> } = {}
	local current: { Observable.Observable<Instance> } = {}
	for i = 1, #built do
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
		Size = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,

		[Blend.OnEvent "InputBegan"] = function(inputObject, processed)
			if processed then
				return
			end

			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				currentVisible.Value = nil
			end
		end,

		Blend.New "UIListLayout" {
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			FillDirection = Enum.FillDirection.Vertical,
		},

		groups,
	}
end

return ColorPickerStoryUtils
