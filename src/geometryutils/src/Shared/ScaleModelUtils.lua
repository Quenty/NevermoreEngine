--!strict
--[=[
	Utility methods to scale a model
	@class ScaleModelUtils
]=]

local ScaleModelUtils = {}

local CLASS_NAME_TO_MIN_SIZE = {
	["TrussPart"] = Vector3.new(2, 2, 2),
	["UnionOperation"] = Vector3.zero,
}

local MIN_PART_SIZE = Vector3.new(0.05, 0.05, 0.05)

--[=[
	Scales a given part's size and any mesh underneath it.
	@param part BasePart
	@param scale number
]=]
function ScaleModelUtils.scalePartSize(part: BasePart, scale: Vector3 | number)
	local partSize = part.Size

	local mesh = part:FindFirstChildWhichIsA("DataModelMesh")
	local renderedSize
	if mesh then
		renderedSize = partSize * mesh.Scale
	else
		renderedSize = part.Size
	end

	local newRenderSize = renderedSize * scale
	local newPartSize = newRenderSize

	local minSize = CLASS_NAME_TO_MIN_SIZE[part.ClassName] or MIN_PART_SIZE

	if newPartSize.X < minSize.X or newPartSize.Y < minSize.Y or newPartSize.Z < minSize.Z then
		newPartSize = Vector3.new(
			math.max(newPartSize.X, minSize.X),
			math.max(newPartSize.Y, minSize.Y),
			math.max(newPartSize.Z, minSize.Z)
		)

		-- We need a mesh for scaling (hopefully)
		mesh = ScaleModelUtils.createMeshFromPart(part)
	end

	part.Size = newPartSize

	if mesh then
		mesh.Scale = newRenderSize / newPartSize
		mesh.Offset = mesh.Offset * scale
	end
end

--[=[
	Scales the part around the centroid

	@param part BasePart
	@param scale number
	@param centroid Vector3
]=]
function ScaleModelUtils.scalePart(part: BasePart, scale: Vector3 | number, centroid: Vector3)
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local partPosition = part.Position
	local partCFrame = part.CFrame

	local offset = partPosition - centroid
	local rotation = partCFrame - partPosition

	ScaleModelUtils.scalePartSize(part, scale)
	part.CFrame = CFrame.new(centroid + (offset * scale)) * rotation
end

--[=[
	Scales a group of parts around a centroid
	@param parts { BasePart } -- Table of parts, the parts to scale
	@param scale number -- The scale to scale by
	@param centroid Vector3 -- the center to scale by
]=]
function ScaleModelUtils.scale(parts: { BasePart }, scale: number, centroid: Vector3)
	for _, part in parts do
		ScaleModelUtils.scalePart(part, scale, centroid)
	end
end

--[=[
	Given a part, creates a mesh for that part type if possible

	@param part BasePart
	@return Mesh?
]=]
function ScaleModelUtils.createMeshFromPart(part: BasePart): FileMesh?
	if part:IsA("WedgePart") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		return mesh
	elseif part:IsA("CornerWedgePart") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.CornerWedge
		return mesh
	elseif part:IsA("Part") then
		local mesh = Instance.new("SpecialMesh")

		if part.Shape.Name == "Ball" then
			mesh.MeshType = Enum.MeshType.Sphere
		elseif part.Shape.Name == "Cylinder" then
			mesh.MeshType = Enum.MeshType.Cylinder
		else
			mesh.MeshType = Enum.MeshType.Brick
		end

		return mesh
	else
		return nil
	end
end

return ScaleModelUtils