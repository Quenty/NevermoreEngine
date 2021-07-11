---
-- @module PlaneUtils
-- @author Quenty

local PlaneUtils = {}

-- wiki.roblox.com/index.php?title=User:EgoMoose/Articles/Silhouettes_and_shadows#Ray_plane_intersection
-- EgoMoose
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