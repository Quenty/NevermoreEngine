---
-- @module Draw

local Workspace = game:GetService("Workspace")

local lib = {}
lib._defaultColor = Color3.new(1, 0, 0)

function lib.SetColor(color)
	lib._defaultColor = color
end

function lib.SetRandomColor()
	lib.SetColor(Color3.fromHSV(math.random(), 0.5+0.5*math.random(), 1))
end

--- Draws a ray for debugging
-- @param ray The ray to draw
function lib.Ray(ray, color, parent, meshDiameter, diameter)
	color = color or lib._defaultColor
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
	part.Color = color
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
	color = color or lib._defaultColor
	parent = parent or Workspace.CurrentCamera
	diameter = diameter or 1

	local part = Instance.new("Part")
	part.Anchored = true
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CFrame = CFrame.new(vector3)
	part.Color = color
	part.Name = "DebugPoint"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5

	local sphereHandle = Instance.new("SphereHandleAdornment")
	sphereHandle.Archivable = false
	sphereHandle.Radius = diameter/4
	sphereHandle.Color3 = color
	sphereHandle.AlwaysOnTop = true
	sphereHandle.Adornee = part
	sphereHandle.ZIndex = 1
	sphereHandle.Parent = part

	part.Parent = parent

	return part
end

function lib.Box(cframe, size, color)
	color = color or lib._defaultColor
	cframe = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe

	local part = Instance.new("Part")
	part.Color= color
	part.Name = "DebugPart"
	part.Anchored = true
	part.CanCollide = false
	part.Archivable = false
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.5
	part.Size = size
	part.CFrame = cframe
	part.Parent = Workspace.CurrentCamera

	return part
end

return lib