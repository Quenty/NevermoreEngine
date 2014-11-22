local ReplicatedStorage           = game:GetService("ReplicatedStorage")
local Players                     = game:GetService("Players")
local LogService                  = game:GetService("LogService")
local ScriptContext               = game:GetService("ScriptContext")

local NevermoreEngine             = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary           = NevermoreEngine.LoadLibrary

local PseudoChatSettings          = LoadCustomLibrary("PseudoChatSettings")
local PseudoChatParser            = LoadCustomLibrary("PseudoChatParser")
local OutputClassStreamLoggers    = LoadCustomLibrary("OutputClassStreamLoggers")
local OutputStream                = LoadCustomLibrary("OutputStream")
local qString                     = LoadCustomLibrary("qString")
local AuthenticationServiceServer = LoadCustomLibrary("AuthenticationServiceServer")
local qPlayer                     = LoadCustomLibrary("qPlayer")

-- local ShipKillFeedParser       = LoadCustomLibrary("ShipKillFeedParser")


-- PseudoChatManagerServer.lua
-- Manages chat connections, sends and making chats, filtering, et cetera.
-- Intendend for Serverside use only. 
-- @author Quenty
-- Last modified Janurary 19th, 2014

--[[-- Change Log --
September 9th, 2014
- Added team chat

Febraury 6th, 2015
- Updated to use AuthenticationServiceServer
- Modified AdminOutput to not use filter
- Modified to accept error output from client

February 3rd, 2014
- Fixed issue with /e emoticons and filtering.

January 26th, 2014
- Switched to OutputStream system. 

January 19th, 2014
- Added callback system to PseudoChatManager
- Added QuentyAdminCommandsOutput parser to system
- Added ScriptbuilderParser to the system
- Added Changelog

-- January 5th, 2014 --
- Wrote initial script

--]]

