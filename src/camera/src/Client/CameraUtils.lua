--!strict
--[=[
	Utility methods for cameras. These are great for viewport frames.

	```lua
	-- Sample viewport frame fitting of a model
	local viewportFrame = ...
	local camera = viewportFrame.CurrentCamera
	local model = viewportFrame:FindFirstChildWhichIsA("Model")

	RunService.RenderStepped:Connect(function()
		local cframe, size = model:GetBoundingBox()
		local size = viewportFrame.AbsoluteSize
		local aspectRatio = size.X/size.Y
		local dist = CameraUtils.fitBoundingBoxToCamera(size, camera.FieldOfView, aspectRatio)
		camera.CFrame = cframe.Position + CFrame.Angles(0, math.pi*os.clock() % math.pi, -math.pi/8)
			:vectorToWorldSpace(Vector3.new(0, 0, -dist))
	end)
	```

	@class CameraUtils
]=]

local CameraUtils = {}

type PointsSubRectBounds = {
	lowEdges: Vector2,
	highEdges: Vector2,
	minSums: Vector2,
	maxSums: Vector2,
	nearestZ: number,
}

local BOX_CORNERS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

--[=[
	Computes the diameter of a cubeid

	@param size Vector3
	@return number
]=]
function CameraUtils.getCubeoidDiameter(size: Vector3): number
	local x = size.X
	local y = size.Y
	local z = size.Z

	return math.sqrt(x * x + y * y + z * z)
end

