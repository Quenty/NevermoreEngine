--!nocheck
local Types = require(script.Parent.Parent.iris_Types)

return function(Iris: Types.Internal, widgets: Types.WidgetUtility)
    --stylua: ignore
    Iris.WidgetConstructor("Selectable", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Index"] = 2,
            ["NoClick"] = 3,
        },
        Events = {
            ["selected"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.lastSelectedTick == Iris._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.lastUnselectedTick == Iris._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget: Types.Selectable) end,
                ["Get"] = function(thisWidget: Types.Selectable)
                    return thisWidget.state.index.value == thisWidget.arguments.Index
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                local Selectable = thisWidget.Instance :: Frame
                return Selectable.SelectableButton
            end),
        },
        Generate = function(thisWidget: Types.Selectable)
            local Selectable = Instance.new("Frame")
            Selectable.Name = "Iris_Selectable"
            Selectable.Size = UDim2.new(Iris._config.ItemWidth, UDim.new(0, Iris._config.TextSize + 2 * Iris._config.FramePadding.Y - Iris._config.ItemSpacing.Y))
            Selectable.BackgroundTransparency = 1
            Selectable.BorderSizePixel = 0

            local SelectableButton = Instance.new("TextButton")
            SelectableButton.Name = "SelectableButton"
            SelectableButton.Size = UDim2.new(1, 0, 0, Iris._config.TextSize + 2 * Iris._config.FramePadding.Y)
            SelectableButton.Position = UDim2.fromOffset(0, -bit32.rshift(Iris._config.ItemSpacing.Y, 1)) -- divide by 2
            SelectableButton.BackgroundColor3 = Iris._config.HeaderColor
            SelectableButton.ClipsDescendants = true

            widgets.applyFrameStyle(SelectableButton)
            widgets.applyTextStyle(SelectableButton)
            widgets.UISizeConstraint(SelectableButton, Vector2.xAxis)

            thisWidget.ButtonColors = {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderActiveColor,
                ActiveTransparency = Iris._config.HeaderActiveTransparency,
            }

            widgets.applyInteractionHighlights("Background", SelectableButton, SelectableButton, thisWidget.ButtonColors)

            widgets.applyButtonClick(SelectableButton, function()
                if thisWidget.arguments.NoClick ~= true then
                    if type(thisWidget.state.index.value) == "boolean" then
                        thisWidget.state.index:set(not thisWidget.state.index.value)
                    else
                        thisWidget.state.index:set(thisWidget.arguments.Index)
                    end
                end
            end)

            SelectableButton.Parent = Selectable

            return Selectable
        end,
        GenerateState = function(thisWidget: Types.Selectable)
            if thisWidget.state.index == nil then
                if thisWidget.arguments.Index ~= nil then
                    error("A shared state index is required for Iris.Selectables() with an Index argument.", 5)
                end
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", false)
            end
        end,
        Update = function(thisWidget: Types.Selectable)
            local Selectable = thisWidget.Instance :: Frame
            local SelectableButton: TextButton = Selectable.SelectableButton
            SelectableButton.Text = thisWidget.arguments.Text or "Selectable"
        end,
        UpdateState = function(thisWidget: Types.Selectable)
            local Selectable = thisWidget.Instance :: Frame
            local SelectableButton: TextButton = Selectable.SelectableButton
            
            if thisWidget.state.index.value == thisWidget.arguments.Index or thisWidget.state.index.value == true then
                thisWidget.ButtonColors.Transparency = Iris._config.HeaderTransparency
                SelectableButton.BackgroundTransparency = Iris._config.HeaderTransparency
                thisWidget.lastSelectedTick = Iris._cycleTick + 1
            else
                thisWidget.ButtonColors.Transparency = 1
                SelectableButton.BackgroundTransparency = 1
                thisWidget.lastUnselectedTick = Iris._cycleTick + 1
            end
        end,
        Discard = function(thisWidget: Types.Selectable)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)

	local AnyOpenedCombo = false
	local ComboOpenedTick = -1
	local OpenedCombo: Types.Combo? = nil
	local CachedContentSize = 0

	local function UpdateChildContainerTransform(thisWidget: Types.Combo)
		local Combo = thisWidget.Instance :: Frame
		local PreviewContainer = Combo.PreviewContainer :: TextButton
		local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame

		local previewPosition = PreviewContainer.AbsolutePosition - widgets.GuiOffset
		local previewSize = PreviewContainer.AbsoluteSize
		local borderSize = Iris._config.PopupBorderSize
		local screenSize: Vector2 = ChildContainer.Parent.AbsoluteSize

		local absoluteContentSize = thisWidget.UIListLayout.AbsoluteContentSize.Y
		CachedContentSize = absoluteContentSize

		local contentsSize = absoluteContentSize + 2 * Iris._config.WindowPadding.Y

		local x = previewPosition.X
		local y = previewPosition.Y + previewSize.Y + borderSize
		local anchor = Vector2.zero
		local distanceToScreen = screenSize.Y - y

		-- Only extend upwards if we cannot fully extend downwards, and we are on the bottom half of the screen.
		--  i.e. there is more space upwards than there is downwards.
		if contentsSize > distanceToScreen and y > (screenSize.Y / 2) then
			y = previewPosition.Y - borderSize
			anchor = Vector2.yAxis
			distanceToScreen = y -- from 0 to the current position
		end

		ChildContainer.AnchorPoint = anchor
		ChildContainer.Position = UDim2.fromOffset(x, y)

		local height = math.min(contentsSize, distanceToScreen)
		ChildContainer.Size = UDim2.fromOffset(PreviewContainer.AbsoluteSize.X, height)
	end

	table.insert(Iris._postCycleCallbacks, function()
		if AnyOpenedCombo and OpenedCombo then
			local contentSize = OpenedCombo.UIListLayout.AbsoluteContentSize.Y
			if contentSize ~= CachedContentSize then
				UpdateChildContainerTransform(OpenedCombo)
			end
		end
	end)

	local function UpdateComboState(input: InputObject)
		if not Iris._started then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.MouseButton2
			and input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseWheel
		then
			return
		end
		if AnyOpenedCombo == false or not OpenedCombo then
			return
		end
		if ComboOpenedTick == Iris._cycleTick then
			return
		end

		local MouseLocation = widgets.getMouseLocation()
		local Combo = OpenedCombo.Instance :: Frame
		local PreviewContainer: TextButton = Combo.PreviewContainer
		local ChildContainer = OpenedCombo.ChildContainer
		local rectMin = PreviewContainer.AbsolutePosition - widgets.GuiOffset
		local rectMax = PreviewContainer.AbsolutePosition - widgets.GuiOffset + PreviewContainer.AbsoluteSize
		if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
			return
		end

		rectMin = ChildContainer.AbsolutePosition - widgets.GuiOffset
		rectMax = ChildContainer.AbsolutePosition - widgets.GuiOffset + ChildContainer.AbsoluteSize
		if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
			return
		end

		OpenedCombo.state.isOpened:set(false)
	end

	widgets.registerEvent("InputBegan", UpdateComboState)

	widgets.registerEvent("InputChanged", UpdateComboState)

    --stylua: ignore
    Iris.WidgetConstructor("Combo", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
            ["NoButton"] = 2,
            ["NoPreview"] = 3,
        },
        Events = {
            ["opened"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastOpenedTick == Iris._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastClosedTick == Iris._cycleTick
                end,
            },
            ["changed"] = {
                ["Init"] = function(_thisWidget: Types.Combo) end,
                ["Get"] = function(thisWidget: Types.Combo)
                    return thisWidget.lastChangedTick == Iris._cycleTick
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget: Types.Widget)
                local Combo = thisWidget.Instance :: Frame
                return Combo.PreviewContainer
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget: Types.Widget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget: Types.Combo)
            local frameHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

            local Combo = Instance.new("Frame")
            Combo.Name = "Iris_Combo"
            Combo.AutomaticSize = Enum.AutomaticSize.Y
            Combo.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            Combo.BackgroundTransparency = 1
            Combo.BorderSizePixel = 0

            widgets.UIListLayout(Combo, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local PreviewContainer = Instance.new("TextButton")
            PreviewContainer.Name = "PreviewContainer"
            PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            PreviewContainer.Size = UDim2.new(Iris._config.ContentWidth, UDim.new(0, 0))
            PreviewContainer.BackgroundTransparency = 1
            PreviewContainer.Text = ""
            PreviewContainer.AutoButtonColor = false
            PreviewContainer.ZIndex = 2

            widgets.applyFrameStyle(PreviewContainer, true)
            widgets.UIListLayout(PreviewContainer, Enum.FillDirection.Horizontal, UDim.new(0, 0))
            widgets.UISizeConstraint(PreviewContainer, Vector2.new(frameHeight))

            PreviewContainer.Parent = Combo

            local PreviewLabel = Instance.new("TextLabel")
            PreviewLabel.Name = "PreviewLabel"
            PreviewLabel.AutomaticSize = Enum.AutomaticSize.Y
            PreviewLabel.Size = UDim2.new(UDim.new(1, 0), Iris._config.ContentHeight)
            PreviewLabel.BackgroundColor3 = Iris._config.FrameBgColor
            PreviewLabel.BackgroundTransparency = Iris._config.FrameBgTransparency
            PreviewLabel.BorderSizePixel = 0
            PreviewLabel.ClipsDescendants = true

            widgets.applyTextStyle(PreviewLabel)
            widgets.UIPadding(PreviewLabel, Iris._config.FramePadding)

            PreviewLabel.Parent = PreviewContainer

            local DropdownButton = Instance.new("TextLabel")
            DropdownButton.Name = "DropdownButton"
            DropdownButton.Size = UDim2.new(0, frameHeight, Iris._config.ContentHeight.Scale, math.max(Iris._config.ContentHeight.Offset, frameHeight))
            DropdownButton.BackgroundColor3 = Iris._config.ButtonColor
            DropdownButton.BackgroundTransparency = Iris._config.ButtonTransparency
            DropdownButton.BorderSizePixel = 0
            DropdownButton.Text = ""

            local padding = math.round(frameHeight * 0.2)
            local dropdownSize = frameHeight - 2 * padding

            local Dropdown = Instance.new("ImageLabel")
            Dropdown.Name = "Dropdown"
            Dropdown.AnchorPoint = Vector2.new(0.5, 0.5)
            Dropdown.Size = UDim2.fromOffset(dropdownSize, dropdownSize)
            Dropdown.Position = UDim2.fromScale(0.5, 0.5)
            Dropdown.BackgroundTransparency = 1
            Dropdown.BorderSizePixel = 0
            Dropdown.ImageColor3 = Iris._config.TextColor
            Dropdown.ImageTransparency = Iris._config.TextTransparency

            Dropdown.Parent = DropdownButton

            DropdownButton.Parent = PreviewContainer

            -- for some reason ImGui Combo has no highlights for Active, only hovered.
            -- so this deviates from ImGui, but its a good UX change
            widgets.applyInteractionHighlightsWithMultiHighlightee("Background", PreviewContainer, {
                {
                    PreviewLabel,
                    {
                        Color = Iris._config.FrameBgColor,
                        Transparency = Iris._config.FrameBgTransparency,
                        HoveredColor = Iris._config.FrameBgHoveredColor,
                        HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                        ActiveColor = Iris._config.FrameBgActiveColor,
                        ActiveTransparency = Iris._config.FrameBgActiveTransparency,
                    },
                },
                {
                    DropdownButton,
                    {
                        Color = Iris._config.ButtonColor,
                        Transparency = Iris._config.ButtonTransparency,
                        HoveredColor = Iris._config.ButtonHoveredColor,
                        HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                        -- Use hovered for active
                        ActiveColor = Iris._config.ButtonHoveredColor,
                        ActiveTransparency = Iris._config.ButtonHoveredTransparency,
                    },
                },
            })

            widgets.applyButtonClick(PreviewContainer, function()
                if AnyOpenedCombo and OpenedCombo ~= thisWidget then
                    return
                end
                thisWidget.state.isOpened:set(not thisWidget.state.isOpened.value)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = Combo

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "ComboContainer"
            ChildContainer.BackgroundColor3 = Iris._config.PopupBgColor
            ChildContainer.BackgroundTransparency = Iris._config.PopupBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Iris._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Iris._config.ScrollbarGrabColor
            ChildContainer.ScrollBarThickness = Iris._config.ScrollbarSize
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            -- appear over everything else
            ChildContainer.ClipsDescendants = true

            -- Unfortunatley, ScrollingFrame does not work with UICorner
            -- if Iris._config.PopupRounding > 0 then
            --     widgets.UICorner(ChildContainer, Iris._config.PopupRounding)
            -- end

            widgets.UIStroke(ChildContainer, Iris._config.WindowBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)
            widgets.UIPadding(ChildContainer, Vector2.new(2, Iris._config.WindowPadding.Y))
            widgets.UISizeConstraint(ChildContainer, Vector2.new(100))

            local ChildContainerUIListLayout = widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
            ChildContainerUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

            local RootPopupScreenGui = Iris._rootInstance and Iris._rootInstance:WaitForChild("PopupScreenGui") :: GuiObject
            ChildContainer.Parent = RootPopupScreenGui

            thisWidget.ChildContainer = ChildContainer
            thisWidget.UIListLayout = ChildContainerUIListLayout
            return Combo
        end,
        GenerateState = function(thisWidget: Types.Combo)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", "No Selection")
            end
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Iris._widgetState(thisWidget, "isOpened", false)
            end
            
            thisWidget.state.index:onChange(function()
                thisWidget.lastChangedTick = Iris._cycleTick + 1
                if thisWidget.state.isOpened.value then
                    thisWidget.state.isOpened:set(false)
                end
            end)
        end,
        Update = function(thisWidget: Types.Combo)
            local Iris_Combo = thisWidget.Instance :: Frame
            local PreviewContainer = Iris_Combo.PreviewContainer :: TextButton
            local PreviewLabel: TextLabel = PreviewContainer.PreviewLabel
            local DropdownButton: TextLabel = PreviewContainer.DropdownButton
            local TextLabel: TextLabel = Iris_Combo.TextLabel

            TextLabel.Text = thisWidget.arguments.Text or "Combo"

            if thisWidget.arguments.NoButton then
                DropdownButton.Visible = false
                PreviewLabel.Size = UDim2.new(UDim.new(1, 0), PreviewLabel.Size.Height)
            else
                DropdownButton.Visible = true
                local DropdownButtonSize = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y
                PreviewLabel.Size = UDim2.new(UDim.new(1, -DropdownButtonSize), PreviewLabel.Size.Height)
            end

            if thisWidget.arguments.NoPreview then
                PreviewLabel.Visible = false
                PreviewContainer.Size = UDim2.new(0, 0, 0, 0)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.XY
            else
                PreviewLabel.Visible = true
                PreviewContainer.Size = UDim2.new(Iris._config.ContentWidth, Iris._config.ContentHeight)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            end
        end,
        UpdateState = function(thisWidget: Types.Combo)
            local Combo = thisWidget.Instance :: Frame
            local ChildContainer = thisWidget.ChildContainer :: ScrollingFrame
            local PreviewContainer = Combo.PreviewContainer :: TextButton
            local PreviewLabel: TextLabel = PreviewContainer.PreviewLabel
            local DropdownButton = PreviewContainer.DropdownButton :: TextLabel
            local Dropdown: ImageLabel = DropdownButton.Dropdown

            if thisWidget.state.isOpened.value then
                AnyOpenedCombo = true
                OpenedCombo = thisWidget
                ComboOpenedTick = Iris._cycleTick
                thisWidget.lastOpenedTick = Iris._cycleTick + 1

                -- ImGui also does not do this, and the Arrow is always facing down
                Dropdown.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE
                ChildContainer.Visible = true

                UpdateChildContainerTransform(thisWidget)
            else
                if AnyOpenedCombo then
                    AnyOpenedCombo = false
                    OpenedCombo = nil
                    thisWidget.lastClosedTick = Iris._cycleTick + 1
                end
                Dropdown.Image = widgets.ICONS.DOWN_POINTING_TRIANGLE
                ChildContainer.Visible = false
            end

            local stateIndex = thisWidget.state.index.value
            PreviewLabel.Text = if typeof(stateIndex) == "EnumItem" then stateIndex.Name else tostring(stateIndex)
        end,
        ChildAdded = function(thisWidget: Types.Combo, _thisChild: Types.Widget)
            UpdateChildContainerTransform(thisWidget)
            return thisWidget.ChildContainer
        end,
        Discard = function(thisWidget: Types.Combo)
            -- If we are discarding the current combo active, we need to hide it
            if OpenedCombo and OpenedCombo == thisWidget then
                OpenedCombo = nil
                AnyOpenedCombo = false
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end,
    } :: Types.WidgetClass)
end
