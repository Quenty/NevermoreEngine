local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local CallOnChildren = qSystems.CallOnChildren

local lib = {}


-- Code via WhoBloxedWho

local NON_FORM_FACTOR_PARTS = {
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
}

----

local function findMesh(part)
    for _, object in next, part:GetChildren() do
        if object:IsA("DataModelMesh") then
            return object
        end
    end
end
lib.FindMesh = findMesh

local function getCenteroidPoint(objects)
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

	scan(objects)

	return center / totalObjs
end

function lib.Scale(selection, scale, centeroid)
	-- @param centeroid Vector3

	for _, object in next, selection do
		if object:IsA("BasePart") then
			local formFactor = NON_FORM_FACTOR_PARTS[object.ClassName] and object.ClassName or object.FormFactor.Name
			local minSize = MINIMUM_SIZES[formFactor]

			local objectOffset = object.Position - centeroid
			local objectRotation = object.CFrame - object.CFrame.p

			local foundMesh = findMesh(object)
			local trueSize = foundMesh and object.Size * foundMesh.Scale or object.Size
			local newSize = trueSize * scale

			if not object:IsA("Truss") and not object:IsA("UnionOperation") then
				if newSize.X < minSize.X or newSize.Y < minSize.Y or newSize.Z < minSize.Z then
					if not foundMesh then
						foundMesh = Instance.new("SpecialMesh", object)

						if object:IsA("WedgePart") then
							foundMesh.MeshType = "Wedge"
						elseif object:IsA("CornerWedgePart") then
							foundMesh.MeshType = "CornerWedge"

						elseif object:IsA("Part") then

							if object.Shape.Name == "Ball" then
								foundMesh.MeshType = "Sphere"
							elseif object.Shape.Name == "Cylinder" then
								foundMesh.MeshType = "Cylinder"
							else
								foundMesh.MeshType = "Brick"
							end
						else
							foundMesh.MeshType = "Brick"
						end
					end
				end
			end

			object.Size = newSize

			if foundMesh then
				foundMesh.Scale = newSize / object.Size
				foundMesh.Offset = foundMesh.Offset * scale
				
				if foundMesh.Scale == Vector3.new(1, 1, 1) and foundMesh.Offset == Vector3.new(0, 0, 0) then
					foundMesh:Destroy()
				end
			end

			object.CFrame = CFrame.new(centeroid + (objectOffset * scale)) * objectRotation
		end

		lib.Scale(object:GetChildren(), scale, centeroid)
	end
end

----

return lib