while not _G.NevermoreEngine do wait(0) end

local Players            = Game:GetService('Players')
local StarterPack        = Game:GetService('StarterPack')
local StarterGui         = Game:GetService('StarterGui')
local Lighting           = Game:GetService('Lighting')
local Debris             = Game:GetService('Debris')
local Teams              = Game:GetService('Teams')
local BadgeService       = Game:GetService('BadgeService')
local InsertService      = Game:GetService('InsertService')
local MarketplaceService = game:GetService("MarketplaceService")
local Terrain            = Workspace.Terrain

local NevermoreEngine    = _G.NevermoreEngine
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary;

local qSystems           = LoadCustomLibrary('qSystems')

qSystems:Import(getfenv(0));

local lib = {}

-- This service helpers manage the 

local MakeUserActionSystem = Class 'UserActionSystem' (function(UserActionSystem)
	local Actions = {}
	local CurrentAction

	local function AddAction(Action, Name)
		Name = Name or "Unnammed"
		Action.Name = Name
		Action.Data = Action.Data or {}
		-- Adds a new action to the service. Actions have OnStart, OnStop, Condition, and Step

		-- May have: OnButton1Click
		Actions[#Actions+1] = Actions
	end

	function UserActionSystem.Update(Mouse)
		for _, Action in ipairs(Actions) do
			if Action.Condition(Mouse) then

			end
		end
	end
end)