local ReplicatedStorage           = game:GetService("ReplicatedStorage")
local Players                     = game:GetService("Players")
local LogService                  = game:GetService("LogService")
local ScriptContext               = game:GetService("ScriptContext")
local StarterGui                  = game:GetService("StarterGui")

local NevermoreEngine             = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary           = NevermoreEngine.LoadLibrary

local OutputStreamInterface       = LoadCustomLibrary("OutputStreamInterface")
local PseudoChatParser            = LoadCustomLibrary("PseudoChatParser")
local OutputClassStreamLoggers    = LoadCustomLibrary("OutputClassStreamLoggers")
local OutputStream                = LoadCustomLibrary("OutputStream")
local PseudoChatBar               = LoadCustomLibrary("PseudoChatBar")
local ClientAuthenticationService = LoadCustomLibrary("ClientAuthenticationService")

-- local ShipKillFeedParser          = LoadCustomLibrary("ShipKillFeedParser")

-- Setups up the PseudoChat on the client. It's the equivalent of the PseudoChatManager for the
-- server

-- PseudoChat.lua
-- Intended for the client only. Sets up pseudo chat on the client. 
-- @author Quenty
-- Last modified Janurary 19th, 2014

--[[-- Update Log --
September 9th, 2014
- Added team chat

July 25th, 2014
- Made ChatBar API avialable. 

February 6th, 2014
- Added local-side output support for errors.
- Output does not go to global chat log now
- Fixed glitch with script concatination

January 26th, 2014
- Updated to OutputStream

January 19th, 2014
- Added change log
- Added ScriptbuilderParser
- Added QuentyAdminCommandsOutput

January 5th, 2014
- Wrote intitial script

--]]



local lib = {}

local function MakePseudoChat(ScreenGui, DoNotDisableCoreGui)
	--- This will render a pseudo chat output stream thingy. Of course, you don't have to use this module, but it simplifies everything.
	-- @param ScreenGui The ScreenGui the chat goes into. 
	local Chat = {}
	local LocalPlayer = game.Players.LocalPlayer

	local ClientToServerOutputStream = NevermoreEngine.GetEventStream("ClientToServerOutputStream")

	local Interface = OutputStreamInterface.MakeOutputStreamInterface(nil, ScreenGui)
	Chat.Interface  = Interface
	Chat.Gui        = Interface.Gui

	local ChatBar

	local function SendMessage(Message)
		ClientToServerOutputStream.Fire("Message", Message); --[[{
			Message = Message;
			-- Player  = LocalPlayer;
		})--]]
	end


	if not DoNotDisableCoreGui then
		ChatBar = PseudoChatBar.MakePseudoChatBar(ScreenGui)
		Chat.ChatBar = ChatBar

		ChatBar.NewChat:connect(function(Message)
			SendMessage(Message)
		end)
	end

	LocalPlayer.Chatted:connect(function(Message)
		SendMessage(Message)
	end)

	local ChatChannel = OutputStream.MakeOutputStreamClient(
		"ChatChannel"
	);
	ChatChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)
	ChatChannel.AddOutputClass(PseudoChatParser.ChatOutputClass)

	local TeamChannel = OutputStream.MakeOutputStreamClient(
		"TeamChannel"
	);
	TeamChannel.AddOutputClass(PseudoChatParser.ChatOutputClass)


	-- Notification stream
	local NotificationChannel = OutputStream.MakeOutputStreamClient(
		"NotificationChannel"
	);
	NotificationChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- Admin stream
	local AdminLogChannel = OutputStream.MakeOutputStreamClient(
		"AdminChannel"
	);
	AdminLogChannel.AddOutputClass(PseudoChatParser.OutputOutputClass)
	AdminLogChannel.AddOutputClass(PseudoChatParser.AdminLogOutputClass)

	-- We will syndicate resources. 
	-- Global one has all of 'em. 
	local GlobalSyndictator = OutputStream.MakeOutputStreamSyndicator("Chat")
		GlobalSyndictator.AddOutputStream(ChatChannel)
		GlobalSyndictator.AddOutputStream(NotificationChannel)
		GlobalSyndictator.AddOutputStream(AdminLogChannel)
		GlobalSyndictator.AddOutputStream(TeamChannel)

	Interface.Subscribe(GlobalSyndictator, nil, Color3.new(78/255, 205/255, 196/255), true) --Color3.new( 85/255,  98/255, 112/255), true)

	spawn(function()
		local AdminSyndictator
		local Subscriber

		local function SetupAdmin()
			if not AdminSyndictator then
				AdminSyndictator = OutputStream.MakeOutputStreamSyndicator("Admin Logs")
				AdminSyndictator.AddOutputStream(AdminLogChannel)
			end

			if not Subscriber then
				Subscriber = Interface.Subscribe(AdminSyndictator, nil, Color3.new(255/255, 107/255, 107/255), true)
			end
		end

		local function DeconstructAdmin()
			if Subscriber then
				Subscriber:Destroy()
				Subscriber = nil
			end
		end

		if ClientAuthenticationService.IsAuthorized() then
			SetupAdmin()
		end

		ClientAuthenticationService.AuthenticationChanged:connect(function(IsAuthorized)
			if IsAuthorized then
				SetupAdmin()
			else
				DeconstructAdmin()
			end
		end)
	end)

	if not DoNotDisableCoreGui then
		StarterGui:SetCoreGuiEnabled("Chat", false)
	end

	return Chat
end
lib.MakePseudoChat = MakePseudoChat
lib.makePseudoChat = MakePseudoChat

return lib