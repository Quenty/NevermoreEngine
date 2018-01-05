---
-- @module ScaleModel

local lib = {}

local MINIMUM_SIZES = {
	["TrussPart"] = Vector3.new(2, 2, 2);
	["UnionOperation"]  = Vector3.new(0, 0, 0);
}

--- Scales a group of parts around a centroid
-- @param parts Table of parts, the parts to scale
-- @param Scale The scale to scale by
-- @param Centroid Vector3, the center to scale by
function lib.Scale(parts, scale, Centroid)
	for _, Object in pairs(parts) do
		if Object:IsA("BasePart") then

			local MinSize = MINIMUM_SIZES[Object.ClassName] or Vector3.new(0.05, 0.05, 0.05)

			local ObjectOffset = Object.Position - Centroid
			local ObjectRotation = Object.CFrame - Object.CFrame.p

			local FoundMesh = Object:FindFirstChildWhichIsA("DataModelMesh")
			local TrueSize = FoundMesh and Object.Size * FoundMesh.Scale or Object.Size
			local NewSize = TrueSize * scale

			if not Object:IsA("TrussPart") and not Object:IsA("UnionOperation") then
				if NewSize.X < MinSize.X or NewSize.Y < MinSize.Y or NewSize.Z < MinSize.Z then
					if not FoundMesh then
						FoundMesh = Instance.new("SpecialMesh", Object)

						if Object:IsA("WedgePart") then
							FoundMesh.MeshType = "Wedge"
						elseif Object:IsA("CornerWedgePart") then
							FoundMesh.MeshType = "CornerWedge"

						elseif Object:IsA("Part") then

							if Object.Shape.Name == "Ball" then
								FoundMesh.MeshType = "Sphere"
							elseif Object.Shape.Name == "Cylinder" then
								FoundMesh.MeshType = "Cylinder"
							else
								FoundMesh.MeshType = "Brick"
							end
						else
							FoundMesh.MeshType = "Brick"
						end
					end
				end
			end

			Object.Size = NewSize

			if FoundMesh then
				FoundMesh.Scale = NewSize / Object.Size
				FoundMesh.Offset = FoundMesh.Offset * scale

				-- if FoundMesh.Scale == Vector3.new(1, 1, 1) and FoundMesh.Offset == Vector3.new(0, 0, 0) then
				-- 	FoundMesh:Destroy()
				-- end
			end

			Object.CFrame = CFrame.new(Centroid + (ObjectOffset * scale)) * ObjectRotation
		end
	end
end

return lib