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
local PlayerManager     = LoadCustomLibrary('PlayerManager').PlayerManager

qSystems:Import(getfenv(0));

local lib = {}

RespawnService = service 'RespawnService' (function(RespawnService)
	RespawnService.Enabled = false;
	RespawnService.RespawnTime = 0;

	function RespawnService:Enable(Value)
		-- Sets whether this service is enabled or not. One shoudl note you need to manually call setupPlayer
		--[[if Value and Players.CharacterAutoLoads then
			warn("CharaterAutoLoads is not set relative to respawn service, you could get some weird or glitched loading. ")
		end--]]

		RespawnService.Enabled = Value
		Players.CharacterAutoLoads = not Value
		RespawnService.RespawnAllPlayers()
	end

	PlayerManager.PlayerAdded:connect(function(Player)
		if RespawnService.Enabled then -- We've got to respawn them when they're added, of course. 
			Player:LoadCharacter(true)
		end
	end)

	PlayerManager.CharacterDied:connect(function(Player)
		wait(RespawnService.RespawnTime)
		if RespawnService.Enabled then
			Player:LoadCharacter(true);
		end
	end)

	function RespawnService:RespawnAllPlayers(DoNotRespawnPlayer)
		-- Respawns all the players, regardless of if they've been enabled or not. 

		for _, Player in pairs(Players:GetPlayers()) do
			if Player and DoNotRespawnPlayer and not DoNotRespawnPlayer(Player) then
				Player:LoadCharacter();
			end
		end
	end

	RespawnService:Enable(RespawnService.Enabled)
end)

lib.RespawnService = RespawnService;

NevermoreEngine.RegisterLibrary('RespawnService', lib);