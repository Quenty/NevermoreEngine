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
function InputObjectRayUtils.cameraRayFromInputObject(inputObject, distance, offset, camera)
	assert(inputObject, "Bad inputObject")
	offset = offset or Vector3.new()

	local position = inputObject.Position
	return InputObjectRayUtils.cameraRayFromScreenPosition(Vector2.new(position.x + offset.x, position.y + offset.y), distance, camera)
end

--[=[
	Computes a camera ray from the mouse
	@param mouse Mouse
	@param distance number
	@param offset Vector3 | Vector2 | nil -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromMouse(mouse, distance, offset, camera)
	assert(mouse, "Bad mouse")
	offset = offset or Vector3.new(0, 0, 0)

	return InputObjectRayUtils.cameraRayFromScreenPosition(
		Vector2.new(mouse.x + offset.x, mouse.y + offset.y),
		distance,
		camera)
end

--[=[
	@param inputObject InputObject
	@param distance number? -- Optional
	@param offset Vector3 | Vector2
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromInputObjectWithOffset(inputObject, distance, offset, camera)
	assert(inputObject, "Bad inputObject")

	local position = inputObject.Position
	return InputObjectRayUtils.cameraRayFromScreenPosition(
		Vector2.new(position.x + offset.x, position.y + offset.y),
		distance,
		camera)
end

--[=[
	@param position Vector3 | Vector2
	@param distance number? -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromScreenPosition(position, distance, camera)
	distance = distance or DEFAULT_RAY_DISTANCE
	camera = camera or Workspace.CurrentCamera

	local baseRay = camera:ScreenPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end

--[=[
	@param position Vector3 | Vector2
	@param distance number? -- Optional
	@param camera Camera? -- Optional
	@return Ray
]=]
function InputObjectRayUtils.cameraRayFromViewportPosition(position, distance, camera)
	distance = distance or DEFAULT_RAY_DISTANCE
	camera = camera or Workspace.CurrentCamera

	local baseRay = camera:ViewportPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end

--[=[
	Generates a circle of rays including the center ray
	@param ray Ray
	@param count number
	@param radius number
	@return { Ray }
]=]
function InputObjectRayUtils.generateCircleRays(ray, count, radius)
	local rays = { }

	local origin = ray.Origin
	local direction = ray.Direction

	local cframePointing = CFrame.new(origin, origin + direction)

	for i=1, count do
		local angle = math.pi*2*(i-1)/count
		local offset = cframePointing:vectorToWorldSpace(Vector3.new(
			math.cos(angle)*radius,
			math.sin(angle)*radius,
			0))
		table.insert(rays, Ray.new(origin + offset, direction))
	end

	return rays
end

return InputObjectRayUtils