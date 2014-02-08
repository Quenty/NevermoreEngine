local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qInstance         = LoadCustomLibrary("qInstance")
local qCFrame           = LoadCustomLibrary("qCFrame")

qSystems:Import(getfenv(0));

-- BuidingLoader.lua
-- Handles building loading and management. Handles it server-side. 

local lib = {}

local MakeBuildingHandler = Class(function(BuildingHandler, BuildingList)
	local function CreateNewDoor(Door, )


end)


return lib