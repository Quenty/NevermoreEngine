local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0))

local lib = {}

-- See Type library for more identification stuff.
-- @author Quenty
-- Last Modified Februrary 9th, 2014

--[[
Change log

February 15th, 2014
- Added GetPartVolume

--]]

local function GetBricks(StartInstance)
	local List = {}

	-- if StartInstance:IsA("BasePart") then
	-- 	List[#List+1] = StartInstance
	-- end

	CallOnChildren(StartInstance, function(Item)
		if Item:IsA("BasePart") then
			List[#List+1] = Item;
		end
	end)

	return List;
end
lib.GetBricks  = GetBricks
lib.get_bricks = GetBricks
lib.getBricks  = GetBricks

local function GetBricksWithIgnore(StartInstance, NoInclude)
	--- Get's the bricks in a model, but will not get a brick that is "NoInclude"

	local List = {}

	CallOnChildren(StartInstance, function(Item)
		if Item:IsA("BasePart") and Item ~= NoInclude then
			List[#List+1] = Item;
		end
	end)

	return List;
end
lib.GetBricksWithIgnore = GetBricksWithIgnore
lib.getBricksWithIgnore = GetBricksWithIgnore


local function GetPartVolume(Part, CountWedgesAsSolids)
	-- Returns a parts volume.
	-- @param Part The part to get the volume for
	-- @param CountWedgesAsSolids Boolean, if true, counts a wedge part as a solid.
	
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
lib.getPartVolume = GetPartVolume
lib.get_part_volume = GetPartVolume


return lib