--!strict
--[=[
	Determines if parts are touching or not
	@class PartTouchingCalculator
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local BoundingBoxUtils = require("BoundingBoxUtils")
local CharacterUtils = require("CharacterUtils")

local PartTouchingCalculator = {}
PartTouchingCalculator.__index = PartTouchingCalculator
PartTouchingCalculator.ClassName = "PartTouchingCalculator"

export type TouchingHumanoidData = {
	Humanoid: Humanoid,
	Character: Model?,
	Player: Player?,
	Touching: { BasePart },
}

export type PartTouchingCalculator = typeof(setmetatable({} :: {}, {} :: typeof({ __index = PartTouchingCalculator })))

--[=[
	Constructs a new PartTouchingCalculator
]=]
function PartTouchingCalculator.new(): PartTouchingCalculator
	local self = setmetatable({}, PartTouchingCalculator)

	return self
end

function PartTouchingCalculator.CheckIfTouchingHumanoid(
	self: PartTouchingCalculator,
	humanoid: Humanoid,
	parts: { BasePart }
): boolean
	assert(humanoid, "Bad humanoid")
	assert(parts, "Must have parts")

	local character = humanoid.Parent
	if not character then
		return false
	end

	local humanoidParts = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(humanoidParts, item)
		end
	end

	if #humanoidParts == 0 then
		warn("[PartTouchingCalculator.CheckIfTouchingHumanoid] - #humanoidParts == 0!")
		return false
	end

	local dummyPart = self:GetCollidingPartFromParts(humanoidParts)

	local previousProperties: { [BasePart]: { [string]: any } } = {}
	local toSet: { [string]: any } = {
		CanCollide = true,
		Anchored = false,
	}
	local partSet: { [BasePart]: boolean } = {}
	for _, part in parts do
		previousProperties[part] = {}
		local anyPart = part :: any
		for name, value in toSet do
			previousProperties[part][name] = anyPart[name]
			anyPart[name] = value
		end
		partSet[part] = true
	end

	local touching = dummyPart:GetTouchingParts()
	dummyPart:Destroy()

	local returnValue = false

	for _, part in touching do
		if partSet[part] then
			returnValue = true
			break
		end
	end

	for part, properties in previousProperties do
		for name, value in properties do
			(part :: any)[name] = value
		end
	end

	return returnValue
end

function PartTouchingCalculator.GetCollidingPartFromParts(
	_self: PartTouchingCalculator,
	parts: { BasePart },
	relativeTo: CFrame?,
	padding: number?
): BasePart
	local actualRelativeTo = relativeTo or CFrame.new()

	local size, position = BoundingBoxUtils.getPartsBoundingBox(parts, actualRelativeTo)

	if padding then
		size = size + Vector3.new(padding, padding, padding)
	end

	local dummyPart = Instance.new("Part")
	dummyPart.Name = "CollisionDetection"
	dummyPart.Size = size
	dummyPart.CFrame = actualRelativeTo + actualRelativeTo:VectorToWorldSpace(position)
	dummyPart.Anchored = false
	dummyPart.CanCollide = true
	dummyPart.Parent = Workspace

	return dummyPart
end

function PartTouchingCalculator.GetTouchingBoundingBox(
	self: PartTouchingCalculator,
	parts: { BasePart },
	relativeTo: CFrame?,
	padding: number?
): { BasePart }
	local dummy = self:GetCollidingPartFromParts(parts, relativeTo, padding)
	local touching = dummy:GetTouchingParts()
	dummy:Destroy()

	return touching
end

-- Expensive hull check on a list of parts (aggregating each parts touching list)
function PartTouchingCalculator.GetTouchingHull(
	self: PartTouchingCalculator,
	parts: { BasePart },
	padding: number?
): { BasePart }
	local hitParts: { [BasePart]: boolean } = {}

	for _, part in parts do
		for _, TouchingPart in self:GetTouching(part, padding) do
			hitParts[TouchingPart] = true
		end
	end

	local touching = {}
	for part, _ in hitParts do
		table.insert(touching, part)
	end

	return touching
end

--[=[
	Retrieves parts touching a base part
	@param basePart BasePart -- item to identify touching. Geometry matters
	@param padding number -- studs of padding around the part
	@return { BasePart }
]=]
function PartTouchingCalculator.GetTouching(
	_self: PartTouchingCalculator,
	basePart: BasePart,
	padding: number?
): { BasePart }
	local actualPadding = padding or 2
	local part: BasePart

	if basePart:IsA("TrussPart") then
		-- Truss parts can't be resized
		part = Instance.new("Part")
	else
		-- Clone part
		part = basePart:Clone()

		-- Remove all tags
		for _, tag in CollectionService:GetTags(part) do
			CollectionService:RemoveTag(part, tag)
		end

		part:ClearAllChildren()
	end

	part.Size = basePart.Size + Vector3.new(actualPadding, actualPadding, actualPadding)
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

function PartTouchingCalculator.GetTouchingHumanoids(
	_self: PartTouchingCalculator,
	touchingList: { BasePart }
): { TouchingHumanoidData }
	local touchingHumanoids: { [Humanoid]: TouchingHumanoidData } = {}

	for _, part in touchingList do
		local parent = part.Parent
		local humanoid = parent and parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if not touchingHumanoids[humanoid] then
				local player = CharacterUtils.getPlayerFromCharacter(humanoid)
				touchingHumanoids[humanoid] = {
					Humanoid = humanoid,
					Character = player and player.Character, -- May be nil
					Player = player, -- May be nil
					Touching = { part },
				}
			else
				table.insert(touchingHumanoids[humanoid].Touching, part)
			end
		end
	end

	local list = {}
	for _, data in touchingHumanoids do
		table.insert(list, data)
	end

	return list
end

return PartTouchingCalculator
