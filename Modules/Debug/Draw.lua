---
-- @module Draw

local Workspace = game:GetService("Workspace")

local lib = {}

--- Draws a ray for debugging
-- @param ray The ray to draw
function lib.Ray(ray, color, parent, meshDiameter, diameter)
	color = color or Color3.new(1, 0, 0)
	parent = parent or Workspace.CurrentCamera
	meshDiameter = meshDiameter or 0.2
	diameter = diameter or 0.2

	local rayCenter = ray.Origin + ray.Direction/2

	local part = Instance.new("Part")
	part.Anchored = true
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CFrame = CFrame.new(rayCenter, ray.Origin + ray.Direction) * CFrame.Angles(math.pi/2, 0, 0)
	part.Color3 = color or Color3.new(1, 0, 0)
	part.Name = "DebugRay"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(1 * diameter, ray.Direction.magnitude, 1 * diameter)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5

	local mesh = Instance.new("SpecialMesh")
	mesh.Scale = Vector3.new(0, 1, 0) + Vector3.new(meshDiameter, 0, meshDiameter) / diameter
	mesh.parent = part

	part.parent = parent

	return part
end

--- Draws a point for debugging
-- @param vector3 Point to draw
function lib.Point(vector3, color, parent, diameter)
	assert(vector3)
	color = color or Color3.new(1, 0, 0)
	parent = parent or Workspace.CurrentCamera
	diameter = diameter or 1

	local part = Instance.new("Part")
	part.Anchored = true
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CFrame = CFrame.new(vector3)
	part.Color3 = color
	part.Name = "DebugPoint"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5

	part.Parent = parent

	return part
end

return lib