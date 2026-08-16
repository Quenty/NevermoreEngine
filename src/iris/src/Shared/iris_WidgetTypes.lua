--!nocheck
--[=[
    @within Iris
    @type ID string
]=]
export type ID = string

--[=[
    @within State
    @type State<T> { ID: ID, value: T, get: (self) -> T, set: (self, newValue: T) -> T, onChange: (self, callback: (newValue: T) -> ()) -> (), ConnectedWidgets: { [ID]: Widget }, ConnectedFunctions: { (newValue: T) -> () } }
]=]
export type State<T> = {
	ID: ID,
	value: T,
	lastChangeTick: number,
	ConnectedWidgets: { [ID]: Widget },
	ConnectedFunctions: { (newValue: T) -> () },

	get: (self: State<T>) -> T,
	set: (self: State<T>, newValue: T, force: true?) -> (),
	onChange: (self: State<T>, funcToConnect: (newValue: T) -> ()) -> () -> (),
	changed: (self: State<T>) -> boolean,
}

--[=[
    @within Iris
    @type Widget { ID: ID, type: string, lastCycleTick: number, parentWidget: Widget, Instance: GuiObject, ZIndex: number, arguments: { [string]: any }}
]=]
export type Widget = {
	ID: ID,
	type: string,
	lastCycleTick: number,
	trackedEvents: {},
	parentWidget: ParentWidget,

	arguments: {},
	providedArguments: {},

	Instance: GuiObject,
	ZIndex: number,
}

export type ParentWidget = Widget & {
	ChildContainer: GuiObject,
	ZOffset: number,
	ZUpdate: boolean,
}

export type StateWidget = Widget & {
	state: {
		[string]: State<any>,
	},
}

-- Events

export type Hovered = {
	isHoveredEvent: boolean,
	hovered: () -> boolean,
}

export type Clicked = {
	lastClickedTick: number,
	clicked: () -> boolean,
}

export type RightClicked = {
	lastRightClickedTick: number,
	rightClicked: () -> boolean,
}

export type DoubleClicked = {
	lastClickedTime: number,
	lastClickedPosition: Vector2,
	lastDoubleClickedTick: number,
	doubleClicked: () -> boolean,
}

export type CtrlClicked = {
	lastCtrlClickedTick: number,
	ctrlClicked: () -> boolean,
}

export type Active = {
	active: () -> boolean,
}

export type Checked = {
	lastCheckedTick: number,
	checked: () -> boolean,
}

export type Unchecked = {
	lastUncheckedTick: number,
	unchecked: () -> boolean,
}

export type Opened = {
	lastOpenedTick: number,
	opened: () -> boolean,
}

export type Closed = {
	lastClosedTick: number,
	closed: () -> boolean,
}

export type Collapsed = {
	lastCollapsedTick: number,
	collapsed: () -> boolean,
}

export type Uncollapsed = {
	lastUncollapsedTick: number,
	uncollapsed: () -> boolean,
}

export type Selected = {
	lastSelectedTick: number,
	selected: () -> boolean,
}

export type Unselected = {
	lastUnselectedTick: number,
	unselected: () -> boolean,
}

export type Changed = {
	lastChangedTick: number,
	changed: () -> boolean,
}

export type NumberChanged = {
	lastNumberChangedTick: number,
	numberChanged: () -> boolean,
}

export type TextChanged = {
	lastTextChangedTick: number,
	textChanged: () -> boolean,
}

-- Widgets

-- Window

export type Root = ParentWidget

export type Window = ParentWidget & {
	usesScreenGuis: boolean,

	arguments: {
		Title: string?,
		NoTitleBar: boolean?,
		NoBackground: boolean?,
		NoCollapse: boolean?,
		NoClose: boolean?,
		NoMove: boolean?,
		NoScrollbar: boolean?,
		NoResize: boolean?,
		NoNav: boolean?,
		NoMenu: boolean?,
	},

	state: {
		size: State<Vector2>,
		position: State<Vector2>,
		isUncollapsed: State<boolean>,
		isOpened: State<boolean>,
		scrollDistance: State<number>,
	},
} & Opened & Closed & Collapsed & Uncollapsed & Hovered

export type Tooltip = Widget & {
	arguments: {
		Text: string,
	},
}

