--!nocheck
local Types = require(script.Parent.iris_Types)

return function(Iris: Types.Iris)
	local showMainWindow = Iris.State(true)
	local showRecursiveWindow = Iris.State(false)
	local showRuntimeInfo = Iris.State(false)
	local showStyleEditor = Iris.State(false)
	local showWindowlessDemo = Iris.State(false)
	local showMainMenuBarWindow = Iris.State(false)
	local showDebugWindow = Iris.State(false)

	local showBackground = Iris.State(false)
	local backgroundColour = Iris.State(Color3.fromRGB(115, 140, 152))
	local backgroundTransparency = Iris.State(0)
	table.insert(Iris.Internal._initFunctions, function()
		local background = Instance.new("Frame")
		background.Name = "Background"
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = backgroundColour.value
		background.BackgroundTransparency = backgroundTransparency.value

		local widget
		if Iris._config.UseScreenGUIs then
			widget = Instance.new("ScreenGui")
			widget.Name = "Iris_Background"
			widget.IgnoreGuiInset = true
			widget.DisplayOrder = Iris._config.DisplayOrderOffset - 1
			widget.ScreenInsets = Enum.ScreenInsets.None
			widget.Enabled = true

			background.Parent = widget
		else
			background.ZIndex = Iris._config.DisplayOrderOffset - 1
			widget = background
		end

		backgroundColour:onChange(function(value: Color3)
			background.BackgroundColor3 = value
		end)
		backgroundTransparency:onChange(function(value: number)
			background.BackgroundTransparency = value
		end)

		showBackground:onChange(function(show: boolean)
			if show then
				widget.Parent = Iris.Internal.parentInstance
			else
				widget.Parent = nil
			end
		end)
	end)

	local function helpMarker(helpText: string)
		Iris.PushConfig({ TextColor = Iris._config.TextDisabledColor })
		local text = Iris.Text({ "(?)" })
		Iris.PopConfig()

		Iris.PushConfig({ ContentWidth = UDim.new(0, 350) })
		if text.hovered() then
			Iris.Tooltip({ helpText })
		end
		Iris.PopConfig()
	end

	local function textAndHelpMarker(text: string, helpText: string)
		Iris.SameLine()
		do
			Iris.Text({ text })
			helpMarker(helpText)
		end
		Iris.End()
	end

	-- shows each widgets functionality
	local widgetDemos = {
		Basic = function()
			Iris.Tree({ "Basic" })
			do
				Iris.SeparatorText({ "Basic" })

				local radioButtonState = Iris.State(1)
				Iris.Button({ "Button" })
				Iris.SmallButton({ "SmallButton" })
				Iris.Text({ "Text" })
				Iris.TextWrapped({ string.rep("Text Wrapped ", 5) })
				Iris.TextColored({ "Colored Text", Color3.fromRGB(255, 128, 0) })
				Iris.Text({
					`Rich Text: <b>bold text</b> <i>italic text</i> <u>underline text</u> <s>strikethrough text</s> <font color= "rgb(240, 40, 10)">red text</font> <font size="32">bigger text</font>`,
					true,
					nil,
					true,
				})

				Iris.SameLine()
				do
					Iris.RadioButton({ "Index '1'", 1 }, { index = radioButtonState })
					Iris.RadioButton({ "Index 'two'", "two" }, { index = radioButtonState })
					if Iris.RadioButton({ "Index 'false'", false }, { index = radioButtonState }).active() == false then
						if Iris.SmallButton({ "Select last" }).clicked() then
							radioButtonState:set(false)
						end
					end
				end
				Iris.End()

				Iris.Text({ "The Index is: " .. tostring(radioButtonState.value) })

				Iris.SeparatorText({ "Inputs" })

				Iris.InputNum({})
				Iris.DragNum({})
				Iris.SliderNum({})
			end
			Iris.End()
		end,

		Image = function()
			Iris.Tree({ "Image" })
			do
				Iris.SeparatorText({ "Image Controls" })

				local AssetState = Iris.State("rbxasset://textures/ui/common/robux.png")
				local SizeState = Iris.State(UDim2.fromOffset(100, 100))
				local RectState = Iris.State(Rect.new(0, 0, 0, 0))
				local ScaleTypeState = Iris.State(Enum.ScaleType.Stretch)
				local PixelatedCheckState = Iris.State(false)
				local PixelatedState = Iris.ComputedState(PixelatedCheckState, function(check)
					return check and Enum.ResamplerMode.Pixelated or Enum.ResamplerMode.Default
				end)

				local ImageColorState = Iris.State(Iris._config.ImageColor)
				local ImageTransparencyState = Iris.State(Iris._config.ImageTransparency)
				Iris.InputColor4({ "Image Tint" }, { color = ImageColorState, transparency = ImageTransparencyState })

				Iris.Combo({ "Asset" }, { index = AssetState })
				do
					Iris.Selectable(
						{ "Robux Small", "rbxasset://textures/ui/common/robux.png" },
						{ index = AssetState }
					)
					Iris.Selectable(
						{ "Robux Large", "rbxasset://textures//ui/common/robux@3x.png" },
						{ index = AssetState }
					)
					Iris.Selectable(
						{ "Loading Texture", "rbxasset://textures//loading/darkLoadingTexture.png" },
						{ index = AssetState }
					)
					Iris.Selectable(
						{ "Hue-Saturation Gradient", "rbxasset://textures//TagEditor/huesatgradient.png" },
						{ index = AssetState }
					)
					Iris.Selectable(
						{ "famfamfam.png (WHY?)", "rbxasset://textures//TagEditor/famfamfam.png" },
						{ index = AssetState }
					)
				end
				Iris.End()

				Iris.SliderUDim2({ "Image Size", nil, nil, UDim2.new(1, 240, 1, 240) }, { number = SizeState })
				Iris.SliderRect({ "Image Rect", nil, nil, Rect.new(256, 256, 256, 256) }, { number = RectState })

				Iris.Combo({ "Scale Type" }, { index = ScaleTypeState })
				do
					Iris.Selectable({ "Stretch", Enum.ScaleType.Stretch }, { index = ScaleTypeState })
					Iris.Selectable({ "Fit", Enum.ScaleType.Fit }, { index = ScaleTypeState })
					Iris.Selectable({ "Crop", Enum.ScaleType.Crop }, { index = ScaleTypeState })
				end

				Iris.End()
				Iris.Checkbox({ "Pixelated" }, { isChecked = PixelatedCheckState })

				Iris.PushConfig({
					ImageColor = ImageColorState:get(),
					ImageTransparency = ImageTransparencyState:get(),
				})
				Iris.Image({
					AssetState:get(),
					SizeState:get(),
					RectState:get(),
					ScaleTypeState:get(),
					PixelatedState:get(),
				})
				Iris.PopConfig()

				Iris.SeparatorText({ "Tile" })
				local TileState = Iris.State(UDim2.fromScale(0.5, 0.5))
				Iris.SliderUDim2({ "Tile Size", nil, nil, UDim2.new(1, 240, 1, 240) }, { number = TileState })

				Iris.PushConfig({
					ImageColor = ImageColorState:get(),
					ImageTransparency = ImageTransparencyState:get(),
				})
				Iris.Image({
					"rbxasset://textures/grid2.png",
					SizeState:get(),
					nil,
					Enum.ScaleType.Tile,
					PixelatedState:get(),
					TileState:get(),
				})
				Iris.PopConfig()

				Iris.SeparatorText({ "Slice" })
				local SliceScaleState = Iris.State(1)
				Iris.SliderNum({ "Image Slice Scale", 0.1, 0.1, 5 }, { number = SliceScaleState })

				Iris.PushConfig({
					ImageColor = ImageColorState:get(),
					ImageTransparency = ImageTransparencyState:get(),
				})
				Iris.Image({
					"rbxasset://textures/ui/chatBubble_blue_notify_bkg.png",
					SizeState:get(),
					nil,
					Enum.ScaleType.Slice,
					PixelatedState:get(),
					nil,
					Rect.new(12, 12, 56, 56),
					1,
				}, SliceScaleState:get())
				Iris.PopConfig()

				Iris.SeparatorText({ "Image Button" })
				local count = Iris.State(0)

				Iris.SameLine()
				do
					Iris.PushConfig({
						ImageColor = ImageColorState:get(),
						ImageTransparency = ImageTransparencyState:get(),
					})
					if
						Iris.ImageButton({
							"rbxasset://textures/AvatarCompatibilityPreviewer/add.png",
							UDim2.fromOffset(20, 20),
						}).clicked()
					then
						count:set(count.value + 1)
					end
					Iris.PopConfig()

					Iris.Text({ `Click count: {count.value}` })
				end
				Iris.End()
			end
			Iris.End()
		end,

		Selectable = function()
			Iris.Tree({ "Selectable" })
			do
				local sharedIndex = Iris.State(2)
				Iris.Selectable({ "Selectable #1", 1 }, { index = sharedIndex })
				Iris.Selectable({ "Selectable #2", 2 }, { index = sharedIndex })
				if Iris.Selectable({ "Double click Selectable", 3, true }, { index = sharedIndex }).doubleClicked() then
					sharedIndex:set(3)
				end

				Iris.Selectable({ "Impossible to select", 4, true }, { index = sharedIndex })
				if Iris.Button({ "Select last" }).clicked() then
					sharedIndex:set(4)
				end

				Iris.Selectable({ "Independent Selectable" })
			end
			Iris.End()
		end,

		Combo = function()
			Iris.Tree({ "Combo" })
			do
				Iris.PushConfig({ ContentWidth = UDim.new(1, -200) })
				local sharedComboIndex = Iris.State("No Selection")

				local NoPreview, NoButton
				Iris.SameLine()
				do
					NoPreview = Iris.Checkbox({ "No Preview" })
					NoButton = Iris.Checkbox({ "No Button" })
					if NoPreview.checked() and NoButton.isChecked.value == true then
						NoButton.isChecked:set(false)
					end
					if NoButton.checked() and NoPreview.isChecked.value == true then
						NoPreview.isChecked:set(false)
					end
				end
				Iris.End()

				Iris.Combo(
					{ "Basic Usage", NoButton.isChecked:get(), NoPreview.isChecked:get() },
					{ index = sharedComboIndex }
				)
				do
					Iris.Selectable({ "Select 1", "One" }, { index = sharedComboIndex })
					Iris.Selectable({ "Select 2", "Two" }, { index = sharedComboIndex })
					Iris.Selectable({ "Select 3", "Three" }, { index = sharedComboIndex })
				end
				Iris.End()

				Iris.ComboArray({ "Using ComboArray" }, { index = "No Selection" }, { "Red", "Green", "Blue" })

				local heightTestArray = {}
				for i = 1, 50 do
					table.insert(heightTestArray, tostring(i))
				end
				Iris.ComboArray({ "Height Test" }, { index = "1" }, heightTestArray)

				local sharedComboIndex2 = Iris.State("7 AM")

				Iris.Combo({ "Combo with Inner widgets" }, { index = sharedComboIndex2 })
				do
					Iris.Tree({ "Morning Shifts" })
					do
						Iris.Selectable({ "Shift at 7 AM", "7 AM" }, { index = sharedComboIndex2 })
						Iris.Selectable({ "Shift at 11 AM", "11 AM" }, { index = sharedComboIndex2 })
						Iris.Selectable({ "Shift at 3 PM", "3 PM" }, { index = sharedComboIndex2 })
					end
					Iris.End()
					Iris.Tree({ "Night Shifts" })
					do
						Iris.Selectable({ "Shift at 6 PM", "6 PM" }, { index = sharedComboIndex2 })
						Iris.Selectable({ "Shift at 9 PM", "9 PM" }, { index = sharedComboIndex2 })
					end
					Iris.End()
				end
				Iris.End()

				local ComboEnum = Iris.ComboEnum(
					{ "Using ComboEnum" },
					{ index = Enum.UserInputState.Begin },
					Enum.UserInputState
				)
				Iris.Text({ "Selected: " .. ComboEnum.index:get().Name })
				Iris.PopConfig()
			end
			Iris.End()
		end,

		Tree = function()
			Iris.Tree({ "Trees" })
			do
				Iris.Tree({ "Tree using SpanAvailWidth", true })
				do
					helpMarker(
						"SpanAvailWidth determines if the Tree is selectable from its entire with, or only the text area"
					)
				end
				Iris.End()

				local tree1 = Iris.Tree({ "Tree with Children" })
				do
					Iris.Text({ "Im inside the first tree!" })
					Iris.Button({ "Im a button inside the first tree!" })
					Iris.Tree({ "Im a tree inside the first tree!" })
					do
						Iris.Text({ "I am the innermost text!" })
					end
					Iris.End()
				end
				Iris.End()

				Iris.Checkbox({ "Toggle above tree" }, { isChecked = tree1.state.isUncollapsed })
			end
			Iris.End()
		end,

		CollapsingHeader = function()
			Iris.Tree({ "Collapsing Headers" })
			do
				Iris.CollapsingHeader({ "A header" })
				do
					Iris.Text({ "This is under the first header!" })
				end
				Iris.End()

				local secondHeader = Iris.State(false)
				Iris.CollapsingHeader({ "Another header" }, { isUncollapsed = secondHeader })
				do
					if Iris.Button({ "Shhh... secret button!" }).clicked() then
						secondHeader:set(true)
					end
				end
				Iris.End()
			end
			Iris.End()
		end,

		Group = function()
			Iris.Tree({ "Groups" })
			do
				Iris.SameLine()
				do
					Iris.Group()
					do
						Iris.Text({ "I am in group A" })
						Iris.Button({ "Im also in A" })
					end
					Iris.End()

					Iris.Separator()

					Iris.Group()
					do
						Iris.Text({ "I am in group B" })
						Iris.Button({ "Im also in B" })
						Iris.Button({ "Also group B" })
					end
					Iris.End()
				end
				Iris.End()
			end
			Iris.End()
		end,

		Tab = function()
			Iris.Tree({ "Tabs" })
			do
				Iris.Tree({ "Simple" })
				do
					Iris.TabBar()
					do
						Iris.Tab({ "Apples" })
						do
							Iris.Text({ "Who loves apples?" })
						end
						Iris.End()
						Iris.Tab({ "Broccoli" })
						do
							Iris.Text({ "And what about broccoli?" })
						end
						Iris.End()
						Iris.Tab({ "Carrots" })
						do
							Iris.Text({ "But carrots are the best." })
						end
						Iris.End()
					end
					Iris.End()
					Iris.Separator()
					Iris.Text({ "Very important questions." })
				end
				Iris.End()

				Iris.Tree({ "Closable" })
				do
					local a = Iris.State(true)
					local b = Iris.State(true)
					local c = Iris.State(true)

					Iris.TabBar()
					do
						Iris.Tab({ "🍎", true }, { isOpened = a })
						do
							Iris.Text({ "Who loves apples?" })
							if Iris.Button({ "I don't like apples." }).clicked() then
								a:set(false)
							end
						end
						Iris.End()
						Iris.Tab({ "🥦", true }, { isOpened = b })
						do
							Iris.Text({ "And what about broccoli?" })
							if Iris.Button({ "Not for me." }).clicked() then
								b:set(false)
							end
						end
						Iris.End()
						Iris.Tab({ "🥕", true }, { isOpened = c })
						do
							Iris.Text({ "But carrots are the best." })
							if Iris.Button({ "I disagree with you." }).clicked() then
								c:set(false)
							end
						end
						Iris.End()
					end
					Iris.End()
					Iris.Separator()
					if Iris.Button({ "Actually, let me reconsider it." }).clicked() then
						a:set(true)
						b:set(true)
						c:set(true)
					end
				end
				Iris.End()
			end
			Iris.End()
		end,

		Indent = function()
			Iris.Tree({ "Indents" })
			Iris.Text({ "Not Indented" })
			Iris.Indent()
			do
				Iris.Text({ "Indented" })
				Iris.Indent({ 7 })
				do
					Iris.Text({ "Indented by 7 more pixels" })
					Iris.End()

					Iris.Indent({ -7 })
					do
						Iris.Text({ "Indented by 7 less pixels" })
					end
					Iris.End()
				end
				Iris.End()
			end
			Iris.End()
		end,

		Input = function()
			Iris.Tree({ "Input" })
			do
				local NoField, NoButtons, Min, Max, Increment, Format =
					Iris.State(false),
					Iris.State(false),
					Iris.State(0),
					Iris.State(100),
					Iris.State(1),
					Iris.State("%d")

				Iris.PushConfig({ ContentWidth = UDim.new(1, -120) })
				local InputNum = Iris.InputNum({
					[Iris.Args.InputNum.Text] = "Input Number",
					-- [Iris.Args.InputNum.NoField] = NoField.value,
					[Iris.Args.InputNum.NoButtons] = NoButtons.value,
					[Iris.Args.InputNum.Min] = Min.value,
					[Iris.Args.InputNum.Max] = Max.value,
					[Iris.Args.InputNum.Increment] = Increment.value,
					[Iris.Args.InputNum.Format] = { Format.value },
				})
				Iris.PopConfig()
				Iris.Text({ "The Value is: " .. InputNum.number.value })
				if Iris.Button({ "Randomize Number" }).clicked() then
					InputNum.number:set(math.random(1, 99))
				end
				local NoFieldCheckbox = Iris.Checkbox({ "NoField" }, { isChecked = NoField })
				local NoButtonsCheckbox = Iris.Checkbox({ "NoButtons" }, { isChecked = NoButtons })
				if NoFieldCheckbox.checked() and NoButtonsCheckbox.isChecked.value == true then
					NoButtonsCheckbox.isChecked:set(false)
				end
				if NoButtonsCheckbox.checked() and NoFieldCheckbox.isChecked.value == true then
					NoFieldCheckbox.isChecked:set(false)
				end

				Iris.PushConfig({ ContentWidth = UDim.new(1, -120) })
				Iris.InputVector2({ "InputVector2" })
				Iris.InputVector3({ "InputVector3" })
				Iris.InputUDim({ "InputUDim" })
				Iris.InputUDim2({ "InputUDim2" })
				local UseFloats = Iris.State(false)
				local UseHSV = Iris.State(false)
				local sharedColor = Iris.State(Color3.new())
				local transparency = Iris.State(0)
				Iris.SliderNum({ "Transparency", 0.01, 0, 1 }, { number = transparency })
				Iris.InputColor3({ "InputColor3", UseFloats:get(), UseHSV:get() }, { color = sharedColor })
				Iris.InputColor4(
					{ "InputColor4", UseFloats:get(), UseHSV:get() },
					{ color = sharedColor, transparency = transparency }
				)
				Iris.SameLine()
				Iris.Text({ `#{sharedColor:get():ToHex()}` })
				Iris.Checkbox({ "Use Floats" }, { isChecked = UseFloats })
				Iris.Checkbox({ "Use HSV" }, { isChecked = UseHSV })
				Iris.End()

				Iris.PopConfig()

				Iris.Separator()

				Iris.SameLine()
				do
					Iris.Text({ "Slider Numbers" })
					helpMarker("ctrl + click slider number widgets to input a number")
				end
				Iris.End()
				Iris.PushConfig({ ContentWidth = UDim.new(1, -120) })
				Iris.SliderNum({ "Slide Int", 1, 1, 8 })
				Iris.SliderNum({ "Slide Float", 0.01, 0, 100 })
				Iris.SliderNum({ "Small Numbers", 0.001, -2, 1, "%f radians" })
				Iris.SliderNum({ "Odd Ranges", 0.001, -math.pi, math.pi, "%f radians" })
				Iris.SliderNum({ "Big Numbers", 1e4, 1e5, 1e7 })
				Iris.SliderNum({ "Few Numbers", 1, 0, 3 })
				Iris.PopConfig()

				Iris.Separator()

				Iris.SameLine()
				do
					Iris.Text({ "Drag Numbers" })
					helpMarker(
						"ctrl + click or double click drag number widgets to input a number, hold shift/alt while dragging to increase/decrease speed"
					)
				end
				Iris.End()
				Iris.PushConfig({ ContentWidth = UDim.new(1, -120) })
				Iris.DragNum({ "Drag Int" })
				Iris.DragNum({ "Slide Float", 0.001, -10, 10 })
				Iris.DragNum({ "Percentage", 1, 0, 100, "%d %%" })
				Iris.PopConfig()
			end
			Iris.End()
		end,

		InputText = function()
			Iris.Tree({ "Input Text" })
			do
				local InputText = Iris.InputText({ "Input Text Test", "Input Text here" })
				Iris.Text({ "The text is: " .. InputText.text.value })
			end
			Iris.End()
		end,

		MultiInput = function()
			Iris.Tree({ "Multi-Component Input" })
			do
				local sharedVector2 = Iris.State(Vector2.new())
				local sharedVector3 = Iris.State(Vector3.new())
				local sharedUDim = Iris.State(UDim.new())
				local sharedUDim2 = Iris.State(UDim2.new())
				local sharedColor3 = Iris.State(Color3.new())
				local SharedRect = Iris.State(Rect.new(0, 0, 0, 0))

				Iris.SeparatorText({ "Input" })

				Iris.InputVector2({}, { number = sharedVector2 })
				Iris.InputVector3({}, { number = sharedVector3 })
				Iris.InputUDim({}, { number = sharedUDim })
				Iris.InputUDim2({}, { number = sharedUDim2 })
				Iris.InputRect({}, { number = SharedRect })

				Iris.SeparatorText({ "Drag" })

				Iris.DragVector2({}, { number = sharedVector2 })
				Iris.DragVector3({}, { number = sharedVector3 })
				Iris.DragUDim({}, { number = sharedUDim })
				Iris.DragUDim2({}, { number = sharedUDim2 })
				Iris.DragRect({}, { number = SharedRect })

				Iris.SeparatorText({ "Slider" })

				Iris.SliderVector2({}, { number = sharedVector2 })
				Iris.SliderVector3({}, { number = sharedVector3 })
				Iris.SliderUDim({}, { number = sharedUDim })
				Iris.SliderUDim2({}, { number = sharedUDim2 })
				Iris.SliderRect({}, { number = SharedRect })

				Iris.SeparatorText({ "Color" })

				Iris.InputColor3({}, { color = sharedColor3 })
				Iris.InputColor4({}, { color = sharedColor3 })
			end
			Iris.End()
		end,

		Tooltip = function()
			Iris.PushConfig({ ContentWidth = UDim.new(0, 250) })
			Iris.Tree({ "Tooltip" })
			do
				if Iris.Text({ "Hover over me to reveal a tooltip" }).hovered() then
					Iris.Tooltip({ "I am some helpful tooltip text" })
				end
				local dynamicText = Iris.State("Hello ")
				local numRepeat = Iris.State(1)
				if Iris.InputNum({ "# of repeat", 1, 1, 50 }, { number = numRepeat }).numberChanged() then
					dynamicText:set(string.rep("Hello ", numRepeat:get()))
				end
				if Iris.Checkbox({ "Show dynamic text tooltip" }).state.isChecked.value then
					Iris.Tooltip({ dynamicText:get() })
				end
			end
			Iris.End()
			Iris.PopConfig()
		end,

		Plotting = function()
			Iris.Tree({ "Plotting" })
			do
				Iris.SeparatorText({ "Progress" })
				local curTime = os.clock() * 15

				local Progress = Iris.State(0)
				-- formula to cycle between 0 and 100 linearly
				local newValue = math.clamp((math.abs(curTime % 100 - 50)) - 7.5, 0, 35) / 35
				Progress:set(newValue)

				Iris.ProgressBar({ "Progress Bar" }, { progress = Progress })
				Iris.ProgressBar(
					{ "Progress Bar", `{math.floor(Progress:get() * 1753)}/1753` },
					{ progress = Progress }
				)

				Iris.SeparatorText({ "Graphs" })

				do
					local ValueState = Iris.State({ 0.5, 0.8, 0.2, 0.9, 0.1, 0.6, 0.4, 0.7, 0.3, 0.0 })

					Iris.PlotHistogram({ "Histogram", 100, 0, 1, "random" }, { values = ValueState })
					Iris.PlotLines({ "Lines", 100, 0, 1, "random" }, { values = ValueState })
				end

				do
					local FunctionState = Iris.State("Cos")
					local SampleState = Iris.State(37)
					local BaseLineState = Iris.State(0)
					local ValueState = Iris.State({})
					local TimeState = Iris.State(0)

					local Animated = Iris.Checkbox({ "Animate" })
					local plotFunc = Iris.ComboArray(
						{ "Plotting Function" },
						{ index = FunctionState },
						{ "Sin", "Cos", "Tan", "Saw" }
					)
					local samples = Iris.SliderNum({ "Samples", 1, 1, 145, "%d samples" }, { number = SampleState })
					if Iris.SliderNum({ "Baseline", 0.1, -1, 1 }, { number = BaseLineState }).numberChanged() then
						ValueState:set(ValueState.value, true)
					end

					if
						Animated.state.isChecked.value
						or plotFunc.closed()
						or samples.numberChanged()
						or #ValueState.value == 0
					then
						if Animated.state.isChecked.value then
							TimeState:set(TimeState.value + Iris.Internal._deltaTime)
						end
						local offset = math.floor(TimeState.value * 30) - 1
						local func = FunctionState.value
						table.clear(ValueState.value)
						for i = 1, SampleState.value do
							if func == "Sin" then
								ValueState.value[i] = math.sin(math.rad(5 * (i + offset)))
							elseif func == "Cos" then
								ValueState.value[i] = math.cos(math.rad(5 * (i + offset)))
							elseif func == "Tan" then
								ValueState.value[i] = math.tan(math.rad(5 * (i + offset)))
							elseif func == "Saw" then
								ValueState.value[i] = if (i % 2) == (offset % 2) then 1 else -1
							end
						end

						ValueState:set(ValueState.value, true)
					end

					Iris.PlotHistogram({ "Histogram", 100, -1, 1, "", BaseLineState:get() }, { values = ValueState })
					Iris.PlotLines({ "Lines", 100, -1, 1 }, { values = ValueState })
				end
			end
			Iris.End()
		end,
	}
	local widgetDemosOrder = {
		"Basic",
		"Image",
		"Selectable",
		"Combo",
		"Tree",
		"CollapsingHeader",
		"Group",
		"Tab",
		"Indent",
		"Input",
		"MultiInput",
		"InputText",
		"Tooltip",
		"Plotting",
	}

	local function recursiveTree()
		local theTree = Iris.Tree({ "Recursive Tree" })
		do
			if theTree.state.isUncollapsed.value then
				recursiveTree()
			end
		end
		Iris.End()
	end

	local function recursiveWindow(parentCheckboxState)
		local theCheckbox
		Iris.Window(
			{ "Recursive Window" },
			{ size = Iris.State(Vector2.new(175, 100)), isOpened = parentCheckboxState }
		)
		do
			theCheckbox = Iris.Checkbox({ "Recurse Again" })
		end
		Iris.End()

		if theCheckbox.isChecked.value then
			recursiveWindow(theCheckbox.isChecked)
		end
	end

	-- shows list of runtime widgets and states, including IDs. shows other info about runtime and can show widgets/state info in depth.
	local function runtimeInfo()
		local runtimeInfoWindow = Iris.Window({ "Runtime Info" }, { isOpened = showRuntimeInfo })
		do
			local lastVDOM = Iris.Internal._lastVDOM
			local states = Iris.Internal._states

			local numSecondsDisabled = Iris.State(3)
			local rollingDT = Iris.State(0)
			local lastT = Iris.State(os.clock())

			Iris.SameLine()
			do
				Iris.InputNum({
					[Iris.Args.InputNum.Text] = "",
					[Iris.Args.InputNum.Format] = "%d Seconds",
					[Iris.Args.InputNum.Max] = 10,
				}, { number = numSecondsDisabled })
				if Iris.Button({ "Disable" }).clicked() then
					Iris.Disabled = true
					task.delay(numSecondsDisabled:get(), function()
						Iris.Disabled = false
					end)
				end
			end
			Iris.End()

			local t = os.clock()
			local dt = t - lastT.value
			rollingDT.value += (dt - rollingDT.value) * 0.2
			lastT.value = t
			Iris.Text({ string.format("Average %.3f ms/frame (%.1f FPS)", rollingDT.value * 1000, 1 / rollingDT.value) })

			Iris.Text({
				string.format(
					"Window Position: (%d, %d), Window Size: (%d, %d)",
					runtimeInfoWindow.position.value.X,
					runtimeInfoWindow.position.value.Y,
					runtimeInfoWindow.size.value.X,
					runtimeInfoWindow.size.value.Y
				),
			})

			Iris.SameLine()
			do
				Iris.Text({ "Enter an ID to learn more about it." })
				helpMarker(
					"every widget and state has an ID which Iris tracks to remember which widget is which. below lists all widgets and states, with their respective IDs"
				)
			end
			Iris.End()

			Iris.PushConfig({ ItemWidth = UDim.new(1, -150) })
			local enteredText =
				Iris.InputText({ "ID field" }, { text = Iris.State(runtimeInfoWindow.ID) }).state.text.value
			Iris.PopConfig()

			Iris.Indent()
			do
				local enteredWidget = lastVDOM[enteredText]
				local enteredState = states[enteredText]
				if enteredWidget then
					Iris.Table({ 1 })
					Iris.Text({ string.format('The ID, "%s", is a widget', enteredText) })
					Iris.NextRow()

					Iris.Text({ string.format("Widget is type: %s", enteredWidget.type) })
					Iris.NextRow()

					Iris.Tree({ "Widget has Args:" }, { isUncollapsed = Iris.State(true) })
					for i, v in enteredWidget.arguments do
						Iris.Text({ i .. " - " .. tostring(v) })
					end
					Iris.End()
					Iris.NextRow()

					if enteredWidget.state then
						Iris.Tree({ "Widget has State:" }, { isUncollapsed = Iris.State(true) })
						for i, v in enteredWidget.state do
							Iris.Text({ i .. " - " .. tostring(v.value) })
						end
						Iris.End()
					end
					Iris.End()
				elseif enteredState then
					Iris.Table({ 1 })
					Iris.Text({ string.format('The ID, "%s", is a state', enteredText) })
					Iris.NextRow()

					Iris.Text({
						string.format(
							"Value is type: %s, Value = %s",
							typeof(enteredState.value),
							tostring(enteredState.value)
						),
					})
					Iris.NextRow()

					Iris.Tree({ "state has connected widgets:" }, { isUncollapsed = Iris.State(true) })
					for i, v in enteredState.ConnectedWidgets do
						Iris.Text({ i .. " - " .. v.type })
					end
					Iris.End()
					Iris.NextRow()

					Iris.Text({ string.format("state has: %d connected functions", #enteredState.ConnectedFunctions) })
					Iris.End()
				else
					Iris.Text({ string.format('The ID, "%s", is not a state or widget', enteredText) })
				end
			end
			Iris.End()

			if Iris.Tree({ "Widgets" }).state.isUncollapsed.value then
				local widgetCount = 0
				local widgetStr = ""
				for _, v in lastVDOM do
					widgetCount += 1
					widgetStr ..= "\n" .. v.ID .. " - " .. v.type
				end

				Iris.Text({ "Number of Widgets: " .. widgetCount })

				Iris.Text({ widgetStr })
			end
			Iris.End()

			if Iris.Tree({ "States" }).state.isUncollapsed.value then
				local stateCount = 0
				local stateStr = ""
				for i, v in states do
					stateCount += 1
					stateStr ..= "\n" .. i .. " - " .. tostring(v.value)
				end

				Iris.Text({ "Number of States: " .. stateCount })

				Iris.Text({ stateStr })
			end
			Iris.End()
		end
		Iris.End()
	end

	local function debugPanel()
		Iris.Window({ "Debug Panel" }, { isOpened = showDebugWindow })
		do
			Iris.CollapsingHeader({ "Widgets" })
			do
				Iris.SeparatorText({ "GuiService" })
				Iris.Text({ `GuiOffset: {Iris.Internal._utility.GuiOffset}` })
				Iris.Text({ `MouseOffset: {Iris.Internal._utility.MouseOffset}` })

				Iris.SeparatorText({ "UserInputService" })
				Iris.Text({ `MousePosition: {Iris.Internal._utility.UserInputService:GetMouseLocation()}` })
				Iris.Text({ `MouseLocation: {Iris.Internal._utility.getMouseLocation()}` })

				Iris.Text({
					`Left Control: {Iris.Internal._utility.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)}`,
				})
				Iris.Text({
					`Right Control: {Iris.Internal._utility.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)}`,
				})
			end
			Iris.End()
		end
		Iris.End()
	end

	local function recursiveMenu()
		if Iris.Menu({ "Recursive" }).state.isOpened.value then
			Iris.MenuItem({ "New", Enum.KeyCode.N, Enum.ModifierKey.Ctrl })
			Iris.MenuItem({ "Open", Enum.KeyCode.O, Enum.ModifierKey.Ctrl })
			Iris.MenuItem({ "Save", Enum.KeyCode.S, Enum.ModifierKey.Ctrl })
			Iris.Separator()
			Iris.MenuToggle({ "Autosave" })
			Iris.MenuToggle({ "Checked" })
			Iris.Separator()
			Iris.Menu({ "Options" })
			Iris.MenuItem({ "Red" })
			Iris.MenuItem({ "Yellow" })
			Iris.MenuItem({ "Green" })
			Iris.MenuItem({ "Blue" })
			Iris.Separator()
			recursiveMenu()
			Iris.End()
		end
		Iris.End()
	end

	local function mainMenuBar()
		Iris.MenuBar()
		do
			Iris.Menu({ "File" })
			do
				Iris.MenuItem({ "New", Enum.KeyCode.N, Enum.ModifierKey.Ctrl })
				Iris.MenuItem({ "Open", Enum.KeyCode.O, Enum.ModifierKey.Ctrl })
				Iris.MenuItem({ "Save", Enum.KeyCode.S, Enum.ModifierKey.Ctrl })
				recursiveMenu()
				if Iris.MenuItem({ "Quit", Enum.KeyCode.Q, Enum.ModifierKey.Alt }).clicked() then
					showMainWindow:set(false)
				end
			end
			Iris.End()

			Iris.Menu({ "Examples" })
			do
				Iris.MenuToggle({ "Recursive Window" }, { isChecked = showRecursiveWindow })
				Iris.MenuToggle({ "Windowless" }, { isChecked = showWindowlessDemo })
				Iris.MenuToggle({ "Main Menu Bar" }, { isChecked = showMainMenuBarWindow })
			end
			Iris.End()

			Iris.Menu({ "Tools" })
			do
				Iris.MenuToggle({ "Runtime Info" }, { isChecked = showRuntimeInfo })
				Iris.MenuToggle({ "Style Editor" }, { isChecked = showStyleEditor })
				Iris.MenuToggle({ "Debug Panel" }, { isChecked = showDebugWindow })
			end
			Iris.End()
		end
		Iris.End()
	end

	local function mainMenuBarExample()
		-- local screenSize = Iris.Internal._rootWidget.Instance.PseudoWindowScreenGui.AbsoluteSize
		-- Iris.Window(
		--     {[Iris.Args.Window.NoBackground] = true, [Iris.Args.Window.NoTitleBar] = true, [Iris.Args.Window.NoMove] = true, [Iris.Args.Window.NoResize] = true},
		--     {size = Iris.State(screenSize), position = Iris.State(Vector2.new(0, 0))}
		-- )

		mainMenuBar()

		--Iris.End()
	end

	-- allows users to edit state
	local styleEditor
	do
		styleEditor = function()
			local styleList = {
				{
					"Sizing",
					function()
						local UpdatedConfig = Iris.State({})

						Iris.SameLine()
						do
							if Iris.Button({ "Update" }).clicked() then
								Iris.UpdateGlobalConfig(UpdatedConfig.value)
								UpdatedConfig:set({})
							end

							helpMarker("Update the global config with these changes.")
						end
						Iris.End()

						local function SliderInput(input: string, arguments: { any })
							local Input =
								Iris[input](arguments, { number = Iris.WeakState(Iris._config[arguments[1]]) })
							if Input.numberChanged() then
								UpdatedConfig.value[arguments[1]] = Input.number:get()
							end
						end

						local function BooleanInput(arguments: { any })
							local Input =
								Iris.Checkbox(arguments, { isChecked = Iris.WeakState(Iris._config[arguments[1]]) })
							if Input.checked() or Input.unchecked() then
								UpdatedConfig.value[arguments[1]] = Input.isChecked:get()
							end
						end

						Iris.SeparatorText({ "Main" })
						SliderInput("SliderVector2", { "WindowPadding", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderVector2", { "WindowResizePadding", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderVector2", { "FramePadding", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderVector2", { "ItemSpacing", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderVector2", { "ItemInnerSpacing", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderVector2", { "CellPadding", nil, Vector2.zero, Vector2.new(20, 20) })
						SliderInput("SliderNum", { "IndentSpacing", 1, 0, 36 })
						SliderInput("SliderNum", { "ScrollbarSize", 1, 0, 20 })
						SliderInput("SliderNum", { "GrabMinSize", 1, 0, 20 })

						Iris.SeparatorText({ "Borders & Rounding" })
						SliderInput("SliderNum", { "FrameBorderSize", 0.1, 0, 1 })
						SliderInput("SliderNum", { "WindowBorderSize", 0.1, 0, 1 })
						SliderInput("SliderNum", { "PopupBorderSize", 0.1, 0, 1 })
						SliderInput("SliderNum", { "SeparatorTextBorderSize", 1, 0, 20 })
						SliderInput("SliderNum", { "FrameRounding", 1, 0, 12 })
						SliderInput("SliderNum", { "GrabRounding", 1, 0, 12 })
						SliderInput("SliderNum", { "PopupRounding", 1, 0, 12 })

						Iris.SeparatorText({ "Widgets" })
						SliderInput(
							"SliderVector2",
							{ "DisplaySafeAreaPadding", nil, Vector2.zero, Vector2.new(20, 20) }
						)
						SliderInput("SliderVector2", { "SeparatorTextPadding", nil, Vector2.zero, Vector2.new(36, 36) })
						SliderInput("SliderUDim", { "ItemWidth", nil, UDim.new(), UDim.new(1, 200) })
						SliderInput("SliderUDim", { "ContentWidth", nil, UDim.new(), UDim.new(1, 200) })
						SliderInput("SliderNum", { "ImageBorderSize", 1, 0, 12 })
						local TitleInput = Iris.ComboEnum(
							{ "WindowTitleAlign" },
							{ index = Iris.WeakState(Iris._config.WindowTitleAlign) },
							Enum.LeftRight
						)
						if TitleInput.closed() then
							UpdatedConfig.value["WindowTitleAlign"] = TitleInput.index:get()
						end
						BooleanInput({ "RichText" })
						BooleanInput({ "TextWrapped" })

						Iris.SeparatorText({ "Config" })
						BooleanInput({ "UseScreenGUIs" })
						SliderInput("DragNum", { "DisplayOrderOffset", 1, 0 })
						SliderInput("DragNum", { "ZIndexOffset", 1, 0 })
						SliderInput("SliderNum", { "MouseDoubleClickTime", 0.1, 0, 5 })
						SliderInput("SliderNum", { "MouseDoubleClickMaxDist", 0.1, 0, 20 })
					end,
				},
				{
					"Colors",
					function()
						local UpdatedConfig = Iris.State({})

						Iris.SameLine()
						do
							if Iris.Button({ "Update" }).clicked() then
								Iris.UpdateGlobalConfig(UpdatedConfig.value)
								UpdatedConfig:set({})
							end
							helpMarker("Update the global config with these changes.")
						end
						Iris.End()

						local color4s = {
							"Text",
							"TextDisabled",
							"WindowBg",
							"PopupBg",
							"Border",
							"BorderActive",
							"ScrollbarGrab",
							"TitleBg",
							"TitleBgActive",
							"TitleBgCollapsed",
							"MenubarBg",
							"FrameBg",
							"FrameBgHovered",
							"FrameBgActive",
							"Button",
							"ButtonHovered",
							"ButtonActive",
							"Image",
							"SliderGrab",
							"SliderGrabActive",
							"Header",
							"HeaderHovered",
							"HeaderActive",
							"SelectionImageObject",
							"SelectionImageObjectBorder",
							"TableBorderStrong",
							"TableBorderLight",
							"TableRowBg",
							"TableRowBgAlt",
							"NavWindowingHighlight",
							"NavWindowingDimBg",
							"Separator",
							"CheckMark",
						}

						for _, vColor in color4s do
							local Input = Iris.InputColor4({ vColor }, {
								color = Iris.WeakState(Iris._config[vColor .. "Color"]),
								transparency = Iris.WeakState(Iris._config[vColor .. "Transparency"]),
							})
							if Input.numberChanged() then
								UpdatedConfig.value[vColor .. "Color"] = Input.color:get()
								UpdatedConfig.value[vColor .. "Transparency"] = Input.transparency:get()
							end
						end
					end,
				},
				{
					"Fonts",
					function()
						local UpdatedConfig = Iris.State({})

						Iris.SameLine()
						do
							if Iris.Button({ "Update" }).clicked() then
								Iris.UpdateGlobalConfig(UpdatedConfig.value)
								UpdatedConfig:set({})
							end

							helpMarker("Update the global config with these changes.")
						end
						Iris.End()

						local fonts: { [string]: Font } = {
							["Code (default)"] = Font.fromEnum(Enum.Font.Code),
							["Ubuntu (template)"] = Font.fromEnum(Enum.Font.Ubuntu),
							["Arial"] = Font.fromEnum(Enum.Font.Arial),
							["Highway"] = Font.fromEnum(Enum.Font.Highway),
							["Roboto"] = Font.fromEnum(Enum.Font.Roboto),
							["Roboto Mono"] = Font.fromEnum(Enum.Font.RobotoMono),
							["Noto Sans"] = Font.new("rbxassetid://12187370747"),
							["Builder Sans"] = Font.fromEnum(Enum.Font.BuilderSans),
							["Builder Mono"] = Font.new("rbxassetid://16658246179"),
							["Sono"] = Font.new("rbxassetid://12187374537"),
						}

						Iris.Text({
							`Current Font: {Iris._config.TextFont.Family} Weight: {Iris._config.TextFont.Weight} Style: {Iris._config.TextFont.Style}`,
						})
						Iris.SeparatorText({ "Size" })

						local TextSize = Iris.SliderNum(
							{ "Font Size", 1, 4, 20 },
							{ number = Iris.WeakState(Iris._config.TextSize) }
						)
						if TextSize.numberChanged() then
							UpdatedConfig.value["TextSize"] = TextSize.state.number:get()
						end

						Iris.SeparatorText({ "Properties" })

						local TextFont = Iris.WeakState(Iris._config.TextFont.Family)
						local FontWeight = Iris.ComboEnum(
							{ "Font Weight" },
							{ index = Iris.WeakState(Iris._config.TextFont.Weight) },
							Enum.FontWeight
						)
						local FontStyle = Iris.ComboEnum(
							{ "Font Style" },
							{ index = Iris.WeakState(Iris._config.TextFont.Style) },
							Enum.FontStyle
						)

						Iris.SeparatorText({ "Fonts" })
						for name, font in fonts do
							font = Font.new(font.Family, FontWeight.state.index.value, FontStyle.state.index.value)
							Iris.SameLine()
							do
								Iris.PushConfig({
									TextFont = font,
								})

								if
									Iris.Selectable(
										{ `{name} | "The quick brown fox jumps over the lazy dog."`, font.Family },
										{ index = TextFont }
									).selected()
								then
									UpdatedConfig.value["TextFont"] = font
								end
								Iris.PopConfig()
							end
							Iris.End()
						end
					end,
				},
			}

			Iris.Window({ "Style Editor" }, { isOpened = showStyleEditor })
			do
				Iris.Text({ "Customize the look of Iris in realtime." })

				local ThemeState = Iris.State("Dark Theme")
				if Iris.ComboArray({ "Theme" }, { index = ThemeState }, { "Dark Theme", "Light Theme" }).closed() then
					if ThemeState.value == "Dark Theme" then
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorDark)
					elseif ThemeState.value == "Light Theme" then
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorLight)
					end
				end

				local SizeState = Iris.State("Classic Size")
				if Iris.ComboArray({ "Size" }, { index = SizeState }, { "Classic Size", "Larger Size" }).closed() then
					if SizeState.value == "Classic Size" then
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeDefault)
					elseif SizeState.value == "Larger Size" then
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeClear)
					end
				end

				Iris.SameLine()
				do
					if Iris.Button({ "Revert" }).clicked() then
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorDark)
						Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeDefault)
						ThemeState:set("Dark Theme")
						SizeState:set("Classic Size")
					end

					helpMarker("Reset Iris to the default theme and size.")
				end
				Iris.End()

				Iris.TabBar()
				do
					for i, v in ipairs(styleList) do
						Iris.Tab({ v[1] })
						do
							styleList[i][2]()
						end
						Iris.End()
					end
				end
				Iris.End()

				Iris.Separator()
			end
			Iris.End()
		end
	end

	local function widgetEventInteractivity()
		Iris.CollapsingHeader({ "Widget Event Interactivity" })
		do
			local clickCount = Iris.State(0)
			if Iris.Button({ "Click to increase Number" }).clicked() then
				clickCount:set(clickCount:get() + 1)
			end
			Iris.Text({ "The Number is: " .. clickCount:get() })

			Iris.Separator()

			local showEventText = Iris.State(false)
			local selectedEvent = Iris.State("clicked")

			Iris.SameLine()
			do
				Iris.RadioButton({ "clicked", "clicked" }, { index = selectedEvent })
				Iris.RadioButton({ "rightClicked", "rightClicked" }, { index = selectedEvent })
				Iris.RadioButton({ "doubleClicked", "doubleClicked" }, { index = selectedEvent })
				Iris.RadioButton({ "ctrlClicked", "ctrlClicked" }, { index = selectedEvent })
			end
			Iris.End()

			Iris.SameLine()
			do
				local button = Iris.Button({ selectedEvent:get() .. " to reveal text" })
				if button[selectedEvent:get()]() then
					showEventText:set(not showEventText:get())
				end
				if showEventText:get() then
					Iris.Text({ "Here i am!" })
				end
			end
			Iris.End()

			Iris.Separator()

			local showTextTimer = Iris.State(0)
			Iris.SameLine()
			do
				if Iris.Button({ "Click to show text for 20 frames" }).clicked() then
					showTextTimer:set(20)
				end
				if showTextTimer:get() > 0 then
					Iris.Text({ "Here i am!" })
				end
			end
			Iris.End()

			showTextTimer:set(math.max(0, showTextTimer:get() - 1))
			Iris.Text({ "Text Timer: " .. showTextTimer:get() })

			local checkbox0 = Iris.Checkbox({ "Event-tracked checkbox" })
			Iris.Indent()
			do
				Iris.Text({ "unchecked: " .. tostring(checkbox0.unchecked()) })
				Iris.Text({ "checked: " .. tostring(checkbox0.checked()) })
			end
			Iris.End()

			Iris.SameLine()
			do
				if Iris.Button({ "Hover over me" }).hovered() then
					Iris.Text({ "The button is hovered" })
				end
			end
			Iris.End()
		end
		Iris.End()
	end

	local function widgetStateInteractivity()
		Iris.CollapsingHeader({ "Widget State Interactivity" })
		do
			local checkbox0 = Iris.Checkbox({ "Widget-Generated State" })
			Iris.Text({ `isChecked: {checkbox0.state.isChecked.value}\n` })

			local checkboxState0 = Iris.State(false)
			local checkbox1 = Iris.Checkbox({ "User-Generated State" }, { isChecked = checkboxState0 })
			Iris.Text({ `isChecked: {checkbox1.state.isChecked.value}\n` })

			local checkbox2 = Iris.Checkbox({ "Widget Coupled State" })
			local checkbox3 = Iris.Checkbox({ "Coupled to above Checkbox" }, { isChecked = checkbox2.state.isChecked })
			Iris.Text({ `isChecked: {checkbox3.state.isChecked.value}\n` })

			local checkboxState1 = Iris.State(false)
			local _checkbox4 = Iris.Checkbox({ "Widget and Code Coupled State" }, { isChecked = checkboxState1 })
			local Button0 = Iris.Button({ "Click to toggle above checkbox" })
			if Button0.clicked() then
				checkboxState1:set(not checkboxState1:get())
			end
			Iris.Text({ `isChecked: {checkboxState1.value}\n` })

			local checkboxState2 = Iris.State(true)
			local checkboxState3 = Iris.ComputedState(checkboxState2, function(newValue)
				return not newValue
			end)
			local _checkbox5 = Iris.Checkbox({ "ComputedState (dynamic coupling)" }, { isChecked = checkboxState2 })
			local _checkbox5 = Iris.Checkbox({ "Inverted of above checkbox" }, { isChecked = checkboxState3 })
			Iris.Text({ `isChecked: {checkboxState3.value}\n` })
		end
		Iris.End()
	end

	local function dynamicStyle()
		Iris.CollapsingHeader({ "Dynamic Styles" })
		do
			local colorH = Iris.State(0)
			Iris.SameLine()
			do
				if Iris.Button({ "Change Color" }).clicked() then
					colorH:set(math.random())
				end
				Iris.Text({ "Hue: " .. math.floor(colorH:get() * 255) })
				helpMarker("Using PushConfig with a changing value, this can be done with any config field")
			end
			Iris.End()

			Iris.PushConfig({ TextColor = Color3.fromHSV(colorH:get(), 1, 1) })
			Iris.Text({ "Text with a unique and changable color" })
			Iris.PopConfig()
		end
		Iris.End()
	end

	local function tablesDemo()
		local showTablesTree = Iris.State(false)

		Iris.CollapsingHeader({ "Tables & Columns" }, { isUncollapsed = showTablesTree })
		if showTablesTree.value == false then
			-- optimization to skip code which draws GUI which wont be seen.
			-- its a trade off because when the tree becomes opened widgets will all have to be generated again.
			-- Dear ImGui utilizes the same trick, but its less useful here because the Retained mode Backend
			Iris.End()
		else
			Iris.Tree({ "Basic" })
			do
				Iris.SameLine()
				do
					Iris.Text({ "Table using NextColumn syntax:" })
					helpMarker(
						"calling Iris.NextColumn() in the inner loop,\nwhich automatically goes to the next row at the end."
					)
				end
				Iris.End()

				Iris.Table({ 3 })
				do
					for i = 1, 4 do
						for i2 = 1, 3 do
							Iris.Text({ `Row: {i}, Column: {i2}` })
							Iris.NextColumn()
						end
					end
				end
				Iris.End()

				Iris.Text({ "" })

				Iris.SameLine()
				do
					Iris.Text({ "Table using NextColumn and NextRow syntax:" })
					helpMarker(
						"Calling Iris.NextColumn() in the inner loop and Iris.NextRow() in the outer loop,\nto acehieve a visually identical result. Technically they are not the same."
					)
				end
				Iris.End()

				Iris.Table({ 3 })
				do
					for j = 1, 4 do
						for i = 1, 3 do
							Iris.Text({ `Row: {j}, Column: {i}` })
							Iris.NextColumn()
						end
						Iris.NextRow()
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tree({ "Headers, borders and backgrounds" })
			do
				local Type = Iris.State(0)
				local Header = Iris.State(false)
				local RowBackgrounds = Iris.State(false)
				local OuterBorders = Iris.State(true)
				local InnerBorders = Iris.State(true)

				Iris.Checkbox({ "Table header row" }, { isChecked = Header })
				Iris.Checkbox({ "Table row backgrounds" }, { isChecked = RowBackgrounds })
				Iris.Checkbox({ "Table outer border" }, { isChecked = OuterBorders })
				Iris.Checkbox({ "Table inner borders" }, { isChecked = InnerBorders })
				Iris.SameLine()
				do
					Iris.Text({ "Cell contents" })
					Iris.RadioButton({ "Text", 0 }, { index = Type })
					Iris.RadioButton({ "Fill button", 1 }, { index = Type })
				end
				Iris.End()

				Iris.Table({ 3, Header.value, RowBackgrounds.value, OuterBorders.value, InnerBorders.value })
				do
					Iris.SetHeaderColumnIndex(1)
					for j = 0, 4 do
						for i = 1, 3 do
							if Type.value == 0 then
								Iris.Text({ `Cell ({i}, {j})` })
							else
								Iris.Button({ `Cell ({i}, {j})`, UDim2.fromScale(1, 0) })
							end
							Iris.NextColumn()
						end
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tree({ "Sizing" })
			do
				local Resizable = Iris.State(false)
				local LimitWidth = Iris.State(false)
				Iris.Checkbox({ "Resizable" }, { isChecked = Resizable })
				Iris.Checkbox({ "Limit Table Width" }, { isChecked = LimitWidth })

				do
					Iris.SeparatorText({ "stretch, equal" })
					Iris.Table({ 3, false, true, true, true, Resizable.value })
					do
						for _ = 1, 3 do
							for _ = 1, 3 do
								Iris.Text({ "stretch" })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
					Iris.Table({ 3, false, true, true, true, Resizable.value })
					do
						for _ = 1, 3 do
							for i = 1, 3 do
								Iris.Text({ string.rep(string.char(64 + i), 4 * i) })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
				end

				do
					Iris.SeparatorText({ "stretch, proportional" })
					Iris.Table({ 3, false, true, true, true, Resizable.value, false, true })
					do
						for _ = 1, 3 do
							for _ = 1, 3 do
								Iris.Text({ "stretch" })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
					Iris.Table({ 3, false, true, true, true, Resizable.value, false, true })
					do
						for _ = 1, 3 do
							for i = 1, 3 do
								Iris.Text({ string.rep(string.char(64 + i), 4 * i) })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
				end

				do
					Iris.SeparatorText({ "fixed, equal" })
					Iris.Table({ 3, false, true, true, true, Resizable.value, true, false, LimitWidth.value })
					do
						for _ = 1, 3 do
							for _ = 1, 3 do
								Iris.Text({ "fixed" })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
					Iris.Table({ 3, false, true, true, true, Resizable.value, true, false, LimitWidth.value })
					do
						for _ = 1, 3 do
							for i = 1, 3 do
								Iris.Text({ string.rep(string.char(64 + i), 4 * i) })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
				end

				do
					Iris.SeparatorText({ "fixed, proportional" })
					Iris.Table({ 3, false, true, true, true, Resizable.value, true, true, LimitWidth.value })
					do
						for _ = 1, 3 do
							for _ = 1, 3 do
								Iris.Text({ "fixed" })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
					Iris.Table({ 3, false, true, true, true, Resizable.value, true, true, LimitWidth.value })
					do
						for _ = 1, 3 do
							for i = 1, 3 do
								Iris.Text({ string.rep(string.char(64 + i), 4 * i) })
								Iris.NextColumn()
							end
						end
					end
					Iris.End()
				end
			end
			Iris.End()

			Iris.Tree({ "Resizable" })
			do
				local NumColumns = Iris.State(4)
				local NumRows = Iris.State(3)
				local TableUseButtons = Iris.State(false)

				local HeaderState = Iris.State(true)
				local BackgroundState = Iris.State(true)
				local OuterBorderState = Iris.State(true)
				local InnerBorderState = Iris.State(true)
				local ResizableState = Iris.State(false)
				local FixedWidthState = Iris.State(false)
				local ProportionalWidthState = Iris.State(false)
				local LimitTableWidthState = Iris.State(false)

				local AddExtra = Iris.State(false)

				local WidthState = Iris.State(table.create(10, 100))

				Iris.SliderNum({ "Num Columns", 1, 1, 10 }, { number = NumColumns })
				Iris.SliderNum({ "Number of rows", 1, 0, 100 }, { number = NumRows })

				Iris.SameLine()
				do
					Iris.RadioButton({ "Buttons", true }, { index = TableUseButtons })
					Iris.RadioButton({ "Text", false }, { index = TableUseButtons })
				end
				Iris.End()

				Iris.Table({ 3 })
				do
					Iris.Checkbox({ "Show Header Row" }, { isChecked = HeaderState })
					Iris.NextColumn()
					Iris.Checkbox({ "Show Row Backgrounds" }, { isChecked = BackgroundState })
					Iris.NextColumn()
					Iris.Checkbox({ "Show Outer Border" }, { isChecked = OuterBorderState })
					Iris.NextColumn()
					Iris.Checkbox({ "Show Inner Border" }, { isChecked = InnerBorderState })
					Iris.NextColumn()
					Iris.Checkbox({ "Resizable" }, { isChecked = ResizableState })
					Iris.NextColumn()
					Iris.Checkbox({ "Fixed Width" }, { isChecked = FixedWidthState })
					Iris.NextColumn()
					Iris.Checkbox({ "Proportional Width" }, { isChecked = ProportionalWidthState })
					Iris.NextColumn()
					Iris.Checkbox({ "Limit Table Width" }, { isChecked = LimitTableWidthState })
					Iris.NextColumn()
					Iris.Checkbox({ "Add extra" }, { isChecked = AddExtra })
					Iris.NextColumn()
				end
				Iris.End()

				for i = 1, NumColumns.value do
					local increment = if FixedWidthState.value == true then 1 else 0.05
					local min = if FixedWidthState.value == true then 2 else 0.05
					local max = if FixedWidthState.value == true then 480 else 1
					Iris.SliderNum({ `Column {i} Width`, increment, min, max }, {
						number = Iris.TableState(WidthState.value, i, function(value)
							-- we have to force the state to change, because comparing two tables is equal
							WidthState.value[i] = value
							WidthState:set(WidthState.value, true)
							return false
						end),
					})
				end

				Iris.PushConfig({
					NumColumns = NumColumns.value,
				})
				Iris.Table({
					NumColumns.value,
					HeaderState.value,
					BackgroundState.value,
					OuterBorderState.value,
					InnerBorderState.value,
					ResizableState.value,
					FixedWidthState.value,
					ProportionalWidthState.value,
					LimitTableWidthState.value,
				}, { widths = WidthState })
				do
					Iris.SetHeaderColumnIndex(1)
					for i = 0, NumRows:get() do
						for j = 1, NumColumns.value do
							if i == 0 then
								if TableUseButtons.value then
									Iris.Button({ `H: {j}` })
								else
									Iris.Text({ `H: {j}` })
								end
							else
								if TableUseButtons.value then
									Iris.Button({ `R: {i}, C: {j}` })
									Iris.Button({ string.rep("...", j) })
								else
									Iris.Text({ `R: {i}, C: {j}` })
									Iris.Text({ string.rep("...", j) })
								end
							end
							Iris.NextColumn()
						end
					end

					if AddExtra.value then
						Iris.Text({ "A really long piece of text!" })
					end
				end
				Iris.End()
				Iris.PopConfig()
			end
			Iris.End()

			Iris.End()
		end
	end

	local function layoutDemo()
		Iris.CollapsingHeader({ "Widget Layout" })
		do
			Iris.Tree({ "Widget Alignment" })
			do
				Iris.Text({ "Iris.SameLine has optional argument supporting horizontal and vertical alignments." })
				Iris.Text({ "This allows widgets to be place anywhere on the line." })
				Iris.Separator()

				Iris.SameLine()
				do
					Iris.Text({ "By default child widgets will be aligned to the left." })
					helpMarker(
						'Iris.SameLine()\n\tIris.Button({ "Button A" })\n\tIris.Button({ "Button B" })\nIris.End()'
					)
				end
				Iris.End()

				Iris.SameLine()
				do
					Iris.Button({ "Button A" })
					Iris.Button({ "Button B" })
				end
				Iris.End()

				Iris.SameLine()
				do
					Iris.Text({ "But can be aligned to the center." })
					helpMarker(
						'Iris.SameLine({ nil, nil, Enum.HorizontalAlignment.Center })\n\tIris.Button({ "Button A" })\n\tIris.Button({ "Button B" })\nIris.End()'
					)
				end
				Iris.End()

				Iris.SameLine({ nil, nil, Enum.HorizontalAlignment.Center })
				do
					Iris.Button({ "Button A" })
					Iris.Button({ "Button B" })
				end
				Iris.End()

				Iris.SameLine()
				do
					Iris.Text({ "Or right." })
					helpMarker(
						'Iris.SameLine({ nil, nil, Enum.HorizontalAlignment.Right })\n\tIris.Button({ "Button A" })\n\tIris.Button({ "Button B" })\nIris.End()'
					)
				end
				Iris.End()

				Iris.SameLine({ nil, nil, Enum.HorizontalAlignment.Right })
				do
					Iris.Button({ "Button A" })
					Iris.Button({ "Button B" })
				end
				Iris.End()

				Iris.Separator()

				Iris.SameLine()
				do
					Iris.Text({ "You can also specify the padding." })
					helpMarker(
						'Iris.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })\n\tIris.Button({ "Button A" })\n\tIris.Button({ "Button B" })\nIris.End()'
					)
				end
				Iris.End()

				Iris.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })
				do
					Iris.Button({ "Button A" })
					Iris.Button({ "Button B" })
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tree({ "Widget Sizing" })
			do
				Iris.Text({ "Nearly all widgets are the minimum size of the content." })
				Iris.Text({ "For example, text and button widgets will be the size of the text labels." })
				Iris.Text({
					"Some widgets, such as the Image and Button have Size arguments will will set the size of them.",
				})
				Iris.Separator()

				textAndHelpMarker(
					"The button takes up the full screen-width.",
					'Iris.Button({ "Button", UDim2.fromScale(1, 0) })'
				)
				Iris.Button({ "Button", UDim2.fromScale(1, 0) })
				textAndHelpMarker(
					"The button takes up half the screen-width.",
					'Iris.Button({ "Button", UDim2.fromScale(0.5, 0) })'
				)
				Iris.Button({ "Button", UDim2.fromScale(0.5, 0) })

				textAndHelpMarker(
					"Combining with SameLine, the buttons can fill the screen width.",
					"The button will still be larger that the text size."
				)
				local num = Iris.State(2)
				Iris.SliderNum({ "Number of Buttons", 1, 1, 8 }, { number = num })
				Iris.SameLine({ 0, nil, Enum.HorizontalAlignment.Center })
				do
					for i = 1, num.value do
						Iris.Button({ `Button {i}`, UDim2.fromScale(1 / num.value, 0) })
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tree({ "Content Width" })
			do
				local value = Iris.State(50)
				local index = Iris.State(Enum.Axis.X)

				Iris.Text({ "The Content Width is a size property which determines the width of input fields." })
				Iris.SameLine()
				do
					Iris.Text({ "By default the value is UDim.new(0.65, 0)" })
					helpMarker("This is the default value from Dear ImGui.\nIt is 65% of the window width.")
				end
				Iris.End()

				Iris.Text({
					"This works well, but sometimes we know how wide elements are going to be and want to maximise the space.",
				})
				Iris.Text({ "Therefore, we can use Iris.PushConfig() to change the width" })

				Iris.Separator()

				Iris.SameLine()
				do
					Iris.Text({ "Content Width = 150 pixels" })
					helpMarker("UDim.new(0, 150)")
				end
				Iris.End()

				Iris.PushConfig({ ContentWidth = UDim.new(0, 150) })
				Iris.DragNum({ "number", 1, 0, 100 }, { number = value })
				Iris.InputEnum({ "axis" }, { index = index }, Enum.Axis)
				Iris.PopConfig()

				Iris.SameLine()
				do
					Iris.Text({ "Content Width = 50% window width" })
					helpMarker("UDim.new(0.5, 0)")
				end
				Iris.End()

				Iris.PushConfig({ ContentWidth = UDim.new(0.5, 0) })
				Iris.DragNum({ "number", 1, 0, 100 }, { number = value })
				Iris.InputEnum({ "axis" }, { index = index }, Enum.Axis)
				Iris.PopConfig()

				Iris.SameLine()
				do
					Iris.Text({ "Content Width = -150 pixels from the right side" })
					helpMarker("UDim.new(1, -150)")
				end
				Iris.End()

				Iris.PushConfig({ ContentWidth = UDim.new(1, -150) })
				Iris.DragNum({ "number", 1, 0, 100 }, { number = value })
				Iris.InputEnum({ "axis" }, { index = index }, Enum.Axis)
				Iris.PopConfig()
			end
			Iris.End()

			Iris.Tree({ "Content Height" })
			do
				local text = Iris.State("a single line")
				local value = Iris.State(50)
				local index = Iris.State(Enum.Axis.X)
				local progress = Iris.State(0)

				-- formula to cycle between 0 and 100 linearly
				local newValue = math.clamp((math.abs((os.clock() * 15) % 100 - 50)) - 7.5, 0, 35) / 35
				progress:set(newValue)

				Iris.Text({
					"The Content Height is a size property that determines the minimum size of certain widgets.",
				})
				Iris.Text({ "By default the value is UDim.new(0, 0), so there is no minimum height." })
				Iris.Text({ "We use Iris.PushConfig() to change this value." })

				Iris.Separator()
				Iris.SameLine()
				do
					Iris.Text({ "Content Height = 0 pixels" })
					helpMarker("UDim.new(0, 0)")
				end
				Iris.End()

				Iris.InputText({ "text" }, { text = text })
				Iris.ProgressBar({ "progress" }, { progress = progress })
				Iris.DragNum({ "number", 1, 0, 100 }, { number = value })
				Iris.ComboEnum({ "axis" }, { index = index }, Enum.Axis)

				Iris.SameLine()
				do
					Iris.Text({ "Content Height = 60 pixels" })
					helpMarker("UDim.new(0, 60)")
				end
				Iris.End()

				Iris.PushConfig({ ContentHeight = UDim.new(0, 60) })
				Iris.InputText({ "text", nil, nil, true }, { text = text })
				Iris.ProgressBar({ "progress" }, { progress = progress })
				Iris.DragNum({ "number", 1, 0, 100 }, { number = value })
				Iris.ComboEnum({ "axis" }, { index = index }, Enum.Axis)
				Iris.PopConfig()

				Iris.Text({ "This property can be used to force the height of a text box." })
				Iris.Text({ "Just make sure you enable the MultiLine argument." })
			end
			Iris.End()
		end
		Iris.End()
	end

	-- showcases how widgets placed outside of a window are placed inside root
	local function windowlessDemo()
		Iris.PushConfig({ ItemWidth = UDim.new(0, 150) })
		Iris.SameLine()
		do
			Iris.TextWrapped({ "Windowless widgets" })
			helpMarker("Widgets which are placed outside of a window will appear on the top left side of the screen.")
		end
		Iris.End()

		Iris.Button({})
		Iris.Tree({})
		do
			Iris.InputText({})
		end
		Iris.End()

		Iris.PopConfig()
	end

	-- main demo window
	return function()
		local NoTitleBar = Iris.State(false)
		local NoBackground = Iris.State(false)
		local NoCollapse = Iris.State(false)
		local NoClose = Iris.State(true)
		local NoMove = Iris.State(false)
		local NoScrollbar = Iris.State(false)
		local NoResize = Iris.State(false)
		local NoNav = Iris.State(false)
		local NoMenu = Iris.State(false)

		if showMainWindow.value == false then
			Iris.Checkbox({ "Open main window" }, { isChecked = showMainWindow })
			return
		end

		debug.profilebegin("Iris/Demo/Window")
		local window = Iris.Window({
			[Iris.Args.Window.Title] = "Iris Demo Window",
			[Iris.Args.Window.NoTitleBar] = NoTitleBar.value,
			[Iris.Args.Window.NoBackground] = NoBackground.value,
			[Iris.Args.Window.NoCollapse] = NoCollapse.value,
			[Iris.Args.Window.NoClose] = NoClose.value,
			[Iris.Args.Window.NoMove] = NoMove.value,
			[Iris.Args.Window.NoScrollbar] = NoScrollbar.value,
			[Iris.Args.Window.NoResize] = NoResize.value,
			[Iris.Args.Window.NoNav] = NoNav.value,
			[Iris.Args.Window.NoMenu] = NoMenu.value,
		}, {
			size = Iris.State(Vector2.new(600, 550)),
			position = Iris.State(Vector2.new(100, 25)),
			isOpened = showMainWindow,
		})

		if window.state.isUncollapsed.value and window.state.isOpened.value then
			debug.profilebegin("Iris/Demo/MenuBar")
			mainMenuBar()
			debug.profileend()

			Iris.Text({ "Iris says hello. (" .. Iris.Internal._version .. ")" })

			debug.profilebegin("Iris/Demo/Options")
			Iris.CollapsingHeader({ "Window Options" })
			do
				Iris.Table({ 3, false, false, false })
				do
					Iris.Checkbox({ "NoTitleBar" }, { isChecked = NoTitleBar })
					Iris.NextColumn()
					Iris.Checkbox({ "NoBackground" }, { isChecked = NoBackground })
					Iris.NextColumn()
					Iris.Checkbox({ "NoCollapse" }, { isChecked = NoCollapse })
					Iris.NextColumn()
					Iris.Checkbox({ "NoClose" }, { isChecked = NoClose })
					Iris.NextColumn()
					Iris.Checkbox({ "NoMove" }, { isChecked = NoMove })
					Iris.NextColumn()
					Iris.Checkbox({ "NoScrollbar" }, { isChecked = NoScrollbar })
					Iris.NextColumn()
					Iris.Checkbox({ "NoResize" }, { isChecked = NoResize })
					Iris.NextColumn()
					Iris.Checkbox({ "NoNav" }, { isChecked = NoNav })
					Iris.NextColumn()
					Iris.Checkbox({ "NoMenu" }, { isChecked = NoMenu })
					Iris.NextColumn()
				end
				Iris.End()
			end
			Iris.End()
			debug.profileend()

			debug.profilebegin("Iris/Demo/Events")
			widgetEventInteractivity()
			debug.profileend()

			debug.profilebegin("Iris/Demo/States")
			widgetStateInteractivity()
			debug.profileend()

			debug.profilebegin("Iris/Demo/Recursive")
			Iris.CollapsingHeader({ "Recursive Tree" })
			recursiveTree()
			Iris.End()
			debug.profileend()

			debug.profilebegin("Iris/Demo/Style")
			dynamicStyle()
			debug.profileend()

			Iris.Separator()

			debug.profilebegin("Iris/Demo/Widgets")
			Iris.CollapsingHeader({ "Widgets" })
			do
				for _, name in widgetDemosOrder do
					debug.profilebegin(`Iris/Demo/Widgets/{name}`)
					widgetDemos[name]()
					debug.profileend()
				end
			end
			Iris.End()
			debug.profileend()

			debug.profilebegin("Iris/Demo/Tables")
			tablesDemo()
			debug.profileend()

			debug.profilebegin("Iris/Demo/Layout")
			layoutDemo()
			debug.profileend()

			Iris.CollapsingHeader({ "Background" })
			do
				Iris.Checkbox({ "Show background colour" }, { isChecked = showBackground })
				Iris.InputColor4(
					{ "Background colour" },
					{ color = backgroundColour, transparency = backgroundTransparency }
				)
			end
			Iris.End()
		end
		Iris.End()
		debug.profileend()

		if showRecursiveWindow.value then
			recursiveWindow(showRecursiveWindow)
		end
		if showRuntimeInfo.value then
			runtimeInfo()
		end
		if showDebugWindow.value then
			debugPanel()
		end
		if showStyleEditor.value then
			styleEditor()
		end
		if showWindowlessDemo.value then
			windowlessDemo()
		end

		if showMainMenuBarWindow.value then
			mainMenuBarExample()
		end

		return window
	end
end
