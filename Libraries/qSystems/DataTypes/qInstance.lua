local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0))

local lib = {}

local function GetBricks(StartInstance)
	local List = {}

	if StartInstance:IsA("BasePart") then
		List[#List+1] = StartInstance
	end

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

return lib