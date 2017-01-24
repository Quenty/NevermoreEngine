-- PseudoChat.lua
-- (Client only) Sets up PseudoChat on the client. Equivalent of PseudoChatManager for the server
-- @author Quenty

local ReplicatedStorage           = game:GetService("ReplicatedStorage")
local Players                     = game:GetService("Players")
local LogService                  = game:GetService("LogService")
local ScriptContext               = game:GetService("ScriptContext")
local StarterGui                  = game:GetService("StarterGui")

local LoadCustomLibrary           = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local OutputStreamInterface       = LoadCustomLibrary("OutputStreamInterface")
local PseudoChatParser            = LoadCustomLibrary("PseudoChatParser")
local OutputClassStreamLoggers    = LoadCustomLibrary("OutputClassStreamLoggers")
local OutputStream                = LoadCustomLibrary("OutputStream")
local PseudoChatBar               = LoadCustomLibrary("PseudoChatBar")
local ClientAuthenticationService = LoadCustomLibrary("ClientAuthenticationService")                 
local RemoteManager               = LoadCustomLibrary("RemoteManager")

local Color3 = Color3.new
local IsPhone = LoadCustomLibrary("qGUI").IsPhone


local lib = {}

local function MakePseudoChat(ScreenGui, DoNotDisableCoreGui)
	--- This will render a pseudo chat output stream thingy. Of course, you don't have to use this module, but it simplifies everything.
	-- @param ScreenGui The ScreenGui the chat goes into. 
	local Chat = {}
	local LocalPlayer = game.Players.LocalPlayer

	local ClientChatted = RemoteManager:GetEvent("ClientChatted")

	local Interface = OutputStreamInterface.MakeOutputStreamInterface(nil, ScreenGui)
	Chat.Interface  = Interface
	Chat.Gui        = Interface.Gui

	function Chat.GetDefaultPosition()
		if IsPhone(ScreenGui) then
			return UDim2.new(0, 36, 0, 4)
		else
			return UDim2.new(0, 4, 0, 4)
		end
	end

	local ChatBar

	local function SendMessage(Message)
		assert(Message, "Need message")
		
		ClientChatted:SendToServer(Message); --[[{
			Message = Message;
			-- Player  = LocalPlayer;
		})--]]
	end


	if not DoNotDisableCoreGui then
		ChatBar = PseudoChatBar(ScreenGui, Chat.Gui)
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
	local AddOutputStream = GlobalSyndictator.AddOutputStream
	AddOutputStream(ChatChannel)
	AddOutputStream(NotificationChannel)
	AddOutputStream(AdminLogChannel)
	AddOutputStream(TeamChannel)

	Interface.Subscribe(GlobalSyndictator, nil, Color3(78/255, 205/255, 196/255), true) --Color3( 85/255,  98/255, 112/255), true)

	spawn(function()
		local AdminSyndictator
		local Subscriber

		local function SetupAdmin()
			if not AdminSyndictator then
				AdminSyndictator = OutputStream.MakeOutputStreamSyndicator("Admin Logs")
				AdminSyndictator.AddOutputStream(AdminLogChannel)
			end

			if not Subscriber then
				Subscriber = Interface.Subscribe(AdminSyndictator, nil, Color3(255/255, 107/255, 107/255), true)
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

return setmetatable({MakePseudoChat = MakePseudoChat; makePseudoChat = MakePseudoChat}, {__call = function(_, ...) return MakePseudoChat(...) end})
