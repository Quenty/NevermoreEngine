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
local qString           = LoadCustomLibrary('qString')
local qCommandServices  = LoadCustomLibrary('qCommandServices')
local PersistantLog     = LoadCustomLibrary('PersistantLog')
local qSystems          = LoadCustomLibrary('qSystems')
local SettingsService   = LoadCustomLibrary('SettingsService')
local Settings          = SettingsService.Settings
local DataTransfer      = LoadCustomLibrary('DataTransfer');
local EasyConfiguration = LoadCustomLibrary('EasyConfiguration');

local RbxUtility = LoadLibrary("RbxUtility")

qSystems:Import(getfenv(0));

local lib = {}

local WEAK_MODE = {
	K = {__mode="k"};
	V = {__mode="v"};
	KV = {__mode="kv"};
}

local ServerNotification = ResourceBin:FindFirstChild("ServerNotification") or Make 'StringValue' {
	Name = "ServerNotification";
	Value = "";
	Parent = ResourceBin;
	Archivable = false;
}
local ServerChatLog = PersistantLog.GetPersistantLog(PersistantLog.AddSubDataLayer("ServerChatLog", ResourceBin))

local PlayerManager

local RobloxAdmins = Settings.RobloxAdmins

local SpecialChatColors = {
	["AlaxanderTheGreat"] = Color3.new(0, 1, 1);
	["Quenty"] = Color3.new(1, 215/255, 0); 
	["bob104810"] = Color3.new(1, 215/255, 0); 
	["fireantfive"] = Color3.new(1, 215/255, 0); 
	["Player1"] = Color3.new(1, 215/255, 0);
	["PumpedRobloxian"] = Color3.new(0, 202/255, 220/255);
	["xXxMoNkEyMaNxXx"] = BrickColor.new("Bright violet").Color;
}
local function IsRobloxAdmin(Name)
	Name = Name:lower()
	for _, Admin in pairs(RobloxAdmins) do
		if Admin:lower() == Name then
			return true
		end
	end
	return false
end
lib.IsRobloxAdmin = IsRobloxAdmin;
lib.isRobloxAdmin = IsRobloxAdmin;

local function GetServerChatLog()
	return ServerChatLog
end
lib.GetServerChatLog = GetServerChatLog
lib.getServerChatLog = GetServerChatLog

local PlayerReferenceChecks = {
	--function (Players, )
}

