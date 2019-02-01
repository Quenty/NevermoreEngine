--- Determines if parts are touching or not
-- @classmod PartTouchingCalculator

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local BoundingBox = require("BoundingBox")
local CharacterUtil = require("CharacterUtil")

local PartTouchingCalculator = {}
PartTouchingCalculator.__index = PartTouchingCalculator
PartTouchingCalculator.ClassName = "PartTouchingCalculator"

function PartTouchingCalculator.new()
	local self = setmetatable({}, PartTouchingCalculator)

	return self
end

function PartTouchingCalculator:CheckIfTouchingHumanoid(humanoid, parts)
	assert(humanoid)
	assert(parts, "Must have parts")

	local humanoidParts = {}
	for _, item in pairs(humanoid.Parent:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(humanoidParts, item)
		end
	end

	if #humanoidParts == 0 then
		warn("[PartTouchingCalculator.CheckIfTouchingHumanoid] - #humanoidParts == 0!")
		return false
	end

	local dummyPart = self:GetCollidingPartFromParts(humanoidParts)

	local previousProperties = {}
	local toSet = {
		CanCollide = true;
		Anchored = false;
	}
	local partSet = {}
	for _, part in pairs(parts) do
		previousProperties[part] = {}
		for name, value in pairs(toSet) do
			previousProperties[part][name] = part[name]
			part[name] = value
		end
		partSet[part] = true
	end

	local touching = dummyPart:GetTouchingParts()
	dummyPart:Destroy()

	local returnValue = false

	for _, part in pairs(touching) do
		if partSet[part] then
			returnValue = true
			break
		end
	end

	for part, properties in pairs(previousProperties) do
		for name, value in pairs(properties) do
			part[name] = value
		end
	end

	return returnValue
end

function PartTouchingCalculator:GetCollidingPartFromParts(parts, relativeTo, padding)
	relativeTo = relativeTo or CFrame.new()

	local size, position = BoundingBox.GetPartsBoundingBox(parts, relativeTo)

	if padding then
		size = size + Vector3.new(padding, padding, padding)
	end

	local dummyPart = Instance.new("Part")
	dummyPart.Name = "CollisionDetection"
	dummyPart.Size = size
	dummyPart.CFrame = relativeTo + relativeTo:vectorToWorldSpace(position)
	dummyPart.Anchored = false
	dummyPart.CanCollide = true
	dummyPart.Parent = Workspace

	return dummyPart
end

function PartTouchingCalculator:GetTouchingBoundingBox(parts, relativeTo, padding)
	local dummy = self:GetCollidingPartFromParts(parts, relativeTo, padding)
	local touching = dummy:GetTouchingParts()
	dummy:Destroy()

	return touching
end

--- Expensive hull check on a list of parts (aggregating each parts touching list)
function PartTouchingCalculator:GetTouchingHull(parts, padding)
	local hitParts = {}

	for _, part in pairs(parts) do
		for _, TouchingPart in pairs(self:GetTouching(part, padding)) do
			hitParts[TouchingPart] = true
		end
	end

	local touching = {}
	for part, _ in pairs(hitParts) do
		table.insert(touching, part)
	end

	return touching
end

--- Retrieves parts touching a base part
-- @param basePart item to identify touching. Geometry matters
-- @param padding studs of padding around the part
function PartTouchingCalculator:GetTouching(basePart, padding)
	padding = padding or 2
	local part

	if basePart:IsA("TrussPart") then
		-- Truss parts can't be resized
		part = Instance.new("Part")
	else
		-- Clone part
		part = basePart:Clone()

		-- Remove all tags
		for _, tag in pairs(CollectionService:GetTags(part)) do
			CollectionService:RemoveTag(part, tag)
		end

		part:ClearAllChildren()
	end

	part.Size = basePart.Size + Vector3.new(padding, padding, padding)
	part.CFrame = basePart.CFrame
	part.Anchored = false
	part.CanCollide = true
	part.Transparency = 0.1
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = Workspace

	local touching = part:GetTouchingParts()
	part:Destroy()

	return touching
end

function PartTouchingCalculator:GetTouchingHumanoids(touchingList)
	local touchingHumanoids = {}

	for _, part in pairs(touchingList) do
		local humanoid = part.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if not touchingHumanoids[humanoid] then
				local player = CharacterUtil.GetPlayerFromCharacter(humanoid)
				touchingHumanoids[humanoid] = {
					Humanoid = humanoid;
					Character = player and player.Character; -- May be nil
					Player = player; -- May be nil
					Touching = { part };
				}
			else
				table.insert(touchingHumanoids[humanoid].Touching, part)
			end
		end
	end

	local list = {}
	for _, data in pairs(touchingHumanoids) do
		table.insert(list, data)
	end

	return list
end

return PartTouchingCalculator