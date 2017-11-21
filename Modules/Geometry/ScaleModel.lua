local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local CallOnChildren = qSystems.CallOnChildren

local lib = {}


-- Code via WhoBloxedWho

local NON_FORM_FACTOR_PARTS = {
	["MeshPart"] = true;
	["TrussPart"]       = true,
	["VehicleSeat"]    = true,
	["CornerWedgePart"] = true,
	["UnionOperation"]  = true,
}

local MINIMUM_SIZES = {
	["Symmetric"] = Vector3.new(1, 1, 1),
	["Brick"]     = Vector3.new(1, 1.2, 1),
	["Plate"]     = Vector3.new(1, 0.4, 1),
	["Custom"]    = Vector3.new(0.2, 0.2, 0.2),

	["TrussPart"]       = Vector3.new(2, 2, 2),
	["VehicleSeat"]    = Vector3.new(1, 1, 1),
	["CornerWedgePart"] = Vector3.new(1, 1, 1),
	["UnionOperation"]  = Vector3.new(0, 0, 0),
	
	["MeshPart"] = Vector3.new(0.2, 0.2, 0.2);
}


--- Gets the centroid of objects, equally weighted
-- @param Objects the objects to find the centroid of, recursively
local function GetCentroidPoint(Objects)
	local center = Vector3.new()
	local totalObjs = 0

	local function scan(objs)
		for i, v in next, objs do
			if v:IsA("BasePart") then
				center = center + v.Position
				totalObjs = totalObjs + 1
			end

			scan(v:GetChildren())
		end
	end

	scan(Objects)

	return center / totalObjs
end
lib.GetCentroidPoint = GetCentroidPoint

--- Scales a model
-- @param Parts Table of parts, the parts to scale
-- @param Scale The scale to scale by
-- @param Centroid Vector3, the center to scale by
local function Scale(Parts, Scale, Centroid)
	for _, Object in next, Parts do
		if Object:IsA("BasePart") then
			local FormFactor = NON_FORM_FACTOR_PARTS[Object.ClassName] and Object.ClassName or Object.FormFactor.Name
			local minSize = MINIMUM_SIZES[FormFactor]

			local ObjectOffset = Object.Position - Centroid
			local ObjectRotation = Object.CFrame - Object.CFrame.p

			local FoundMesh = Object:FindFirstChildWhichIsA("DataModelMesh")
			local TrueSize = FoundMesh and Object.Size * FoundMesh.Scale or Object.Size
			local NewSize = TrueSize * Scale

			if not Object:IsA("TrussPart") and not Object:IsA("UnionOperation") then
				if NewSize.X < minSize.X or NewSize.Y < minSize.Y or NewSize.Z < minSize.Z then
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

		lib.Scale(Object:GetChildren(), scale, Centroid)
	end
end
lib.Scale = Scale

return lib