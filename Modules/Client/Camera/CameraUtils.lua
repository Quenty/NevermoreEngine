--- Utility methods for cameras
-- @module CameraUtils

local CameraUtils = {}

function CameraUtils.getCubeoidDiameter(size)
	return math.sqrt(size.x^2 + size.y^2 + size.z^2)
end

--- Use spherical bounding box to calculate how far back to move a camera
-- See: https://community.khronos.org/t/zoom-to-fit-screen/59857/12
function CameraUtils.fitBoundingBoxToCamera(size, fovDeg, aspectRatio)
	local radius = CameraUtils.getCubeoidDiameter(size)/2
	return CameraUtils.fitSphereToCamera(radius, fovDeg, aspectRatio)
end

function CameraUtils.fitSphereToCamera(radius, fovDeg, aspectRatio)
	local halfMinFov = 0.5 * math.rad(fovDeg)
	if aspectRatio < 1 then
		halfMinFov = math.atan(aspectRatio * math.tan(halfMinFov))
	end

	return radius / math.sin(halfMinFov)
end

function CameraUtils.isOnScreen(camera, position)
	local _, onScreen = camera:WorldToScreenPoint(position)
	return onScreen
end

return CameraUtils