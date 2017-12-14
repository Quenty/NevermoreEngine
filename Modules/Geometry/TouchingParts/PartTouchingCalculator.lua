--- Determines if parts are touching or not
-- @classmod PartTouchingCalculator

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qCFrame = LoadCustomLibrary("qCFrame")
local CharacterUtil = LoadCustomLibrary("CharacterUtil")

local PartTouchingCalculator = {}
PartTouchingCalculator.__index = PartTouchingCalculator
PartTouchingCalculator.ClassName = "PartTouchingCalculator"

function PartTouchingCalculator.new(BoatDataManager)
	local self = setmetatable({}, PartTouchingCalculator)
	
	self.BoatDataManager = BoatDataManager or error("No BoatDataManager")
	
	return self
end

function PartTouchingCalculator:CheckIfTouchingHumanoid(Humanoid, Parts)
	assert(Humanoid)
	assert(Parts, "Must have parts")
	
	local HumanoidParts = {}
	for _, Item in pairs(Humanoid:GetDesendants()) do
		if Item:IsA("BasePart") then
			table.insert(HumanoidParts, Item)
		end
	end

	if #HumanoidParts == 0 then
		warn("[BoatPlacer][CheckIfTouchingHumanoid] - #Parts == 0, retrieved from humanoid")
		return false
	end
	
	local DummyPart = self:GetCollidingPartFromParts(HumanoidParts)
	
	local PreviousProperties = {}
	local ToSet = {
		CanCollide = true;
		Anchored = false;
	}
	local PartSet = {}
	for _, Part in pairs(Parts) do
		PreviousProperties[Part] = {}
		for Name, Value in pairs(ToSet) do
			PreviousProperties[Part][Name] = Part[Name]
			Part[Name] = Value
		end
		PartSet[Part] = true
	end
	
	local Touching = DummyPart:GetTouchingParts()
	DummyPart:Destroy()

	local ReturnValue = false
	
	for _, Part in pairs(Touching) do
		if PartSet[Part] then
			ReturnValue = true
			break
		end
	end
	
	for Part, Properties in pairs(PreviousProperties) do
		for Name, Value in pairs(Properties) do
			Part[Name] = Value
		end
	end
	
	return ReturnValue
end


function PartTouchingCalculator:GetCollidingPartFromParts(Parts, RelativeTo, Padding)
	RelativeTo = RelativeTo or CFrame.new()
	
	local Size, Rotation = qCFrame.GetBoundingBox(Parts, RelativeTo)
	
	if Padding then
		Size = Size + Vector3.new(Padding, Padding, Padding)
	end
	
	local DummyPart = Instance.new("Part")
	DummyPart.Name = "CollisionDetection"
	DummyPart.Size = Size
	DummyPart.CFrame = Rotation
	DummyPart.Anchored = false
	DummyPart.CanCollide = true
	DummyPart.Parent = workspace
	
	return DummyPart
end

function PartTouchingCalculator:GetTouchingBoundingBox(Parts, RelativeTo, Padding)
	local Dummy = self:GetCollidingPartFromParts(Parts, RelativeTo, Padding)
	local Touching = Dummy:GetTouchingParts()
	Dummy:Destroy()
	
	return Touching
end

--- Expensive hull check on a list of parts (aggregating each parts touching list)
function PartTouchingCalculator:GetTouchingHull(Parts, Padding)
	local HitParts = {}
	
	for _, Part in pairs(Parts) do
		for _, TouchingPart in pairs(self:GetTouching(Part, Padding)) do
			HitParts[TouchingPart] = true
		end
	end

	local Touching = {}
	for Part, _ in pairs(HitParts) do
		table.insert(Touching, Part)
	end
	
	return Touching
end


--- Retrieves parts touching a base part
-- @param BasePart item to identify touching. Geometry matters
-- @param Padding studs of padding around the part
function PartTouchingCalculator:GetTouching(BasePart, Padding)
	Padding = Padding or 2
	local Copy
	
	if BasePart:IsA("TrussPart") then
		-- Truss parts can't be resized
		Copy = Instance.new("Part")
	else
		-- Clone copy
		Copy = BasePart:Clone()
		
		-- Remove all tags
		for _, Tag in pairs(CollectionService:GetTags(Copy)) do
			CollectionService:RemoveTag(Copy, Tag)
		end
	end
	Copy:ClearAllChildren()
	
	Copy.Size = BasePart.Size + Vector3.new(Padding, Padding, Padding)
	Copy.CFrame = BasePart.CFrame
	Copy.Anchored = false
	Copy.CanCollide = true
	Copy.Transparency = 0.1
	Copy.Material = Enum.Material.SmoothPlastic
	Copy.Parent = workspace
	
	local Touching = Copy:GetTouchingParts()
	Copy:Destroy()
	
	return Touching
end

function PartTouchingCalculator:GetTouchingHumanoids(TouchingList)
	local TouchingHumanoids = {}
	
	for _, Part in pairs(TouchingList) do
		local Humanoid = Part.Parent:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			if not TouchingHumanoids[Humanoid] then
				local Player, Character = CharacterUtil.GetPlayerFromCharacter(Humanoid)
				TouchingHumanoids[Humanoid] = {
					Humanoid = Humanoid;
					Character = Character;
					Player = Player;
					Touching = {Part}
				}
			else
				table.insert(TouchingHumanoids[Humanoid].Touching, Part)
			end
		end
	end
	
	local List = {}
	for Humanoid, Data in pairs(TouchingHumanoids) do
		table.insert(List, Data)
	end

	return List
end

function PartTouchingCalculator:GetTouchingProps(TouchingList)
	local TouchingProps = {}
	
	for _, Part in pairs(TouchingList) do
		local PropData, BasePart = self.BoatDataManager.SearchForPropData(Part)
		if PropData then
			local Prop = PropData.Parent
			if not TouchingProps[Prop] then
				TouchingProps[Prop] = {
					PropData = PropData;
					Prop = Prop;
					BasePart = BasePart;
					Touching = {Part}
				}
			else
				table.insert(TouchingProps[Prop].Touching, Part)
			end
		end
	end
	
	local List = {}
	for Prop, Data in pairs(TouchingProps) do
		table.insert(List, Data)
	end
	
	return List
end

function PartTouchingCalculator:GetTouchingBoats(TouchingList)
	local TouchingBoats = {}
	
	for _, Part in pairs(TouchingList) do
		local BoatData, Boat, BoatBasePart = self.BoatDataManager:GetBoatData(Part)
		if BoatData then
			if not TouchingBoats[Boat] then
				TouchingBoats[Boat] = {
					BoatData = BoatData;
					Boat = Boat;
					BoatBasePart = BoatBasePart;
					Touching = {Part};
				}
			else
				table.insert(TouchingBoats[Boat].Touching, Part)
			end
		end
	end
	
	local List = {}
	for Boat, Data in pairs(TouchingBoats) do
		table.insert(List, Data)
	end
	
	return List
end



return PartTouchingCalculator