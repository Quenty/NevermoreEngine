--[=[
	@class ConvexHull2DUtils
]=]

local ConvexHull2DUtils = {}

--[=[
	Computes a convex hull using the gift wrapping algorithm.

	https://en.wikipedia.org/wiki/Gift_wrapping_algorithm
]=]
function ConvexHull2DUtils.convexHull(points: { Vector2 }): { Vector2 }
	table.sort(points, function(a, b)
		return a.x < b.x
	end)

	local pointOnHull = points[1]

	local hull = {}
	repeat
		table.insert(hull, pointOnHull)

		local endpoint = points[1]

		for i=1, #points do
			local point = points[i]

			-- endpoint == pointOnHull is a rare case and can happen only when j == 1 and a better endpoint has not yet been set for the loop
			if endpoint == pointOnHull or ConvexHull2DUtils.isClockWiseTurn(pointOnHull, endpoint, point) then
				endpoint = point
			end
		end
		pointOnHull = endpoint
	until endpoint == hull[1]

	return hull
end

--[=[
	Retrns whether these 3 points are in a clockwise turn
]=]
function ConvexHull2DUtils.isClockWiseTurn(p1: Vector2, p2: Vector2, p3: Vector2): boolean
	return (p3.y - p1.y)*(p2.x - p1.x) < (p2.y - p1.y)*(p3.x - p1.x)
end

--[=[
	Computes line intersection between vectors
]=]
function ConvexHull2DUtils.lineIntersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2): Vector2 | nil
	local r = b - a
	local s = d - c
	local dot = r.x * s.y - r.y * s.x
	local u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / dot
	local t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / dot
	return (0 <= u and u <= 1 and 0 <= t and t <= 1) and a + t * r or nil
end

--[=[
	Raycasts from `from` to `to` against the convex hull.
]=]
function ConvexHull2DUtils.raycast(from: Vector2, to: Vector2, hull: { Vector2 }): (Vector2 | nil, Vector2 | nil, Vector2 | nil)
	local candidates = {}
	local n = #hull

	for i = 1, n do
		local current = hull[i]
		local after = hull[i%n + 1]
		local point = ConvexHull2DUtils.lineIntersect(current, after, from, to)
		if point then
			table.insert(candidates, {
				point = point;
				startPoint = current;
				finishPoint = after;
			})
		end
	end

	local closest
	local closestDist = math.huge
	for _, data in pairs(candidates) do
		local dist = (data.point - from).magnitude
		if dist < closestDist then
			closest = data
			closestDist = dist
		end
	end

	if not closest then
		return nil, nil, nil
	end

	return closest.point, closest.startPoint, closest.finishPoint
end

return ConvexHull2DUtils