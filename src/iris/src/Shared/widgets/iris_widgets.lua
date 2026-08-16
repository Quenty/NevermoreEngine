--!nocheck
local Types = require(script.Parent.Parent.iris_Types)

local widgets = {} :: Types.WidgetUtility

return function(Iris: Types.Internal)
	widgets.GuiService = game:GetService("GuiService")
	widgets.RunService = game:GetService("RunService")
	widgets.UserInputService = game:GetService("UserInputService")
	widgets.ContextActionService = game:GetService("ContextActionService")
	widgets.TextService = game:GetService("TextService")

	widgets.ICONS = {
		BLANK_SQUARE = "rbxassetid://83265623867126",
		RIGHT_POINTING_TRIANGLE = "rbxassetid://105541346271951",
		DOWN_POINTING_TRIANGLE = "rbxassetid://95465797476827",
		MULTIPLICATION_SIGN = "rbxassetid://133890060015237", -- best approximation for a close X which roblox supports, needs to be scaled about 2x
		BOTTOM_RIGHT_CORNER = "rbxassetid://125737344915000", -- used in window resize icon in bottom right
		CHECKMARK = "rbxassetid://109638815494221",
		BORDER = "rbxassetid://133803690460269",
		ALPHA_BACKGROUND_TEXTURE = "rbxassetid://114090016039876", -- used for color4 alpha
		UNKNOWN_TEXTURE = "rbxassetid://95045813476061",
	}

	widgets.IS_STUDIO = widgets.RunService:IsStudio()
	function widgets.getTime()
		-- time() always returns 0 in the context of plugins
		if widgets.IS_STUDIO then
			return os.clock()
		else
			return time()
		end
	end

	-- acts as an offset where the absolute position of the base frame is not zero, such as IgnoreGuiInset or for stories
	widgets.GuiOffset = if Iris._config.IgnoreGuiInset then -widgets.GuiService:GetGuiInset() else Vector2.zero
	-- the registered mouse position always ignores the topbar, so needs a separate variable offset
	widgets.MouseOffset = if Iris._config.IgnoreGuiInset then Vector2.zero else widgets.GuiService:GetGuiInset()

	-- the topbar inset changes updates a frame later.
	local connection: RBXScriptConnection
	connection = widgets.GuiService:GetPropertyChangedSignal("TopbarInset"):Once(function()
		widgets.MouseOffset = if Iris._config.IgnoreGuiInset then Vector2.zero else widgets.GuiService:GetGuiInset()
		widgets.GuiOffset = if Iris._config.IgnoreGuiInset then -widgets.GuiService:GetGuiInset() else Vector2.zero
		connection:Disconnect()
	end)
	-- in case the topbar doesn't change, we cancel the event.
	task.delay(5, function()
		connection:Disconnect()
	end)

	function widgets.getMouseLocation()
		return widgets.UserInputService:GetMouseLocation() - widgets.MouseOffset
	end

	function widgets.isPosInsideRect(pos: Vector2, rectMin: Vector2, rectMax: Vector2)
		return pos.X >= rectMin.X and pos.X <= rectMax.X and pos.Y >= rectMin.Y and pos.Y <= rectMax.Y
	end

	function widgets.findBestWindowPosForPopup(refPos: Vector2, size: Vector2, outerMin: Vector2, outerMax: Vector2)
		local CURSOR_OFFSET_DIST = 20

		if refPos.X + size.X + CURSOR_OFFSET_DIST > outerMax.X then
			if refPos.Y + size.Y + CURSOR_OFFSET_DIST > outerMax.Y then
				-- placed to the top
				refPos += Vector2.new(0, -(CURSOR_OFFSET_DIST + size.Y))
			else
				-- placed to the bottom
				refPos += Vector2.new(0, CURSOR_OFFSET_DIST)
			end
		else
			-- placed to the right
			refPos += Vector2.new(CURSOR_OFFSET_DIST)
		end

		return Vector2.new(
			math.max(math.min(refPos.X + size.X, outerMax.X) - size.X, outerMin.X),
			math.max(math.min(refPos.Y + size.Y, outerMax.Y) - size.Y, outerMin.Y)
		)
	end

	function widgets.getScreenSizeForWindow(thisWidget: Types.Widget) -- possible parents are GuiBase2d, CoreGui, PlayerGui
		if thisWidget.Instance:IsA("GuiBase2d") then
			return thisWidget.Instance.AbsoluteSize
		else
			local rootParent = thisWidget.Instance.Parent
			if rootParent:IsA("GuiBase2d") then
				return rootParent.AbsoluteSize
			else
				if rootParent.Parent:IsA("GuiBase2d") then
					return rootParent.AbsoluteSize
				else
					return workspace.CurrentCamera.ViewportSize
				end
			end
		end
	end

	function widgets.extend(superClass: Types.WidgetClass, subClass: Types.WidgetClass): Types.WidgetClass
		local newClass = table.clone(superClass)
		for index, value in subClass do
			newClass[index] = value
		end
		return newClass
	end

	function widgets.UIPadding(Parent: GuiObject, PxPadding: Vector2)
		local UIPaddingInstance = Instance.new("UIPadding")
		UIPaddingInstance.PaddingLeft = UDim.new(0, PxPadding.X)
		UIPaddingInstance.PaddingRight = UDim.new(0, PxPadding.X)
		UIPaddingInstance.PaddingTop = UDim.new(0, PxPadding.Y)
		UIPaddingInstance.PaddingBottom = UDim.new(0, PxPadding.Y)
		UIPaddingInstance.Parent = Parent
		return UIPaddingInstance
	end

	function widgets.UIListLayout(Parent: GuiObject, FillDirection: Enum.FillDirection, Padding: UDim)
		local UIListLayoutInstance = Instance.new("UIListLayout")
		UIListLayoutInstance.SortOrder = Enum.SortOrder.LayoutOrder
		UIListLayoutInstance.Padding = Padding
		UIListLayoutInstance.FillDirection = FillDirection
		UIListLayoutInstance.Parent = Parent
		return UIListLayoutInstance
	end

	function widgets.UIStroke(Parent: GuiObject, Thickness: number, Color: Color3, Transparency: number)
		local UIStrokeInstance = Instance.new("UIStroke")
		UIStrokeInstance.Thickness = Thickness
		UIStrokeInstance.Color = Color
		UIStrokeInstance.Transparency = Transparency
		UIStrokeInstance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		UIStrokeInstance.LineJoinMode = Enum.LineJoinMode.Round
		UIStrokeInstance.Parent = Parent
		return UIStrokeInstance
	end

	function widgets.UICorner(Parent: GuiObject, PxRounding: number?)
		local UICornerInstance = Instance.new("UICorner")
		UICornerInstance.CornerRadius = UDim.new(PxRounding and 0 or 1, PxRounding or 0)
		UICornerInstance.Parent = Parent
		return UICornerInstance
	end

	function widgets.UISizeConstraint(Parent: GuiObject, MinSize: Vector2?, MaxSize: Vector2?)
		local UISizeConstraintInstance = Instance.new("UISizeConstraint")
		UISizeConstraintInstance.MinSize = MinSize or UISizeConstraintInstance.MinSize -- made these optional
		UISizeConstraintInstance.MaxSize = MaxSize or UISizeConstraintInstance.MaxSize
		UISizeConstraintInstance.Parent = Parent
		return UISizeConstraintInstance
	end

	-- below uses Iris

	function widgets.applyTextStyle(thisInstance: TextLabel & TextButton & TextBox)
		thisInstance.FontFace = Iris._config.TextFont
		thisInstance.TextSize = Iris._config.TextSize
		thisInstance.TextColor3 = Iris._config.TextColor
		thisInstance.TextTransparency = Iris._config.TextTransparency
		thisInstance.TextXAlignment = Enum.TextXAlignment.Left
		thisInstance.TextYAlignment = Enum.TextYAlignment.Center
		thisInstance.RichText = Iris._config.RichText
		thisInstance.TextWrapped = Iris._config.TextWrapped

		thisInstance.AutoLocalize = false
	end

	function widgets.applyInteractionHighlights(
		Property: string,
		Button: GuiButton,
		Highlightee: GuiObject,
		Colors: { [string]: any }
	)
		local exitedButton = false
		widgets.applyMouseEnter(Button, function()
			Highlightee[Property .. "Color3"] = Colors.HoveredColor
			Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency

			exitedButton = false
		end)

		widgets.applyMouseLeave(Button, function()
			Highlightee[Property .. "Color3"] = Colors.Color
			Highlightee[Property .. "Transparency"] = Colors.Transparency

			exitedButton = true
		end)

		widgets.applyInputBegan(Button, function(input: InputObject)
			if
				not (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Gamepad1
				)
			then
				return
			end
			Highlightee[Property .. "Color3"] = Colors.ActiveColor
			Highlightee[Property .. "Transparency"] = Colors.ActiveTransparency
		end)

		widgets.applyInputEnded(Button, function(input: InputObject)
			if
				not (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Gamepad1
				) or exitedButton
			then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				Highlightee[Property .. "Color3"] = Colors.HoveredColor
				Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency
			end
			if input.UserInputType == Enum.UserInputType.Gamepad1 then
				Highlightee[Property .. "Color3"] = Colors.Color
				Highlightee[Property .. "Transparency"] = Colors.Transparency
			end
		end)

		Button.SelectionImageObject = Iris.SelectionImageObject
	end

	function widgets.applyInteractionHighlightsWithMultiHighlightee(
		Property: string,
		Button: GuiButton,
		Highlightees: { { GuiObject | { [string]: Color3 | number } } }
	)
		local exitedButton = false
		widgets.applyMouseEnter(Button, function()
			for _, Highlightee in Highlightees do
				Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
				Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency

				exitedButton = false
			end
		end)

		widgets.applyMouseLeave(Button, function()
			for _, Highlightee in Highlightees do
				Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
				Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency

				exitedButton = true
			end
		end)

		widgets.applyInputBegan(Button, function(input: InputObject)
			if
				not (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Gamepad1
				)
			then
				return
			end
			for _, Highlightee in Highlightees do
				Highlightee[1][Property .. "Color3"] = Highlightee[2].ActiveColor
				Highlightee[1][Property .. "Transparency"] = Highlightee[2].ActiveTransparency
			end
		end)

		widgets.applyInputEnded(Button, function(input: InputObject)
			if
				not (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Gamepad1
				) or exitedButton
			then
				return
			end
			for _, Highlightee in Highlightees do
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
					Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency
				end
				if input.UserInputType == Enum.UserInputType.Gamepad1 then
					Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
					Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency
				end
			end
		end)

		Button.SelectionImageObject = Iris.SelectionImageObject
	end

	function widgets.applyFrameStyle(thisInstance: GuiObject, noPadding: boolean?, noCorner: boolean?)
		-- padding, border, and rounding
		-- optimized to only use what instances are needed, based on style
		local FrameBorderSize = Iris._config.FrameBorderSize
		local FrameRounding = Iris._config.FrameRounding
		thisInstance.BorderSizePixel = 0

		if FrameBorderSize > 0 then
			widgets.UIStroke(thisInstance, FrameBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)
		end
		if FrameRounding > 0 and not noCorner then
			widgets.UICorner(thisInstance, FrameRounding)
		end
		if not noPadding then
			widgets.UIPadding(thisInstance, Iris._config.FramePadding)
		end
	end

	function widgets.applyButtonClick(thisInstance: GuiButton, callback: () -> ())
		thisInstance.MouseButton1Click:Connect(function()
			callback()
		end)
	end

	function widgets.applyButtonDown(thisInstance: GuiButton, callback: (x: number, y: number) -> ())
		thisInstance.MouseButton1Down:Connect(function(x: number, y: number)
			local position = Vector2.new(x, y) - widgets.MouseOffset
			callback(position.X, position.Y)
		end)
	end

	function widgets.applyMouseEnter(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
		thisInstance.MouseEnter:Connect(function(x: number, y: number)
			local position = Vector2.new(x, y) - widgets.MouseOffset
			callback(position.X, position.Y)
		end)
	end

	function widgets.applyMouseMoved(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
		thisInstance.MouseMoved:Connect(function(x: number, y: number)
			local position = Vector2.new(x, y) - widgets.MouseOffset
			callback(position.X, position.Y)
		end)
	end

	function widgets.applyMouseLeave(thisInstance: GuiObject, callback: (x: number, y: number) -> ())
		thisInstance.MouseLeave:Connect(function(x: number, y: number)
			local position = Vector2.new(x, y) - widgets.MouseOffset
			callback(position.X, position.Y)
		end)
	end

	function widgets.applyInputBegan(thisInstance: GuiButton, callback: (input: InputObject) -> ())
		thisInstance.InputBegan:Connect(function(...)
			callback(...)
		end)
	end

	function widgets.applyInputEnded(thisInstance: GuiButton, callback: (input: InputObject) -> ())
		thisInstance.InputEnded:Connect(function(...)
			callback(...)
		end)
	end

	function widgets.discardState(thisWidget: Types.StateWidget)
		for _, state in thisWidget.state do
			state.ConnectedWidgets[thisWidget.ID] = nil
		end
	end

	function widgets.registerEvent(event: string, callback: (...any) -> ())
		table.insert(Iris._initFunctions, function()
			table.insert(Iris._connections, widgets.UserInputService[event]:Connect(callback))
		end)
	end

	widgets.EVENTS = {
		hover = function(pathToHovered: (thisWidget: Types.Widget) -> GuiObject)
			return {
				["Init"] = function(thisWidget: Types.Widget & Types.Hovered)
					local hoveredGuiObject = pathToHovered(thisWidget)
					widgets.applyMouseEnter(hoveredGuiObject, function()
						thisWidget.isHoveredEvent = true
					end)
					widgets.applyMouseLeave(hoveredGuiObject, function()
						thisWidget.isHoveredEvent = false
					end)
					thisWidget.isHoveredEvent = false
				end,
				["Get"] = function(thisWidget: Types.Widget & Types.Hovered)
					return thisWidget.isHoveredEvent
				end,
			}
		end,

		click = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
			return {
				["Init"] = function(thisWidget: Types.Widget & Types.Clicked)
					local clickedGuiObject = pathToClicked(thisWidget)
					thisWidget.lastClickedTick = -1

					widgets.applyButtonClick(clickedGuiObject, function()
						thisWidget.lastClickedTick = Iris._cycleTick + 1
					end)
				end,
				["Get"] = function(thisWidget: Types.Widget & Types.Clicked)
					return thisWidget.lastClickedTick == Iris._cycleTick
				end,
			}
		end,

		rightClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
			return {
				["Init"] = function(thisWidget: Types.Widget & Types.RightClicked)
					local clickedGuiObject = pathToClicked(thisWidget)
					thisWidget.lastRightClickedTick = -1

					clickedGuiObject.MouseButton2Click:Connect(function()
						thisWidget.lastRightClickedTick = Iris._cycleTick + 1
					end)
				end,
				["Get"] = function(thisWidget: Types.Widget & Types.RightClicked)
					return thisWidget.lastRightClickedTick == Iris._cycleTick
				end,
			}
		end,

		doubleClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
			return {
				["Init"] = function(thisWidget: Types.Widget & Types.DoubleClicked)
					local clickedGuiObject = pathToClicked(thisWidget)
					thisWidget.lastClickedTime = -1
					thisWidget.lastClickedPosition = Vector2.zero
					thisWidget.lastDoubleClickedTick = -1

					widgets.applyButtonDown(clickedGuiObject, function(x: number, y: number)
						local currentTime = widgets.getTime()
						local isTimeValid = currentTime - thisWidget.lastClickedTime < Iris._config.MouseDoubleClickTime
						if
							isTimeValid
							and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude
								< Iris._config.MouseDoubleClickMaxDist
						then
							thisWidget.lastDoubleClickedTick = Iris._cycleTick + 1
						else
							thisWidget.lastClickedTime = currentTime
							thisWidget.lastClickedPosition = Vector2.new(x, y)
						end
					end)
				end,
				["Get"] = function(thisWidget: Types.Widget & Types.DoubleClicked)
					return thisWidget.lastDoubleClickedTick == Iris._cycleTick
				end,
			}
		end,

		ctrlClick = function(pathToClicked: (thisWidget: Types.Widget) -> GuiButton)
			return {
				["Init"] = function(thisWidget: Types.Widget & Types.CtrlClicked)
					local clickedGuiObject = pathToClicked(thisWidget)
					thisWidget.lastCtrlClickedTick = -1

					widgets.applyButtonClick(clickedGuiObject, function()
						if
							widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
							or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
						then
							thisWidget.lastCtrlClickedTick = Iris._cycleTick + 1
						end
					end)
				end,
				["Get"] = function(thisWidget: Types.Widget & Types.CtrlClicked)
					return thisWidget.lastCtrlClickedTick == Iris._cycleTick
				end,
			}
		end,
	}

	Iris._utility = widgets

	require(script.Parent.iris_Root)(Iris, widgets)
	require(script.Parent.iris_Window)(Iris, widgets)

	require(script.Parent.iris_Menu)(Iris, widgets)

	require(script.Parent.iris_Format)(Iris, widgets)

	require(script.Parent.iris_Text)(Iris, widgets)
	require(script.Parent.iris_Button)(Iris, widgets)
	require(script.Parent.iris_Checkbox)(Iris, widgets)
	require(script.Parent.iris_RadioButton)(Iris, widgets)
	require(script.Parent.iris_Image)(Iris, widgets)

	require(script.Parent.iris_Tree)(Iris, widgets)
	require(script.Parent.iris_Tab)(Iris, widgets)

	require(script.Parent.iris_Input)(Iris, widgets)
	require(script.Parent.iris_Combo)(Iris, widgets)
	require(script.Parent.iris_Plot)(Iris, widgets)

	require(script.Parent.iris_Table)(Iris, widgets)

	require(script.Parent.iris_ImPlot)(Iris, widgets)
end