--[=[
	Use spherical bounding box to calculate how far back to move a camera
	See: https://community.khronos.org/t/zoom-to-fit-screen/59857/12

	@param size Vector3 -- Size of the bounding box
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtils.fitBoundingBoxToCamera(size: Vector3, fovDeg: number, aspectRatio: number): number
	local radius = CameraUtils.getCubeoidDiameter(size) / 2
	return CameraUtils.fitSphereToCamera(radius, fovDeg, aspectRatio)
end

--[=[
	Like [CameraUtils.fitBoundingBoxToCamera], but frames the box in a sub-rect of the viewport.
	See [CameraUtils.fitSphereToCameraRect].

	```lua
	-- Keep a hat clear of a label along the bottom of a viewport frame
	local viewportSize = viewportFrame.AbsoluteSize
	local labelTop = label.AbsolutePosition.Y - viewportFrame.AbsolutePosition.Y
	local visibleRect = Rect.new(0, 0, 1, labelTop / viewportSize.Y)

	local boxCFrame, size = hat:GetBoundingBox()
	local offset = CameraUtils.fitBoundingBoxToCameraRect(size, camera.FieldOfView, viewportSize.X / viewportSize.Y, visibleRect)
	camera.CFrame = CFrame.new(boxCFrame.Position) * rotation * CFrame.new(offset)
	```

	@param size Vector3 -- Size of the bounding box
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param rect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera position relative to the bounding box center, in camera space
]=]
function CameraUtils.fitBoundingBoxToCameraRect(size: Vector3, fovDeg: number, aspectRatio: number, rect: Rect): Vector3
	local radius = CameraUtils.getCubeoidDiameter(size) / 2
	return CameraUtils.fitSphereToCameraRect(radius, fovDeg, aspectRatio, rect)
end

--[=[
	Like [CameraUtils.fitBoundingBoxToCameraRect], but fits the box's corners exactly for the given
	camera rotation instead of its bounding sphere. Much tighter for boxes that aren't cube shaped,
	but the distance changes as the camera rotates around the box.

	```lua
	local boxCFrame, size = model:GetBoundingBox()
	local offset = CameraUtils.fitBoundingBoxToCameraRectExact(boxCFrame, size, rotation, camera.FieldOfView, aspectRatio, visibleRect)
	camera.CFrame = CFrame.new(boxCFrame.Position) * rotation * CFrame.new(offset)
	```

	@param boxCFrame CFrame -- CFrame of the bounding box
	@param size Vector3 -- Size of the bounding box
	@param rotation CFrame -- Camera rotation. Position is ignored.
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param subrect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera position relative to the bounding box center, in camera space
]=]
function CameraUtils.fitBoundingBoxToCameraRectExact(
	boxCFrame: CFrame,
	size: Vector3,
	rotation: CFrame,
	fovDeg: number,
	aspectRatio: number,
	subrect: Rect
): Vector3
	local points = CameraUtils.boundingBoxPoints(boxCFrame, size)
	for index, point in points do
		points[index] = rotation:VectorToObjectSpace(point - boxCFrame.Position)
	end

	return CameraUtils.fitPointsToCameraRect(points, fovDeg, aspectRatio, subrect)
end

--[=[
	Fits a sphere to the camera, computing how far back to zoom the camera from
	the center of the sphere.

	@param radius number -- Radius of the sphere
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtils.fitSphereToCamera(radius: number, fovDeg: number, aspectRatio: number): number
	local halfFov = 0.5 * math.rad(fovDeg)
	if aspectRatio < 1 then
		halfFov = math.atan(aspectRatio * math.tan(halfFov))
	end

	return radius / math.sin(halfFov)
end

--[=[
	Like [CameraUtils.fitSphereToCamera], but frames the sphere in a sub-rect of the viewport,
	such as the space left visible by UI. Rotation is unchanged.

	Returns both the distance and the sideways shift that centers the sphere in the rect.
	The distance alone would center the sphere on the full viewport, under the UI.

	Off-center spheres project stretched away from the viewport center, so the sphere's outline
	is centered in the rect rather than its center point. It touches both edges on the limiting axis.

	```lua
	-- Frame a sphere left of a panel covering the right 40% of the screen
	local offset = CameraUtils.fitSphereToCameraRect(radius, camera.FieldOfView, aspectRatio, Rect.new(0, 0, 0.6, 1))
	camera.CFrame = CFrame.new(center) * rotation * CFrame.new(offset)
	```

	@param radius number -- Radius of the sphere
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param subrect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera position relative to the sphere center, in camera space
]=]
function CameraUtils.fitSphereToCameraRect(radius: number, fovDeg: number, aspectRatio: number, subrect: Rect): Vector3
	assert(subrect.Width > 0 and subrect.Height > 0, "Bad rect size")

	-- A sphere tangent to both edges of an axis sits on the bisector, at radius / sin(halfAngle) from the camera
	local centerAngle, halfAngle = CameraUtils._getSubRectAngles(fovDeg, aspectRatio, subrect)
	local depth = math.max(
		radius * math.cos(centerAngle.X) / math.sin(halfAngle.X),
		radius * math.cos(centerAngle.Y) / math.sin(halfAngle.Y)
	)

	local shift = CameraUtils.getCameraSubRectShift(depth, fovDeg, aspectRatio, subrect)
	return Vector3.new(shift.X, shift.Y, depth)
end

--[=[
	Fits points into a sub-rect of the viewport exactly, without rotating the camera. Returns the
	closest camera position that keeps every point inside the rect. On the limiting axis the points
	touch both edges, and on the other axis they're centered between the edges.

	For a fixed rotation, keeping a point inside an edge is linear in the camera position, so the
	closest distance has a closed form per axis.

	@param points { Vector3 } -- Points in camera space (x right, y up, looking down -z), relative to an origin
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param subrect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera position relative to the origin, in camera space
]=]
function CameraUtils.fitPointsToCameraRect(
	points: { Vector3 },
	fovDeg: number,
	aspectRatio: number,
	subrect: Rect
): Vector3
	local bounds = CameraUtils._getPointsSubRectBounds(points, fovDeg, aspectRatio, subrect)

	-- The camera's allowed x and y ranges only overlap once it's far enough back
	local spans = (bounds.maxSums - bounds.minSums) / (bounds.highEdges - bounds.lowEdges)
	local depth = math.max(spans.X, spans.Y, bounds.nearestZ)

	local shift = CameraUtils._getPointsSubRectShift(bounds, depth)
	return Vector3.new(shift.X, shift.Y, depth)
end

--[=[
	Computes the camera-space shift that centers points in a sub-rect of the viewport at the given
	depth, without rotating the camera. Matches [CameraUtils.fitPointsToCameraRect] at its depth.

	Use this when the distance comes from elsewhere, such as a spring. Unlike
	[CameraUtils.getCameraSubRectShift], this centers the points' projected outline.

	@param points { Vector3 } -- Points in camera space (x right, y up, looking down -z), relative to an origin
	@param depth number -- Distance from the camera to the origin along the look vector
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param subrect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera-space offset
]=]
function CameraUtils.getPointsCameraSubRectShift(
	points: { Vector3 },
	depth: number,
	fovDeg: number,
	aspectRatio: number,
	subrect: Rect
): Vector3
	local bounds = CameraUtils._getPointsSubRectBounds(points, fovDeg, aspectRatio, subrect)
	local shift = CameraUtils._getPointsSubRectShift(bounds, depth)
	return Vector3.new(shift.X, shift.Y, 0)
end

--[=[
	Returns the 8 corners of a bounding box in world space.

	@param boxCFrame CFrame -- CFrame of the bounding box
	@param size Vector3 -- Size of the bounding box
	@return { Vector3 }
]=]
function CameraUtils.boundingBoxPoints(boxCFrame: CFrame, size: Vector3): { Vector3 }
	local halfSize = size / 2
	local points = table.create(#BOX_CORNERS)
	for _, corner in BOX_CORNERS do
		table.insert(points, boxCFrame:PointToWorldSpace(halfSize * corner))
	end
	return points
end

--[[
	A point p is inside an edge with slope s when p.Y - camera.Y <= s * (camera.Z - p.Z) (or >=),
	which bounds camera.Y by p.Y + s * p.Z - s * camera.Z. The same holds for X. Collects the
	tightest of those bounds over all points, with the rect edges as slopes off the look axis.
]]
function CameraUtils._getPointsSubRectBounds(
	points: { Vector3 },
	fovDeg: number,
	aspectRatio: number,
	subrect: Rect
): PointsSubRectBounds
	assert(#points > 0, "Bad points")
	assert(subrect.Width > 0 and subrect.Height > 0, "Bad rect size")

	local tanHalfY = math.tan(0.5 * math.rad(fovDeg))
	local tanHalfX = tanHalfY * aspectRatio
	local lowEdges = Vector2.new((2 * subrect.Min.X - 1) * tanHalfX, (1 - 2 * subrect.Max.Y) * tanHalfY)
	local highEdges = Vector2.new((2 * subrect.Max.X - 1) * tanHalfX, (1 - 2 * subrect.Min.Y) * tanHalfY)

	local minSums = Vector2.new(math.huge, math.huge)
	local maxSums = Vector2.new(-math.huge, -math.huge)
	local nearestZ = -math.huge
	for _, point in points do
		local xy = Vector2.new(point.X, point.Y)
		minSums = minSums:Min(xy + lowEdges * point.Z)
		maxSums = maxSums:Max(xy + highEdges * point.Z)
		nearestZ = math.max(nearestZ, point.Z)
	end

	return {
		lowEdges = lowEdges,
		highEdges = highEdges,
		minSums = minSums,
		maxSums = maxSums,
		nearestZ = nearestZ,
	}
end

-- Centers the camera between its allowed range on each axis, which collapses on the limiting axis
function CameraUtils._getPointsSubRectShift(bounds: PointsSubRectBounds, depth: number): Vector2
	return ((bounds.maxSums + bounds.minSums) - (bounds.highEdges + bounds.lowEdges) * depth) / 2
end

--[=[
	Computes the camera-space shift that centers a subject at `depth` in a sub-rect of the
	viewport, without rotating the camera.

	The subject is placed on the angle bisector of the rect's edges rather than its screen-space
	center, since off-center objects project stretched away from the viewport center. This centers
	the outline of a sphere at any depth and radius.

	Use this when the distance comes from elsewhere, such as a spring. Otherwise prefer
	[CameraUtils.fitSphereToCameraRect].

	```lua
	-- Center the subject above a dialog box covering the bottom 30% of the screen
	local shift = CameraUtils.getCameraSubRectShift(distance, camera.FieldOfView, aspectRatio, Rect.new(0, 0, 1, 0.7))
	camera.CFrame = CFrame.new(subjectPosition) * rotation * CFrame.new(shift + Vector3.new(0, 0, distance))
	```

	@param depth number -- Distance from the camera to the subject along the look vector
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@param subrect Rect -- Normalized viewport rect (0 to 1, top-left origin)
	@return Vector3 -- Camera-space offset
]=]
function CameraUtils.getCameraSubRectShift(depth: number, fovDeg: number, aspectRatio: number, subrect: Rect): Vector3
	local centerAngle = CameraUtils._getSubRectAngles(fovDeg, aspectRatio, subrect)
	return Vector3.new(-math.tan(centerAngle.X) * depth, -math.tan(centerAngle.Y) * depth, 0)
end

--[[
	Returns the angle bisector and half angle of the sub-rect's edges on each screen axis,
	measured off the look axis (x right, y up). Each axis can be handled on its own, since a
	plane through the camera along one axis only depends on the other axis and depth.
]]
function CameraUtils._getSubRectAngles(fovDeg: number, aspectRatio: number, subrect: Rect): (Vector2, Vector2)
	local tanHalfY = math.tan(0.5 * math.rad(fovDeg))
	local tanHalfX = tanHalfY * aspectRatio

	local left = math.atan((2 * subrect.Min.X - 1) * tanHalfX)
	local right = math.atan((2 * subrect.Max.X - 1) * tanHalfX)
	local top = math.atan((1 - 2 * subrect.Min.Y) * tanHalfY)
	local bottom = math.atan((1 - 2 * subrect.Max.Y) * tanHalfY)

	local centerAngle = Vector2.new(left + right, bottom + top) / 2
	local halfAngle = Vector2.new(right - left, top - bottom) / 2

	return centerAngle, halfAngle
end

--[=[
	Checks if a position is on screen on a camera

	@param camera Camera
	@param position Vector3
	@return boolean
]=]
function CameraUtils.isOnScreen(camera: Camera, position: Vector3): boolean
	local _, onScreen = camera:WorldToScreenPoint(position)
	return onScreen
end

return CameraUtils
