--!strict
--[=[
	Mesh utility methods
	@class MeshUtils
]=]

local MeshUtils = {}

--[=[
	Get or create a mesh object for a part

	@param part BasePart
	@return DataModelMesh?
]=]
function MeshUtils.getOrCreateMesh(part: BasePart): DataModelMesh?
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
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Brick
			mesh.Parent = part
			return mesh
		else
			warn(string.format("Unsupported part shape %q", tostring(part.Shape)))
			return nil
		end
	elseif part:IsA("VehicleSeat") or part:IsA("Seat") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Brick
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

return MeshUtils
