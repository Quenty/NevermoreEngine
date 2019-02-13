--- Mesh utility methods
-- @module MeshUtil

local lib = {}

--- Get or create a mesh for a part
function lib.GetOrCreateMesh(part)
	local dataModelMesh = part:FindFirstChildWhichIsA("DataModelMesh")
	if dataModelMesh then
		return dataModelMesh
	end

	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Wedge
			mesh.Parent = part
			return mesh
		elseif part.Shape == Enum.PartType.Cylinder then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Cylinder
			mesh.Parent = part
			return mesh
		elseif part.Shape == Enum.PartType.Block then
			local mesh = Instance.new("BlockMesh")
			mesh.Parent = part
			return mesh
		else
			warn(("Unsupported part shape %q"):format(tostring(part.Shape)))
			return nil
		end
	elseif part:IsA("VehicleSeat") or part:IsA("Seat") then
		local mesh = Instance.new("BlockMesh")
		mesh.Parent = part
		return mesh
	elseif part:IsA("MeshPart") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = part.MeshId
		mesh.TextureId = part.TextureID -- yeah, inconsistent APIs FTW
		mesh.Parent = part
		return mesh
	elseif part:IsA("WedgePart") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = part
		return mesh
	else
		return nil
	end
end

return lib
