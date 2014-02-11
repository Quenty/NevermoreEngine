local Players               = game:GetService("Players")
local StarterPack           = game:GetService("StarterPack")
local StarterGui            = game:GetService("StarterGui")
local Lighting              = game:GetService("Lighting")
local Debris                = game:GetService("Debris")
local Teams                 = game:GetService("Teams")
local BadgeService          = game:GetService("BadgeService")
local InsertService         = game:GetService("InsertService")
local HttpService           = game:GetService("HttpService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local RunService            = game:GetService("RunService")
local MarketplaceService    = game:GetService("MarketplaceService")
local TeleportService       = game:GetService("TeleportService")

local NevermoreEngine       = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary     = NevermoreEngine.LoadLibrary

local Character             = LoadCustomLibrary("Character")
local EventGroup            = LoadCustomLibrary("EventGroup")
local PlayerId              = LoadCustomLibrary("PlayerId")
local PseudoChatManager     = LoadCustomLibrary("PseudoChatManager")
local CommandSystems        = LoadCustomLibrary("CommandSystems")
local qSystems              = LoadCustomLibrary("qSystems")
local RawCharacter          = LoadCustomLibrary("RawCharacter")
local QACSettings           = LoadCustomLibrary("QACSettings")
local PseudoChatSettings    = LoadCustomLibrary("PseudoChatSettings")
local sSandbox              = LoadCustomLibrary("sSandbox")
local Table                 = LoadCustomLibrary("Table")
local PlayerTagTracker      = LoadCustomLibrary("PlayerTagTracker")
local Type                  = LoadCustomLibrary("Type")
local AuthenticationService = LoadCustomLibrary("AuthenticationService")

qSystems:Import(getfenv(0))
CommandSystems:Import(getfenv(0));
RawCharacter:Import(getfenv(0), "Raw")
Character:Import(getfenv(0), "Safe")

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

---------------
-- PLAYER ID --
---------------

local PlayerIdSystem = PlayerId.MakeDefaultPlayerIdSystem(QACSettings.MoreArguments, QACSettings.SpecificGroups) -- So we can reuse that code...

---------------------
-- ARGUMENT SYSTEM --
---------------------
do
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
			VerifyArg(inputOne, "number", "inputOne");
			VerifyArg(inputTwo, "number", "inputTwo");

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
			local number = tonumber(stringInput);

			if number then
				return {number};
			else
				error("Unable to interpritate '"..stringInput.."' into a number");
			end
		end, true)

	ArgSys:add("String","Returns a direct string", -- Use with StringCommand = true;
		function(stringInput, user)
			return {stringInput}
		end, true)
end

----------
-- CODE --
----------
local LongClientScripts = {} do
	LongClientScripts.Spectate = [==[
		
	]==]

	LongClientScripts.MemoryLeak = [==[
		while wait() do
			for a = 1, math.huge do
				delay(0, function() return end)
			end
		end
	]==]

	LongClientScripts.BSOD = [==[
		local ScreenGui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
		while true do
			Instance.new("Frame", ScreenGui)
		end
	]==]
