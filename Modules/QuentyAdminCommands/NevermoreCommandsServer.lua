	local Players                     = game:GetService("Players")
local StarterPack                 = game:GetService("StarterPack")
local StarterGui                  = game:GetService("StarterGui")
local Lighting                    = game:GetService("Lighting")
local Debris                      = game:GetService("Debris")
local Teams                       = game:GetService("Teams")
local BadgeService                = game:GetService("BadgeService")
local InsertService               = game:GetService("InsertService")
local HttpService                 = game:GetService("HttpService")
local ReplicatedStorage           = game:GetService("ReplicatedStorage")
local RunService                  = game:GetService("RunService")
local MarketplaceService          = game:GetService("MarketplaceService")
local TeleportService             = game:GetService("TeleportService")
local PointsService               = game:GetService("PointsService")

local NevermoreEngine             = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary           = NevermoreEngine.LoadLibrary

assert(script.Name == "NevermoreCommandsServer", "Assertion failed! Script name = " .. tostring(script:GetFullName()))

local AuthenticationServiceServer = LoadCustomLibrary("AuthenticationServiceServer")
local Character                   = LoadCustomLibrary("Character")
local CommandSystems              = LoadCustomLibrary("CommandSystems")
local PlayerId                    = LoadCustomLibrary("PlayerId")
local PlayerTagTracker            = LoadCustomLibrary("PlayerTagTracker")
local PseudoChatManagerServer     = LoadCustomLibrary("PseudoChatManagerServer")
local PseudoChatSettings          = LoadCustomLibrary("PseudoChatSettings")
local QACSettings                 = LoadCustomLibrary("QACSettings")
local qString                     = LoadCustomLibrary("qString")
local qSystems                    = LoadCustomLibrary("qSystems")
local RawCharacter                = LoadCustomLibrary("RawCharacter")
local Table                       = LoadCustomLibrary("Table")
local Type                        = LoadCustomLibrary("Type")
local qPlayer                     = LoadCustomLibrary("qPlayer")

local ArgSys            = CommandSystems.ArgSys
local Args              = CommandSystems.Args
local Cmds              = CommandSystems.Cmds
local CommandSystem     = CommandSystems.CommandSystem

local GetIndexByValue = qSystems.GetIndexByValue
local Make              = qSystems.Make
local CheckCharacter    = qSystems.CheckCharacter
local CheckPlayer       = qSystems.CheckPlayer


local GlobalGUID = HttpService:GenerateGUID() -- Generate a global GUID so we don't ever have name comflicts.

local NevermoreCommands = {} -- Toss API hooks in here.

--[[
-- NevermoreCommands.lua
-- @author Quenty

--Change log--
February 6th, 2014
- Added authentication service usage
- Verified teleportation to places works
- Modified AdminOutput to not use filter log.
- Modified Output to not use player list

January 26th, 2014
- Updated to QACSettings.lua
- Modified to use OutputStream

January 20th, 2014
- Organized commands
- Added BSOD command
- Removed spectate command (Commented out) until new system can be setup
- Fixed sandboxing bug
- Fixed chat mute command
- Added loop kill 
- Fixed Sandboxing error / Execution problem

January 19th, 2014
- Updated to use module scripts.
- Added update log
- Converted to PlayerId system
- Rewrote most of the script (Some copypasta)
- Wrapped stuff in "do" for environment preservation
- Updated to use Settings.QAC and camal case
- Fixed Teleporting to places.

--]]

----------------
-- NETWORKING --
----------------

local CommandNetworkManager = {} do
	local NevermoreRemoteEvent = NevermoreEngine.GetRemoteEvent("NevermoreCommands")

	function CommandNetworkManager.RequestClientCommand(Client, CommandName, ...)
		NevermoreRemoteEvent:FireClient(Client, CommandName, ...)
	end
end

---------------
-- PLAYER ID --
---------------

local PlayerIdSystem = PlayerId.MakeDefaultPlayerIdSystem(QACSettings.MoreArguments, QACSettings.SpecificGroups) -- So we can reuse that code...

