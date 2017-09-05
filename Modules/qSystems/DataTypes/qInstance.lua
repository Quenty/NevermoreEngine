local lib = {}

-- Utility instance functions, to be depreciated
-- @author Quenty



--- Retrieve all parts in a hierarchy
-- @param StartInstance The instance to start searching under
local function GetBricks(StartInstance)
	local List = {}

	if StartInstance:IsA("BasePart") then
		List[#List+1] = StartInstance
	end

	for _, Item in pairs(StartInstance:GetDescendants()) do
		if Item:IsA("BasePart") then
			List[#List+1] = Item
		end
	end

	return List
end
lib.GetBricks  = GetBricks


--- Returns a list of the seats, such as GetBricks
-- @param StartInstance The instance to start searching under
local function GetSeats(StartInstance)
	local List = {}

	if StartInstance:IsA("Seat") or StartInstance:IsA("VehicleSeat") then
		List[#List+1] = StartInstance
	end
	
	for _, Item in pairs(StartInstance:GetDescendants()) do
		if Item:IsA("Seat") or Item:IsA("VehicleSeat") then
			List[#List+1] = Item;
		end
	end

	return List
end
lib.GetSeats = GetSeats


--- Get's the bricks in a model, but will not get a brick that is "NoInclude"
-- @param StartInstance The instance to start searching under
-- @param NoInclude The instance to not include
local function GetBricksWithIgnore(StartInstance, NoInclude)
	local List = {}
		
	if StartInstance:IsA("BasePart") and StartInstance ~= NoInclude then
		List[#List+1] = StartInstance
	end
	
	for _, Item in pairs(StartInstance:GetDescendants()) do
		if Item:IsA("BasePart") and Item ~= NoInclude then
			List[#List+1] = Item
		end
	end

	return List;
end
lib.GetBricksWithIgnore = GetBricksWithIgnore


--- Get's the bricks in a model, but will not get a brick that is "DoIgnore"
-- @param StartInstance The instance to start searching under
-- @param DoIgnore A Function that is called to filter out components. Return true to ignore.
local function GetBricksWithIgnoreFunction(StartInstance, DoIgnore)
	local List = {}

	if StartInstance:IsA("BasePart") and not DoIgnore(StartInstance) then
		List[#List+1] = StartInstance
	end
	
	for _, Item in pairs(StartInstance:GetDescendants()) do
		if Item:IsA("BasePart") and not DoIgnore(Item) then
			List[#List+1] = Item
		end
	end

	return List
end
lib.GetBricksWithIgnoreFunction = GetBricksWithIgnoreFunction


--- Returns a parts volume.
-- @param Part The part to get the volume for
-- @param CountWedgesAsSolids Boolean, if true, counts a wedge part as a solid.
local function GetPartVolume(Part, CountWedgesAsSolids)
	
	
	local Size = Part.Size
	if Part:IsA("Part") or CountWedgesAsSolids then
		return Size.X * Size.Y * Size.Z
	elseif Part:IsA("WedgePart") then
		return (Size.X * Size.Y * Size.Z) / 2
	elseif Part:IsA("CornerWedgePart") then
		return (Size.X * Size.Y * Size.Z) / 3
	else
		error("[GetPartVolume] - Not a part")
	end
end
lib.GetPartVolume = GetPartVolume

return lib