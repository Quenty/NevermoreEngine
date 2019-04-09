--- Utility methods for cameras
-- @module CameraUtils
-- @author Quenty

local CameraUtils = {}

local function getRadius(size)
	return math.sqrt(size.x^2 + size.y^2 + size.z^2)/2
end

--- Use spherical bounding box to calculate how far back to move a camera
-- See: https://community.khronos.org/t/zoom-to-fit-screen/59857/12
function CameraUtils.fitBoundingBoxToCamera(size, fov, aspectRatio)
	local radius = getRadius(size)

	local halfMinFov = 0.5 * math.rad(fov)
	if aspectRatio < 1 then
		halfMinFov = math.atan(aspectRatio * math.tan(halfMinFov))
	end

	return radius / math.sin(halfMinFov)
end

return CameraUtils