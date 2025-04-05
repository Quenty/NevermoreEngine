--[=[
	@class ChatProviderCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local ChatTagCmdrUtils = require("ChatTagCmdrUtils")
local Set = require("Set")
local Maid = require("Maid")
local String = require("String")
local _ServiceBag = require("ServiceBag")

local ChatProviderCommandServiceClient = {}
ChatProviderCommandServiceClient.ServiceName = "ChatProviderCommandServiceClient"

function ChatProviderCommandServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._chatProviderServiceClient = self._serviceBag:GetService((require :: any)("ChatProviderServiceClient"))
	self._chatTagBinder = self._serviceBag:GetService(require("ChatTagClient"))
end

function ChatProviderCommandServiceClient:Start()
	self._cmdrService:PromiseCmdr():Then(function(cmdr)
		ChatTagCmdrUtils.registerChatTagKeys(cmdr, self)

		self:_registerChatCommand(cmdr)
	end)
end

function ChatProviderCommandServiceClient:_registerChatCommand(cmdr)
	self._maid:GiveTask(self._chatProviderServiceClient.MessageIncoming:Connect(function(textChatMessage)
		if not (textChatMessage.TextSource and textChatMessage.TextSource.UserId == Players.LocalPlayer.UserId) then
			return
		end

		if String.startsWith(textChatMessage.Text, "/cmdr")  then
			cmdr:Show()
		end
	end))
end

function ChatProviderCommandServiceClient:GetChatTagKeyList()
	local tagSet = {}
	for chatTag, _ in pairs(self._chatTagBinder:GetAllSet()) do
		local tagKey = chatTag.ChatTagKey.Value
		tagSet[tagKey] = true
	end
	return Set.toList(tagSet)
end

return ChatProviderCommandServiceClient