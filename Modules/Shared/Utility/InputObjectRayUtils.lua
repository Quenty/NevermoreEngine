--- Utility functions for constructing rays from input objects
-- @module InputObjectRayUtils

local Workspace = game:GetService("Workspace")

local DEFAULT_RAY_DISTANCE = 1000

local InputObjectRayUtils = {}

function InputObjectRayUtils.cameraRayFromInputObject(inputObject, distance)
	assert(inputObject)
	return InputObjectRayUtils.cameraRayFromScreenPosition(inputObject.Position, distance)
end

function InputObjectRayUtils.cameraRayFromInputObjectWithOffset(inputObject, distance, offset)
	assert(inputObject)
	return InputObjectRayUtils.cameraRayFromScreenPosition(inputObject.Position + offset, distance)
end

function InputObjectRayUtils.cameraRayFromScreenPosition(position, distance)
	distance = distance or DEFAULT_RAY_DISTANCE

	local baseRay = Workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end

function InputObjectRayUtils.cameraRayFromViewportPosition(position, distance)
	distance = distance or DEFAULT_RAY_DISTANCE

	local baseRay = Workspace.CurrentCamera:ViewportPointToRay(position.X, position.Y)
	return Ray.new(baseRay.Origin, baseRay.Direction.unit * distance)
end


-- Generates a circle of rays including the center ray
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