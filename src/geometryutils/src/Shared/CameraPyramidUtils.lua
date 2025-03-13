--!strict
--[=[
	@class CameraPyramidUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlaneUtils = require("PlaneUtils")
local Draw = require("Draw")

local CameraPyramidUtils = {}

type InBoundIntersection = {
	point: Vector3,
	dist: number,
}

--[=[
	Treating the camera like a pyramid, compute points on the screen that the ray intersects with the
	screen.

	Returns the screen points in the same order as the ray orientation, such that the line is always
	moving away from the ray.

	@param camera Camera
	@param rayOrigin Vector3
	@param unitRayDirection Vector3
	@param debugMaid Maid? -- Optional debug maid
	@return Vector3? -- Screen point1
	@return Vector3? -- Screen point2
]=]
function CameraPyramidUtils.rayIntersection(
	camera: Camera,
	rayOrigin: Vector3,
	unitRayDirection: Vector3,
	debugMaid: any?
): (Vector3?, Vector3?)
	assert(typeof(rayOrigin) == "Vector3", "Bad rayOrigin")
	assert(typeof(unitRayDirection) == "Vector3", "Bad unitRayDirection")

	unitRayDirection = unitRayDirection.Unit
	local camCFrame = camera.CFrame
	local viewportSize = camera.ViewportSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		return nil, nil
	end

	local aspectRatio = viewportSize.X / viewportSize.Y
	local halfVerticalFov = math.rad(camera.FieldOfView / 2)
	local halfHorizontalFov = math.atan(math.tan(halfVerticalFov) * aspectRatio)

	-- Construct pyramid with normals facing out
	local origin = camCFrame.Position
	local cframeTop = (camCFrame * CFrame.Angles(halfVerticalFov, 0, 0))
	local cframeBottom = (camCFrame * CFrame.Angles(-halfVerticalFov, 0, 0))
	local cframeLeft = (camCFrame * CFrame.Angles(0, halfHorizontalFov, 0))
	local cframeRight = (camCFrame * CFrame.Angles(0, -halfHorizontalFov, 0))

	local normalTop = cframeTop.YVector
	local normalBottom = -cframeBottom.YVector
	local normalLeft = -cframeLeft.XVector -- these are flipped because the camera CFrame is flipped
	local normalRight = cframeRight.XVector

	local intersectionTop, distTop = PlaneUtils.rayIntersection(origin, normalTop, rayOrigin, unitRayDirection)
	local intersectionBottom, distBottom = PlaneUtils.rayIntersection(origin, normalBottom, rayOrigin, unitRayDirection)
	local intersectionLeft, distLeft = PlaneUtils.rayIntersection(origin, normalLeft, rayOrigin, unitRayDirection)
	local intersectionRight, distRight = PlaneUtils.rayIntersection(origin, normalRight, rayOrigin, unitRayDirection)

	local topInBounds = CameraPyramidUtils._isInBounds(camCFrame, intersectionTop, halfHorizontalFov, true)
	local bottomInBounds = CameraPyramidUtils._isInBounds(camCFrame, intersectionBottom, halfHorizontalFov, true)
	local leftInBounds = CameraPyramidUtils._isInBounds(camCFrame, intersectionLeft, halfVerticalFov, false)
	local rightInBounds = CameraPyramidUtils._isInBounds(camCFrame, intersectionRight, halfVerticalFov, false)

	local inBoundsIntersections: { InBoundIntersection } = {}
	if topInBounds and intersectionTop and distTop then
		table.insert(inBoundsIntersections, {
			point = intersectionTop,
			dist = distTop,
		})
	end
	if bottomInBounds and intersectionBottom and distBottom then
		table.insert(inBoundsIntersections, {
			point = intersectionBottom,
			dist = distBottom,
		})
	end
	if leftInBounds and intersectionLeft and distLeft then
		table.insert(inBoundsIntersections, {
			point = intersectionLeft,
			dist = distLeft,
		})
	end
	if rightInBounds and intersectionRight and distRight then
		table.insert(inBoundsIntersections, {
			point = intersectionRight,
			dist = distRight,
		})
	end

	if debugMaid then
		debugMaid._top = CameraPyramidUtils._drawIntersection(camera, unitRayDirection, intersectionTop, topInBounds)
		debugMaid._bottom =
			CameraPyramidUtils._drawIntersection(camera, unitRayDirection, intersectionBottom, bottomInBounds)
		debugMaid._left = CameraPyramidUtils._drawIntersection(camera, unitRayDirection, intersectionLeft, leftInBounds)
		debugMaid._right =
			CameraPyramidUtils._drawIntersection(camera, unitRayDirection, intersectionRight, rightInBounds)
	end

	if #inBoundsIntersections == 0 then
		return nil, nil
	elseif #inBoundsIntersections == 1 then
		-- Happens when the other point fades off into the distance on this one screen such that it never ends
		local data = inBoundsIntersections[1]
		local intersection = data.point
		local firstViewportPoint = camera:WorldToViewportPoint(intersection)

		local firstOption, firstOptionOnScreen = camera:WorldToViewportPoint(intersection + unitRayDirection * 10000)
		local secondOption, secondOptionOnScreen = camera:WorldToViewportPoint(intersection - unitRayDirection * 10000)

		local secondViewportPoint
		if firstOptionOnScreen then
			secondViewportPoint = firstOption
		elseif secondOptionOnScreen then
			secondViewportPoint = secondOption
		else
			warn("Failed to find option on screen")
			return nil, nil
		end

		-- Flip around
		if data.dist < 0 then
			firstViewportPoint, secondViewportPoint = secondViewportPoint, firstViewportPoint
		end

		return firstViewportPoint, secondViewportPoint
	else
		local first = inBoundsIntersections[1]
		local second = inBoundsIntersections[2]

		if first.dist > second.dist then
			first, second = second, first
		end

		local firstScreenPoint = camera:WorldToViewportPoint(first.point)
		local secondScreenPoint = camera:WorldToViewportPoint(second.point)
		return firstScreenPoint, secondScreenPoint
	end
end

function CameraPyramidUtils._drawIntersection(
	camera: Camera,
	unitRayDirection: Vector3,
	intersection: Vector3?,
	inBounds: boolean
): Instance?
	if not inBounds or not intersection then
		return nil
	end

	local halfVerticalFov = math.rad(camera.FieldOfView / 2)
	local viewportSize = camera.ViewportSize
	local PIXELS_DIAMETER = 40
	local PIXELS_OFFSET = 5 + PIXELS_DIAMETER / 2

	local position = camera:WorldToViewportPoint(intersection)
	local dist = position.Z
	local worldHeight = 2 * math.tan(halfVerticalFov) * dist
	local scale = worldHeight / viewportSize.Y

	local firstPoint = intersection + PIXELS_OFFSET * unitRayDirection * scale
	local secondPoint = intersection - PIXELS_OFFSET * unitRayDirection * scale

	local _, onScreen1 = camera:WorldToViewportPoint(firstPoint)
	local _, onScreen2 = camera:WorldToViewportPoint(secondPoint)

	local color = Color3.new(1, 1, 0)
	if onScreen1 then
		return Draw.point(firstPoint, color, nil, PIXELS_DIAMETER * scale)
	elseif onScreen2 then
		return Draw.point(secondPoint, color, nil, PIXELS_DIAMETER * scale)
	else
		return nil
	end
end

function CameraPyramidUtils._isInBounds(camCFrame: CFrame, intersection: Vector3?, halfFov: number, isVertical: boolean): boolean
	if not intersection then
		return false
	end

	local relative = camCFrame:PointToObjectSpace(intersection)
	local dist = -relative.Z

	if dist < 0 then
		return false
	end

	-- Discard the other information (we're projecting onto the flat camera plane)
	local horizontalDist
	if isVertical then
		horizontalDist = math.abs(relative.X)
	else
		horizontalDist = math.abs(relative.Y)
	end

	local angle = math.atan2(horizontalDist, dist)
	return angle <= halfFov
end

return CameraPyramidUtils