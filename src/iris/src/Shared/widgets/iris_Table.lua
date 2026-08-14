--!nocheck
local Types = require(script.Parent.Parent.iris_Types)

-- Tables need an overhaul.

--[[
	Iris.Table(
		{
			NumColumns,
			Header,
			RowBackground,
			OuterBorders,
			InnerBorders
		}
	)

	Config = {
		CellPadding: Vector2,
		CellSize: UDim2,
	}

	Iris.NextColumn()
	Iris.NextRow()
	Iris.SetColumnIndex(index: number)
	Iris.SetRowIndex(index: number)

	Iris.NextHeaderColumn()
	Iris.SetHeaderColumnIndex(index: number)

	Iris.SetColumnWidth(index: number, width: number | UDim)
]]

return function(Iris: Types.Internal, widgets: Types.WidgetUtility)
	local Tables: { [Types.ID]: Types.Table } = {}
	local TableMinWidths: { [Types.Table]: { boolean } } = {}
	local AnyActiveTable = false
	local ActiveTable: Types.Table? = nil
	local ActiveColumn = 0
	local ActiveLeftWidth = -1
	local ActiveRightWidth = -1
	local MousePositionX = 0

	local function CalculateMinColumnWidth(thisWidget: Types.Table, index: number)
		local width = 0
		for _, row in thisWidget._cellInstances do
			local cell = row[index]
			for _, child in cell:GetChildren() do
				if child:IsA("GuiObject") then
					width = math.max(width, child.AbsoluteSize.X)
				end
			end
		end

		thisWidget._minWidths[index] = width + 2 * Iris._config.CellPadding.X
	end

	table.insert(Iris._postCycleCallbacks, function()
		for _, thisWidget in Tables do
			for rowIndex, cycleTick in thisWidget._rowCycles do
				if cycleTick < Iris._cycleTick - 1 then
					local Row = thisWidget._rowInstances[rowIndex]
					local RowBorder = thisWidget._rowBorders[rowIndex - 1]
					if Row ~= nil then
						Row:Destroy()
					end
					if RowBorder ~= nil then
						RowBorder:Destroy()
					end
					thisWidget._rowInstances[rowIndex] = nil
					thisWidget._rowBorders[rowIndex - 1] = nil
					thisWidget._cellInstances[rowIndex] = nil
					thisWidget._rowCycles[rowIndex] = nil
				end
			end

			thisWidget._rowIndex = 1
			thisWidget._columnIndex = 1

			-- update the border container size to be the same, albeit *every* frame!
			local Table = thisWidget.Instance :: Frame
			local BorderContainer: Frame = Table.BorderContainer
			BorderContainer.Size = UDim2.new(1, 0, 0, thisWidget._rowContainer.AbsoluteSize.Y)
			thisWidget._columnBorders[0].Size = UDim2.fromOffset(5, thisWidget._rowContainer.AbsoluteSize.Y)
		end

		for thisWidget, columns in TableMinWidths do
			local refresh = false
			for column, _ in columns do
				CalculateMinColumnWidth(thisWidget, column)
				refresh = true
			end
			if refresh then
				table.clear(columns)
				Iris._widgets["Table"].UpdateState(thisWidget)
			end
		end
	end)

	local function UpdateActiveColumn()
		if AnyActiveTable == false or ActiveTable == nil then
			return
		end

		local widths = ActiveTable.state.widths
		local NumColumns = ActiveTable.arguments.NumColumns
		local Table = ActiveTable.Instance :: Frame
		local BorderContainer = Table.BorderContainer :: Frame
		local Fixed = ActiveTable.arguments.FixedWidth
		local Padding = 2 * Iris._config.CellPadding.X

		if ActiveLeftWidth == -1 then
			ActiveLeftWidth = widths.value[ActiveColumn]
			if ActiveLeftWidth == 0 then
				ActiveLeftWidth = Padding / Table.AbsoluteSize.X
			end
			ActiveRightWidth = widths.value[ActiveColumn + 1] or -1
			if ActiveRightWidth == 0 then
				ActiveRightWidth = Padding / Table.AbsoluteSize.X
			end
		end

		local BorderX = Table.AbsolutePosition.X
		local LeftX: number -- the start of the current column
		-- local CurrentX: number = BorderContainer:FindFirstChild(`Border_{ActiveColumn}`).AbsolutePosition.X + 3 - BorderX -- the current column position
		local RightX: number -- the end of the next column
		if ActiveColumn == 1 then
			LeftX = 0
		else
			LeftX =
				math.floor(BorderContainer:FindFirstChild(`Border_{ActiveColumn - 1}`).AbsolutePosition.X + 3 - BorderX)
		end
		if ActiveColumn >= NumColumns - 1 then
			RightX = Table.AbsoluteSize.X
		else
			RightX =
				math.floor(BorderContainer:FindFirstChild(`Border_{ActiveColumn + 1}`).AbsolutePosition.X + 3 - BorderX)
		end

		local TableX: number = BorderX - widgets.GuiOffset.X
		local DeltaX: number = math.clamp(
			widgets.getMouseLocation().X,
			LeftX + TableX + Padding,
			RightX + TableX - Padding
		) - MousePositionX
		local LeftOffset = (MousePositionX - TableX) - LeftX
		local LeftRatio = ActiveLeftWidth / LeftOffset

		if Fixed then
			widths.value[ActiveColumn] =
				math.clamp(math.round(ActiveLeftWidth + DeltaX), Padding, Table.AbsoluteSize.X - LeftX)
		else
			local Change = LeftRatio * DeltaX
			widths.value[ActiveColumn] =
				math.clamp(ActiveLeftWidth + Change, 0, (RightX - LeftX - Padding) / Table.AbsoluteSize.X)
			if ActiveColumn < NumColumns then
				widths.value[ActiveColumn + 1] = math.clamp(ActiveRightWidth - Change, 0, 1)
			end
		end

		widths:set(widths.value, true)
	end

	local function ColumnMouseDown(thisWidget: Types.Table, index: number)
		AnyActiveTable = true
		ActiveTable = thisWidget
		ActiveColumn = index
		ActiveLeftWidth = -1
		ActiveRightWidth = -1
		MousePositionX = widgets.getMouseLocation().X
	end

	widgets.registerEvent("InputChanged", function()
		if not Iris._started then
			return
		end
		UpdateActiveColumn()
	end)

	widgets.registerEvent("InputEnded", function(inputObject: InputObject)
		if not Iris._started then
			return
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveTable then
			AnyActiveTable = false
			ActiveTable = nil
			ActiveColumn = 0
			ActiveLeftWidth = -1
			ActiveRightWidth = -1
			MousePositionX = 0
		end
	end)

	local function GenerateCell(_thisWidget: Types.Table, index: number, width: UDim, header: boolean)
		local Cell: TextButton
		if header then
			Cell = Instance.new("TextButton")
			Cell.Text = ""
			Cell.AutoButtonColor = false
		else
			Cell = (Instance.new("Frame") :: GuiObject) :: TextButton
		end
		Cell.Name = `Cell_{index}`
		Cell.AutomaticSize = Enum.AutomaticSize.Y
		Cell.Size = UDim2.new(width, UDim.new())
		Cell.BackgroundTransparency = 1
		Cell.ZIndex = index
		Cell.LayoutOrder = index
		Cell.ClipsDescendants = true

		if header then
			widgets.applyInteractionHighlights("Background", Cell, Cell, {
				Color = Iris._config.HeaderColor,
				Transparency = 1,
				HoveredColor = Iris._config.HeaderHoveredColor,
				HoveredTransparency = Iris._config.HeaderHoveredTransparency,
				ActiveColor = Iris._config.HeaderActiveColor,
				ActiveTransparency = Iris._config.HeaderActiveTransparency,
			})
		end

		widgets.UIPadding(Cell, Iris._config.CellPadding)
		widgets.UIListLayout(Cell, Enum.FillDirection.Vertical, UDim.new())
		widgets.UISizeConstraint(Cell, Vector2.new(2 * Iris._config.CellPadding.X, 0))

		return Cell
	end

	local function GenerateColumnBorder(thisWidget: Types.Table, index: number, style: "Light" | "Strong")
		local Border = Instance.new("ImageButton")
		Border.Name = `Border_{index}`
		Border.Size = UDim2.new(0, 5, 1, 0)
		Border.BackgroundTransparency = 1
		Border.Image = ""
		Border.ImageTransparency = 1
		Border.AutoButtonColor = false
		Border.ZIndex = index
		Border.LayoutOrder = 2 * index

		local offset = if index == thisWidget.arguments.NumColumns then 3 else 2

		local Line = Instance.new("Frame")
		Line.Name = "Line"
		Line.Size = UDim2.new(0, 1, 1, 0)
		Line.Position = UDim2.fromOffset(offset, 0)
		Line.BackgroundColor3 = Iris._config[`TableBorder{style}Color`]
		Line.BackgroundTransparency = Iris._config[`TableBorder{style}Transparency`]
		Line.BorderSizePixel = 0

		Line.Parent = Border

		local Hover = Instance.new("Frame")
		Hover.Name = "Hover"
		Hover.Position = UDim2.fromOffset(offset, 0)
		Hover.Size = UDim2.new(0, 1, 1, 0)
		Hover.BackgroundColor3 = Iris._config[`TableBorder{style}Color`]
		Hover.BackgroundTransparency = Iris._config[`TableBorder{style}Transparency`]
		Hover.BorderSizePixel = 0

		Hover.Visible = thisWidget.arguments.Resizable

		Hover.Parent = Border

		widgets.applyInteractionHighlights("Background", Border, Hover, {
			Color = Iris._config.ResizeGripColor,
			Transparency = 1,
			HoveredColor = Iris._config.ResizeGripHoveredColor,
			HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
			ActiveColor = Iris._config.ResizeGripActiveColor,
			ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
		})

		widgets.applyButtonDown(Border, function()
			if thisWidget.arguments.Resizable then
				ColumnMouseDown(thisWidget, index)
			end
		end)

		return Border
	end

	-- creates a new row and all columns, and adds all to the table's row and cell instance tables, but does not parent
	local function GenerateRow(thisWidget: Types.Table, index: number)
		local Row: Frame = Instance.new("Frame")
		Row.Name = `Row_{index}`
		Row.AutomaticSize = Enum.AutomaticSize.Y
		Row.Size = UDim2.fromScale(1, 0)
		if index == 0 then
			Row.BackgroundColor3 = Iris._config.TableHeaderColor
			Row.BackgroundTransparency = Iris._config.TableHeaderTransparency
		elseif thisWidget.arguments.RowBackground == true then
			if (index % 2) == 0 then
				Row.BackgroundColor3 = Iris._config.TableRowBgAltColor
				Row.BackgroundTransparency = Iris._config.TableRowBgAltTransparency
			else
				Row.BackgroundColor3 = Iris._config.TableRowBgColor
				Row.BackgroundTransparency = Iris._config.TableRowBgTransparency
			end
		else
			Row.BackgroundTransparency = 1
		end
		Row.BorderSizePixel = 0
		Row.ZIndex = 2 * index - 1
		Row.LayoutOrder = 2 * index - 1
		Row.ClipsDescendants = true

		widgets.UIListLayout(Row, Enum.FillDirection.Horizontal, UDim.new())

		thisWidget._cellInstances[index] = table.create(thisWidget.arguments.NumColumns)
		for columnIndex = 1, thisWidget.arguments.NumColumns do
			local Cell = GenerateCell(thisWidget, columnIndex, thisWidget._widths[columnIndex], index == 0)
			Cell.Parent = Row
			thisWidget._cellInstances[index][columnIndex] = Cell
		end

		thisWidget._rowInstances[index] = Row

		return Row
	end

	local function GenerateRowBorder(_thisWidget: Types.Table, index: number, style: "Light" | "Strong")
		local Border = Instance.new("Frame")
		Border.Name = `Border_{index}`
		Border.Size = UDim2.fromScale(1, 0)
		Border.BackgroundTransparency = 1
		Border.ZIndex = 2 * index
		Border.LayoutOrder = 2 * index

		local Line = Instance.new("Frame")
		Line.Name = "Line"
		Line.AnchorPoint = Vector2.new(0, 0.5)
		Line.Size = UDim2.new(1, 0, 0, 1)
		Line.BackgroundColor3 = Iris._config[`TableBorder{style}Color`]
		Line.BackgroundTransparency = Iris._config[`TableBorder{style}Transparency`]
		Line.BorderSizePixel = 0

		Line.Parent = Border

		return Border
	end

    --stylua: ignore
    Iris.WidgetConstructor("Table", {
        hasState = true,
        hasChildren = true,
        Args = {
            NumColumns = 1,
            Header = 2,
            RowBackground = 3,
            OuterBorders = 4,
            InnerBorders = 5,
            Resizable = 6,
            FixedWidth = 7,
            ProportionalWidth = 8,
            LimitTableWidth = 9,
        },
        Events = {},
        Generate = function(thisWidget: Types.Table)
            Tables[thisWidget.ID] = thisWidget
            TableMinWidths[thisWidget] = {}

            local Table = Instance.new("Frame")
            Table.Name = "Iris_Table"
            Table.AutomaticSize = Enum.AutomaticSize.Y
            Table.Size = UDim2.fromScale(1, 0)
            Table.BackgroundTransparency = 1

            local RowContainer = Instance.new("Frame")
            RowContainer.Name = "RowContainer"
            RowContainer.AutomaticSize = Enum.AutomaticSize.Y
            RowContainer.Size = UDim2.fromScale(1, 0)
            RowContainer.BackgroundTransparency = 1
            RowContainer.ZIndex = 1

            widgets.UISizeConstraint(RowContainer)
            widgets.UIListLayout(RowContainer, Enum.FillDirection.Vertical, UDim.new())

            RowContainer.Parent = Table
			thisWidget._rowContainer = RowContainer

            local BorderContainer = Instance.new("Frame")
            BorderContainer.Name = "BorderContainer"
            BorderContainer.Size = UDim2.fromScale(1, 1)
            BorderContainer.BackgroundTransparency = 1
            BorderContainer.ZIndex = 2
            BorderContainer.ClipsDescendants = true

            widgets.UISizeConstraint(BorderContainer)            
            widgets.UIListLayout(BorderContainer, Enum.FillDirection.Horizontal, UDim.new())
            widgets.UIStroke(BorderContainer, 1, Iris._config.TableBorderStrongColor, Iris._config.TableBorderStrongTransparency)

            BorderContainer.Parent = Table

            thisWidget._columnIndex = 1
            thisWidget._rowIndex = 1
            thisWidget._rowInstances = {}
            thisWidget._cellInstances = {}
            thisWidget._rowBorders = {}
            thisWidget._columnBorders = {}
            thisWidget._rowCycles = {}

            local callbackIndex = #Iris._postCycleCallbacks + 1
            local desiredCycleTick = Iris._cycleTick + 1
            Iris._postCycleCallbacks[callbackIndex] = function()
                if Iris._cycleTick >= desiredCycleTick then
                    if thisWidget.lastCycleTick ~= -1 then
                        thisWidget.state.widths.lastChangeTick = Iris._cycleTick
                        Iris._widgets["Table"].UpdateState(thisWidget)
                    end
                    Iris._postCycleCallbacks[callbackIndex] = nil
                end
            end

            return Table
        end,
        GenerateState = function(thisWidget: Types.Table)
            local NumColumns = thisWidget.arguments.NumColumns
            if thisWidget.state.widths == nil then
                local Widths: { number } = table.create(NumColumns, 1 / NumColumns)
                thisWidget.state.widths = Iris._widgetState(thisWidget, "widths", Widths)
            end
            thisWidget._widths = table.create(NumColumns, UDim.new())
            thisWidget._minWidths = table.create(NumColumns, 0)

            local Table = thisWidget.Instance :: Frame
            local BorderContainer: Frame = Table.BorderContainer

            thisWidget._cellInstances[-1] = table.create(NumColumns)
            for index = 1, NumColumns do
                local Border = GenerateColumnBorder(thisWidget, index, "Light")
                Border.Visible = thisWidget.arguments.InnerBorders
                thisWidget._columnBorders[index] = Border
                Border.Parent = BorderContainer

                local Cell = GenerateCell(thisWidget, index, thisWidget._widths[index], false)
                local UISizeConstraint = Cell:FindFirstChild("UISizeConstraint") :: UISizeConstraint
                UISizeConstraint.MinSize = Vector2.new(
                    2 * Iris._config.CellPadding.X + (if index > 1 then -2 else 0) + (if index < NumColumns then -3 else 0),
                    0
                )
                Cell.LayoutOrder = 2 * index - 1
                thisWidget._cellInstances[-1][index] = Cell
                Cell.Parent = BorderContainer
            end

            local TableColumnBorder = GenerateColumnBorder(thisWidget, NumColumns, "Strong")
            thisWidget._columnBorders[0] = TableColumnBorder
            TableColumnBorder.Parent = Table
        end,
        Update = function(thisWidget: Types.Table)
            local NumColumns = thisWidget.arguments.NumColumns
            assert(NumColumns >= 1, "Iris.Table must have at least one column.")

            if thisWidget._widths ~= nil and #thisWidget._widths ~= NumColumns then
                -- disallow changing the number of columns. It's too much effort
                thisWidget.arguments.NumColumns = #thisWidget._widths
                warn("NumColumns cannot change once set. See documentation.")
            end

            for rowIndex, row in thisWidget._rowInstances do
                if rowIndex == 0 then
                    row.BackgroundColor3 = Iris._config.TableHeaderColor
                    row.BackgroundTransparency = Iris._config.TableHeaderTransparency
                elseif thisWidget.arguments.RowBackground == true then
                    if (rowIndex % 2) == 0 then
                        row.BackgroundColor3 = Iris._config.TableRowBgAltColor
                        row.BackgroundTransparency = Iris._config.TableRowBgAltTransparency
                    else
                        row.BackgroundColor3 = Iris._config.TableRowBgColor
                        row.BackgroundTransparency = Iris._config.TableRowBgTransparency
                    end
                else
                    row.BackgroundTransparency = 1
                end
            end
            
            for _, Border: Frame in thisWidget._rowBorders do
                Border.Visible = thisWidget.arguments.InnerBorders
            end

            for _, Border: GuiButton in thisWidget._columnBorders do
                Border.Visible = thisWidget.arguments.InnerBorders or thisWidget.arguments.Resizable
            end

            for _, border in thisWidget._columnBorders do
                local hover = border:FindFirstChild("Hover") :: Frame?
                if hover then
                    hover.Visible = thisWidget.arguments.Resizable
                end
            end

            if thisWidget._columnBorders[NumColumns] ~= nil then
                thisWidget._columnBorders[NumColumns].Visible =
                    not thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.InnerBorders)
                thisWidget._columnBorders[0].Visible =
                    thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.OuterBorders)
            end
            
            -- the header border visibility must be updated after settings all borders
            -- visiblity or not
            local HeaderRow: Frame? = thisWidget._rowInstances[0]
            local HeaderBorder: Frame? = thisWidget._rowBorders[0]
            if HeaderRow ~= nil then
                HeaderRow.Visible = thisWidget.arguments.Header
            end
            if HeaderBorder ~= nil then
                HeaderBorder.Visible = thisWidget.arguments.Header and thisWidget.arguments.InnerBorders
            end

            local Table = thisWidget.Instance :: Frame
            local BorderContainer = Table.BorderContainer :: Frame
            BorderContainer.UIStroke.Enabled = thisWidget.arguments.OuterBorders

            for index = 1, thisWidget.arguments.NumColumns do
                TableMinWidths[thisWidget][index] = true
            end

            if thisWidget._widths ~= nil then
                Iris._widgets["Table"].UpdateState(thisWidget)
            end
        end,
        UpdateState = function(thisWidget: Types.Table)
            local Table = thisWidget.Instance :: Frame
            local BorderContainer = Table.BorderContainer :: Frame
            local RowContainer = Table.RowContainer :: Frame
            local NumColumns = thisWidget.arguments.NumColumns
            local ColumnWidths = thisWidget.state.widths.value
            local MinWidths = thisWidget._minWidths
            
            local Fixed = thisWidget.arguments.FixedWidth
            local Proportional = thisWidget.arguments.ProportionalWidth

            if not thisWidget.arguments.Resizable then
                if Fixed then
                    if Proportional then
                        for index = 1, NumColumns do
                            ColumnWidths[index] = MinWidths[index]
                        end
                    else
                        local maxWidth = 0
                        for _, width in MinWidths do
                            maxWidth = math.max(maxWidth, width)
                        end
                        for index = 1, NumColumns do
                            ColumnWidths[index] = maxWidth
                        end
                    end
                else
                    if Proportional then
                        local TotalWidth = 0
                        for _, width in MinWidths do
                            TotalWidth += width
                        end
                        local Ratio = 1 / TotalWidth
                        for index = 1, NumColumns do
                            ColumnWidths[index] = Ratio * MinWidths[index]
                        end
                    else
                        local width = 1 / NumColumns
                        for index = 1, NumColumns do
                            ColumnWidths[index] = width
                        end
                    end
                end
            end

            local Position = UDim.new()
            for index = 1, NumColumns do
                local ColumnWidth = ColumnWidths[index]

                local Width = UDim.new(
                    if Fixed then 0 else math.clamp(ColumnWidth, 0, 1),
                    if Fixed then math.max(ColumnWidth, 0) else 0
                )
                thisWidget._widths[index] = Width
                Position += Width

                for _, row in thisWidget._cellInstances do
                    row[index].Size = UDim2.new(Width, UDim.new())
                end

                thisWidget._cellInstances[-1][index].Size = UDim2.new(Width + UDim.new(0,
                    (if index > 1 then -2 else 0) - 3
                ), UDim.new())
            end

            -- if the table has a fixed width and we want to cap it, we calculate the table width necessary
            local Width = Position.Offset
            if not thisWidget.arguments.FixedWidth or not thisWidget.arguments.LimitTableWidth then
                Width = math.huge
            end

            BorderContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            RowContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            thisWidget._columnBorders[0].Position = UDim2.fromOffset(Width - 3, 0)
        end,
        ChildAdded = function(thisWidget: Types.Table, _: Types.Widget)
            local rowIndex = thisWidget._rowIndex
            local columnIndex = thisWidget._columnIndex
            -- determine if the row exists yet
            local Row = thisWidget._rowInstances[rowIndex]
            thisWidget._rowCycles[rowIndex] = Iris._cycleTick
            TableMinWidths[thisWidget][columnIndex] = true

            if Row ~= nil then
                return thisWidget._cellInstances[rowIndex][columnIndex]
            end

            Row = GenerateRow(thisWidget, rowIndex)
            if rowIndex == 0 then
                Row.Visible = thisWidget.arguments.Header
            end
            Row.Parent = thisWidget._rowContainer

            if rowIndex > 0 then
                local Border = GenerateRowBorder(thisWidget, rowIndex - 1, if rowIndex == 1 then "Strong" else "Light")
                Border.Visible = thisWidget.arguments.InnerBorders and (if rowIndex == 1 then (thisWidget.arguments.Header and thisWidget.arguments.InnerBorders) and (thisWidget._rowInstances[0] ~= nil) else true)
                thisWidget._rowBorders[rowIndex - 1] = Border
                Border.Parent = thisWidget._rowContainer
            end

            return thisWidget._cellInstances[rowIndex][columnIndex]
        end,
        ChildDiscarded = function(thisWidget: Types.Table, thisChild: Types.Widget)
            local Cell = thisChild.Instance.Parent

            if Cell ~= nil then
                local columnIndex = tonumber(Cell.Name:sub(6))
                
                if columnIndex then
                    TableMinWidths[thisWidget][columnIndex] = true
                end
            end
        end,
        Discard = function(thisWidget: Types.Table)
            Tables[thisWidget.ID] = nil
            TableMinWidths[thisWidget] = nil
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end
    } :: Types.WidgetClass)
end
