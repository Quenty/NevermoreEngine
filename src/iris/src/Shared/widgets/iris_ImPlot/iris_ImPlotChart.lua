--!strict
local Path2D = require(script.Parent.iris_ImPlotPath2D)
local Util = require(script.Parent.iris_ImPlotUtil)

local table_clear = table.clear
local table_insert = table.insert
local min = math.min
local max = math.max

local function Square(Color: Color3, Scale: number, Transparency: number)
	local ui_object = Instance.new("Frame")
	ui_object.Size = UDim2.fromOffset(Scale, Scale)
	ui_object.BackgroundColor3 = Color
	ui_object.AnchorPoint = Vector2.new(0.5, 0.5)
	ui_object.BackgroundTransparency = Transparency

	local stroke = Instance.new("UIStroke")
	stroke.Parent = ui_object
	stroke.Color = Color
	stroke.Thickness = 1

	return ui_object
end

local function Circle(Color: Color3, Scale: number, Transparency: number)
	local ui_object = Square(Color, Scale, Transparency)
	local ui_corner = Instance.new("UICorner")
	ui_corner.Parent = ui_object
	ui_corner.CornerRadius = UDim.new(1, 0)

	return ui_object
end

local function GraphXYToScaleUDIM2(
	MinX: number,
	XRange: number,
	MinY: number,
	YRange: number,
	XScale: number,
	YScale: number,
	x: number,
	y: number
)
	local centerX = MinX + XRange / 2

	local xScale = ((x - centerX) / XRange) * XScale + 0.5
	local yScale = 1 - (((y - MinY) / YRange) * YScale)

	return UDim2.fromScale(xScale, yScale)
end

local function MarkerXYToScaleUDIM2(
	MinX: number,
	XRange: number,
	MinY: number,
	YRange: number,
	XScale: number,
	YScale: number,
	x: number,
	y: number
)
	local centerX = MinX + XRange / 2
	local centerY = MinY + YRange / 2

	local xScale = ((x - centerX) / XRange) * XScale + 0.5
	local yScale = 1 - (((y - centerY) / YRange) * YScale + 0.5)

	return UDim2.fromScale(xScale, yScale)
end

local Chart = {}
Chart.__index = Chart

function Chart.new()
	local self = setmetatable({} :: self, Chart)
	self._chart_data = {}
	self._paths = {}

	self.Canvas = Instance.new("CanvasGroup")
	self.Canvas.BackgroundTransparency = 1
	self.Canvas.Size = UDim2.fromScale(1, 1)

	self.XScale = 1
	self.YScale = 0.9

	self.Range = {
		RangeX = 1,
		MinX = 0,
		MaxX = 1,

		RangeY = 1,
		MinY = 0,
		MaxY = 1,
	}

	return self
end

function Chart._calculate_range(self: self)
	local max_x = 1
	local min_x = -1

	local max_y = 1
	local min_y = -1

	for _, plot: Plot in ipairs(self._chart_data) do
		for _, marker: Vector2 in ipairs(plot.Data) do
			max_x = max(max_x, marker.X)
			min_x = min(min_x, marker.X)

			max_y = max(max_y, marker.Y)
			min_y = min(min_y, marker.Y)
		end
	end

	self.Range = {
		RangeX = max_x - min_x,
		MinX = min_x,
		MaxX = max_x,

		RangeY = max_y - min_y,
		MinY = min_y,
		MaxY = max_y,
	}
end

function Chart._draw_scatter(self: self, Data: { Vector2 }, MarkerStyle: MarkerStyle)
	local template = if MarkerStyle.Shape == "Square"
		then Square(MarkerStyle.Color, MarkerStyle.Size, MarkerStyle.Transparency)
		else Circle(MarkerStyle.Color, MarkerStyle.Size, MarkerStyle.Transparency)

	local range = self.Range

	for _, marker: Vector2 in ipairs(Data) do
		local clone = template:Clone()
		clone.Position = MarkerXYToScaleUDIM2(
			range.MinX,
			range.RangeX,
			range.MinY,
			range.RangeY,
			self.XScale,
			self.YScale,
			marker.X,
			marker.Y
		)
		clone.Parent = self.Canvas
	end

	template:Destroy()
end

function Chart._draw_graph(self: self, Data: { Vector2 }, GraphStyle: GraphStyle)
	local packed_points = {}

	local range = self.Range

	for _, marker: Vector2 in ipairs(Data) do
		table_insert(
			packed_points,
			Path2DControlPoint.new(
				GraphXYToScaleUDIM2(
					range.MinX,
					range.RangeX,
					range.MinY,
					range.RangeY,
					self.XScale,
					self.YScale,
					marker.X,
					marker.Y
				)
			)
		)
	end

	local path = Path2D.new() :: P2D
	path:PushProperty("Color3", GraphStyle.Color)
	path:PushProperty("Thickness", GraphStyle.Thickness)
	path:PushProperty("Parent", self.Canvas)

	path:SetControlPoints(packed_points)

	table_insert(self._paths, path)
end

function Chart._update(self: self)
	for _, path: P2D in ipairs(self._paths) do
		path:Destroy()
	end
	table_clear(self._paths)
	self.Canvas:ClearAllChildren()

	self:_calculate_range()

	for _, plot: Plot in self._chart_data do
		if plot.MarkerStyle then
			self:_draw_scatter(plot.Data, plot.MarkerStyle)
		elseif plot.GraphStyle then
			self:_draw_graph(plot.Data, plot.GraphStyle)
		end
	end
end

function Chart.SetChartData(self: self, Data: { Plot })
	self._chart_data = Util.DeepCopy(Data) :: { Plot }

	self:_update()
end

function Chart.Destroy(self: self)
	for _, path: P2D in ipairs(self._paths) do
		path:Destroy()
	end
	self.Canvas:Destroy()
	table_clear(self)
end

type P2D = Path2D.Path

export type Shape = "Circle" | "Square"

export type MarkerStyle = {
	Shape: Shape,
	Color: Color3,
	Size: number,
	Transparency: number,
}

export type GraphStyle = {
	Color: Color3,
	Thickness: number,
}

export type Plot = {
	Name: string?,
	Data: { Vector2 },
	MarkerStyle: MarkerStyle?,
	GraphStyle: GraphStyle?,
}

export type Chart = {
	_chart_data: { Plot },
	_paths: { P2D },

	Canvas: CanvasGroup,
	XScale: number,
	YScale: number,

	Range: {
		RangeX: number,
		MinX: number,
		MaxX: number,

		RangeY: number,
		MinY: number,
		MaxY: number,
	},
} & typeof(Chart)
type self = Chart

return Chart
