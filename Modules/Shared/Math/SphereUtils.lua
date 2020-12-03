---
-- @module SphereUtils

local SphereUtils = {}

function SphereUtils.intersectsRay(
	sphereCenter, sphereRadius,
	rayOrigin, rayDirection
)
	local relOrigin = rayOrigin - sphereCenter
	local rr = relOrigin:Dot(relOrigin)
	local dr = rayDirection:Dot(relOrigin)
	local dd = rayDirection:Dot(rayDirection)

	local passTime = -dr/dd
	local passDist2 = rr - dr*dr/dd

	if passDist2 <= sphereRadius*sphereRadius then
		local offset = math.sqrt((sphereRadius*sphereRadius - passDist2)/dd)
		local t0 = passTime - offset
		local t1 = passTime + offset

		if t0 <= 1 and t1 >= 0 then
			return true
		end
	end

	return false
end

return SphereUtils