local PseudoChatManager = {} do
	local ClientToServerOutputStream = NevermoreEngine.GetEventStream("ClientToServerOutputStream")

	local ChatChannel = OutputStream.MakeOutputStreamServer(
			OutputClassStreamLoggers.MakeGlobalOutputStreamLog(PseudoChatSettings.BufferSize),
			"ChatChannel"
		)
		ChatChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)
		ChatChannel.AddOutputClass(PseudoChatParser.ChatOutputClass)

	-- Team chat channel
	local TeamChannel = OutputStream.MakeOutputStreamServer(
			OutputClassStreamLoggers.MakeGlobalFilteredLogStreamLog(function(Client, Item)
				assert(Item.TeamColor, "No Item.TeamColor")

				if (Client.Neutral and Item.TeamColor == "Neutral") or (not Client.Neutral and Client.TeamColor.Name == Item.TeamColor.Name) then
					return true
				end

				return false
			end, PseudoChatSettings.BufferSize),
			"TeamChannel"
		)
		TeamChannel.AddOutputClass(PseudoChatParser.ChatOutputClass)

	-- Notification stream
	local NotificationChannel = OutputStream.MakeOutputStreamServer(
			OutputClassStreamLoggers.MakePlayerNotificationStreamLog(PseudoChatSettings.BufferSize), 
			"NotificationChannel"
		)
		NotificationChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)


	-- Admin stream
	local AdminLogChannel = OutputStream.MakeOutputStreamServer(
			OutputClassStreamLoggers.MakeGlobalFilteredLogStreamLog(AuthenticationServiceServer.IsAuthorized, PseudoChatSettings.BufferSize), 
			"AdminChannel"
		)
		AdminLogChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)
		AdminLogChannel.AddOutputClass(PseudoChatParser.AdminLogOutputClass)

	local Muted = {} -- List of muted players
	local ChatCallbacks = {}

	local function ExecuteChatCallbacks(Player, Message, PlayerColor, ChatColor)
		--- Goes through each ChatCallbacks and executes it.
		-- Used internally, called before a player is allowed to chat. 
		-- Called even if mute is enabled. Calls every one. Order is undefined. 
		-- @return Boolean True if it should not render.

		local DoNotRender = false

		for _, Item in pairs(ChatCallbacks) do
			local Result = Item(Player, Message, PlayerColor, ChatColor, DoNotRender)
			if Result then
				-- print("[PseudoChatManager] - Callback result was " .. tostring(Result))
				DoNotRender = true
			end
		end
		return DoNotRender
	end

	local function AddChatCallback(Callback)
		--- Adds a callback to the chat callback system.
		-- @param CallbackName The name of the callback.
			--- Should do stuff with the information, and / or execute code.
			-- @param PlayerName The name of the player chatting
			-- @param Message The message
			-- @param PlayerColor Color3, The color of the player label 
			-- @param ChatColor	Color3 The color of the chat
			-- @return Boolean, true if it should not render. 
		-- Callbacks will be executed in any arbitary order. 

		ChatCallbacks[#ChatCallbacks + 1] = Callback
	end
	PseudoChatManager.AddChatCallback = AddChatCallback
	PseudoChatManager.addChatCallback = AddChatCallback
	PseudoChatManager.add_chat_callback = AddChatCallback

	local function Mute(PlayerName)
		--- Mute's any player's with the name "PlayerName";
		-- @param PlayerName String, The name of the player to mute

		Muted[PlayerName:lower()] = true
	end
	PseudoChatManager.Mute = Mute
	PseudoChatManager.mute = Mute

	local function Unmute(PlayerName)
		--- Remove's the mute from the player
		-- @param PlayerName String, The name of the player to unmute

		Muted[PlayerName:lower()] = nil
	end
	PseudoChatManager.Unmute = Unmute
	PseudoChatManager.unmute = Unmute

	local function IsMuted(PlayerName)
		--- Get if a player is muted or not
		-- @param PlayerName String, The name of the player to check
		-- @return Boolean, is the player muted or not.

		return Muted[PlayerName:lower()] or false
	end
	PseudoChatManager.IsMuted = IsMuted
	PseudoChatManager.isMuted = IsMuted

	local function FilteredNotify(PlayerList, Message, ChatColor)
		--- Notifies a player
		-- @param PlayerList A list of players to send it too
		-- @param ChatColor The color of the chat. 
		-- @param Message The message to send

		-- This is basically a shortcode for RenderDataStream.Send

		assert(PlayerList ~= nil, "[PseudoChatManager] - PlayerList is nil.")

		NotificationChannel.Send("OutputOutputClass", {
			Message = tostring(Message);
			ChatColor = ChatColor;

			Inclusive = true;
			FilterList = PlayerList;
		})
	end
	PseudoChatManager.FilteredNotify = FilteredNotify
	PseudoChatManager.filteredNotify = FilteredNotify

	local function Notify(Message, ChatColor)
		-- print("Notify")
		NotificationChannel.Send("OutputOutputClass", {
			Message = tostring(Message);
			ChatColor = ChatColor;

			Inclusive = false;
			FilterList = {};
		})
	end
	PseudoChatManager.Notify = Notify
	PseudoChatManager.Notify = Notify

	-- local function Output(Output, ChatColor)
	-- 	--- Output's script builder output to a player
	-- 	-- @param Output The output to output
	-- 	-- @param ChatColor The chat color to output.

	-- 	-- print("*** OUTPUT \"" .. Output .. "\"")

	-- 	local Data = {
	-- 		Message = Output;
	-- 		ChatColor = ChatColor;
	-- 	}
	-- 	-- print("Filter list [0] @ Send" .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))

	-- 	AdminOutputClass.Send("OutputOutputClass", Data)
	-- end
	-- PseudoChatManager.Output = Output
	-- PseudoChatManager.output = Output

	local function AdminOutput(Output, ChatColor)
		--- Output's admin commands log
		-- @param Output The output to Output
		-- @param ChatColor The chat color to output.


		AdminLogChannel.Send("OutputOutputClass", {
			Message   = Output;
			ChatColor = ChatColor;
		})
	end
	PseudoChatManager.AdminOutput = AdminOutput
	PseudoChatManager.adminOutput = AdminOutput

	local function AdminLogOutput(CommandName, CommandDescription, PlayerExecutingName, CommandColor)
		-- CommandColor is optional

		assert(PlayerExecutingName, "Need a PlayerExecutingName")

		AdminLogChannel.Send("AdminLogOutputClass", {
			CommandName         = CommandName;
			CommandDescription  = CommandDescription;
			PlayerExecutingName = PlayerExecutingName;
			CommandColor        = CommandColor
		})
	end
	PseudoChatManager.AdminLogOutput = AdminLogOutput
	PseudoChatManager.adminLogOutput = AdminLogOutput

	local function Chat(PlayerName, Message, PlayerColor, ChatColor)
		--- Makes the player with the name "PlayerName" chat "Message" No callbacks or filtered anything
		-- @param PlayerName The name of the player saying the message
		-- @param Message The message to say
		-- @param [PlayerColor] The color of the player's name. Optional. 
		-- @param [ChatColor] The color of the chat. Optional. 

		Message = tostring(Message)
		Message = qString.TrimString(Message, "%s")

		if #Message > 0 then
			ChatChannel.Send("ChatOutputClass", {
				PlayerName  = tostring(PlayerName);
				Message     = Message;
				PlayerColor = PlayerColor;
				ChatColor   = ChatColor;
			})
		else
			warn("[Chat] - Empty string, will not send")
		end
	end
	PseudoChatManager.RawChat  = Chat
	PseudoChatManager.rawChat  = Chat
	PseudoChatManager.raw_chat = Chat

	local function TeamChat(Player, Message, PlayerColor, ChatColor)
		--- Makes the player with the name "PlayerName" chat "Message" No callbacks or filtered anything
		-- @param PlayerName The name of the player saying the message
		-- @param Message The message to say
		-- @param [PlayerColor] The color of the player's name. Optional. 
		-- @param [ChatColor] The color of the chat. Optional. 

		Message = tostring(Message)
		Message = qString.TrimString(Message, "%s")

		if #Message > 0 then
			TeamChannel.Send("ChatOutputClass", {
				PlayerName  = tostring(Player.Name);
				Message     = "(TEAM) " .. Message;
				PlayerColor = PlayerColor;
				ChatColor   = ChatColor;
				TeamColor   = Player.Neutral and "Neutral" or Player.TeamColor 
			})
		else
			warn("[TeamChat] - Empty string, will not send")
		end
	end
	PseudoChatManager.TeamChat = TeamChat

	local function SendCustomNotification(OutputClass, Data)
		--- Used to send killfeed and stuff...

		NotificationChannel.Send(OutputClass, Data)
	end
	PseudoChatManager.SendCustomNotification = SendCustomNotification
	PseudoChatManager.sendCustomNotification = SendCustomNotification

	local function AddOutputClassToMainChannelNotify(Class)
		--- Used to output custom classes, like kill feed.
		NotificationChannel.AddOutputClass(Class)
	end
	PseudoChatManager.AddOutputClassToMainChannelNotify = AddOutputClassToMainChannelNotify
	PseudoChatManager.addOutputClassToMainChannelNotify = AddOutputClassToMainChannelNotify

	local function HandleChat(PlayerName, Message, PlayerColor, ChatColor)
		--- Handle's chat replciation whenver a player chats.
		-- @param PlayerName The PlayerName chatting
		-- @param Message The message of the player

		local DoNotDisplay = ExecuteChatCallbacks(PlayerName, Message, PlayerColor, ChatColor)

		if DoNotDisplay then
			print("[PseudoChatManager] - Player " .. PlayerName .. "'s chat '" .. Message .. "' was stopped by a callback. ")
		else
			if not IsMuted(PlayerName) then
				Chat(PlayerName, Message, PlayerColor, ChatColor)
			else
				print("[PseudoChatManager] - Player '" .. PlayerName .. "' is muted. ")
				-- Notify the player that they can't speak, they are muted!
				local Player = Players:FindFirstChild(PlayerName)
				if Player and Player:IsA("Player") then
					FilteredNotify({Player.userId}, PseudoChatSettings.MutedMessage, PseudoChatSettings.MutedMessageColor)
				else
					print("No player identified to notify the cannot chat")
				end
			end
		end
	end
	PseudoChatManager.Chat = HandleChat
	PseudoChatManager.chat = HandleChat

	--[[local function HandlePlayer(Player)
		--- Handle's the player by connecting events, et cetera.

		Player.Chatted:connect(function(Message)
			HandleChat(Player.Name, Message)
		end)
	end--]]
	
	--[==[
	local function Initiate()
		-- Sets up PseudoChat. 

		-- Connect events
		--[[for _, Player in pairs(Players:GetPlayers()) do
			HandlePlayer(Player)
		end

		Players.PlayerAdded:connect(function(Player)
			HandlePlayer(Player)
		end)--]]

		ScriptContext.Error:connect(function(Message, StackTrace, Script)
			Script = tostring(Script)
			
			Output((Script .. " " .. Message), Color3.new(1, 0, 0))
			Output(StackTrace, Color3.new(0, 209/255, 255/255))
		end)

		LogService.MessageOut:connect(function(Message, MessageType)
			local MessageColor
			if MessageType.Name == "MessageWarning" then
				MessageColor = Color3.new(255/255, 233/255, 181/255)
			elseif MessageType.Name == "MessageError" then
				MessageColor = Color3.new(1, 0, 0)
			elseif MessageType.Name == MessageInfo then
				MessageColor = Color3.new(0, 209/255, 255/255)
			end
			Output(Message, MessageColor)
		end)
	end
	PseudoChatManager.Initiate = Initiate
	PseudoChatManager.Initiate = Initiate--]==]

	-- ClientToServerOutputStream.RegisterRequestTag("Error", function(Client, NewOutput)
	-- 	Output("[" .. tostring(Client) .. "] - " .. NewOutput.Script .. NewOutput.Message, Color3.new(1, 0, 0))
	-- 	Output(NewOutput.StackTrace, Color3.new(0, 209/255, 255/255))
	-- end)

	ClientToServerOutputStream.RegisterRequestTag("Message", function(Client, Message)
		if Message then
			HandleChat(Client.Name, Message)
		else
			warn("[ClientToServerOutputStream] - No message sent. :/")
		end
	end)
