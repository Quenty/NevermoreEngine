--!strict
--[=[
	Utility functions for constructing rays from input objects
	@class InputObjectRayUtils
]=]

local Workspace = game:GetService("Workspace")

local DEFAULT_RAY_DISTANCE = 1000

local InputObjectRayUtils = {}

--[=[
	Computes a camera ray from an inputObject
	@param inputObject InputObject
	@param distance number
	@param offset Vector3 | Vector2 | nil -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromInputObject(
	inputObject: InputObject,
	distance: number,
	offset: (Vector3 | Vector2)?,
	camera: Camera?
): Ray
	assert(inputObject, "Bad inputObject")

	local rayOffset = offset or Vector3.zero

	local position = inputObject.Position
	return InputObjectRayUtils.cameraRayFromScreenPosition(
		Vector2.new(position.X + rayOffset.X, position.Y + rayOffset.Y),
		distance,
		camera
	)
end

--[=[
	Computes a camera ray from the mouse
	@param mouse Mouse
	@param distance number
	@param offset Vector3 | Vector2 | nil -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromMouse(
	mouse: Mouse,
	distance: number,
	offset: (Vector3 | Vector2)?,
	camera: Camera?
): Ray
	assert(mouse, "Bad mouse")

	local rayOffset = offset or Vector3.zero

	return InputObjectRayUtils.cameraRayFromScreenPosition(
		Vector2.new(mouse.X + rayOffset.X, mouse.Y + rayOffset.Y),
		distance,
		camera
	)
end

--[=[
	@param inputObject InputObject
	@param distance number? -- Optional
	@param offset Vector3 | Vector2
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromInputObjectWithOffset(
	inputObject: InputObject,
	distance: number?,
	offset: Vector3 | Vector2,
	camera: Camera?
): Ray
	assert(inputObject, "Bad inputObject")

	local position = inputObject.Position
	return InputObjectRayUtils.cameraRayFromScreenPosition(
		Vector2.new(position.X + offset.X, position.Y + offset.Y),
		distance,
		camera
	)
end

--[=[
	@param position Vector3 | Vector2
	@param distance number? -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromScreenPosition(
	position: Vector3 | Vector2,
	distance: number?,
	camera: Camera?
): Ray
	distance = distance or DEFAULT_RAY_DISTANCE
	local currentCamera = camera or Workspace.CurrentCamera

	local baseRay = currentCamera:ScreenPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end

--[=[
	@param position Vector3 | Vector2
	@param distance number? -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromViewportPosition(
	position: Vector3 | Vector2,
	distance: number?,
	camera: Camera?
): Ray
	distance = distance or DEFAULT_RAY_DISTANCE
	local currentCamera = camera or Workspace.CurrentCamera

	local baseRay = currentCamera:ViewportPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end

--[=[
	Generates a circle of rays including the center ray
	@param ray Ray
	@param count number
	@param radius number
	@return { Ray }
]=]
function InputObjectRayUtils.generateCircleRays(ray: Ray, count: number, radius: number): { Ray }
	local rays = {}

	local origin = ray.Origin
	local direction = ray.Direction

	local cframePointing = CFrame.new(origin, origin + direction)

	for i = 1, count do
		local angle = math.pi * 2 * (i - 1) / count
		local offset =
			cframePointing:VectorToWorldSpace(Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
		table.insert(rays, Ray.new(origin + offset, direction))
	end

	return rays
end

return InputObjectRayUtils
