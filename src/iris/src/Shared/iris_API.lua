--!nocheck
local Types = require(script.Parent.iris_Types)

return function(Iris: Types.Iris)
	local function wrapper(name)
		return function(arguments, states)
			return Iris.Internal._Insert(name, arguments, states)
		end
	end

	Iris.Window = wrapper("Window")

	Iris.SetFocusedWindow = Iris.Internal.SetFocusedWindow

	Iris.Tooltip = wrapper("Tooltip")

	Iris.MenuBar = wrapper("MenuBar")

	Iris.Menu = wrapper("Menu")

	Iris.MenuItem = wrapper("MenuItem")

	Iris.MenuToggle = wrapper("MenuToggle")

	Iris.Separator = wrapper("Separator")

	Iris.Indent = wrapper("Indent")

	Iris.SameLine = wrapper("SameLine")

	Iris.Group = wrapper("Group")

	Iris.Text = wrapper("Text")

	Iris.TextWrapped = function(arguments: Types.WidgetArguments)
		arguments[2] = true
		return Iris.Internal._Insert("Text", arguments)
	end

	Iris.TextColored = function(arguments: Types.WidgetArguments)
		arguments[3] = arguments[2]
		arguments[2] = nil
		return Iris.Internal._Insert("Text", arguments)
	end

	Iris.SeparatorText = wrapper("SeparatorText")

	Iris.InputText = wrapper("InputText")

	Iris.Button = wrapper("Button")

	Iris.SmallButton = wrapper("SmallButton")

	Iris.Checkbox = wrapper("Checkbox")

	Iris.RadioButton = wrapper("RadioButton")

	Iris.Image = wrapper("Image")

	Iris.ImageButton = wrapper("ImageButton")

	Iris.Tree = wrapper("Tree")

	Iris.CollapsingHeader = wrapper("CollapsingHeader")

	Iris.TabBar = wrapper("TabBar")

	Iris.Tab = wrapper("Tab")

	Iris.InputNum = wrapper("InputNum")

	Iris.InputVector2 = wrapper("InputVector2")

	Iris.InputVector3 = wrapper("InputVector3")

	Iris.InputUDim = wrapper("InputUDim")

	Iris.InputUDim2 = wrapper("InputUDim2")

	Iris.InputRect = wrapper("InputRect")

	Iris.DragNum = wrapper("DragNum")

	Iris.DragVector2 = wrapper("DragVector2")

	Iris.DragVector3 = wrapper("DragVector3")

	Iris.DragUDim = wrapper("DragUDim")

	Iris.DragUDim2 = wrapper("DragUDim2")

	Iris.DragRect = wrapper("DragRect")

	Iris.InputColor3 = wrapper("InputColor3")

	Iris.InputColor4 = wrapper("InputColor4")

	Iris.SliderNum = wrapper("SliderNum")

	Iris.SliderVector2 = wrapper("SliderVector2")

	Iris.SliderVector3 = wrapper("SliderVector3")

	Iris.SliderUDim = wrapper("SliderUDim")

	Iris.SliderUDim2 = wrapper("SliderUDim2")

	Iris.SliderRect = wrapper("SliderRect")

	Iris.Selectable = wrapper("Selectable")

	Iris.Combo = wrapper("Combo")

	Iris.ComboArray = function<T>(arguments: Types.WidgetArguments, states: Types.WidgetStates?, selectionArray: { T })
		local defaultState
		if states == nil then
			defaultState = Iris.State(selectionArray[1])
		else
			defaultState = states
		end
		local thisWidget = Iris.Internal._Insert("Combo", arguments, defaultState)
		local sharedIndex = thisWidget.state.index
		for _, Selection in selectionArray do
			Iris.Internal._Insert("Selectable", { Selection, Selection }, { index = sharedIndex })
		end
		Iris.End()

		return thisWidget
	end

	Iris.ComboEnum = function(arguments: Types.WidgetArguments, states: Types.WidgetStates?, enumType: Enum)
		local defaultState
		if states == nil then
			defaultState = Iris.State(enumType:GetEnumItems()[1])
		else
			defaultState = states
		end
		local thisWidget = Iris.Internal._Insert("Combo", arguments, defaultState)
		local sharedIndex = thisWidget.state.index
		for _, Selection in enumType:GetEnumItems() do
			Iris.Internal._Insert("Selectable", { Selection.Name, Selection }, { index = sharedIndex })
		end
		Iris.End()

		return thisWidget
	end

	Iris.InputEnum = Iris.ComboEnum

	Iris.ProgressBar = wrapper("ProgressBar")

	Iris.PlotLines = wrapper("PlotLines")

	Iris.PlotHistogram = wrapper("PlotHistogram")

	Iris.ImPlotGraph = wrapper("ImPlotGraph")

	Iris.ImPlotPieChart = wrapper("ImPlotPieChart")

	Iris.Table = wrapper("Table")

	Iris.NextColumn = function()
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.NextColumn() can only called when directly within a table.")

		local columnIndex = Table._columnIndex
		if columnIndex == Table.arguments.NumColumns then
			Table._columnIndex = 1
			Table._rowIndex += 1
		else
			Table._columnIndex += 1
		end
		return Table._columnIndex
	end

	Iris.NextRow = function()
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.NextRow() can only called when directly within a table.")
		Table._columnIndex = 1
		Table._rowIndex += 1
		return Table._rowIndex
	end

	Iris.SetColumnIndex = function(index: number)
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.SetColumnIndex() can only called when directly within a table.")
		assert(
			(index >= 1) and (index <= Table.arguments.NumColumns),
			`The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`
		)
		Table._columnIndex = index
	end

	Iris.SetRowIndex = function(index: number)
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.SetRowIndex() can only called when directly within a table.")
		assert(index >= 1, "The index must be greater or equal to 1.")
		Table._rowIndex = index
	end

	Iris.NextHeaderColumn = function()
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.NextHeaderColumn() can only called when directly within a table.")

		Table._rowIndex = 0
		Table._columnIndex = (Table._columnIndex % Table.arguments.NumColumns) + 1

		return Table._columnIndex
	end

	Iris.SetHeaderColumnIndex = function(index: number)
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.SetHeaderColumnIndex() can only called when directly within a table.")
		assert(
			(index >= 1) and (index <= Table.arguments.NumColumns),
			`The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`
		)

		Table._rowIndex = 0
		Table._columnIndex = index
	end

	Iris.SetColumnWidth = function(index: number, width: number)
		local Table = Iris.Internal._GetParentWidget() :: Types.Table
		assert(Table ~= nil, "Iris.SetColumnWidth() can only called when directly within a table.")
		assert(
			(index >= 1) and (index <= Table.arguments.NumColumns),
			`The index must be between 1 and {Table.arguments.NumColumns}, inclusive.`
		)

		local oldValue = Table.state.widths.value[index]
		Table.state.widths.value[index] = width
		Table.state.widths:set(Table.state.widths.value, width ~= oldValue)
	end
end
