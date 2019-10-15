---
-- @module ScaleModel

local ScaleModel = {}

local CLASS_NAME_TO_MIN_SIZE = {
	["TrussPart"] = Vector3.new(2, 2, 2);
	["UnionOperation"]  = Vector3.new(0, 0, 0);
}

local MIN_PART_SIZE = Vector3.new(0.05, 0.05, 0.05)

function ScaleModel.scalePartSize(part, scale)
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

	if newPartSize.X < minSize.X
		or newPartSize.Y < minSize.Y
		or newPartSize.Z < minSize.Z then

		newPartSize = Vector3.new(
			math.max(newPartSize.X, minSize.X),
			math.max(newPartSize.Y, minSize.Y),
			math.max(newPartSize.Z, minSize.Z))

		-- We need a mesh for scaling (hopefully)
		mesh = ScaleModel.createMeshFromPart(part)
	end

	part.Size = newPartSize

	if mesh then
		mesh.Scale = newRenderSize/newPartSize
		mesh.Offset = mesh.Offset * scale
	end
end

function ScaleModel.scalePart(part, scale, centroid)
	assert(typeof(part) == "Instance" and part:IsA("BasePart"))

	local partPosition = part.Position
	local partCFrame = part.CFrame

	local offset = partPosition - centroid
	local rotation = partCFrame - partPosition

	ScaleModel.scalePartSize(part, scale)
	part.CFrame = CFrame.new(centroid + (offset * scale)) * rotation
end

--- Scales a group of parts around a centroid
-- @param parts Table of parts, the parts to scale
-- @param Scale The scale to scale by
-- @param centroid Vector3, the center to scale by
function ScaleModel.scale(parts, scale, centroid)
	for _, part in pairs(parts) do
		ScaleModel.scalePart(part, scale, centroid)
	end
end

function ScaleModel.createMeshFromPart(part)
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

return ScaleModel