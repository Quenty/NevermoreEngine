while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')

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

lib.GetBricks = GetBricks
lib.get_bricks = GetBricks
lib.getBricks = GetBricks

NevermoreEngine.RegisterLibrary('qInstance', lib);