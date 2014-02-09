local ReplicatedStorage        = game:GetService("ReplicatedStorage")
local Players                  = game:GetService("Players")
local LogService               = game:GetService("LogService")
local ScriptContext            = game:GetService("ScriptContext")

local NevermoreEngine          = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary        = NevermoreEngine.LoadLibrary

local qSystems                 = LoadCustomLibrary("qSystems")
local OutputStreamInterface    = LoadCustomLibrary("OutputStreamInterface")
local PseudoChatParser         = LoadCustomLibrary("PseudoChatParser")
local OutputClassStreamLoggers = LoadCustomLibrary("OutputClassStreamLoggers")
local OutputStream             = LoadCustomLibrary("OutputStream")



-- Setups up the PseudoChat on the client. It's the equivalent of the PseudoChatManager for the
-- server

-- PseudoChat.lua
-- Intended for the client only. Sets up pseudo chat on the client. 
-- @author Quenty
-- Last modified Janurary 19th, 2014

--[[-- Update Log --
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


qSystems:Import(getfenv(0))

local lib = {}

local function MakePseudoChat(ScreenGui)
	--- This will render a pseudo chat output stream thingy. Of course, you don't have to use this module, but it simplifies everything.
	-- @param ScreenGui The ScreenGui the chat goes into. 
	local ClientToServerOutputStream = NevermoreEngine.GetEventStream("ClientToServerOutputStream")

	local Chat = {}

	local MainChannelGlobal = OutputStream.MakeOutputStreamClient(
		"MainChannel-Global"
	);
	MainChannelGlobal.AddOutputClass(PseudoChatParser.OutputOutputClass)
	MainChannelGlobal.AddOutputClass(PseudoChatParser.ChatOutputClass)

	-- Notification stream
	local MainChannelNotify = OutputStream.MakeOutputStreamClient(
		"MainChannel-Notify"
	);
	MainChannelNotify.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- Admin stream
	local AdminGlobal = OutputStream.MakeOutputStreamClient(
		"Admin-Global"
	);
	AdminGlobal.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- Output Stream
	local AdminOutput = OutputStream.MakeOutputStreamClient(
		"Admin-Output"
	);
	AdminOutput.AddOutputClass(PseudoChatParser.OutputOutputClass)

	-- We will syndicate resources. 
	-- Global one has all of 'em. 
	local GlobalSyndictator = OutputStream.MakeOutputStreamSyndicator("Global Channel")
		GlobalSyndictator.AddOutputStream(MainChannelGlobal)
		GlobalSyndictator.AddOutputStream(MainChannelNotify)
		GlobalSyndictator.AddOutputStream(AdminGlobal)
		-- GlobalSyndictator.AddOutputStream(AdminOutput)

	-- Chat Syndictator has only chat.
	local ChatSyndictator = OutputStream.MakeOutputStreamSyndicator("Main chat")
		ChatSyndictator.AddOutputStream(MainChannelGlobal)
		ChatSyndictator.AddOutputStream(MainChannelNotify)

	local NotificationSyndictator = OutputStream.MakeOutputStreamSyndicator("Notifications")
		NotificationSyndictator.AddOutputStream(MainChannelNotify)
		NotificationSyndictator.AddOutputStream(AdminOutput)

	-- And admin only admin stuff. 
	local AdminSyndictator  = OutputStream.MakeOutputStreamSyndicator("Admin syndictator")
		AdminSyndictator.AddOutputStream(AdminGlobal)
		AdminSyndictator.AddOutputStream(AdminOutput)

	local Interface = OutputStreamInterface.MakeOutputStreamInterface(nil, ScreenGui)
	Chat.Interface  = Interface
	Chat.Gui        = Interface.Gui

	Interface.Subscribe(GlobalSyndictator,         nil, Color3.new( 85/255,  98/255, 112/255), true)
	Interface.Subscribe(ChatSyndictator,           nil, Color3.new( 78/255, 205/255, 196/255), false)
	Interface.Subscribe(NotificationSyndictator,   nil, Color3.new(199/255, 244/255, 100/255), false)
	Interface.Subscribe(AdminSyndictator,          nil, Color3.new(255/255, 107/255, 107/255), false)

	if not NevermoreEngine.SoloTestMode then
		-- In SoloTest mode we log Errors already. 
		
		ScriptContext.Error:connect(function(Message, StackTrace, Script)
			Script = tostring(Script)

			ClientToServerOutputStream.Fire("Error", {
				Message    = Message;
				StackTrace = StackTrace;
				Script     = Script;
			})
		end)
	end

	return Chat
end
lib.MakePseudoChat = MakePseudoChat
lib.makePseudoChat = MakePseudoChat

return lib