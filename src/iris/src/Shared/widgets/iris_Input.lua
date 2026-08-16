--!nocheck
local Types = require(script.Parent.Parent.iris_Types)

type InputDataTypes =
	"Num"
	| "Vector2"
	| "Vector3"
	| "UDim"
	| "UDim2"
	| "Color3"
	| "Color4"
	| "Rect"
	| "Enum"
	| ""
	| string
type InputType = "Input" | "Drag" | "Slider"

return function(Iris: Types.Internal, widgets: Types.WidgetUtility)
	local numberChanged = {
		["Init"] = function(_thisWidget: Types.Widget) end,
		["Get"] = function(thisWidget: Types.Input<any>)
			return thisWidget.lastNumberChangedTick == Iris._cycleTick
		end,
	}

	local function getValueByIndex<T>(value: T, index: number, arguments: Types.Arguments)
		local val = value :: unknown
		if typeof(val) == "number" then
			return val
		elseif typeof(val) == "Vector2" then
			if index == 1 then
				return val.X
			elseif index == 2 then
				return val.Y
			end
		elseif typeof(val) == "Vector3" then
			if index == 1 then
				return val.X
			elseif index == 2 then
				return val.Y
			elseif index == 3 then
				return val.Z
			end
		elseif typeof(val) == "UDim" then
			if index == 1 then
				return val.Scale
			elseif index == 2 then
				return val.Offset
			end
		elseif typeof(val) == "UDim2" then
			if index == 1 then
				return val.X.Scale
			elseif index == 2 then
				return val.X.Offset
			elseif index == 3 then
				return val.Y.Scale
			elseif index == 4 then
				return val.Y.Offset
			end
		elseif typeof(val) == "Color3" then
			local color = if arguments.UseHSV then { val:ToHSV() } else { val.R, val.G, val.B }
			if index == 1 then
				return color[1]
			elseif index == 2 then
				return color[2]
			elseif index == 3 then
				return color[3]
			end
		elseif typeof(val) == "Rect" then
			if index == 1 then
				return val.Min.X
			elseif index == 2 then
				return val.Min.Y
			elseif index == 3 then
				return val.Max.X
			elseif index == 4 then
				return val.Max.Y
			end
		elseif typeof(val) == "table" then
			return val[index]
		end

		error(`Incorrect datatype or value: {value} {typeof(value)} {index}.`)
	end

	local function updateValueByIndex<T>(value: T, index: number, newValue: number, arguments: Types.Arguments): T
		local val = value :: unknown
		if typeof(val) == "number" then
			return newValue :: any
		elseif typeof(val) == "Vector2" then
			if index == 1 then
				return Vector2.new(newValue, val.Y) :: any
			elseif index == 2 then
				return Vector2.new(val.X, newValue) :: any
			end
		elseif typeof(val) == "Vector3" then
			if index == 1 then
				return Vector3.new(newValue, val.Y, val.Z) :: any
			elseif index == 2 then
				return Vector3.new(val.X, newValue, val.Z) :: any
			elseif index == 3 then
				return Vector3.new(val.X, val.Y, newValue) :: any
			end
		elseif typeof(val) == "UDim" then
			if index == 1 then
				return UDim.new(newValue, val.Offset) :: any
			elseif index == 2 then
				return UDim.new(val.Scale, newValue) :: any
			end
		elseif typeof(val) == "UDim2" then
			if index == 1 then
				return UDim2.new(UDim.new(newValue, val.X.Offset), val.Y) :: any
			elseif index == 2 then
				return UDim2.new(UDim.new(val.X.Scale, newValue), val.Y) :: any
			elseif index == 3 then
				return UDim2.new(val.X, UDim.new(newValue, val.Y.Offset)) :: any
			elseif index == 4 then
				return UDim2.new(val.X, UDim.new(val.Y.Scale, newValue)) :: any
			end
		elseif typeof(val) == "Rect" then
			if index == 1 then
				return Rect.new(Vector2.new(newValue, val.Min.Y), val.Max) :: any
			elseif index == 2 then
				return Rect.new(Vector2.new(val.Min.X, newValue), val.Max) :: any
			elseif index == 3 then
				return Rect.new(val.Min, Vector2.new(newValue, val.Max.Y)) :: any
			elseif index == 4 then
				return Rect.new(val.Min, Vector2.new(val.Max.X, newValue)) :: any
			end
		elseif typeof(val) == "Color3" then
			if arguments.UseHSV then
				local h: number, s: number, v: number = val:ToHSV()
				if index == 1 then
					return Color3.fromHSV(newValue, s, v) :: any
				elseif index == 2 then
					return Color3.fromHSV(h, newValue, v) :: any
				elseif index == 3 then
					return Color3.fromHSV(h, s, newValue) :: any
				end
			end
			if index == 1 then
				return Color3.new(newValue, val.G, val.B) :: any
			elseif index == 2 then
				return Color3.new(val.R, newValue, val.B) :: any
			elseif index == 3 then
				return Color3.new(val.R, val.G, newValue) :: any
			end
		end

		error(`Incorrect datatype or value {value} {typeof(value)} {index}.`)
	end

	local defaultIncrements: { [InputDataTypes]: { number } } = {
		Num = { 1 },
		Vector2 = { 1, 1 },
		Vector3 = { 1, 1, 1 },
		UDim = { 0.01, 1 },
		UDim2 = { 0.01, 1, 0.01, 1 },
		Color3 = { 1, 1, 1 },
		Color4 = { 1, 1, 1, 1 },
		Rect = { 1, 1, 1, 1 },
	}

	local defaultMin: { [InputDataTypes]: { number } } = {
		Num = { 0 },
		Vector2 = { 0, 0 },
		Vector3 = { 0, 0, 0 },
		UDim = { 0, 0 },
		UDim2 = { 0, 0, 0, 0 },
		Rect = { 0, 0, 0, 0 },
	}

	local defaultMax: { [InputDataTypes]: { number } } = {
		Num = { 100 },
		Vector2 = { 100, 100 },
		Vector3 = { 100, 100, 100 },
		UDim = { 1, 960 },
		UDim2 = { 1, 960, 1, 960 },
		Rect = { 960, 960, 960, 960 },
	}

	local defaultPrefx: { [InputDataTypes]: { string } } = {
		Num = { "" },
		Vector2 = { "X: ", "Y: " },
		Vector3 = { "X: ", "Y: ", "Z: " },
		UDim = { "", "" },
		UDim2 = { "", "", "", "" },
		Color3_RGB = { "R: ", "G: ", "B: " },
		Color3_HSV = { "H: ", "S: ", "V: " },
		Color4_RGB = { "R: ", "G: ", "B: ", "T: " },
		Color4_HSV = { "H: ", "S: ", "V: ", "T: " },
		Rect = { "X: ", "Y: ", "X: ", "Y: " },
	}

	local defaultSigFigs: { [InputDataTypes]: { number } } = {
		Num = { 0 },
		Vector2 = { 0, 0 },
		Vector3 = { 0, 0, 0 },
		UDim = { 3, 0 },
		UDim2 = { 3, 0, 3, 0 },
		Color3 = { 0, 0, 0 },
		Color4 = { 0, 0, 0, 0 },
		Rect = { 0, 0, 0, 0 },
	}

	local function generateAbstract<T>(
		inputType: InputType,
		dataType: InputDataTypes,
		components: number,
		defaultValue: T
	): Types.WidgetClass
		return {
			hasState = true,
			hasChildren = false,
			Args = {
				["Text"] = 1,
				["Increment"] = 2,
				["Min"] = 3,
				["Max"] = 4,
				["Format"] = 5,
			},
			Events = {
				["numberChanged"] = numberChanged,
				["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
					return thisWidget.Instance
				end),
			},
			GenerateState = function(thisWidget: Types.Input<T>)
				if thisWidget.state.number == nil then
					thisWidget.state.number = Iris._widgetState(thisWidget, "number", defaultValue)
				end
				if thisWidget.state.editingText == nil then
					thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", 0)
				end
			end,
			Update = function(thisWidget: Types.Input<T>)
				local Input = thisWidget.Instance :: GuiObject
				local TextLabel: TextLabel = Input.TextLabel
				TextLabel.Text = thisWidget.arguments.Text or `Input {dataType}`

				if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
					thisWidget.arguments.Format = { thisWidget.arguments.Format }
				elseif not thisWidget.arguments.Format then
					-- we calculate the format for the s.f. using the max, min and increment arguments.
					local format = {}
					for index = 1, components do
						local sigfigs = defaultSigFigs[dataType][index]

						if thisWidget.arguments.Increment then
							local value =
								getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
							sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
						end

						if thisWidget.arguments.Max then
							local value = getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any)
							sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
						end

						if thisWidget.arguments.Min then
							local value = getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any)
							sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
						end

						if sigfigs > 0 then
							-- we know it's a float.
							format[index] = `%.{sigfigs}f`
						else
							format[index] = "%d"
						end
					end

					thisWidget.arguments.Format = format
					thisWidget.arguments.Prefix = defaultPrefx[dataType]
				end

				if inputType == "Input" and dataType == "Num" then
					Input.SubButton.Visible = not thisWidget.arguments.NoButtons
					Input.AddButton.Visible = not thisWidget.arguments.NoButtons
					local InputField: TextBox = Input.InputField1
					local rightPadding = if thisWidget.arguments.NoButtons
						then 0
						else (2 * Iris._config.ItemInnerSpacing.X)
							+ (2 * (Iris._config.TextSize + 2 * Iris._config.FramePadding.Y))
					InputField.Size = UDim2.new(
						UDim.new(Iris._config.ContentWidth.Scale, Iris._config.ContentWidth.Offset - rightPadding),
						Iris._config.ContentHeight
					)
				end

				if inputType == "Slider" then
					for index = 1, components do
						local SliderField = Input:FindFirstChild("SliderField" .. tostring(index)) :: TextButton
						local GrabBar: Frame = SliderField.GrabBar

						local increment = thisWidget.arguments.Increment
								and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
							or defaultIncrements[dataType][index]
						local min = thisWidget.arguments.Min
								and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any)
							or defaultMin[dataType][index]
						local max = thisWidget.arguments.Max
								and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any)
							or defaultMax[dataType][index]

						local grabScaleSize = 1 / math.floor((1 + max - min) / increment)

						GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
					end

					local callbackIndex = #Iris._postCycleCallbacks + 1
					local desiredCycleTick = Iris._cycleTick + 1
					Iris._postCycleCallbacks[callbackIndex] = function()
						if Iris._cycleTick >= desiredCycleTick then
							if thisWidget.lastCycleTick ~= -1 then
								thisWidget.state.number.lastChangeTick = Iris._cycleTick
								Iris._widgets[`Slider{dataType}`].UpdateState(thisWidget)
							end
							Iris._postCycleCallbacks[callbackIndex] = nil
						end
					end
				end
			end,
			Discard = function(thisWidget: Types.Input<T>)
				thisWidget.Instance:Destroy()
				widgets.discardState(thisWidget)
			end,
		} :: Types.WidgetClass
	end

	local function focusLost<T>(thisWidget: Types.Input<T>, InputField: TextBox, index: number, dataType: InputDataTypes)
		local newValue = tonumber(InputField.Text:match("-?%d*%.?%d*"))
		local state = thisWidget.state.number
		local widget = thisWidget
		if dataType == "Color4" and index == 4 then
			state = widget.state.transparency
		elseif dataType == "Color3" or dataType == "Color4" then
			state = widget.state.color
		end
		if newValue ~= nil then
			if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
				newValue = newValue / 255
			end
			if thisWidget.arguments.Min ~= nil then
				newValue =
					math.max(newValue, getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any))
			end
			if thisWidget.arguments.Max ~= nil then
				newValue =
					math.min(newValue, getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any))
			end

			if thisWidget.arguments.Increment then
				newValue = math.round(
					newValue / getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
				) * getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
			end

			state:set(updateValueByIndex(state.value, index, newValue, thisWidget.arguments :: any))
			thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
		end

		local value = getValueByIndex(state.value, index, thisWidget.arguments :: any)
		if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
			value = math.round(value * 255)
		end

		local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
		if thisWidget.arguments.Prefix then
			format = thisWidget.arguments.Prefix[index] .. format
		end
		InputField.Text = string.format(format, value)

		thisWidget.state.editingText:set(0)
		InputField:ReleaseFocus(true)
	end

	--[[
        Input
    ]]
	local generateInputScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
	do
		local function generateButtons(thisWidget: Types.Input<number>, parent: GuiObject, textHeight: number)
			local SubButton = widgets.abstractButton.Generate(thisWidget) :: TextButton
			SubButton.Name = "SubButton"
			SubButton.Size =
				UDim2.fromOffset(Iris._config.TextSize + 2 * Iris._config.FramePadding.Y, Iris._config.TextSize)
			SubButton.Text = "-"
			SubButton.TextXAlignment = Enum.TextXAlignment.Center
			SubButton.ZIndex = 5
			SubButton.LayoutOrder = 5
			SubButton.Parent = parent

			widgets.applyButtonClick(SubButton, function()
				local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				local changeValue = (
					thisWidget.arguments.Increment
						and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments :: Types.Argument)
					or 1
				) * (isCtrlHeld and 100 or 1)
				local newValue = thisWidget.state.number.value - changeValue
				if thisWidget.arguments.Min ~= nil then
					newValue = math.max(
						newValue,
						getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments :: Types.Argument)
					)
				end
				if thisWidget.arguments.Max ~= nil then
					newValue = math.min(
						newValue,
						getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments :: Types.Argument)
					)
				end
				thisWidget.state.number:set(newValue)
				thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
			end)

			local AddButton = widgets.abstractButton.Generate(thisWidget) :: TextButton
			AddButton.Name = "AddButton"
			AddButton.Size =
				UDim2.fromOffset(Iris._config.TextSize + 2 * Iris._config.FramePadding.Y, Iris._config.TextSize)
			AddButton.Text = "+"
			AddButton.TextXAlignment = Enum.TextXAlignment.Center
			AddButton.ZIndex = 6
			AddButton.LayoutOrder = 6
			AddButton.Parent = parent

			widgets.applyButtonClick(AddButton, function()
				local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				local changeValue = (
					thisWidget.arguments.Increment
						and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments :: Types.Argument)
					or 1
				) * (isCtrlHeld and 100 or 1)
				local newValue = thisWidget.state.number.value + changeValue
				if thisWidget.arguments.Min ~= nil then
					newValue = math.max(
						newValue,
						getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments :: Types.Argument)
					)
				end
				if thisWidget.arguments.Max ~= nil then
					newValue = math.min(
						newValue,
						getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments :: Types.Argument)
					)
				end
				thisWidget.state.number:set(newValue)
				thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
			end)

			return 2 * Iris._config.ItemInnerSpacing.X + 2 * textHeight
		end

		local function generateField<T>(
			thisWidget: Types.Input<T>,
			index: number,
			componentWidth: UDim,
			dataType: InputDataTypes
		)
			local InputField = Instance.new("TextBox")
			InputField.Name = "InputField" .. tostring(index)
			InputField.AutomaticSize = Enum.AutomaticSize.Y
			InputField.Size = UDim2.new(componentWidth, Iris._config.ContentHeight)
			InputField.BackgroundColor3 = Iris._config.FrameBgColor
			InputField.BackgroundTransparency = Iris._config.FrameBgTransparency
			InputField.TextTruncate = Enum.TextTruncate.AtEnd
			InputField.ClearTextOnFocus = false
			InputField.ZIndex = index
			InputField.LayoutOrder = index
			InputField.ClipsDescendants = true

			widgets.applyFrameStyle(InputField)
			widgets.applyTextStyle(InputField)
			widgets.UISizeConstraint(InputField, Vector2.xAxis)

			InputField.FocusLost:Connect(function()
				focusLost(thisWidget, InputField, index, dataType)
			end)

			InputField.Focused:Connect(function()
				-- this highlights the entire field
				InputField.CursorPosition = #InputField.Text + 1
				InputField.SelectionStart = 1

				thisWidget.state.editingText:set(index)
			end)

			return InputField
		end

		function generateInputScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
			local input = generateAbstract("Input", dataType, components, defaultValue)

			return widgets.extend(input, {
				Generate = function(thisWidget: Types.Input<T>)
					local Input = Instance.new("Frame")
					Input.Name = "Iris_Input" .. dataType
					Input.AutomaticSize = Enum.AutomaticSize.Y
					Input.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
					Input.BackgroundTransparency = 1
					Input.BorderSizePixel = 0

					widgets.UIListLayout(
						Input,
						Enum.FillDirection.Horizontal,
						UDim.new(0, Iris._config.ItemInnerSpacing.X)
					).VerticalAlignment =
						Enum.VerticalAlignment.Center

					-- we add plus and minus buttons if there is only one box. This can be disabled through the argument.
					local rightPadding = 0
					local textHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

					if components == 1 then
						rightPadding = generateButtons(thisWidget :: any, Input, textHeight)
					end

					-- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
					-- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
					-- 4 pixels shorter, all for the sake of flush.
					local componentWidth = UDim.new(
						Iris._config.ContentWidth.Scale / components,
						(
							Iris._config.ContentWidth.Offset
							- (Iris._config.ItemInnerSpacing.X * (components - 1))
							- rightPadding
						) / components
					)
					local totalWidth = UDim.new(
						componentWidth.Scale * (components - 1),
						(componentWidth.Offset * (components - 1))
							+ (Iris._config.ItemInnerSpacing.X * (components - 1))
							+ rightPadding
					)
					local lastComponentWidth = Iris._config.ContentWidth - totalWidth

					-- we handle each component individually since they don't need to interact with each other.
					for index = 1, components do
						generateField(
							thisWidget,
							index,
							if index == components then lastComponentWidth else componentWidth,
							dataType
						).Parent =
							Input
					end

					local TextLabel = Instance.new("TextLabel")
					TextLabel.Name = "TextLabel"
					TextLabel.AutomaticSize = Enum.AutomaticSize.XY
					TextLabel.BackgroundTransparency = 1
					TextLabel.BorderSizePixel = 0
					TextLabel.LayoutOrder = 7

					widgets.applyTextStyle(TextLabel)

					TextLabel.Parent = Input

					return Input
				end,
				UpdateState = function(thisWidget: Types.Input<T>)
					local Input = thisWidget.Instance :: GuiObject

					for index = 1, components do
						local InputField: TextBox = Input:FindFirstChild("InputField" .. tostring(index))
						local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
						if thisWidget.arguments.Prefix then
							format = thisWidget.arguments.Prefix[index] .. format
						end
						InputField.Text = string.format(
							format,
							getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments :: any)
						)
					end
				end,
			})
		end
	end

	--[[
        Drag
    ]]
	local generateDragScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
	local generateColorDragScalar: (dataType: InputDataTypes, ...any) -> Types.WidgetClass
	do
		local PreviouseMouseXPosition = 0
		local AnyActiveDrag = false
		local ActiveDrag: Types.Input<Types.InputDataType>? = nil
		local ActiveIndex = 0
		local ActiveDataType: InputDataTypes | "" = ""

		local function updateActiveDrag()
			local currentMouseX = widgets.getMouseLocation().X
			local mouseXDelta = currentMouseX - PreviouseMouseXPosition
			PreviouseMouseXPosition = currentMouseX
			if AnyActiveDrag == false then
				return
			end
			if ActiveDrag == nil then
				return
			end

			local state = ActiveDrag.state.number
			if ActiveDataType == "Color3" or ActiveDataType == "Color4" then
				local Drag = ActiveDrag
				state = Drag.state.color
				if ActiveIndex == 4 then
					state = Drag.state.transparency
				end
			end

			local increment = ActiveDrag.arguments.Increment
					and getValueByIndex(ActiveDrag.arguments.Increment, ActiveIndex, ActiveDrag.arguments :: any)
				or defaultIncrements[ActiveDataType][ActiveIndex]
			increment *= (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or widgets.UserInputService:IsKeyDown(
				Enum.KeyCode.RightShift
			)) and 10 or 1
			increment *= (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or widgets.UserInputService:IsKeyDown(
				Enum.KeyCode.RightAlt
			)) and 0.1 or 1
			-- we increase the speed for Color3 and Color4 since it's too slow because the increment argument needs to be low.
			increment *= (ActiveDataType == "Color3" or ActiveDataType == "Color4") and 5 or 1

			local value = getValueByIndex(state.value, ActiveIndex, ActiveDrag.arguments :: any)
			local newValue = value + (mouseXDelta * increment)

			if ActiveDrag.arguments.Min ~= nil then
				newValue = math.max(
					newValue,
					getValueByIndex(ActiveDrag.arguments.Min, ActiveIndex, ActiveDrag.arguments :: any)
				)
			end
			if ActiveDrag.arguments.Max ~= nil then
				newValue = math.min(
					newValue,
					getValueByIndex(ActiveDrag.arguments.Max, ActiveIndex, ActiveDrag.arguments :: any)
				)
			end

			state:set(updateValueByIndex(state.value, ActiveIndex, newValue, ActiveDrag.arguments :: any))
			ActiveDrag.lastNumberChangedTick = Iris._cycleTick + 1
		end

		local function DragMouseDown(
			thisWidget: Types.Input<Types.InputDataType>,
			dataTypes: InputDataTypes,
			index: number,
			x: number,
			y: number
		)
			local currentTime = widgets.getTime()
			local isTimeValid = currentTime - thisWidget.lastClickedTime < Iris._config.MouseDoubleClickTime
			local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if
				(
					isTimeValid
					and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude
						< Iris._config.MouseDoubleClickMaxDist
				) or isCtrlHeld
			then
				thisWidget.state.editingText:set(index)
			else
				thisWidget.lastClickedTime = currentTime
				thisWidget.lastClickedPosition = Vector2.new(x, y)

				AnyActiveDrag = true
				ActiveDrag = thisWidget
				ActiveIndex = index
				ActiveDataType = dataTypes
				updateActiveDrag()
			end
		end

		widgets.registerEvent("InputChanged", function()
			if not Iris._started then
				return
			end
			updateActiveDrag()
		end)

		widgets.registerEvent("InputEnded", function(inputObject: InputObject)
			if not Iris._started then
				return
			end
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveDrag then
				AnyActiveDrag = false
				ActiveDrag = nil
				ActiveIndex = 0
			end
		end)

		local function generateField<T>(
			thisWidget: Types.Input<T>,
			index: number,
			componentSize: UDim2,
			dataType: InputDataTypes
		)
			local DragField = Instance.new("TextButton")
			DragField.Name = "DragField" .. tostring(index)
			DragField.AutomaticSize = Enum.AutomaticSize.Y
			DragField.Size = componentSize
			DragField.BackgroundColor3 = Iris._config.FrameBgColor
			DragField.BackgroundTransparency = Iris._config.FrameBgTransparency
			DragField.Text = ""
			DragField.AutoButtonColor = false
			DragField.LayoutOrder = index
			DragField.ClipsDescendants = true

			widgets.applyFrameStyle(DragField)
			widgets.applyTextStyle(DragField)
			widgets.UISizeConstraint(DragField, Vector2.xAxis)

			DragField.TextXAlignment = Enum.TextXAlignment.Center

			widgets.applyInteractionHighlights("Background", DragField, DragField, {
				Color = Iris._config.FrameBgColor,
				Transparency = Iris._config.FrameBgTransparency,
				HoveredColor = Iris._config.FrameBgHoveredColor,
				HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
				ActiveColor = Iris._config.FrameBgActiveColor,
				ActiveTransparency = Iris._config.FrameBgActiveTransparency,
			})

			local InputField = Instance.new("TextBox")
			InputField.Name = "InputField"
			InputField.Size = UDim2.fromScale(1, 1)
			InputField.BackgroundTransparency = 1
			InputField.ClearTextOnFocus = false
			InputField.TextTruncate = Enum.TextTruncate.AtEnd
			InputField.ClipsDescendants = true
			InputField.Visible = false

			widgets.applyFrameStyle(InputField, true)
			widgets.applyTextStyle(InputField)

			InputField.Parent = DragField

			InputField.FocusLost:Connect(function()
				focusLost(thisWidget, InputField, index, dataType)
			end)

			InputField.Focused:Connect(function()
				-- this highlights the entire field
				InputField.CursorPosition = #InputField.Text + 1
				InputField.SelectionStart = 1

				thisWidget.state.editingText:set(index)
			end)

			widgets.applyButtonDown(DragField, function(x: number, y: number)
				DragMouseDown(thisWidget :: any, dataType, index, x, y)
			end)

			return DragField
		end

		function generateDragScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
			local input = generateAbstract("Drag", dataType, components, defaultValue)

			return widgets.extend(input, {
				Generate = function(thisWidget: Types.Input<T>)
					thisWidget.lastClickedTime = -1
					thisWidget.lastClickedPosition = Vector2.zero

					local Drag = Instance.new("Frame")
					Drag.Name = "Iris_Drag" .. dataType
					Drag.AutomaticSize = Enum.AutomaticSize.Y
					Drag.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
					Drag.BackgroundTransparency = 1
					Drag.BorderSizePixel = 0

					widgets.UIListLayout(
						Drag,
						Enum.FillDirection.Horizontal,
						UDim.new(0, Iris._config.ItemInnerSpacing.X)
					).VerticalAlignment =
						Enum.VerticalAlignment.Center

					-- we add a color box if it is Color3 or Color4.
					local rightPadding = 0
					local textHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

					if dataType == "Color3" or dataType == "Color4" then
						rightPadding += Iris._config.ItemInnerSpacing.X + textHeight

						local ColorBox = Instance.new("ImageLabel")
						ColorBox.Name = "ColorBox"
						ColorBox.Size = UDim2.fromOffset(textHeight, textHeight)
						ColorBox.BorderSizePixel = 0
						ColorBox.Image = widgets.ICONS.ALPHA_BACKGROUND_TEXTURE
						ColorBox.ImageTransparency = 1
						ColorBox.LayoutOrder = 5

						widgets.applyFrameStyle(ColorBox, true)

						ColorBox.Parent = Drag
					end

					-- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
					-- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
					-- 4 pixels shorter, all for the sake of flush.
					local componentWidth = UDim.new(
						Iris._config.ContentWidth.Scale / components,
						(
							Iris._config.ContentWidth.Offset
							- (Iris._config.ItemInnerSpacing.X * (components - 1))
							- rightPadding
						) / components
					)
					local totalWidth = UDim.new(
						componentWidth.Scale * (components - 1),
						(componentWidth.Offset * (components - 1))
							+ (Iris._config.ItemInnerSpacing.X * (components - 1))
							+ rightPadding
					)
					local lastComponentWidth = Iris._config.ContentWidth - totalWidth

					for index = 1, components do
						generateField(
							thisWidget,
							index,
							if index == components
								then UDim2.new(lastComponentWidth, Iris._config.ContentHeight)
								else UDim2.new(componentWidth, Iris._config.ContentHeight),
							dataType
						).Parent =
							Drag
					end

					local TextLabel = Instance.new("TextLabel")
					TextLabel.Name = "TextLabel"
					TextLabel.AutomaticSize = Enum.AutomaticSize.XY
					TextLabel.BackgroundTransparency = 1
					TextLabel.BorderSizePixel = 0
					TextLabel.LayoutOrder = 6

					widgets.applyTextStyle(TextLabel)

					TextLabel.Parent = Drag

					return Drag
				end,
				UpdateState = function(thisWidget: Types.Input<T>)
					local Drag = thisWidget.Instance :: Frame

					local widget = thisWidget :: any
					for index = 1, components do
						local state = thisWidget.state.number
						if dataType == "Color3" or dataType == "Color4" then
							state = widget.state.color
							if index == 4 then
								state = widget.state.transparency
							end
						end
						local DragField = Drag:FindFirstChild("DragField" .. tostring(index)) :: TextButton
						local InputField: TextBox = DragField.InputField
						local value = getValueByIndex(state.value, index, thisWidget.arguments :: any)
						if (dataType == "Color3" or dataType == "Color4") and not widget.arguments.UseFloats then
							value = math.round(value * 255)
						end

						local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
						if thisWidget.arguments.Prefix then
							format = thisWidget.arguments.Prefix[index] .. format
						end
						DragField.Text = string.format(format, value)
						InputField.Text = tostring(value)

						if thisWidget.state.editingText.value == index then
							InputField.Visible = true
							InputField:CaptureFocus()
							DragField.TextTransparency = 1
						else
							InputField.Visible = false
							DragField.TextTransparency = Iris._config.TextTransparency
						end
					end

					if dataType == "Color3" or dataType == "Color4" then
						local ColorBox: ImageLabel = Drag.ColorBox

						ColorBox.BackgroundColor3 = widget.state.color.value

						if dataType == "Color4" then
							ColorBox.ImageTransparency = 1 - widget.state.transparency.value
						end
					end
				end,
			})
		end

		function generateColorDragScalar(dataType: InputDataTypes, ...: any)
			local defaultValues = { ... }
			local input = generateDragScalar(dataType, dataType == "Color4" and 4 or 3, defaultValues[1])

			return widgets.extend(input, {
				Args = {
					["Text"] = 1,
					["UseFloats"] = 2,
					["UseHSV"] = 3,
					["Format"] = 4,
				},
				Update = function(thisWidget: Types.InputColor4)
					local Input = thisWidget.Instance :: GuiObject
					local TextLabel: TextLabel = Input.TextLabel
					TextLabel.Text = thisWidget.arguments.Text or `Drag {dataType}`

					if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
						thisWidget.arguments.Format = { thisWidget.arguments.Format }
					elseif not thisWidget.arguments.Format then
						if thisWidget.arguments.UseFloats then
							thisWidget.arguments.Format = { "%.3f" }
						else
							thisWidget.arguments.Format = { "%d" }
						end

						thisWidget.arguments.Prefix =
							defaultPrefx[dataType .. if thisWidget.arguments.UseHSV then "_HSV" else "_RGB"]
					end

					thisWidget.arguments.Min = { 0, 0, 0, 0 }
					thisWidget.arguments.Max = { 1, 1, 1, 1 }
					thisWidget.arguments.Increment = { 0.001, 0.001, 0.001, 0.001 }

					-- since the state values have changed display, we call an update. The check is because state is not
					-- initialised on creation, so it would error otherwise.
					if thisWidget.state then
						thisWidget.state.color.lastChangeTick = Iris._cycleTick
						if dataType == "Color4" then
							thisWidget.state.transparency.lastChangeTick = Iris._cycleTick
						end
						Iris._widgets[thisWidget.type].UpdateState(thisWidget)
					end
				end,
				GenerateState = function(thisWidget: Types.InputColor4)
					if thisWidget.state.color == nil then
						thisWidget.state.color = Iris._widgetState(thisWidget, "color", defaultValues[1])
					end
					if dataType == "Color4" then
						if thisWidget.state.transparency == nil then
							thisWidget.state.transparency =
								Iris._widgetState(thisWidget, "transparency", defaultValues[2])
						end
					end
					if thisWidget.state.editingText == nil then
						thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", false)
					end
				end,
			})
		end
	end

	--[[
        Slider
    ]]
	local generateSliderScalar: <T>(dataType: InputDataTypes, components: number, defaultValue: T) -> Types.WidgetClass
	local generateEnumSliderScalar: (enum: Enum, item: EnumItem) -> Types.WidgetClass
	do
		local AnyActiveSlider = false
		local ActiveSlider: Types.Input<Types.InputDataType>? = nil
		local ActiveIndex = 0
		local ActiveDataType: InputDataTypes | "" = ""

		local function updateActiveSlider()
			if AnyActiveSlider == false then
				return
			end
			if ActiveSlider == nil then
				return
			end

			local Slider = ActiveSlider.Instance :: Frame
			local SliderField = Slider:FindFirstChild("SliderField" .. tostring(ActiveIndex)) :: TextButton
			local GrabBar: Frame = SliderField.GrabBar

			local increment = ActiveSlider.arguments.Increment
					and getValueByIndex(ActiveSlider.arguments.Increment, ActiveIndex, ActiveSlider.arguments :: any)
				or defaultIncrements[ActiveDataType][ActiveIndex]
			local min = ActiveSlider.arguments.Min
					and getValueByIndex(ActiveSlider.arguments.Min, ActiveIndex, ActiveSlider.arguments :: any)
				or defaultMin[ActiveDataType][ActiveIndex]
			local max = ActiveSlider.arguments.Max
					and getValueByIndex(ActiveSlider.arguments.Max, ActiveIndex, ActiveSlider.arguments :: any)
				or defaultMax[ActiveDataType][ActiveIndex]

			local GrabWidth = GrabBar.AbsoluteSize.X
			local Offset = widgets.getMouseLocation().X
				- (SliderField.AbsolutePosition.X - widgets.GuiOffset.X + GrabWidth / 2)
			local Ratio = Offset / (SliderField.AbsoluteSize.X - GrabWidth)
			local Positions = math.floor((max - min) / increment)
			local newValue = math.clamp(math.round(Ratio * Positions) * increment + min, min, max)

			ActiveSlider.state.number:set(
				updateValueByIndex(
					ActiveSlider.state.number.value,
					ActiveIndex,
					newValue,
					ActiveSlider.arguments :: any
				)
			)
			ActiveSlider.lastNumberChangedTick = Iris._cycleTick + 1
		end

		local function SliderMouseDown(
			thisWidget: Types.Input<Types.InputDataType>,
			dataType: InputDataTypes,
			index: number
		)
			local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if isCtrlHeld then
				thisWidget.state.editingText:set(index)
			else
				AnyActiveSlider = true
				ActiveSlider = thisWidget
				ActiveIndex = index
				ActiveDataType = dataType
				updateActiveSlider()
			end
		end

		widgets.registerEvent("InputChanged", function()
			if not Iris._started then
				return
			end
			updateActiveSlider()
		end)

		widgets.registerEvent("InputEnded", function(inputObject: InputObject)
			if not Iris._started then
				return
			end
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveSlider then
				AnyActiveSlider = false
				ActiveSlider = nil
				ActiveIndex = 0
				ActiveDataType = ""
			end
		end)

		local function generateField<T>(
			thisWidget: Types.Input<T>,
			index: number,
			componentSize: UDim2,
			dataType: InputDataTypes
		)
			local SliderField = Instance.new("TextButton")
			SliderField.Name = "SliderField" .. tostring(index)
			SliderField.AutomaticSize = Enum.AutomaticSize.Y
			SliderField.Size = componentSize
			SliderField.BackgroundColor3 = Iris._config.FrameBgColor
			SliderField.BackgroundTransparency = Iris._config.FrameBgTransparency
			SliderField.Text = ""
			SliderField.AutoButtonColor = false
			SliderField.LayoutOrder = index
			SliderField.ClipsDescendants = true

			widgets.applyFrameStyle(SliderField)
			widgets.applyTextStyle(SliderField)
			widgets.UISizeConstraint(SliderField, Vector2.xAxis)

			local OverlayText = Instance.new("TextLabel")
			OverlayText.Name = "OverlayText"
			OverlayText.Size = UDim2.fromScale(1, 1)
			OverlayText.BackgroundTransparency = 1
			OverlayText.BorderSizePixel = 0
			OverlayText.ZIndex = 10
			OverlayText.ClipsDescendants = true

			widgets.applyTextStyle(OverlayText)

			OverlayText.TextXAlignment = Enum.TextXAlignment.Center

			OverlayText.Parent = SliderField

			widgets.applyInteractionHighlights("Background", SliderField, SliderField, {
				Color = Iris._config.FrameBgColor,
				Transparency = Iris._config.FrameBgTransparency,
				HoveredColor = Iris._config.FrameBgHoveredColor,
				HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
				ActiveColor = Iris._config.FrameBgActiveColor,
				ActiveTransparency = Iris._config.FrameBgActiveTransparency,
			})

			local InputField = Instance.new("TextBox")
			InputField.Name = "InputField"
			InputField.Size = UDim2.fromScale(1, 1)
			InputField.BackgroundTransparency = 1
			InputField.ClearTextOnFocus = false
			InputField.TextTruncate = Enum.TextTruncate.AtEnd
			InputField.ClipsDescendants = true
			InputField.Visible = false

			widgets.applyFrameStyle(InputField, true)
			widgets.applyTextStyle(InputField)

			InputField.Parent = SliderField

			InputField.FocusLost:Connect(function()
				focusLost(thisWidget, InputField, index, dataType)
			end)

			InputField.Focused:Connect(function()
				-- this highlights the entire field
				InputField.CursorPosition = #InputField.Text + 1
				InputField.SelectionStart = 1

				thisWidget.state.editingText:set(index)
			end)

			widgets.applyButtonDown(SliderField, function()
				SliderMouseDown(thisWidget :: any, dataType, index)
			end)

			local GrabBar = Instance.new("Frame")
			GrabBar.Name = "GrabBar"
			GrabBar.AnchorPoint = Vector2.new(0.5, 0.5)
			GrabBar.Position = UDim2.fromScale(0, 0.5)
			GrabBar.BackgroundColor3 = Iris._config.SliderGrabColor
			GrabBar.Transparency = Iris._config.SliderGrabTransparency
			GrabBar.BorderSizePixel = 0
			GrabBar.ZIndex = 5

			widgets.applyInteractionHighlights("Background", SliderField, GrabBar, {
				Color = Iris._config.SliderGrabColor,
				Transparency = Iris._config.SliderGrabTransparency,
				HoveredColor = Iris._config.SliderGrabColor,
				HoveredTransparency = Iris._config.SliderGrabTransparency,
				ActiveColor = Iris._config.SliderGrabActiveColor,
				ActiveTransparency = Iris._config.SliderGrabActiveTransparency,
			})

			if Iris._config.GrabRounding > 0 then
				widgets.UICorner(GrabBar, Iris._config.GrabRounding)
			end

			widgets.UISizeConstraint(GrabBar, Vector2.new(Iris._config.GrabMinSize, 0))

			GrabBar.Parent = SliderField

			return SliderField
		end

		function generateSliderScalar<T>(dataType: InputDataTypes, components: number, defaultValue: T)
			local input = generateAbstract("Slider", dataType, components, defaultValue)

			return widgets.extend(input, {
				Generate = function(thisWidget: Types.Input<T>)
					local Slider = Instance.new("Frame")
					Slider.Name = "Iris_Slider" .. dataType
					Slider.AutomaticSize = Enum.AutomaticSize.Y
					Slider.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
					Slider.BackgroundTransparency = 1
					Slider.BorderSizePixel = 0

					widgets.UIListLayout(
						Slider,
						Enum.FillDirection.Horizontal,
						UDim.new(0, Iris._config.ItemInnerSpacing.X)
					).VerticalAlignment =
						Enum.VerticalAlignment.Center

					-- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
					-- for the final field, we make sure it's flush by calculating the space avaiable for it. This only makes the Vector2 box
					-- 4 pixels shorter, all for the sake of flush.
					local componentWidth = UDim.new(
						Iris._config.ContentWidth.Scale / components,
						(Iris._config.ContentWidth.Offset - (Iris._config.ItemInnerSpacing.X * (components - 1)))
							/ components
					)
					local totalWidth = UDim.new(
						componentWidth.Scale * (components - 1),
						(componentWidth.Offset * (components - 1))
							+ (Iris._config.ItemInnerSpacing.X * (components - 1))
					)
					local lastComponentWidth = Iris._config.ContentWidth - totalWidth

					for index = 1, components do
						generateField(
							thisWidget,
							index,
							if index == components
								then UDim2.new(lastComponentWidth, Iris._config.ContentHeight)
								else UDim2.new(componentWidth, Iris._config.ContentHeight),
							dataType
						).Parent =
							Slider
					end

					local TextLabel = Instance.new("TextLabel")
					TextLabel.Name = "TextLabel"
					TextLabel.AutomaticSize = Enum.AutomaticSize.XY
					TextLabel.BackgroundTransparency = 1
					TextLabel.BorderSizePixel = 0
					TextLabel.LayoutOrder = 5

					widgets.applyTextStyle(TextLabel)

					TextLabel.Parent = Slider

					return Slider
				end,
				UpdateState = function(thisWidget: Types.Input<T>)
					local Slider = thisWidget.Instance :: Frame

					for index = 1, components do
						local SliderField = Slider:FindFirstChild("SliderField" .. tostring(index)) :: TextButton
						local InputField: TextBox = SliderField.InputField
						local OverlayText: TextLabel = SliderField.OverlayText
						local GrabBar: Frame = SliderField.GrabBar

						local value = getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments :: any)
						local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
						if thisWidget.arguments.Prefix then
							format = thisWidget.arguments.Prefix[index] .. format
						end

						OverlayText.Text = string.format(format, value)
						InputField.Text = tostring(value)

						local increment = thisWidget.arguments.Increment
								and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments :: any)
							or defaultIncrements[dataType][index]
						local min = thisWidget.arguments.Min
								and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments :: any)
							or defaultMin[dataType][index]
						local max = thisWidget.arguments.Max
								and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments :: any)
							or defaultMax[dataType][index]

						local SliderWidth = SliderField.AbsoluteSize.X
						local PaddedWidth = SliderWidth - GrabBar.AbsoluteSize.X
						local Ratio = (value - min) / (max - min)
						local Positions = math.floor((max - min) / increment)
						local ClampedRatio = math.clamp(math.floor((Ratio * Positions)) / Positions, 0, 1)
						local PaddedRatio = ((PaddedWidth / SliderWidth) * ClampedRatio)
							+ ((1 - (PaddedWidth / SliderWidth)) / 2)

						GrabBar.Position = UDim2.fromScale(PaddedRatio, 0.5)

						if thisWidget.state.editingText.value == index then
							InputField.Visible = true
							OverlayText.Visible = false
							GrabBar.Visible = false
							InputField:CaptureFocus()
						else
							InputField.Visible = false
							OverlayText.Visible = true
							GrabBar.Visible = true
						end
					end
				end,
			})
		end

		function generateEnumSliderScalar(enum: Enum, item: EnumItem)
			local input: Types.WidgetClass = generateSliderScalar("Enum", 1, item.Value)
			local valueToName = { string }

			for _, enumItem in enum:GetEnumItems() do
				valueToName[enumItem.Value] = enumItem.Name
			end

			return widgets.extend(input, {
				Args = {
					["Text"] = 1,
				},
				Update = function(thisWidget: Types.InputEnum)
					local Input = thisWidget.Instance :: GuiObject
					local TextLabel: TextLabel = Input.TextLabel
					TextLabel.Text = thisWidget.arguments.Text or "Input Enum"

					thisWidget.arguments.Increment = 1
					thisWidget.arguments.Min = 0
					thisWidget.arguments.Max = #enum:GetEnumItems() - 1

					local SliderField = Input:FindFirstChild("SliderField1") :: TextButton
					local GrabBar: Frame = SliderField.GrabBar

					local grabScaleSize = 1 / math.floor(#enum:GetEnumItems())

					GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
				end,
				GenerateState = function(thisWidget: Types.InputEnum)
					if thisWidget.state.number == nil then
						thisWidget.state.number = Iris._widgetState(thisWidget, "number", item.Value)
					end
					if thisWidget.state.enumItem == nil then
						thisWidget.state.enumItem = Iris._widgetState(thisWidget, "enumItem", item)
					end
					if thisWidget.state.editingText == nil then
						thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", false)
					end
				end,
			})
		end
	end

	do
		local inputNum: Types.WidgetClass = generateInputScalar("Num", 1, 0)
		inputNum.Args["NoButtons"] = 6
		Iris.WidgetConstructor("InputNum", inputNum)
	end
	Iris.WidgetConstructor("InputVector2", generateInputScalar("Vector2", 2, Vector2.zero))
	Iris.WidgetConstructor("InputVector3", generateInputScalar("Vector3", 3, Vector3.zero))
	Iris.WidgetConstructor("InputUDim", generateInputScalar("UDim", 2, UDim.new()))
	Iris.WidgetConstructor("InputUDim2", generateInputScalar("UDim2", 4, UDim2.new()))
	Iris.WidgetConstructor("InputRect", generateInputScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

	Iris.WidgetConstructor("DragNum", generateDragScalar("Num", 1, 0))
	Iris.WidgetConstructor("DragVector2", generateDragScalar("Vector2", 2, Vector2.zero))
	Iris.WidgetConstructor("DragVector3", generateDragScalar("Vector3", 3, Vector3.zero))
	Iris.WidgetConstructor("DragUDim", generateDragScalar("UDim", 2, UDim.new()))
	Iris.WidgetConstructor("DragUDim2", generateDragScalar("UDim2", 4, UDim2.new()))
	Iris.WidgetConstructor("DragRect", generateDragScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

	Iris.WidgetConstructor("InputColor3", generateColorDragScalar("Color3", Color3.fromRGB(0, 0, 0)))
	Iris.WidgetConstructor("InputColor4", generateColorDragScalar("Color4", Color3.fromRGB(0, 0, 0), 0))

	Iris.WidgetConstructor("SliderNum", generateSliderScalar("Num", 1, 0))
	Iris.WidgetConstructor("SliderVector2", generateSliderScalar("Vector2", 2, Vector2.zero))
	Iris.WidgetConstructor("SliderVector3", generateSliderScalar("Vector3", 3, Vector3.zero))
	Iris.WidgetConstructor("SliderUDim", generateSliderScalar("UDim", 2, UDim.new()))
	Iris.WidgetConstructor("SliderUDim2", generateSliderScalar("UDim2", 4, UDim2.new()))
	Iris.WidgetConstructor("SliderRect", generateSliderScalar("Rect", 4, Rect.new(0, 0, 0, 0)))
    -- Iris.WidgetConstructor("SliderEnum", generateSliderScalar("Enum", 4, 0))

    -- stylua: ignore
    Iris.WidgetConstructor("InputText", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["TextHint"] = 2,
            ["ReadOnly"] = 3,
            ["MultiLine"] = 4,
        },
        Events = {
            ["textChanged"] = {
                ["Init"] = function(thisWidget: Types.InputText)
                    thisWidget.lastTextChangedTick = 0
                end,
                ["Get"] = function(thisWidget: Types.InputText)
                    return thisWidget.lastTextChangedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.InputText)
            local InputText: Frame = Instance.new("Frame")
            InputText.Name = "Iris_InputText"
            InputText.AutomaticSize = Enum.AutomaticSize.Y
            InputText.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            InputText.BackgroundTransparency = 1
            InputText.BorderSizePixel = 0
            widgets.UIListLayout(InputText, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local InputField: TextBox = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.AutomaticSize = Enum.AutomaticSize.Y
            InputField.Size = UDim2.new(Iris._config.ContentWidth, Iris._config.ContentHeight)
            InputField.BackgroundColor3 = Iris._config.FrameBgColor
            InputField.BackgroundTransparency = Iris._config.FrameBgTransparency
            InputField.Text = ""
            InputField.TextYAlignment = Enum.TextYAlignment.Top
            InputField.PlaceholderColor3 = Iris._config.TextDisabledColor
            InputField.ClearTextOnFocus = false
            InputField.ClipsDescendants = true

            widgets.applyFrameStyle(InputField)
            widgets.applyTextStyle(InputField)
            widgets.UISizeConstraint(InputField, Vector2.xAxis) -- prevents sizes beaking when getting too small.
            -- InputField.UIPadding.PaddingLeft = UDim.new(0, Iris._config.ItemInnerSpacing.X)
            -- InputField.UIPadding.PaddingRight = UDim.new(0, 0)
            InputField.Parent = InputText

            InputField.FocusLost:Connect(function()
                thisWidget.state.text:set(InputField.Text)
                thisWidget.lastTextChangedTick = Iris._cycleTick + 1
            end)

            local frameHeight: number = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

            local TextLabel: TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = InputText

            return InputText
        end,
        GenerateState = function(thisWidget: Types.InputText)
            if thisWidget.state.text == nil then
                thisWidget.state.text = Iris._widgetState(thisWidget, "text", "")
            end
        end,
        Update = function(thisWidget: Types.InputText)
            local InputText = thisWidget.Instance :: Frame
            local TextLabel: TextLabel = InputText.TextLabel
            local InputField: TextBox = InputText.InputField

            TextLabel.Text = thisWidget.arguments.Text or "Input Text"
            InputField.PlaceholderText = thisWidget.arguments.TextHint or ""
            InputField.TextEditable = not thisWidget.arguments.ReadOnly
            InputField.MultiLine = thisWidget.arguments.MultiLine or false
        end,
        UpdateState = function(thisWidget: Types.InputText)
            local InputText = thisWidget.Instance :: Frame
            local InputField: TextBox = InputText.InputField
    
            InputField.Text = thisWidget.state.text.value
        end,
        Discard = function(thisWidget: Types.InputText)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end