-- Menu

export type MenuBar = ParentWidget

export type Menu = ParentWidget & {
	ButtonColors: { [string]: Color3 | number },

	arguments: {
		Text: string?,
	},

	state: {
		isOpened: State<boolean>,
	},
} & Clicked & Opened & Closed & Hovered

export type MenuItem = Widget & {
	arguments: {
		Text: string,
		KeyCode: Enum.KeyCode?,
		ModifierKey: Enum.ModifierKey?,
	},
} & Clicked & Hovered

export type MenuToggle = Widget & {
	arguments: {
		Text: string,
		KeyCode: Enum.KeyCode?,
		ModifierKey: Enum.ModifierKey?,
	},

	state: {
		isChecked: State<boolean>,
	},
} & Checked & Unchecked & Hovered

-- Format

export type Separator = Widget

export type Indent = ParentWidget & {
	arguments: {
		Width: number?,
	},
}

export type SameLine = ParentWidget & {
	arguments: {
		Width: number?,
		VerticalAlignment: Enum.VerticalAlignment?,
		HorizontalAlignment: Enum.HorizontalAlignment?,
	},
}

export type Group = ParentWidget

-- Text

export type Text = Widget & {
	arguments: {
		Text: string,
		Wrapped: boolean?,
		Color: Color3?,
		RichText: boolean?,
	},
} & Hovered

export type SeparatorText = Widget & {
	arguments: {
		Text: string,
	},
} & Hovered

-- Basic

export type Button = Widget & {
	arguments: {
		Text: string?,
		Size: UDim2?,
	},
} & Clicked & RightClicked & DoubleClicked & CtrlClicked & Hovered

export type Checkbox = Widget & {
	arguments: {
		Text: string?,
	},

	state: {
		isChecked: State<boolean>,
	},
} & Unchecked & Checked & Hovered

export type RadioButton = Widget & {
	arguments: {
		Text: string?,
		Index: any,
	},

	state: {
		index: State<any>,
	},

	active: () -> boolean,
} & Selected & Unselected & Active & Hovered

-- Image

export type Image = Widget & {
	arguments: {
		Image: string,
		Size: UDim2,
		Rect: Rect?,
		ScaleType: Enum.ScaleType?,
		TileSize: UDim2?,
		SliceCenter: Rect?,
		SliceScale: number?,
		ResampleMode: Enum.ResamplerMode?,
	},
} & Hovered

-- ooops, may have overriden a Roblox type, and then got a weird type message
-- let's just hope I don't have to use a Roblox ImageButton type anywhere by name in this file
export type ImageButton = Image & Clicked & RightClicked & DoubleClicked & CtrlClicked

-- Tree

export type Tree = CollapsingHeader & {
	arguments: {
		Text: string,
		SpanAvailWidth: boolean?,
		NoIndent: boolean?,
		DefaultOpen: true?,
	},
}

export type CollapsingHeader = ParentWidget & {
	arguments: {
		Text: string?,
		DefaultOpen: true?,
	},

	state: {
		isUncollapsed: State<boolean>,
	},
} & Collapsed & Uncollapsed & Hovered

-- Tabs

export type TabBar = ParentWidget & {
	Tabs: { Tab },

	state: {
		index: State<number>,
	},
}

export type Tab = ParentWidget & {
	parentWidget: TabBar,
	Index: number,
	ButtonColors: { [string]: Color3 | number },

	arguments: {
		Text: string,
		Hideable: boolean,
	},

	state: {
		index: State<number>,
		isOpened: State<boolean>,
	},
} & Clicked & Opened & Selected & Unselected & Active & Closed & Hovered

-- Input
export type Input<T> = Widget & {
	lastClickedTime: number,
	lastClickedPosition: Vector2,

	arguments: {
		Text: string?,
		Increment: T,
		Min: T,
		Max: T,
		Format: { string },
		Prefix: { string },
		NoButtons: boolean?,
	},

	state: {
		number: State<T>,
		editingText: State<number>,
	},
} & NumberChanged & Hovered

export type InputColor3 = Input<{ number }> & {
	arguments: {
		UseFloats: boolean?,
		UseHSV: boolean?,
	},

	state: {
		color: State<Color3>,
		editingText: State<boolean>,
	},
} & NumberChanged & Hovered

