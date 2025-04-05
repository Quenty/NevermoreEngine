--!strict
--[=[
	@class Line
]=]

local Line = {}

--[=[
	http://wiki.roblox.com/index.php?title=User:EgoMoose/Articles/3D_line_intersection
	@param a Vector3
	@param r Vector3 -- Offset from a
	@param b Vector3
	@param s Vector3
	@return Vector3
	@return Vector3
]=]
function Line.intersection(a: Vector3, r: Vector3, b: Vector3, s: Vector3): (Vector3, Vector3)
	local q = a - b

	local dotqr = q:Dot(r) -- same as: r:Dot(q)
	local dotqs = q:Dot(s) -- same as: s:Dot(q)
	local dotrs = r:Dot(s) -- same as: s:Dot(r)
	local dotrr = r:Dot(r)
	local dotss = s:Dot(s)

	local denom = dotrr * dotss - dotrs * dotrs
	local numer = dotqs * dotrs - dotqr * dotss

	local t = numer / denom
	local u = (dotqs + t * dotrs) / dotss

	-- return the two points on each line that make up the shortest line
	local p0, p1 = a + t * r, b + u * s
	return p0, p1
end

return Line