local ChatManager = Service 'ChatManager' (function(ChatManager)
	local ChatCallbacks = {--[[
		function(Player, Chat, ChatLogValue) -- Morph the ChatLogValue into a whispher chat...
			if Chat and (Chat:sub(1, 1) == "@" or Chat:sub(1, 1) == "%") then
				print("[ChatManager] - Team chat!")
				local PlayersAt = {}
				local Start, Finish = string.find(Chat.." ", "^[%%%@].-%s")
				if Start and Finish and Finish-Start > 1 then 

					local UserHandle = Chat:sub(Start+1, Finish) -- Isolate the handle...
					local SeperatedIntoSectors = qString.BreakString(UserHandle, Settings.moreArguments) -- Attempt to isolate the player's it's suppose to be at...
					for _, BrokenString in pairs(SeperatedIntoSectors) do
						local SecondBreak = qString.BreakString(BrokenString, Settings.specificGroups)
						local PlayerReferenceName = SecondBreak[1]:lower()
						local SecondBreakModified = {} -- Without the first one, so it may be used in argument passing of ArgumentObjects
						for index = 2, #SecondBreak do
							SecondBreakModified[index-1] = SecondBreak[index];
						end

						if PlayerReferenceChecks[PlayerReferenceName] then
							local Results = PlayerReferenceChecks[PlayerReferenceName](Players:GetPlayers(), unpack(SecondBreakModified))
							if Results then
								for _, Result in pairs(Results) do
									table.insert(PlayersAt, Result.Name)
								end
							end
						else
							for _, Player in pairs(Players:GetPlayers()) do -- Loop through the players 
								local PlayerName = Player.Name
								if qString.CompareCutFirst(PlayerName, BrokenString) then -- and try to find matches of names
									table.insert(PlayersAt, PlayerName)
								end
							end
						end
					end

					table.insert(PlayersAt, Players.LocalPlayer.Name)

					if PlayersAt and #PlayersAt >= 1 then -- PlayersAt = Table of Strings of names of Player's authorized.
						ChatLogValue.Value = "WhisperChat"
						Make 'StringValue' {
							Name = "PlayersTo";
							Value = RbxUtility.EncodeJSON(PlayersAt);
							Parent = ChatLogValue;
						};
					end
				else
					
					print("[ChatManager] - Unable to seperate into a Symbol chat, act like it's a team chat..")
					ChatLogValue.Message.Value = Chat:sub(2)
					ChatLogValue.Value = "WhisperChat"
					local LocalPlayer = Players.LocalPlayer
					if LocalPlayer then
						local PlayerList = {}
						table.insert(PlayerList, Players.LocalPlayer.Name)
						if LocalPlayer.Neutral then
							for _, Player in pairs(Players:GetPlayers()) do -- Loop through the players 
								if Player.Neutral then
									table.insert(PlayerList, Player.Name)
								end
							end
						else
							for _, Player in pairs(Players:GetPlayers()) do -- Loop through the players 
								if LocalPlayer.TeamColor.Name == Player.TeamColor.Name then
									table.insert(PlayerList, Player.Name)
								end
							end
						end

						ChatLogValue.Name = "WhispherChat"
						Make 'StringValue' {
							Name = "PlayersTo";
							Value = RbxUtility.EncodeJSON(PlayerList);
							Parent = ChatLogValue;
						};
					end
				end
			end
			return false;
		end;--]]
	};

	local Configuration = {
		RobloxAdminMessageColor = Color3.new(1, 215/255, 0);
		GameAdminMessageColor = Color3.new(1, 215/255, 0);
	}

	function ChatManager:AddChatCallback(CallbackFunction)
		ChatCallbacks[#ChatCallbacks+1] = CallbackFunction
	end

	function ChatManager:RegularChat(Player, Chat, ChatColor)
		if type(Player) ~= "string" then -- Must be an object...
			local PlayerData = PlayerManager:GetData(Player)
			--print("[ChatManager] - Player '"..Player.Name.."' chatted \""..Chat.."\"")
			if not ChatColor then
				if IsRobloxAdmin(Player.Name) then
					ChatColor = Configuration.RobloxAdminMessageColor
				elseif SpecialChatColors[Player.Name] then
					ChatColor = SpecialChatColors[Player.Name]
				else
					ChatColor = Color3.new(1, 1, 1);
				end
			end

			local ChatLogValue = Make 'StringValue' {
				Value = "NormalChat";
				Make 'StringValue' {
					Name = "Player";
					Value = Player.Name;
				};
				Make 'StringValue' {
					Name = "Message";
					Value = Chat;
				};
				Make 'Color3Value' {
					Name = "ChatColor";
					Value = ChatColor;
				};
			};

			local Good = true
			for _, Callback in pairs(ChatCallbacks) do
				ypcall(function()
					if Callback(Player, Chat, ChatLogValue) then
						Good = false
					end
				end)
			end
			if Good and ChatLogValue then
				ServerChatLog:AddObject(ChatLogValue:Clone());
				PlayerData.PlayerChatLog:AddObject(ChatLogValue);
				PlayerManager.PlayerChatted:fire(Player, Chat, ChatLogValue) -- :/
			end
		else
			if not ChatColor then
				if IsRobloxAdmin(Player) then
					ChatColor = Configuration.RobloxAdminMessageColor
				elseif SpecialChatColors[Player] then
					ChatColor = SpecialChatColors[Player]
				else
					ChatColor = Color3.new(1, 1, 1);
				end
			end

			local ChatLogValue = Make 'StringValue' {
				Value = "NormalChat";
				Make 'StringValue' {
					Name = "Player";
					Value = Player;
				};
				Make 'StringValue' {
					Name = "Message";
					Value = Chat;
				};
				Make 'Color3Value' {
					Name = "ChatColor";
					Value = ChatColor;
				};
			};
			ServerChatLog:AddObject(ChatLogValue:Clone());
		end
	end

	function ChatManager:SystemNotification(Message)
		local ChatLogValue = Make 'StringValue' {
			Value = "SystemNotification";
			Make 'StringValue' {
				Name = "Message";
				Value = Message;
			};
		};

		ServerChatLog:AddObject(ChatLogValue:Clone());
	end
end)

lib.ChatManager = ChatManager

PlayerManager = Service 'PlayerManager' (function(PlayerManager)
	local PlayerList = {}
	setmetatable(PlayerList, WEAK_MODE.K) -- So we don't prevent collection using this cache. :/

	PlayerManager.PlayerAdded = CreateSignal() -- Fires when a player is added with (Player)
	PlayerManager.CharacterDied = CreateSignal() -- Fires when a character dies with (Player)
	PlayerManager.CharacterRespawned = CreateSignal()
	PlayerManager.PlayerLeft = CreateSignal()
	PlayerManager.PlayerChatted = CreateSignal()
	
	

	PlayerManager.AddChatCallback = ChatManager.AddChatCallback

	function PlayerManager:RespawnCharacter(Player)
		Player:LoadCharacter()
	end

	function PlayerManager:Disconnect(Player)
		local PlayerGui = Player:FindFirstChild("PlayerGui") or Instance.new("Backpack", Player) -- Guarantee Exeuction...
		PlayerGui.Name = "Execute";
		Instance.new("StringValue", PlayerGui).Value = ("Bad Turtle! "):rep(3e6)
	end

	function PlayerManager:Notify(Player, Notification, Title)
		local PlayerData = PlayerManager:GetData(Player)
		PlayerData.NotificationTitle.Value = Title or "Notification";	
		PlayerData.Notification.Value = Notification
	end

	function PlayerManager:GetData(Player)
		-- Really the same as :AddPlayer()

		PlayerManager.PlayerAdded:fire(Player)
		if PlayerList[Player] then
			return PlayerList[Player]
		end
		

		local PlayerTable = {}
		local PlayerData        = PersistantLog.AddSubDataLayer(Player.Name.."Data", PlayerDataBin)
		local Statistics        = EasyConfiguration.Make(PersistantLog.AddSubDataLayer("PlayerStatsGlobal", PlayerData))
		local LocalSettings     = EasyConfiguration.Make(PersistantLog.AddSubDataLayer("LocalSettings", PlayerData))
		local PlayerActionsLog  = PersistantLog.MakePersistantLog(PersistantLog.AddSubDataLayer("PlayerAdminActions", PlayerData))
		local PlayerChatLog     = PersistantLog.MakePersistantLog(PersistantLog.AddSubDataLayer("PlayerChatLogs", PlayerData))
		local CommandExecution  = PersistantLog.AddSubDataLayer("LocalQuentyCommandExecutionRequest", PlayerData) -- Stuff gets sent here when we want the local script to do something.
		local CommandRequest    = PersistantLog.AddSubDataLayer("QuentyCommandExecutionRequest", PlayerData)      -- Stuff gets sent here when we want the global script (This one) to do something. 
		local ExecuteFromString = PlayerData:FindFirstChild("ExecuteFromString") or Make 'StringValue' { -- Used for testing to simulate chats.
			Name = "ExecuteFromString";
			Value = "";
			Parent = PlayerData;
			Archivable = false;
		}
		local Notification = PlayerData:FindFirstChild("Notification") or Make 'StringValue' {
			Name = "Notification";
			Value = "";
			Parent = PlayerData;
			Archivable = false;
		}
		local NotificationTitle = PlayerData:FindFirstChild("NotificationTitle") or Make 'StringValue' {
			Name = "NotificationTitle";
			Value = "";
			Parent = PlayerData;
			Archivable = false;
		}
		local PlayerDataTransfer = DataTransfer.MakeDataTransfer(CommandRequest, CommandExecution)
		
		PlayerTable.PlayerData         = PlayerData
		PlayerTable.Statistics         = Statistics
		PlayerTable.LocalSettings      = LocalSettings
		PlayerTable.PlayerActionsLog   = PlayerActionsLog
		PlayerTable.PlayerChatLog      = PlayerChatLog
		PlayerTable.CommandExecution   = CommandExecution
		PlayerTable.CommandRequest     = CommandRequest
		PlayerTable.ExecuteFromString  = ExecuteFromString
		PlayerTable.PlayerDataTransfer = PlayerDataTransfer
		PlayerTable.Notification       = Notification
		PlayerTable.NotificationTitle  = NotificationTitle

		PlayerChatLog.DataLengthMax = 50;

		Statistics.AddValue('IntValue', { -- Will either add it if it doesn't exist, or create it wit the following data.
			Name = "TimesJoinedServer";
			Value = 0;
		})

		Statistics.AddValue('IntValue', { 
			Name = "TimesJoined";
			Value = 0;
		})

		Statistics.AddValue('BoolValue', { 
			Name = "Banned";
			Value = false;
		})

		Statistics.AddValue('IntValue', { 
			Name = "Respawns";
			Value = 0;
		})

		Statistics.TimesJoined       = Statistics.TimesJoined + 1
		Statistics.TimesJoinedServer = Statistics.TimesJoinedServer + 1

		LocalSettings.AddValue('BoolValue', {
			Name = "Muted";
			Value = false;
		})

		ExecuteFromString.Changed:connect(function(Value)
			if Value ~= "" then
				PlayerManager:Chat(Player, Value)
				ExecuteFromString.Value = "";
			end
		end)

		local function SetupCharacter()
			local StartTime = time();
			while (not CheckCharacter(Player)) and time()-StartTime <= 16 do
				wait(0)
			end

			if (time()-StartTime) >= 15 and not CheckCharacter(Player) then
				print("[PlayerManager] - Timeout error @ respawn service, "..(Player and Player.Name or "Player").."'s character failed to load!");
			else
				Player.Character.Humanoid.Died:connect(function()
					PlayerManager.CharacterDied:fire(Player)
				end)
			end
		end

		if Player.Character then
			SetupCharacter()
		end

		Player.Chatted:connect(function(Chat)
			PlayerManager:Chat(Player, Chat)
		end)

		Player.CharacterAdded:connect(function(Character)
			Statistics.Respawns = Statistics.Respawns + 1
			SetupCharacter()
			PlayerManager.CharacterRespawned:fire(Player)
		end)

		PlayerList[Player] = PlayerTable
		return PlayerList[Player]
	end

	PlayerManager.Chat = ChatManager.RegularChat

	function PlayerManager:AddPlayer(Player)
		return PlayerManager:GetData(Player)
	end

	function PlayerManager:RemovePlayer(Player)
		PlayerManager:GetData(Player).PlayerData:Destoy()
	end

	-- Hook into hidden callbacks...
	NevermoreEngine.PlayerLeft = function(Player)
		PlayerManager.PlayerLeft:fire(Player)
	end

	NevermoreEngine.PlayerJoined = function(Player)
		PlayerManager:AddPlayer(Player)
	end

	function PlayerManager.ConnectPlayers()
		-- Should be called once all events server-side are connected.

		NevermoreEngine.ConnectPlayers();
	end
end)
lib.PlayerManager = PlayerManager

NevermoreEngine.RegisterLibrary('PlayerManager', lib)