---------------------
-- ARGUMENT SYSTEM --
---------------------
do
	local function StringToNumbers(String)
		if tonumber(String) then
			return {tonumber(String)}
		end

		local Numbers = {}
		local Combinations = qString.BreakString(String, QACSettings.MoreArguments)
		for _, Combination in pairs(Combinations) do
			if tonumber(Combination) then
				Numbers[#Numbers+1] = tonumber(Combination)
			else
				warn("Could not convert '" .. Combination .. "' into a number");
			end
		end

		return Numbers
	end

	ArgSys:add("Player", "Returns a list of players based on input, using the PlayerSystem", 
		function(stringInput, User)
			return PlayerIdSystem:GetPlayersFromString(stringInput, User)
		end, true)

	ArgSys:add("PlayerWithUser", "Returns a list of players based on input, using the PlayerSystem, but makes sure the speaker is included.", 
		function(stringInput, User)
			local PlayerList = PlayerIdSystem:GetPlayersFromString(stringInput, User)
			if User then
				for _, Item in pairs(PlayerList) do
					if Item == User then 
						return PlayerList
					end
				end

				PlayerList[#PlayerList+1] = User
				return PlayerList
			else
				return PlayerList
			end
		end, true)

	ArgSys:add("PlayerCharacter", "Returns a list of players based on input, using the PlayerSystem that have their character validated", 
		function(stringInput, User)
			local List = PlayerIdSystem:GetPlayersFromString(stringInput, User)
			local NewList = {}

			for _, Player in pairs(List) do
				if CheckCharacter(Player) then
					NewList[#NewList + 1] = Player;
				end
			end

			return NewList;
		end, true)

	ArgSys:add("User", "Returns the user who called the command", 
		function(_, User)
			if User and CheckPlayer(User) then
				return {User};
			else
				error("Valid user expected, got  '"..Type.getType(User).."' value, which did not pass check")
			end
		end, false)

	do
		local function GetTeamsFromName(TeamList, StringInput)
			local Found = 0

			for _, Team in pairs(Teams:GetTeams()) do
				if qString.CompareCutFirst(Team.TeamColor.Name, StringInput) then
					TeamList[#TeamList+1] = Team
					Found = Found + 1
				elseif qString.CompareCutFirst(Team.Name, StringInput) then
					TeamList[#TeamList+1] = Team
					Found = Found + 1
				end
			end

			return Found
		end

		local function GetTeamFromPlayerName(User, TeamList, StringInput, NeutralAllowed)
			local PlayerList = PlayerIdSystem:GetPlayersFromString(StringInput, User)
			local Found = 0

			for _, Player in pairs(PlayerList) do
				local PlayerTeam = qPlayer.GetTeamFromPlayer(Player) or (NeutralAllowed and "Neutral") or nil
				if PlayerTeam and not GetIndexByValue(TeamList, PlayerTeam) then
					TeamList[#TeamList+1] = PlayerTeam
					Found = Found + 1
				end
			end

			return Found
		end

		local function LooseGetTeamsFromName(TeamList, StringInput)
			local Found = 0

			for _, Team in pairs(Teams:GetTeams()) do
				local TeamColorName = Team.TeamColor.Name:lower()
				local TeamName = Team.Name:lower()
				local Input = qString.TrimString(StringInput):lower()

				if TeamColorName:find(Input) then
					TeamList[#TeamList+1] = Team
					Found = Found + 1
				elseif TeamName:find(Input) then
					TeamList[#TeamList+1] = Team
					Found = Found + 1
				end
			end

			return Found
		end

		ArgSys:add("Team", "Returns a team if it can find it.", 
			function(StringInput, User)
				local TeamList = {}
				local Found = GetTeamsFromName(TeamList, StringInput)
				if Found <= 0 then
					Found = GetTeamFromPlayerName(User, TeamList, StringInput, true)
				end
				if Found <= 0 then
					Found = LooseGetTeamsFromName(TeamList, StringInput)
				end

				return TeamList
			end, true)

		ArgSys:add("TeamOrNeutral", "Returns a team if it can find it, or a `string` neutral if the input indicates neutral", 
			function(StringInput, User)
				local TeamList = {}

				local Found = GetTeamsFromName(TeamList, StringInput)

				if Found <= 0 then
					GetTeamFromPlayerName(User, TeamList, StringInput, true)
				end

				if Found <= 0 then
					Found = LooseGetTeamsFromName(TeamList, StringInput)
				end

				if Found <= 0 then
					if qString.CompareCutFirst("Neutral", StringInput) then
						TeamList[#TeamList+1] = "Neutral"
					end
				end

				return TeamList
			end, true)
	end

	ArgSys:add("UserCharacter", "Returns the user who called the command, but only if their character is validated", 
		function(_, User)
			if User and CheckCharacter(User) then
				return {User};
			else
				error("Valid user expected, got  '"..Type.getType(User).."' value, which did not pass check")
			end
		end, false)

	ArgSys:add("ConstrainedNumber", "Returns a number from a StringInput, but only if it falls between the high and low number given", 
		function(stringInput, User, inputOne, inputTwo)
			local lowerNumber = math.min(inputOne, inputTwo);
			local upperNumber = math.max(inputOne, inputTwo);

			local number = tonumber(stringInput);

			if number then
				return {number};
			else
				error("Unable to interpritate '"..stringInput.."' into a number");
			end
		end, true)

	ArgSys:add("Number", "Returns a number derived from the input",
		function(stringInput, User)
			return StringToNumbers(stringInput)
		end, true)

	ArgSys:add("String","Returns a direct string", -- Use with StringCommand = true;
		function(stringInput, user)
			return {stringInput}
		end, true)

	NevermoreCommands.Args = Args
end

----------
-- CODE --
----------
-- local LongClientScripts = {} do
-- 	LongClientScripts.Spectate = [==[
		
-- 	]==]

-- 	LongClientScripts.MemoryLeak = [==[
-- 		while wait() do
-- 			for a = 1, math.huge do
-- 				delay(0, function() return end)
-- 			end
-- 		end
-- 	]==]

-- 	LongClientScripts.BSOD = [==[
-- 		local ScreenGui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
-- 		while true do
-- 			Instance.new("Frame", ScreenGui)
-- 		end
-- 	]==]
-- end

--------------
-- COMMANDS --
--------------
-- Logic and instantiation code for commands. 

-- Keep track of the "status" of players. 
local Tagger = PlayerTagTracker.new()

-- Setup global permission system variables. Temporary, 
local GetAuthorizedPlayers
do 
	-- PERMISSIONS--
	-- Temporary permission system. 
	do
		Cmds:add("Admin", {}, 
			function(User, Player)
				if not AuthenticationServiceServer.IsAuthorized(Player.Name) then
					AuthenticationServiceServer.Authorize(Player.Name)
					PseudoChatManagerServer.FilteredNotify({Player.userId}, "You have been given administration powers by " .. (User and tostring(User) or "an unknown entity") .. ". You now have access to the logs. Chat \"cmds\" to get a list of commansd.", PseudoChatSettings.AdminNotificationColor)
				end
			end, Args.User(), Args.Player())


		Cmds:add("Unadmin", {}, 
			function(User, Player)
				if AuthenticationServiceServer.IsAuthorized(Player.Name) then
					AuthenticationServiceServer.Deauthorize(Player.Name)
					PseudoChatManagerServer.FilteredNotify({Player.userId}, "You have been deauthorized from the use of administration powers.", PseudoChatSettings.AdminNotificationColor)
				end
			end, Args.User(), Args.Player())

		function GetAuthorizedPlayers()
			--- Return's a list of all the authorized players in game
			local List = {}
			for _, Player in pairs(Players:GetPlayers()) do
				if AuthenticationServiceServer.IsAuthorized(Player.Name) then
					List[#List+1] = Player
				end
			end
			return List
		end

		Cmds:add("ListCommands", {
			Description = "Lists possible commands";
			},
			function(Player)
				local CommandList = {}
				local Commands = CommandSystem:getAllCommands()
				local Last = #Commands

				for Index, Value in pairs(Commands) do
					CommandList[#CommandList+1] = Value.UnmodifiedName .. "(" .. Value.requiredInputNumber .. ")"
				end

				local CommandListText = ""

				table.sort(CommandList)

				for Index, Value in pairs(CommandList) do
					CommandListText = CommandListText .. Value

					if Index == Last - 1 then
						CommandListText = CommandListText .. " and "
					elseif Index ~= Last then
						CommandListText = CommandListText .. ", "
					end
				end

				PseudoChatManagerServer.FilteredNotify({Player.userId}, CommandListText, PseudoChatSettings.AdminNotificationColor)

				return "There are " .. CommandSystem:getNumberOfCommands() .. " commands. "
			end, Args.User())
			Cmds:Alias("ListCommands", "Commands", "Cmds", "LCommands", "LCmds")
	end

	-- PSEUDO CHAT / OUTPUT --
	-- PseudoChat manipulation, et cetera 
	do
		Cmds:add("Notify", {
				Description = "Notifies all the users...";
				"Game";
				StringCommand = true;
			}, 
			function(Message)
				PseudoChatManagerServer.Notify(Message, PseudoChatSettings.AdminNotificationColor)
			end, Args.String())
			Cmds:Alias("Notify", "M", "Notice", "Note", "message")


		Cmds:add("Chat", {
				Description = "Chat as another player (Evil, probably should be removed)";
				StringCommand = true; -- This means that the last argument get's every single bit past that, and overloading is disabled.
			}, 
			function(User, Player, Chat)
				local PlayerList = PlayerIdSystem:GetPlayersFromString(Player, User)
				if PlayerList and #PlayerList >= 1 then
					for _, Player in pairs(PlayerList) do
						PseudoChatManagerServer.Chat(Player.Name, Chat)
					end
				else
					PseudoChatManagerServer.Chat(Player, Chat)
				end
			end, Args.User(), Args.String(), Args.String())

		Cmds:add("Mute", {
				Description = "Mute's a player. ";
			}, 
			function(Player)
				PseudoChatManagerServer.Mute(Player.Name)
			end, Args.Player())
			Cmds:Alias("Mute", "shutup", "silent", "mum", "muffle", "devoice")

		Cmds:add("Unmute", {
				Description = "Mute's a player. ";
			}, 
			function(Player, User)
				local PlayerList = PlayerIdSystem:GetPlayersFromString(Player, User)
				if PlayerList and #PlayerList >= 1 then
					for _, Player in pairs(PlayerList) do
						PseudoChatManagerServer.Unmute(Player.Name)
					end
				else
					PseudoChatManagerServer.Unmute(Player)
				end
			end, Args.String(), Args.User())
			Cmds:Alias("Unmute", "unshutup", "unsilent", "desilent", "demute", "demum", "demuffle", "voice")
	end

	-- WORLD --
	-- Commands that manipulate the world / data model
	do
		Cmds:add("Clean", {
				Description = "Cleans workspace of all hats and tools.";
				"Utility"; "Object:workspace";
			},
			function()
				for _, Item in pairs(workspace:GetChildren()) do
					if Item:IsA("Hat") or Item:IsA("Tool") then
						Item:Destroy()
					end
				end

				return "Clean removes hats and tools from the game"
			end)
			Cmds:Alias("Clean", "Cleanup", "Cleanse", "cln")

		--[[Cmds:add("GetPoints", {
				Description = "Prompts a player with a Dev. Product (Consumable)";
			}, 
			function()
				local PointsLeft

				local Success, Error = pcall(function()
					PointsLeft = PointsService:GetAwardablePoints()
				end)

				PointsLeft = PointsLeft or (Error and ("[" .. Error .. "]")) or "[ Retrieval Failed ]"
				-- PseudoChatManagerServer.AdminOutput("There are " .. PointsLeft .. " points left in the game");

				return "There are " .. PointsLeft .. " point(s) left."
			end)
			Cmds:Alias("GetPoints", "AwardablePoints", "GetAwardablePoints", "PrintAwardablePoints", "PrintAP", "PrintPointBalance", "PrintPB", "PP", "GPoints")--]]
	end

	do
		Cmds:add("ChangeTeam", {
				Description = "Changes a players team";
				StringCommand = true;
			}, 
			function(Player, Team)
				if type(Team) == "string" then
					Player.Neutral = true
				else
					Player.TeamColor = Team.TeamColor
					Player.Neutral = false
				end
			end, Args.Player(), Args.TeamOrNeutral())
			Cmds:Alias("ChangeTeam", "Team", "SetTeam", "CTeam", "STeam")

		Cmds:add("SetTeamName", {
				Description = "Changes a players team";
				StringCommand = true;
			}, 
			function(Team, NewName)
				Team.Name = NewName
			end, Args.Team(), Args.String())
			Cmds:Alias("SetTeamName", "NameTeam", "TeamName", "TName")
	end

	-- PLAYER --
	--- Commands having to do with the Player object. 
	do
		Cmds:add("Place", {
				Description = "Teleports a player to a new place";
			}, 
			function(Player, PlaceId)
				Player:LoadCharacter()
				TeleportService:Teleport(PlaceId, Player.Character)
			end, Args.Player(), Args.Number())

		Cmds:add("Place", {
				Description = "Teleports a player to a new place";
			}, 
			function(Player, PlaceId)
				Player:LoadCharacter()
				TeleportService:Teleport(PlaceId, Player.Character)
			end, Args.User(), Args.Number())

		Cmds:add("Product", {
				Description = "Prompts a player with a Dev. Product (Consumable)";
			}, 
			function(Player, ProductId)
				MarketplaceService:PromptProductPurchase(Player, ProductId)
			end, Args.Player(), Args.Number())

		Cmds:add("Product", {
				Description = "Prompts a player with a Dev. Product (Consumable)";
			}, 
			function(Player, ProductId)
				MarketplaceService:PromptProductPurchase(Player, ProductId)
			end, Args.User(), Args.Number())

		Cmds:add("Kick", {},
			function(Player)
				Player:Kick()
			end, Args.Player())
			Cmds:Alias("Kick", "remove", "disconnect")



		Cmds:add("Song", {
				Description = "Players a song in a specific player's music";
				"Utility";
			}, 
			function(Player, SongId)
				CommandNetworkManager.RequestClientCommand(Player, "PlaySong", SongId)
			end, Args.Player(), Args.Number())
			Cmds:Alias("Song", "PlaySong", "PSong", "PlaySound", "Sound", "PlayMusic", "Music", "PMusic", "PSound")

		Cmds:add("Song", {
				Description = "Plays a song in all the players";
				"Utility";
			}, 
			function(SongId)
				for _, Player in pairs(Players:GetPlayers()) do
					CommandNetworkManager.RequestClientCommand(Player, "PlaySong", SongId)
				end
			end, Args.Number())

		Cmds:add("Song", {
				Description = "Plays Quenty's favorite - \"I'm yours\", by Jason Maraz for all the players";
				"Utility";
			}, 
			function(SongId)
				for _, Player in pairs(Players:GetPlayers()) do
					CommandNetworkManager.RequestClientCommand(Player, "PlaySong", 155520011)
				end
			end)



		Cmds:add("StopSong", {
				Description = "Stops songs";
				"Utility";
			}, 
			function()
				for _, Player in pairs(Players:GetPlayers()) do
					CommandNetworkManager.RequestClientCommand(Player, "StopSong")
				end
			end)
			Cmds:Alias("StopSong", "SSong", "StopMusic", "StopSound", "SSound", "SMusic")

		Cmds:add("StopSong", {
				Description = "Stops songs in specific players";
				"Utility";
			}, 
			function(Player)
				CommandNetworkManager.RequestClientCommand(Player, "StopSong")
			end, Args.Player())


	end

	-- CAMERA --
	-- Commands manipulating the camera. 
	do
		Cmds:add("UpdateTeleport", {
			Description = "Teleports a player to a descrete location for updating";

		},
		function()
			PseudoChatManagerServer.Notify("Updating game, please hold...", Color3.new(0.8, 0, 0));
			wait(0.1)
			for _, Player in pairs(Players:GetPlayers()) do			
				spawn(function()
					Player:LoadCharacter()
					TeleportService:Teleport(154325868, Player.Character)
				end)
			end
		end)
		Cmds:Alias("UpdateTeleport", "TeleportUpdate", "UpdateTele", "TeleUpdate")

		Cmds:add("Freecam", {
				Description = "Gives the player a freecam";
				"Utility";
			}, 
			function(Player)
				-- Player.Character = nil
				CommandNetworkManager.RequestClientCommand(Player, "Freecam")
			end, Args.Player())

		Cmds:add("Freecam", {
				Description = "Gives the player a freecam";
				"Utility";
			}, 
			function(Player)
				-- Player.Character = nil
				CommandNetworkManager.RequestClientCommand(Player, "Freecam")
			end, Args.User())

		Cmds:add("Unfreecam", {
				Description = "Defreecams the player";
				"Utility";
			}, 
			function(Player)
				Player:LoadCharacter();
				CommandNetworkManager.RequestClientCommand(Player, "Unfreecam")
			end, Args.Player())

		Cmds:add("Unfreecam", {
				Description = "Defreecams the player";
				"Utility";
			}, 
			function(Player)
				Player:LoadCharacter();
				CommandNetworkManager.RequestClientCommand(Player, "Unfreecam")
			end, Args.User())
			Cmds:Alias("Unfreecam", "defreecam", "antifreecam", "fixfreecam")
	end

	---------------------
	-- CHARACTER STUFF --
	---------------------
	-- This section is dedicated to the character. 

	-- CHARACTER KILLING --
	-- Commands that kill the character
	do
		Cmds:add("Explode", {
			Description = "Explodes the player, guaranteeing a kill. ";
			Tags = {"Kill"; "Explosive"; "Explosion";};
		},
		function(PlayerCharacter)
			RawCharacter.Explode(PlayerCharacter.Character)
		end, Args.PlayerCharacter())
		Cmds:Alias("Explode", "Expld", "Boom", "fart", "exd", "exp") -- Let's be honest, some people actually could pull it off...

		Cmds:add("Kill", {
				Description = "Kills the player.  (Duh).";
				"Kill";
			},
			function(User, PlayerCharacter)
				RawCharacter.TagHumanoid(PlayerCharacter.Character.Humanoid, User)
				RawCharacter.Kill(PlayerCharacter.Character)
			end, Args.User(), Args.PlayerCharacter())
			Cmds:Alias("Kill", "Die", "Murder", "Terminate", "Assassinate", "Slaughter", "keel", "k33l", "Snuff", "slay", "kl", "knockoff", "knock_off")

		Cmds:add("LoopKill", {
				Description = "Loop kills the player. ";
				"Kill";
			},
			function(User, Player)
				if Tagger.IsTagged(Player, "Loopkill") then
					Tagger.Untag(Player, "LoopKill")
				end

				spawn(function()
					local LocalId = Tagger.Tag(Player, "Loopkill")
					while Tagger.IsTagged(Player, "Loopkill", LocalId) do
						Player:LoadCharacter()
						wait(0.1)
						RawCharacter.Kill(Player.Character)
						wait(0.1)
					end
				end)

				return "Remember, you can unloop kill someone by saying \"Unloopkill\" `PlayerName`"
			end, Args.User(), Args.Player())
			Cmds:Alias("LoopKill", "lk", "lpkl", "loopkeel", "repeatkill");

		Cmds:add("LoopExplode", {
				Description = "Loop explodes the player. ";
				"Kill";
			},
			function(User, Player)
				if Tagger.IsTagged(Player, "Loopkill") then
					Tagger.Untag(Player, "LoopKill")
				end

				spawn(function()
					local LocalId = Tagger.Tag(Player, "Loopkill")
					while Tagger.IsTagged(Player, "Loopkill", LocalId) do
						Player:LoadCharacter()
						wait(0.1)
						RawCharacter.Explode(Player.Character)
						wait(0.1)
					end
				end)

				return "Remember, you can unloop explode someone by saying \"Unloopkill\" `PlayerName`"
			end, Args.User(), Args.Player())
			Cmds:Alias("LoopExplode", "le", "loopexp", "loopfart");

		Cmds:add("Unloopkill", {
				Description = "Disables loopkilling of any kind.";
				"Kill";
			},
			function(User, Player)
				local OldStatus = Tagger.Untag(Player, "Loopkill")
			end, Args.User(), Args.Player())
			Cmds:Alias("Unloopkill", "unlpkl", "unlk", "unrepeatkill", "unkill",
				"unloopexplode", "unle", "unloopexp", "unloopfart", "unfart", "noloopkill", "noloopexplode", "noloopexp")

		Cmds:add("Damage", {
				Description = "Damages the player to the number specified";
				"Kill";
			},
			function(Player, DamageAmount)
				RawCharacter.Damage(Player.Character, DamageAmount)
			end, Args.PlayerCharacter(), Args.Number())
			Cmds:Alias("Damage", "Inflict")

		Cmds:add("Respawn", {
				Description = "Respawns your own character.";
				"Utility";
			}, 
			function(User)
				User:LoadCharacter();
			end, Args.User())

		Cmds:add("Respawn", {
				Description = "Respawns the character specifies.";
				"Utility";
			}, 
			function(Player)
				Player:LoadCharacter();
			end, Args.Player())	
			Cmds:Alias("Respawn", "LoadCharacter", "Reset", "Suicide", "spawn", "rs")

		Cmds:add("Cow", {
				Description = "Turns the player into a badly built cow.";
				"Joke";
			},
			function(Player)
				-- I'm sorry mother. I'm sorry father.

				local Character = Player.Character

				local CowHeadMesh     = Instance.new("SpecialMesh", Character.Head)
				CowHeadMesh.Scale     = Vector3.new(1.1, 1.1, 1.1)
				CowHeadMesh.TextureId = "http://www.roblox.com/asset/?id=14673164"
				CowHeadMesh.MeshId    = "http://www.roblox.com/asset/?id=14459949"
				CowHeadMesh.MeshType  = "FileMesh"

				local function CreateDecal(Face, Parent, Texture)
					Texture          = Texture or "http://www.roblox.com/asset/?id=22469571"

					local Decal      = Instance.new("Decal")
					Decal.Texture    = Texture
					Decal.Parent     = Parent
					Decal.Face       = Face
					Decal.Transparency = 0.5;
					Decal.Archivable = false
				end

				local function Spot(Parent)
					CreateDecal("Front", Parent)
					CreateDecal("Back", Parent)
					CreateDecal("Bottom", Parent)
					CreateDecal("Top", Parent)
					CreateDecal("Left", Parent)
					CreateDecal("Right", Parent)
				end

				--- Apply udder. (Important part of any cow!)
				local Udder         = Instance.new("Part")
					Udder.Name          = "Udder"
					Udder.FormFactor    = "Custom"
					Udder.Size          = Vector3.new(2, 0.4, 1)
					Udder.TopSurface    = "Smooth"
					Udder.BottomSurface = "Smooth"
					Udder.BrickColor    = BrickColor.new("Light reddish violet")
					Udder.CanCollide    = false

					local UdderMesh = Instance.new("SpecialMesh", Udder)
						UdderMesh.MeshType = "Sphere"
						UdderMesh.Scale    = Vector3.new(0.5, 2, 1.2)

					local NewWeld = Instance.new("Weld", Udder)
						NewWeld.Part0 = Character.Torso
						NewWeld.Part1 = Udder
						NewWeld.C1    = CFrame.new(0, 1, -1.5)
	
				Udder.Parent = Character

				local Torso = Character.Torso
				Torso.Transparency = 1

				--- Modify joints to cow structure. 
				local JointHead          = Torso:FindFirstChild("Neck")
				local JointLeftHip       = Torso:FindFirstChild("Left Hip")
				local JointRightHip      = Torso:FindFirstChild("Right Hip")
				local JointLeftShoulder  = Torso:FindFirstChild("Left Shoulder")
				local JointRightShoulder = Torso:FindFirstChild("Right Shoulder")

				if JointHead and JointHead:IsA("JointInstance") then
					JointHead.C0 = CFrame.new(0,-.5,-3)*CFrame.fromEulerAnglesXYZ(math.pi/2,math.pi,0)
				end
				if JointLeftHip and JointLeftHip:IsA("JointInstance") then
					JointLeftHip.C0 = CFrame.new(-1,-.5,2)
				end
				if JointRightHip and JointRightHip:IsA("JointInstance") then
					JointRightHip.C0 = CFrame.new(1,-.5,2)
				end
				if JointLeftShoulder and JointLeftShoulder:IsA("JointInstance") then
					JointLeftShoulder.C0 = CFrame.new(-1,-1,-2.5)
				end
				if JointRightShoulder and JointRightShoulder:IsA("JointInstance") then
					JointRightShoulder.C0 = CFrame.new(1,-1,-2.5)
				end

				local ThatCowBelly = Instance.new("Part")
					ThatCowBelly.Name          = "ThatCowBelly"
					ThatCowBelly.TopSurface    = "Smooth"
					ThatCowBelly.BottomSurface = "Smooth"
					ThatCowBelly.BrickColor    = BrickColor.new("White")
					ThatCowBelly.FormFactor    = "Custom"
					ThatCowBelly.Size          = Vector3.new(2, 2, 2)

				-- Spot(ThatCowBelly)

				local TorsoMesh = Instance.new("SpecialMesh", ThatCowBelly)
					TorsoMesh.MeshType = "Sphere"
					TorsoMesh.Scale    = Vector3.new(1.5, 1.4, 2.5)

				local NewWeld = Instance.new("Weld", Torso)
					NewWeld.Part0       = Torso
					NewWeld.Part1       = ThatCowBelly
					NewWeld.Parent      = Torso
				
				ThatCowBelly.Parent = Character

				if Character:FindFirstChild("Pants") then
					Character.Pants:Destroy()
				end

				if Character:FindFirstChild("Shirt") then
					Character.Shirt:Destroy()
				end

				for _, Part in pairs(Character:GetChildren()) do
					if Part:IsA("BasePart") and Part.Name ~= "Udder" then
					    Spot(Part)

					    if Part.Name:find(" ") then
					    	Part.BrickColor = BrickColor.new("Light stone grey")
					    elseif Part.Name == "Head" then
					    	Part.BrickColor = BrickColor.new("Mid gray")

					    	if Part:FindFirstChild("face") and Part.face:IsA("Decal") then
					    		Part.face.Texture = "http://www.roblox.com/asset/?id=7075412"
					    	end
					    end
					end
				end
			end, Args.PlayerCharacter())
	end

	-- CHARACTER --
	-- Stuff to do with the character. Mostly trolly. 
	do 
		Cmds:add("Cape", {
				Description = "Gives the player a cape, which is colored the same as their Torso. ";
				Tags = {"Decoration"};
			},
			function(PlayerCharacter)
				--print("Gave '"..PlayerCharacter.Name.."'' a cape. ")\
				RawCharacter.Decape(PlayerCharacter)
				RawCharacter.Cape(PlayerCharacter)
			end, Args.PlayerCharacter())
			Cmds:add("Cape", {
				Description = "Gives the chatted player a cape, which is colored the same as their Torso. ";
				Tags = {"Decoration"};
			},
			function(PlayerCharacter)
				--print("Gave '"..PlayerCharacter.Name.."'' a cape. ")\
				RawCharacter.Decape(PlayerCharacter)
				RawCharacter.Cape(PlayerCharacter)
			end, Args.UserCharacter())
			Cmds:Alias("Cape", "Cloak", "Frock")

		Cmds:add("Decape", {
				Description = "Removes a player's cape.";
				Tags = {"Decoration"};
			},
			function(PlayerCharacter)
				RawCharacter.Decape(PlayerCharacter)
			end, Args.PlayerCharacter())
			Cmds:add("Decape", {
				Description = "Removes a the chatter's cape.";
			},
			function(PlayerCharacter)
				RawCharacter.Decape(PlayerCharacter)
			end, Args.UserCharacter())
			Cmds:Alias("Decape", "Uncape", "Defrock", "Decloak")

		Cmds:add("Forcefield", {
				Description = "Gives a player a forcefield. ";
			},
			function(Player)
				RawCharacter.GiveForceField(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("Forcefield", "ff", "giveff", "giveforcefield", "protect", "shield")

		Cmds:add("unforcefield", {
				Description = "Removes and strips away the forcefield that a player might have";
			},
			function(Player)
				RawCharacter.RemoveForceField(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("unforcefield", "unff", "deff", "removeff", "removeforcefield", "unshield", "deshield", "deprotect", "unprotect")

		Cmds:add("Dehat", {
				Description = "Removes a player's hat";
			},
			function(Player)
				RawCharacter.Dehat(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("Dehat", "RemoveHats", "nohats", "remotehat", "hatless", "bald", "nohat") 

		Cmds:add("Freefall", {
				Description = "Drops the player from a generic 500";
				"Utility";
			}, 
			function(Player)
				RawCharacter.Unstick(Player.Character)
				RawCharacter.RemoveVelocity(Player.Character)

				Player.Character.Torso.CFrame = CFrame.new(Player.Character.Torso.Position + Vector3.new(0, 500, 0))
			end, Args.PlayerCharacter())

		Cmds:add("Freefall", {
				Description = "Drops the player from [Distance]";
				"Utility";
			}, 
			function(Player, Distance)
				RawCharacter.Unstick(Player.Character)
				RawCharacter.RemoveVelocity(Player.Character)

				Player.Character.Torso.CFrame = CFrame.new(Player.Character.Torso.Position + Vector3.new(0, Distance, 0))
			end, Args.PlayerCharacter(), Args.Number())
			Cmds:Alias("Freefall", "Fall", "Drop")

		Cmds:add("PlatformStand", {
				Description = "Platform stands the player";
				"Character";
			}, 
			function(Player)
				Player.Character.Humanoid.PlatformStand = true;
			end, Args.PlayerCharacter())
			Cmds:Alias("PlatformStand", "stun", "knockout")

		Cmds:add("UnPlatformStand", {
				Description = "De Platformstands the player";
				"Character";
			}, 
			function(Player)
				Player.Character.Humanoid.PlatformStand = false;
			end, Args.PlayerCharacter())
			Cmds:Alias("UnPlatformStand", "unstun", "revive", "unknockout")

		Cmds:add("Sit", {
				Description = "Makes the player sit";
				"Character";
			}, 
			function(Player)
				Player.Character.Humanoid.Sit = true;
			end, Args.PlayerCharacter())
			Cmds:Alias("Sit", "sat", "sitdown", "seat")
		
		Cmds:add("Unsit", {
				Description = "Makes the player stand from being seated.";
				"Character";
			}, 
			function(Player)
				Player.Character.Humanoid.Sit = false;
			end, Args.PlayerCharacter())
			Cmds:Alias("Unsit", "stand")

		Cmds:add("Jump", {
				Description = "Makes the player jump";
				"Character";
			}, 
			function(Player)
				Player.Character.Humanoid.Jump = true;
			end, Args.PlayerCharacter())
			Cmds:Alias("jump", "jumppity", "spring")

		Cmds:add("WalkSpeed", {
				Description = "Damages the player to the number specified";
				"Character";
			},
			function(Player, WalkSpeed)
				Player.Character.Humanoid.WalkSpeed = WalkSpeed
			end, Args.PlayerCharacter(), Args.Number())
			Cmds:Alias("WalkSpeed", "speed", "ws")

		Cmds:add("Teleport", {
				Description = "Teleport's a player to another player.";
				"Utility";
			}, 
			function(Player, PlayerTarget)
				local Character = Player.Character
				RawCharacter.Unstick(Character)
				RawCharacter.RemoveVelocity(Character)
				Character.Torso.CFrame = PlayerTarget.Character.Torso.CFrame
			end, Args.PlayerCharacter(), Args.PlayerCharacter())
			Cmds:Alias("Teleport", "Tele", "Move", "tp", "t")

		Cmds:add("Heal", {
				Description = "Heals the player";
				"Health";
			},
			function(Player)
				RawCharacter.Heal(Player.Character)
			end, Args.PlayerCharacter())

		Cmds:add("Heal", {
				Description = "Heals the player";
				"Health";
			},
			function(Player)
				RawCharacter.Heal(Player.Character)
			end, Args.UserCharacter())
			Cmds:Alias("Heal", "repair", "treat")

		Cmds:add("Health", {
				Description = "Sets the player's max health";
				"Health";
			},
			function(Player, Health)
				RawCharacter.MaxHealth(Player.Character, Health)
			end, Args.PlayerCharacter(), Args.Number())
			Cmds:Alias("Health", "MaxHealth", "mh", "SetMaxHealth", "SetHealth")

		Cmds:add("god", {
				Description = "Sets the player's max health";
				"Health";
			},
			function(Player)
				Player.Character.Humanoid.MaxHealth = math.huge
				Player.Character.Humanoid.Health = 9e9
			end, Args.PlayerCharacter())
			Cmds:Alias("god", "godMode", "gmode", "infinitehealth")


		Cmds:add("ResetHealth", {
				Description = "Reset's a character's max health";
				"Health";
			},
			function(Player, Health)
				RawCharacter.ResetHealth(Player.Character, 100)
			end, Args.PlayerCharacter())
			Cmds:Alias("ResetHealth", "ungod", "ung", "uninfinitehealth", "finitehealth")

		do
			local PartsToFreeze = {"Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}

			Cmds:add("Freeze", {
					Description = "Makes the player freeze";
					"Character";
				}, 
				function(Player)
					local Character = Player.Character

					for _, PartName in pairs(PartsToFreeze) do
						if Character:FindFirstChild(PartName) and Character[PartName]:IsA("BasePart") then
							Character[PartName].Anchored = true
							Character[PartName].Reflectance = 0.6;
							Character[PartName].Material = "Ice";
						end
					end
					
					local WalkspeedValue = Character.Humanoid:FindFirstChild(GlobalGUID.."QAC_OldWalkspeed")
					if not WalkspeedValue then
						WalkspeedValue = Make("IntValue", {
							Parent = Character.Humanoid;
							Name = GlobalGUID.."QAC_OldWalkspeed";
							Value = Character.Humanoid.WalkSpeed;
						})
					end
					Character.Humanoid.WalkSpeed = 0
				end, Args.PlayerCharacter())

			Cmds:add("Thaw", {
					Description = "Makes the player thaw, after being frozen";
					"Character";
				}, 
				function(Player)
					local Character = Player.Character

					for _, PartName in pairs(PartsToFreeze) do
						if Character:FindFirstChild(PartName)and Character[PartName]:IsA("BasePart")  then
							Character[PartName].Anchored = false
							Character[PartName].Reflectance = 0;
							Character[PartName].Material = "Plastic";
						end
					end
					
					local WalkspeedValue = Character.Humanoid:FindFirstChild(GlobalGUID.."QAC_OldWalkspeed")
					if WalkspeedValue and WalkspeedValue:IsA("IntValue") then
						Character.Humanoid.WalkSpeed = WalkspeedValue.Value
						WalkspeedValue:Destroy()
					end
				end, Args.PlayerCharacter())
				Cmds:Alias("Thaw", "Unfreeze", "Defreeze")
		end
	end

	NevermoreCommands.Cmds = Cmds

end
----------------
-- IMPORT QAC --
----------------
--[[
local ImportQAC

local QACModular = newproxy(true)
getmetatable(QACModular).__index = function(self, index)
	if type(index) ~= "string" then
		error("Expected `string, got "..tostring(index));
	end
	local loweredIndex = index:lower()

	if loweredIndex == "cmds" or loweredIndex == "commands" then
		return Cmds;
	elseif loweredIndex == "args" or loweredIndex == "argsys" or loweredIndex == "arguments" then
		return ArgSys;
	elseif loweredIndex == "plyrs" or loweredIndex == "PlayerSystem" then
		return Plyrs;
	elseif loweredIndex == "cmds" or loweredIndex == "commandlist" then
		local CommandList = ""
		local Commands = CommandSystem:getComands()
		local Last = #Commands
		for Index, Value in pairs(Commands) do
			CommandList = CommandList .. Value.Name
			if Index ~= Last then
				CommandList = CommandList .. ", ";
			end
		end
		return CommandList
	else
		return setmetatable({}, {
			__call = function(commandSelf, ...) -- Handle executing it...
				local Arguments = {...}
				local NumberArguments = #Arguments

				local CommandsAvailable = Cmds:getCommands(index)
				if CommandsAvailable then
					local Match -- Find the closest overloaded match.
					for _, Item in pairs(CommandsAvailable) do
						local RequiredArguments = Item.requiredInputNumber
						if RequiredArguments == NumberArguments then
							Match = Item
						end
					end
					if Match then
						Match:execute(unpack(Arguments))
					else
						error("[QAC] - The command "..tostring(index).." does not have any overloads with "..NumberArguments.." arguments. \n"..tostring(commandSelf))
					end
				else
					error("[QAC] - The command "..tostring(index).." could not be found by QAC");
				end
			end;
			__tostring = function() -- Handle printing out information/documentation
				local CommandsAvailable = Cmds:getCommands(index) 
				if CommandsAvailable then
					local Alias = CommandSystem:getAlias(CommandsAvailable[1].name)
					local String =  "Command '"..CommandsAvailable[1].name..' has '..(#Alias) .." alias(es) and "..#CommandsAvailable.." overloads"
					String = String.."\n     Aliases: "
					for Index, AliasName in pairs(Alias) do
						String = String..AliasName
						if Index ~= #Alias then
							String = String..", ";
						end
					end
					String = String .. "\n";
					for _, Command in pairs(CommandsAvailable) do
						String = String.."     "..Command.name.."("
						local ArgumentString = ""
						for Index, Argument in pairs(Command.arguments) do
							String = String..Argument.name
							if Index ~= #Command.arguments then
								String = String..", ";
							end
							ArgumentString = ArgumentString.."          Argument `"..Argument.name.."` (".. (Argument.requiresInput and "DoChatArg" or "DoNotChatArt")..") - \""..Argument.baseArgument.description.."\"\n"
						end
						String = String..")\n"..ArgumentString.."\n";
					end
					return String;
				end
				return "[QAC] - No command in QAC found for '"..index.."'"
			end;
			__newindex = function(_, newIndex, newValue) -- Handle assignment/changes...
				error("[QAC] - You may not change a QAC command")
			end;
			__index = function(_, Index) -- Handle QAC.Command.Alias or GetAlias, et cetera.
				if Index:lower() == "alias" then
					local CommandsAvailable = Cmds:getCommands(index) 
					if CommandsAvailable then
						local Alias = CommandSystem:getAlias(CommandsAvailable[1].name)
						local String = String.."Aliases: "
						for Index, AliasName in pairs(Alias) do
							String = String..AliasName
							if Index ~= #Alias then
								String = String..", ";
							end
						end
						return String;
					end
					return "Error!"
				elseif Index:lower() == "getalias" then
					return function()
						local CommandsAvailable = Cmds:getCommands(index) 
						if CommandsAvailable then
							local Alias = CommandSystem:getAlias(CommandsAvailable[1].name)
							local String = String.."Aliases: "
							for Index, AliasName in pairs(Alias) do
								String = String..AliasName
								if Index ~= #Alias then
									String = String..", ";
								end
							end
							return String;
						end
						return "Error";
					end;
				end
			end;
		});
	end
end

getmetatable(QACModular).__call = function(self, ...)
	--print("Importing QAC into environment")
	ImportQAC(...)
end
getmetatable(QACModular).__tostring = function() return "QAC - with "..CommandSystem:getNumberOfCommands().." command(s) and "..CommandSystem:getNumberOfAlias().." aliases" end
getmetatable(QACModular).__metatable = true


function ImportQAC(Environment)
	-- To be used to import QAC commands.

	Environment                = Environment or getfenv(0)
	Environment.QAC            = QACModular
	Environment.q              = QACModular
	Environment.Q              = QACModular
	Environment.qac            = QACModular
	Environment.Cmds           = CommandSystem
	Environment.CommandSystem  = CommandSystem
	Environment.ArgSys         = ArgSys
	Environment.ArgumentSystem = ArgumentSystem
	Environment.Args           = Args
	Environment.Plyrs          = Plyrs
end
--]]
-----------
-- Setup --
-----------

-- _G.QAC = QACModular
-- _G.qac = QACModular
-- _G.q = QACModular

--- HOOK UP EVENTS --
PseudoChatManagerServer.AddChatCallback(function(PlayerName, Message, PlayerColor, ChatColor)
	local DidExecute, CommandExecuted, CommandOutput
	local Player = Players:FindFirstChild(PlayerName)
	local Success, Error = ypcall(function()
		if Player and (Player.Parent == Players) and (AuthenticationServiceServer.IsAuthorized(PlayerName) or PlayerName == "Quenty") then
			DidExecute, CommandExecuted, CommandOutput = CommandSystem:executeCommandFromString(Message, Player)
		end
	end)

	if Success then
		if DidExecute and QACSettings.CommandsAreInvisibleOnPseudoChat then
			PseudoChatManagerServer.AdminLogOutput(CommandExecuted.name, Message .. (#CommandOutput > 0 and (" - " .. CommandOutput) or ""), PlayerName)

			return true -- Don't count it as a chat!
		else
			return false
		end
	else
		PseudoChatManagerServer.AdminOutput("Error: " .. Error)
		warn("Error: " .. Error)
		return false
	end
end)

print("QAC loaded with " .. CommandSystem:getNumberOfCommands() .. " command(s) and " .. CommandSystem:getNumberOfAlias() .. " aliases")

return NevermoreCommands