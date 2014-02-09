local ReplicatedStorage        = game:GetService("ReplicatedStorage")
local Players                  = game:GetService("Players")
local LogService               = game:GetService("LogService")
local ScriptContext            = game:GetService("ScriptContext")

local NevermoreEngine          = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary        = NevermoreEngine.LoadLibrary

local qSystems                 = LoadCustomLibrary("qSystems")
local PseudoChatSettings       = LoadCustomLibrary("PseudoChatSettings")
local PseudoChatParser         = LoadCustomLibrary("PseudoChatParser")
local OutputClassStreamLoggers = LoadCustomLibrary("OutputClassStreamLoggers")
local OutputStream             = LoadCustomLibrary("OutputStream")
local qString                  = LoadCustomLibrary("qString")
local AuthenticationService    = LoadCustomLibrary("AuthenticationService")

qSystems:Import(getfenv(0))

-- PseudoChatManager.lua
-- Manages chat connections, sends and making chats, filtering, et cetera.
-- Intendend for Serverside use only. 
-- @author Quenty
-- Last modified Janurary 19th, 2014

--[[-- Change Log --
Febraury 6th, 2015
- Updated to use AuthenticationService
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

	local MainChannelGlobal = OutputStream.MakeOutputStreamServer(
		OutputClassStreamLoggers.MakeGlobalOutputStreamLog(),
		"MainChannel-Global"
	);
	MainChannelGlobal.AddOutputClass(PseudoChatParser.OutputOutputClass)
	MainChannelGlobal.AddOutputClass(PseudoChatParser.ChatOutputClass)

	-- Notification stream
	local MainChannelNotify = OutputStream.MakeOutputStreamServer(
		OutputClassStreamLoggers.MakePlayerNotificationStreamLog(), 
		"MainChannel-Notify"
	);
	MainChannelNotify.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- Admin stream
	local AdminGlobal = OutputStream.MakeOutputStreamServer(
		OutputClassStreamLoggers.MakeGlobalFilteredLogStreamLog(AuthenticationService.IsAuthorized), 
		"Admin-Global"
	);
	AdminGlobal.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- Output Stream
	local AdminOutputClass = OutputStream.MakeOutputStreamServer(
		OutputClassStreamLoggers.MakeGlobalFilteredLogStreamLog(AuthenticationService.IsAuthorized), 
		"Admin-Output"
	);
	AdminOutputClass.AddOutputClass(PseudoChatParser.OutputOutputClass)

	local Muted = {} -- List of muted players
	local ChatCallbacks = {}

	local function ExecuteChatCallbacks(Player, Message, PlayerColor, ChatColor)
		--- Goes through each ChatCallbacks and executes it.
		-- Used internally, called before a player is allowed to chat. 
		-- Called even if mute is enabled. Calls every one. Order is undefined. 
		-- @return Boolean True if it should not render.

		local DoExecute = false

		for _, Item in pairs(ChatCallbacks) do
			local Result = Item(Player, Message, PlayerColor, ChatColor)
			if Result then
				print("[PseudoChatManager] - Callback result was " .. tostring(Result))
				DoExecute = true
			end
		end
		return DoExecute
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

		MainChannelNotify.Send("OutputOutputClass", {
			Message = tostring(Message);
			ChatColor = ChatColor;

			Inclusive = true;
			FilterList = PlayerList;
		})
	end
	PseudoChatManager.FilteredNotify = FilteredNotify
	PseudoChatManager.filteredNotify = FilteredNotify

	local function Notify(Message, ChatColor)
		MainChannelNotify.Send("OutputOutputClass", {
			Message = tostring(Message);
			ChatColor = ChatColor;

			Inclusive = false;
			FilterList = {};
		})
	end
	PseudoChatManager.Notify = Notify
	PseudoChatManager.Notify = Notify

	local function Output(Output, ChatColor)
		--- Output's script builder output to a player
		-- @param Output The output to output
		-- @param ChatColor The chat color to output.

		-- print("*** OUTPUT \"" .. Output .. "\"")

		local Data = {
			Message = Output;
			ChatColor = ChatColor;
		}
		-- print("Filter list [0] @ Send" .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))

		AdminOutputClass.Send("OutputOutputClass", Data)

	end
	PseudoChatManager.Output = Output
	PseudoChatManager.output = Output

	local function AdminOutput(Output, ChatColor)
		--- Output's admin commands log
		-- @param Output The output to Output
		-- @param ChatColor The chat color to output.


		AdminGlobal.Send("OutputOutputClass", {
			Message   = Output;
			ChatColor = ChatColor;
		})
	end
	PseudoChatManager.AdminOutput = AdminOutput
	PseudoChatManager.adminOutput = AdminOutput

	local function Chat(PlayerName, Message, PlayerColor, ChatColor)
		--- Makes the player with the name "PlayerName" chat "Message" No callbacks or filtered anything
		-- @param PlayerName The name of the player saying the message
		-- @param Message The message to say
		-- @param [PlayerColor] The color of the player's name. Optional. 
		-- @param [ChatColor] The color of the chat. Optional. 

		MainChannelGlobal.Send("ChatOutputClass", {
			PlayerName  = tostring(PlayerName);
			Message     = tostring(Message);
			PlayerColor = PlayerColor;
			ChatColor   = ChatColor;
		})
	end
	PseudoChatManager.RawChat  = Chat
	PseudoChatManager.rawChat  = Chat
	PseudoChatManager.raw_chat = Chat

	local function HandleChat(PlayerName, Message, PlayerColor, ChatColor)
		--- Handle's chat replciation whenver a player chats.
		-- @param PlayerName The PlayerName chatting
		-- @param Message The message of the player

		local DoNotDisplay = ExecuteChatCallbacks(PlayerName, Message, PlayerColor, ChatColor)

		if DoNotDisplay then
			print("[PseudoChatManager] - Player " .. PlayerName .. "'s chat was stopped by a callback. ")
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

	local function HandlePlayer(Player)
		--- Handle's the player by connecting events, et cetera.

		Player.Chatted:connect(function(Message)
			HandleChat(Player.Name, Message)
		end)
	end
	
	local function Initiate()
		-- Sets up PseudoChat. 

		-- Connect events
		for _, Player in pairs(Players:GetPlayers()) do
			HandlePlayer(Player)
		end

		Players.PlayerAdded:connect(function(Player)
			HandlePlayer(Player)
		end)

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
	PseudoChatManager.Initiate = Initiate

	ClientToServerOutputStream.RegisterRequestTag("Error", function(Client, NewOutput)
		Output("[" .. tostring(Client) .. "] - " .. NewOutput.Script .. NewOutput.Message, Color3.new(1, 0, 0))
		Output(NewOutput.StackTrace, Color3.new(0, 209/255, 255/255))
	end)
end

PseudoChatManager.AddChatCallback(function(Player, Message, PlayerColor, ChatColor)
	if qString.CompareCutFirst(Message, "/e") then
		return true
	end
	return false
end)

return PseudoChatManager
