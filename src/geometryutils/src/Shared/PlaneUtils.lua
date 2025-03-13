--!strict
--[=[
	Utility functions involving planes!
	@class PlaneUtils
]=]

local PlaneUtils = {}

--[=[
	Finds the intersection between planes and rays.

	https://wiki.roblox.com/index.php?title=User:EgoMoose/Articles/Silhouettes_and_shadows#Ray_plane_intersection
	Originally from EgoMoose

	@param origin Vector3
	@param normal Vector3
	@param rayOrigin Vector3
	@param unitRayDirection Vector3
	@return Vector3? -- Intersection point
	@return number? -- Distance to intersection point
]=]
function PlaneUtils.rayIntersection(origin: Vector3, normal: Vector3, rayOrigin: Vector3, unitRayDirection: Vector3): (Vector3?, number?)
	local rpoint = rayOrigin - origin
	local dot = unitRayDirection:Dot(normal)
	if dot == 0 then
		-- Parallel
		return nil, nil
	end

	local t = -rpoint:Dot(normal) / dot
	return rayOrigin + t * unitRayDirection, t
end

return PlaneUtils