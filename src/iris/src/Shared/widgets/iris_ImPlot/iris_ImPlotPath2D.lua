--!strict
--[[
	Roblox Path2D allows at most 100 control points. This wrapper splits a
	polyline across multiple Path2D instances and overlaps one point at each
	chunk boundary so the line stays continuous.

	Tangents and GetPositionOnCurve are not used; this is linear polylines only.
]]

local table_insert = table.insert
local table_clear = table.clear
local table_clone = table.clone
local table_move = table.move

local MAX_SIZE = 98

local Path = {}
Path.__index = Path

function Path.new()
	local self = setmetatable({} :: self, Path)
	self._paths = {}
	self._control_points = {}
	self._properties = {}

	return self
end

function Path._clear_paths(self: self)
	for _, v in ipairs(self._paths) do
		v:Destroy()
	end
	table_clear(self._paths)
end

function Path._set_path_properties(self: self, path2D: Path2D)
	for key, value in pairs(self._properties) do
		(path2D :: any)[key] = value
	end
end

function Path._generate_paths(self: self)
	self:_clear_paths()

	local count = #self._control_points
	if count == 0 then
		return
	end

	local i = 1
	while i <= count do
		local path2D = Instance.new("Path2D")
		local split = {}
		local last = math.min(i + MAX_SIZE - 1, count)
		table_move(self._control_points, i, last, 1, split)
		table_insert(self._paths, path2D)

		path2D:SetControlPoints(split)
		self:_set_path_properties(path2D)

		if last == count then
			break
		end
		-- Overlap the last point of this chunk with the first of the next.
		i = last
	end
end

function Path.SetControlPoints(self: self, ControlPoints: ControlPoints)
	self._control_points = table_clone(ControlPoints)
	self:_generate_paths()
end

function Path.PushProperty(self: self, Property: Property | string, Value: any)
	self._properties[Property] = Value
end

function Path.Destroy(self: self)
	self:_clear_paths()
	table_clear(self)
end

export type ControlPoints = { Path2DControlPoint }
export type Property = "Name" | "Parent" | "Closed" | "Visible" | "Color3" | "Thickness" | "ZIndex"
export type Path = {
	_paths: { Path2D },
	_control_points: ControlPoints,
	_properties: { [string]: any },
} & typeof(Path)

type self = Path

return Path
