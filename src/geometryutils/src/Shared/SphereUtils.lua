--!strict
--[=[
	Utility functions involving spheres
	@class SphereUtils
]=]

local SphereUtils = {}

--[=[
	Determines whether the ray intersects with the sphere.

	@param sphereCenter Vector3
	@param sphereRadius number
	@param rayOrigin Vector3
	@param rayDirection Vector3
	@return boolean
]=]
function SphereUtils.intersectsRay(
	sphereCenter: Vector3, sphereRadius: number,
	rayOrigin: Vector3, rayDirection: Vector3
): boolean
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