export type InputColor4 = InputColor3 & {
	state: {
		transparency: State<number>,
	},
}

export type InputEnum = Input<number> & {
	state: {
		enumItem: State<EnumItem>,
	},
}

export type InputText = Widget & {
	arguments: {
		Text: string?,
		TextHint: string?,
		ReadOnly: boolean?,
		MultiLine: boolean?,
	},

	state: {
		text: State<string>,
	},
} & TextChanged & Hovered

-- Combo

export type Selectable = Widget & {
	ButtonColors: { [string]: Color3 | number },

	arguments: {
		Text: string?,
		Index: any?,
		NoClick: boolean?,
	},

	state: {
		index: State<any>,
	},
} & Selected & Unselected & Clicked & RightClicked & DoubleClicked & CtrlClicked & Hovered

export type Combo = ParentWidget & {
	arguments: {
		Text: string?,
		NoButton: boolean?,
		NoPreview: boolean?,
	},

	state: {
		index: State<any>,
		isOpened: State<boolean>,
	},

	UIListLayout: UIListLayout,
} & Opened & Closed & Changed & Clicked & Hovered

-- Plot

export type ProgressBar = Widget & {
	arguments: {
		Text: string?,
		Format: string?,
	},

	state: {
		progress: State<number>,
	},
} & Changed & Hovered

export type PlotLines = Widget & {
	Lines: { Frame },
	HoveredLine: Frame | false,
	Tooltip: TextLabel,

	arguments: {
		Text: string,
		Height: number,
		Min: number,
		Max: number,
		TextOverlay: string,
	},

	state: {
		values: State<{ number }>,
		hovered: State<{ number }?>,
	},
} & Hovered

export type PlotHistogram = Widget & {
	Blocks: { Frame },
	HoveredBlock: Frame | false,
	Tooltip: TextLabel,

	arguments: {
		Text: string,
		Height: number,
		Min: number,
		Max: number,
		TextOverlay: string,
		BaseLine: number,
	},

	state: {
		values: State<{ number }>,
		hovered: State<number?>,
	},
} & Hovered

-- ImPlot (extra widgets; not PlotLines/PlotHistogram)

export type ImPlotPieChart = Widget & {
	ChunkDataContainer: Frame,
	PieChart: any,

	arguments: {
		pieData: {
			{
				Name: string?,
				Color: Color3?,
				Value: number,
			}
		},
	},

	state: {
		showPieData: State<boolean>,
		normalize: State<boolean>,
	},
}

export type ImPlotGraph = Widget & {
	Graph: any,
	XMeterTape: any,
	YMeterTape: any,

	NameLabel: TextLabel,
	XLabel: TextLabel,
	YLabel: TextLabel,

	DataInformation: Frame,
	Tooltip: TextLabel?,
	TooltipConnection: RBXScriptConnection?,

	arguments: {
		GraphName: string?,
		Axes: {
			XScale: number?,
			X: string?,
			YScale: number?,
			Y: string?,
		}?,
	},

	state: {
		showDataInformation: State<boolean>,
		size: State<Vector2>,
		plots: State<{
			{
				Name: string?,
				Data: { Vector2 },
				MarkerStyle: {
					Shape: "Circle" | "Square",
					Color: Color3,
					Size: number,
					Transparency: number,
				}?,
				GraphStyle: {
					Color: Color3,
					Thickness: number,
				}?,
			}
		}>,
	},
}

export type Table = ParentWidget & {
	_columnIndex: number,
	_rowIndex: number,
	_rowContainer: Frame,
	_rowInstances: { Frame },
	_cellInstances: { { Frame } },
	_rowBorders: { Frame },
	_columnBorders: { GuiButton },
	_rowCycles: { number },
	_widths: { UDim },
	_minWidths: { number },

	arguments: {
		NumColumns: number,
		Header: boolean,
		RowBackground: boolean,
		OuterBorders: boolean,
		InnerBorders: boolean,
		Resizable: boolean,
		FixedWidth: boolean,
		ProportionalWidth: boolean,
		LimitTableWidth: boolean,
	},

	state: {
		widths: State<{ number }>,
	},
} & Hovered

return {}
