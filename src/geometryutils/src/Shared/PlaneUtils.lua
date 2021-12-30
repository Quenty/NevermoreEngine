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
]=]
function PlaneUtils.rayIntersection(origin, normal, rayOrigin, unitRayDirection)
	local rpoint = rayOrigin - origin
	local dot = unitRayDirection:Dot(normal)
	if dot == 0 then
		-- Parallel
		return nil
	end

	local t = -rpoint:Dot(normal) / dot
	return rayOrigin + t * unitRayDirection, t
end

return PlaneUtils