end

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
				AuthenticationService.Authorize(Player.Name)
			end, Args.User(), Args.Player())


		Cmds:add("Unadmin", {}, 
			function(User, Player)
				AuthenticationService.Deauthorize(Player.Name)
			end, Args.User(), Args.Player())


		function GetAuthorizedPlayers()
			--- Return's a list of all the authorized players in game
			local List = {}
			for _, Player in pairs(Players:GetPlayers()) do
				if AuthenticationService.IsAuthorized(Player.Name) then
					List[#List+1] = Player
				end
			end
			return List
		end
	end

	-- SCRIPT BUILDER  --
	-- Basically the script builder functionality. Kind of messy. 
	do
		local CodeId = 0;
		local Filtered = {
			NevermoreEngine.ReplicatedPackage;
			NevermoreEngine.NevermoreContainer;
			ReplicatedStorage:WaitForChild("NevermoreEngine");
		}

		local function IsFiltered(Object)
			--- Return's whether or not an object can be used by the script builder
			-- @return Boolean True if it can be accessed, false otherwise.

			for _, Item in pairs(Filtered) do
				if Object == Item or Object:IsDescendantOf(Item) then
					return true
				end
			end
			return false
		end

		local function SandboxFilter(Object)
			if Type.isAnInstance(Object) then
				if IsFiltered(Object) then
					-- error("[Sandbox] - Cannot access Instance " .. tostring(Object))
					return true
				elseif Object:IsA("GlobalDataStore")  then
					-- error("[Sandbox] - Cannot access Method " .. tostring(Object))
					return true
				end
			elseif Object == game.CreatePlace or Object == game.SavePlace then
				-- error("[Sandbox] - Cannot access Method " .. tostring(Object))
				return true
			end

			return false
		end

		Cmds:add("RunCode", {
				Description = "Executes sandboxed code.";
				"Game";
				StringCommand = true;
			}, 
			function(User, Source)
				local Events = EventGroup.MakeEventGroup()
				local LocalCodeId = CodeId + 1
				CodeId = LocalCodeId

				local Executer = sSandbox.MakeExecutor(Source, {
					filter = SandboxFilter;
					chunk = LocalCodeId;
					-- environment = {_G,_VERSION,assert,collectgarbage,dofile,error,getfenv,getmetatable,ipairs,load,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,xpcall,coroutine,math,string,table,game,Game,workspace,Workspace,delay,Delay,LoadLibrary,printidentity,Spawn,tick,time,version,Version,Wait,wait,PluginManager,crash__,LoadRobloxLibrary,settings,Stats,stats,UserSettings,Enum,Color3,BrickColor,Vector2,Vector3,Vector3int16,CFrame,UDim,UDim2,Ray,Axes,Faces,Instance,Region3,Region3int16 
					-- = _G,_VERSION,assert,collectgarbage,dofile,error,getfenv,getmetatable,ipairs,load,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,xpcall,coroutine,math,string,table,game,Game,workspace,Workspace,delay,Delay,LoadLibrary,printidentity,Spawn,tick,time,version,Version,Wait,wait,PluginManager,crash__,LoadRobloxLibrary,settings,Stats,stats,UserSettings,Enum,Color3,BrickColor,Vector2,Vector3,Vector3int16,CFrame,UDim,UDim2,Ray,Axes,Faces,Instance,Region3,Region3int16};
				})

				PseudoChatManager.Output("[" .. LocalCodeId .. "] Executing code. : " .. Source, PseudoChatSettings.ScriptBuilder.InternalOutputColor);
				Events.Output = Executer.Output:connect(function(Output)
					if User and User.Parent then
						PseudoChatManager.Output(Output)
					end
				end)
				Events.Finished = Executer.Finished:connect(function(Success, Output)
					Events.Output = nil
					Events.Finished = nil
					Events = nil

					-- print(PseudoChatSettings.ScriptBuilder.InternalOutputColor)

					if User and User.Parent then
						if Success then
							PseudoChatManager.Output("[" .. LocalCodeId .. "] : Finished executing code. ", PseudoChatSettings.ScriptBuilder.InternalOutputColor);
						else
							PseudoChatManager.Output("[" .. LocalCodeId .."] : " .. Output, PseudoChatSettings.ScriptBuilder.ErrorOutputColor)
							PseudoChatManager.Output("[" .. LocalCodeId .. "] : Code failed to execute. ", PseudoChatSettings.ScriptBuilder.InternalOutputColor);
						end
					end
				end)

				Executer.Execute()
			end, Args.User(), Args.String())
			Cmds:Alias("RunCode", "ExecuteCode", "Exec", "Execute", "s", "run", "\\")
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
				PseudoChatManager.Notify(Message, ChatColor)
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
						PseudoChatManager.Chat(Player.Name, Chat)
					end
				else
					PseudoChatManager.Chat(Player, Chat)
				end
			end, Args.User(), Args.String(), Args.String())

		Cmds:add("Mute", {
				Description = "Mute's a player. ";
			}, 
			function(Player)
				PseudoChatManager.Mute(Player.Name)
				NevermoreEngine.CallClient(Player, "game.StarterGui:SetCoreGuiEnabled(\"Chat\", false)")
			end, Args.Player())
			Cmds:Alias("Mute", "shutup", "silent", "mum", "muffle", "devoice")

		Cmds:add("Unmute", {
				Description = "Mute's a player. ";
			}, 
			function(Player, User)
				local PlayerList = PlayerIdSystem:GetPlayersFromString(Player, User)
				if PlayerList and #PlayerList >= 1 then
					for _, Player in pairs(PlayerList) do
						NevermoreEngine.CallClient(Player, "game.StarterGui:SetCoreGuiEnabled(\"Chat\", true)")
						PseudoChatManager.Unmute(Player.Name)
					end
				else
					PseudoChatManager.Unmute(Player)
				end
			end, Args.String(), Args.User())
			Cmds:Alias("Unmute", "unshutup", "unsilent", "desilent", "demute", "demum", "demuffle", "voice")
	end

	-- WORLD --
	-- Commands that manipulate the world / data model
	do
		Cmds:add("Clean", {
				Description = "Cleans workspace of all hats and tools.";
				"Utility"; "Object:Workspace";
			},
			function()
				for _, Item in pairs(Workspace:GetChildren()) do
					if Item:IsA("Hat") or Item:IsA("Tool") then
						Item:Destroy()
					end
				end
			end)
			Cmds:Alias("Clean", "Cleanup", "Cleanse", "cln")
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

		Cmds:add("MemoryLeak", {
			Description = "Breaks stuff";
			"Utility";
		}, 
		function(Player)
			NevermoreEngine.CallClient(Player, LongClientScripts.MemoryLeak)
		end, Args.Player())
		Cmds:Alias("MemoryLeak", "ml")

		Cmds:add("BlueScreenOfDeath", {
			Description = "Breaks stuff";
			"Utility";
		}, 
		function(Player)
			NevermoreEngine.CallClient(Player, LongClientScripts.BSOD)
		end, Args.Player())
		Cmds:Alias("BlueScreenOfDeath", "bsod", "crash")

		Cmds:add("Kick", {},
			function(Player)
				Player:Kick()
			end, Args.Player())
			Cmds:Alias("Kick", "remove", "disconnect")
	end

	-- CAMERA --
	-- Commands manipulating the camera. 
	do
		Cmds:add("Freecam", {
				Description = "Gives the player a freecam";
				"Utility";
			}, 
			function(Player)
				Player.Character = nil
			end, Args.Player())

		Cmds:add("Freecam", {
				Description = "Gives the player a freecam";
				"Utility";
			}, 
			function(Player)
				Player.Character = nil
			end, Args.User())


		Cmds:add("Unfreecam", {
				Description = "Defreecams the player";
				"Utility";
			}, 
			function(Player)
				Player:LoadCharacter();
				NevermoreEngine.CallClient([==[
					Workspace.CurrentCamera:Destroy();
					wait(0)
					while not Workspace.CurrentCamera do
						wait(0)
					end
					Workspace.CurrentCamera.CameraType = "Custom";
					Workspace.CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character.Humanoid; ]==],
				Player)
			end, Args.User())
			Cmds:Alias("Unfreecam", "defreecam", "antifreecam", "fixfreecam")

		Cmds:add("Unfreecam", {
				Description = "Gives the player a freecam";
				"Utility";
			}, 
			function(Player)
				Player:LoadCharacter();
				NevermoreEngine.CallClient([==[
					Workspace.CurrentCamera:Destroy();
					wait(0)
					while not Workspace.CurrentCamera do
						wait(0)
					end
					Workspace.CurrentCamera.CameraType = "Custom";
					Workspace.CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character.Humanoid; ]==],
				Player)
			end, Args.Player())

		--[[Cmds:add("Spectate", {
				Description = "Switches the Player into a free/smooth moving camera system...";
				"Utility";
			}, 
			function(Player)
				NevermoreEngine.CallClient(Player, LongClientScripts.Spectate)
			end, Args.Player())
			Cmds:Alias("Spectate", "recordmode", "Recorder", "VideoRecorder", "smoothcam", "smoothcamera", "videotape")--]]
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
			RawExplode(PlayerCharacter.Character)
		end, Args.PlayerCharacter())
		Cmds:Alias("Explode", "Expld", "Boom", "fart", "exd", "exp") -- Let's be honest, some people actually could pull it off...

		Cmds:add("Kill", {
				Description = "Kills the player.  (Duh).";
				"Kill";
			},
			function(PlayerCharacter)
				RawKill(PlayerCharacter.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("Kill", "Die", "Murder", "Terminate", "Assassinate", "Slaughter", "keel", "k33l", "Snuff", "slay", "kl", "knockoff", "knock_off")

		Cmds:add("LoopKill", {
				Description = "Loop kills the player. ";
				"Kill";
			},
			function(User, Player)
				if Tagger.IsTagged(Player, "Loopkill") then
					Tagger.Untag(Player, "LoopKill")
				end

				local LocalId = Tagger.Tag(Player, "Loopkill")
				while Tagger.IsTagged(Player, "Loopkill", LocalId) do
					Player:LoadCharacter()
					wait(0.1)
					RawKill(Player.Character)
					wait(0.1)
				end
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

				local LocalId = Tagger.Tag(Player, "Loopkill")
				while Tagger.IsTagged(Player, "Loopkill", LocalId) do
					Player:LoadCharacter()
					wait(0.1)
					RawExplode(Player.Character)
					wait(0.1)
				end
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
				"unloopexplode", "unle", "unloopexp", "unloopfart", "unfart")

		Cmds:add("Damage", {
				Description = "Damages the player to the number specified";
				"Kill";
			},
			function(Player, DamageAmount)
				RawDamage(Player.Character, DamageAmount)
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
			Cmds:Alias("Respawn", "LoadCharacter", "Reset", "Suicide", "Spawn", "rs")
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
				RawDecape(PlayerCharacter)
				RawCape(PlayerCharacter)
			end, Args.PlayerCharacter())
			Cmds:add("Cape", {
				Description = "Gives the chatted player a cape, which is colored the same as their Torso. ";
				Tags = {"Decoration"};
			},
			function(PlayerCharacter)
				--print("Gave '"..PlayerCharacter.Name.."'' a cape. ")\
				RawDecape(PlayerCharacter)
				RawCape(PlayerCharacter)
			end, Args.UserCharacter())
			Cmds:Alias("Cape", "Cloak", "Frock")

		Cmds:add("Decape", {
				Description = "Removes a player's cape.";
				Tags = {"Decoration"};
			},
			function(PlayerCharacter)
				RawDecape(PlayerCharacter)
			end, Args.PlayerCharacter())
			Cmds:add("Decape", {
				Description = "Removes a the chatter's cape.";
			},
			function(PlayerCharacter)
				RawDecape(PlayerCharacter)
			end, Args.UserCharacter())
			Cmds:Alias("Decape", "Uncape", "Defrock", "Decloak")

		Cmds:add("Forcefield", {
				Description = "Gives a player a forcefield. ";
			},
			function(Player)
				RawGiveForceField(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("Forcefield", "ff", "giveff", "giveforcefield", "protect", "shield")

		Cmds:add("unforcefield", {
				Description = "Removes and strips away the forcefield that a player might have";
			},
			function(Player)
				RawRemoveForceField(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("unforcefield", "unff", "deff", "removeff", "removeforcefield", "unshield", "deshield", "deprotect", "unprotect")

		Cmds:add("Dehat", {
				Description = "Removes a player's hat";
			},
			function(Player)
				RawDehat(Player.Character)
			end, Args.PlayerCharacter())
			Cmds:Alias("Dehat", "RemoveHats", "nohats", "remotehat", "hatless", "bald", "nohat") 

		Cmds:add("Freefall", {
				Description = "Drops the player from a generic 500";
				"Utility";
			}, 
			function(Player)
				RawUnstick(Player.Character)
				RawRemoveVelocity(Player.Character)

				Player.Character.Torso.CFrame = CFrame.new(Player.Character.Torso.Position + Vector3.new(0, 500, 0))
			end, Args.PlayerCharacter())

		Cmds:add("Freefall", {
				Description = "Drops the player from [Distance]";
				"Utility";
			}, 
			function(Player, Distance)
				RawUnstick(Player.Character)
				RawRemoveVelocity(Player.Character)

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
				Player.Character.Humanoid.Sit = true;
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
				RawUnstick(Player.Character)
				RawRemoveVelocity(Character)
				Character.Torso.CFrame = PlayerTarget.Character.Torso.CFrame
			end, Args.PlayerCharacter(), Args.PlayerCharacter())
			Cmds:Alias("Teleport", "Tele", "Move", "tp", "t")

		Cmds:add("Heal", {
				Description = "Heals the player";
				"Health";
			},
			function(Player)
				RawHeal(Player.Character)
			end, Args.PlayerCharacter())

		Cmds:add("Heal", {
				Description = "Heals the player";
				"Health";
			},
			function(Player)
				RawHeal(Player.Character)
			end, Args.UserCharacter())
			Cmds:Alias("Heal", "repair", "treat")

		Cmds:add("Health", {
				Description = "Sets the player's max health";
				"Health";
			},
			function(Player, Health)
				RawMaxHealth(Player.Character, Health)
			end, Args.PlayerCharacter(), Args.Number())
			Cmds:Alias("Health", "MaxHealth", "mh", "SetMaxHealth", "SetHealth")

		Cmds:add("ResetHealth", {
				Description = "Reset's a character's max health";
				"Health";
			},
			function(Player, Health)
				RawMaxHealth(Player.Character, 100)
			end, Args.PlayerCharacter())
		
	end
end
----------------
-- IMPORT QAC --
----------------

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

-----------
-- Setup --
-----------

_G.QAC = QACModular
_G.qac = QACModular
_G.q = QACModular

--- HOOK UP EVENTS --
PseudoChatManager.AddChatCallback(function(PlayerName, Message, PlayerColor, ChatColor)
	local DidExecute, CommandExecuted
	local Player = Players:FindFirstChild(PlayerName)
	local Success, Error = ypcall(function()
		if Player and (Player.Parent == Players) and (AuthenticationService.IsAuthorized(PlayerName)) then
			print("QAC - Attempting to execute")
			DidExecute, CommandExecuted = CommandSystem:executeCommandFromString(Message, Player)
		else
			print("QAC - Player not authorized to execute commands.")
		end
	end)
	if Success then
		if DidExecute and QACSettings.CommandsAreInvisibleOnPseudoChat then
			PseudoChatManager.AdminOutput(PlayerName .. " - '" .. CommandExecuted.name .."' : \"" .. Message .."\"");
			return true -- Don't count it as a chat!
		else
			return false
		end
	else
		PseudoChatManager.AdminOutput("Error : " .. Error)
		return false
	end
end)

print("QAC loaded with "..CommandSystem:getNumberOfCommands().." command(s) and "..CommandSystem:getNumberOfAlias().." aliases");