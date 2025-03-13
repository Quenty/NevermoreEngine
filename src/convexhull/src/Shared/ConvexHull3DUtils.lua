--!strict
--[=[
	3D convex hull computation using gift wrappling algorithm

	https://en.wikipedia.org/wiki/Gift_wrapping_algorithm

	@class ConvexHull3DUtils
]=]

local require = require(script.Parent.loader).load(script)

local Queue = require("Queue")
local Draw = require("Draw")

local ConvexHull3DUtils = {}

type Edge = { number }

--[=[
	Computes the convex hull for a given set of points

	https://en.wikipedia.org/wiki/Gift_wrapping_algorithm

	@param points { Vector3 }
	@return { Vector3 }
]=]
function ConvexHull3DUtils.convexHull(points: { Vector3 }): { Vector3 }
	assert(type(points) == "table", "Bad points")

	if #points <= 3 then
		error("Not enough points to make a hull")
	end

	-- Set to store indices of the convex hull points
	local meshIndexSet = {}

	local leftMost = ConvexHull3DUtils._pickLeftMost(points)
	local secondPoint = ConvexHull3DUtils._pickSecondPoint(points, leftMost)

	meshIndexSet[leftMost] = true
	meshIndexSet[secondPoint] = true

	local visited = {} -- Set to keep track of visited edges

	local agenda: Queue.Queue<Edge> = Queue.new() -- Queue to process edgeSet
	agenda:PushRight({ leftMost, secondPoint })

	while not agenda:IsEmpty() do
		local edge = agenda:PopLeft()

		local edgeKey = ConvexHull3DUtils._edgeKey(edge)
		if visited[edgeKey] then
			continue
		end

		visited[edgeKey] = true

		local nextPoint = ConvexHull3DUtils._pickMostConvex(points, edge)
		meshIndexSet[nextPoint] = true
		agenda:PushRight({ edge[2], nextPoint })
		agenda:PushRight({ nextPoint, edge[1] })
	end

	local vertices = {}
	for index, _ in meshIndexSet do
		table.insert(vertices, points[index])
	end

	return vertices
end

function ConvexHull3DUtils._pickMostConvex(points: { Vector3 }, edge: Edge): number
	local bestIndex = 0
	local bestAngle = -math.huge
	local diffEdge = (points[edge[2]] - points[edge[1]]).Unit

	for index, point in points do
		local diff = (points[edge[2]] - point).Unit
		local angle = math.acos(diff:Dot(diffEdge))

		if angle > bestAngle and angle < math.pi then
			bestIndex = index
			bestAngle = angle
		end
	end

	return bestIndex
end

function ConvexHull3DUtils._pickLeftMost(points: { Vector3 }): number
	local leftmostIndex = 1
	local leftMostX = math.huge
	for index, point in points do
		if point.X < leftMostX then
			leftmostIndex = index
			leftMostX = point.X
		end
	end

	return leftmostIndex
end

function ConvexHull3DUtils._pickSecondPoint(points: { Vector3 }, leftMost: number): number
	local v0 = Vector3.new(1, 0, 0)
	local bestAngle = -math.huge
	local bestIndex = 1

	for index, point in points do
		local diff = (point - points[leftMost]).Unit
		local angle = math.acos(diff:Dot(v0))

		if angle > bestAngle and angle < math.pi then
			bestAngle = angle
			bestIndex = index
		end
	end

	return bestIndex
end

function ConvexHull3DUtils._edgeKey(edge: Edge): string
	return edge[1] .. "-" .. edge[2]
end

function ConvexHull3DUtils.drawVertices(points: { Vector3 }, color: Color3?): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ConvexHullPoints"
	folder.Archivable = false

	for _, point in points do
		Draw.point(point, color, folder)
	end

	folder.Parent = Draw.getDefaultParent()

	return folder
end

return ConvexHull3DUtils