end

PseudoChatManager.AddChatCallback(function(Player, Message, PlayerColor, ChatColor)
	if qString.CompareCutFirst(Message, "/e") then
		return true
	end
	return false
end)


local IsMuted do -- Spamming
	local SpamMuted = {}
	local MuteDurationOnViolation = 10
	local TimeWindow              = 15;
	local MaxChatRatioPerASecond  = 1.5--2; -- 2 chats, every 1 seconds.

	local function MutePlayer(PlayerName)
		SpamMuted[PlayerName:lower()] = tick() + MuteDurationOnViolation
	end

	local PlayerDataBin = {}

	PseudoChatManager.AddChatCallback(function(PlayerName, Message, PlayerColor, ChatColor)
		local CurrentTime = tick()
		local Player = qPlayer.GetPlayerFromName(PlayerName)
		local IsMuted, MutedMessage = IsMuted(CurrentTime, Player)

		if IsMuted then
			PseudoChatManager.FilteredNotify({Player.userId}, MutedMessage, PseudoChatSettings.MutedMessageColor)
			return true
		else
			local DataBin = PlayerDataBin[PlayerName:lower()]
			if DataBin then
				-- http://www.perl.com/pub/2004/11/11/floodcontrol.html

				local Index = 1
				local OldestEventAge
				local EventCount = 0

				while Index < #DataBin do
					local TimeStamp = DataBin[Index]

					local TimeAgo = CurrentTime - TimeStamp
					if TimeAgo > TimeWindow then
						table.remove(DataBin, Index)
					else
						OldestEventAge = OldestEventAge or TimeAgo
						EventCount = EventCount + 1
						Index = Index + 1
					end
				end

				if OldestEventAge then
					local Ratio = EventCount/OldestEventAge
					if Ratio >= MaxChatRatioPerASecond then
						MutePlayer(PlayerName)
					end
				end
				DataBin[#DataBin+1] = tick() -- Add a new timestamp in.
			else
				warn("[ChatSpamManager] - Warning, no data for player '" .. PlayerName .. "'. Something is wrong with our PlayerAdd event.")
			end

			return false
		end
	end)

	function IsMuted(CurrentTime, Player)
		if Player then
			local MutedState = SpamMuted[Player.Name:lower()]
			if MutedState then
				local TimeLeft = MutedState - CurrentTime

				if TimeLeft > 0 then
					return true, "Stop spamming please. You've been muted for " .. math.floor(TimeLeft+1) .. " more seconds."
				else
					SpamMuted[Player.Name:lower()] = nil
					return false
				end
			end
		else
			return false
		end
	end

	local function HandlePlayerAdd(Player)
		PlayerDataBin[Player.Name:lower()] = {}
	end

	local function HandlePlayerLeave(Player)
		PlayerDataBin[Player.Name:lower()] = nil
	end

	Players.PlayerAdded:connect(HandlePlayerAdd)
	for _, Player in pairs(Players:GetPlayers()) do
		HandlePlayerAdd(Player)
	end

	Players.PlayerRemoving:connect(HandlePlayerLeave)
end


do -- Team chat
	PseudoChatManager.AddChatCallback(function(PlayerName, Message, PlayerColor, ChatColor, DoNotRender)
		local Player = qPlayer.GetPlayerFromName(PlayerName)

		if Player and not DoNotRender then
			local TeamMessage

			if qString.CompareCutFirst(Message, "%") then
				TeamMessage = Message:sub(2)
			elseif qString.CompareCutFirst(Message, "(team)")  then
				TeamMessage = Message:sub(7)
			end

			if TeamMessage then
				PseudoChatManager.TeamChat(Player, TeamMessage, PlayerColor, ChatColor)
				return true
			end
		end
	end)
end


return PseudoChatManager
