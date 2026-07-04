--!strict
--[=[
	@class ChatProviderCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local ChatTagClient = require("ChatTagClient")
local ChatTagCmdrUtils = require("ChatTagCmdrUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local Set = require("Set")
local String = require("String")

local ChatProviderCommandServiceClient = {}
ChatProviderCommandServiceClient.ServiceName = "ChatProviderCommandServiceClient"

export type ChatProviderCommandServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any, -- CmdrServiceClient (nonstrict, no exported type)
		_chatProviderServiceClient: any, -- require cycle with ChatProviderServiceClient
		_chatTagBinder: Binder.Binder<ChatTagClient.ChatTagClient>,
	},
	{} :: typeof({ __index = ChatProviderCommandServiceClient })
))

function ChatProviderCommandServiceClient.Init(
	self: ChatProviderCommandServiceClient,
	serviceBag: ServiceBag.ServiceBag
)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._chatProviderServiceClient = self._serviceBag:GetService((require :: any)("ChatProviderServiceClient"))
	self._chatTagBinder = self._serviceBag:GetService(ChatTagClient)
end

function ChatProviderCommandServiceClient.Start(self: ChatProviderCommandServiceClient)
	self._cmdrService:PromiseCmdr():Then(function(cmdr)
		ChatTagCmdrUtils.registerChatTagKeys(cmdr, self)

		self:_registerChatCommand(cmdr)
	end)
end

function ChatProviderCommandServiceClient._registerChatCommand(self: ChatProviderCommandServiceClient, cmdr: any)
	self._maid:GiveTask(self._chatProviderServiceClient.MessageIncoming:Connect(function(textChatMessage)
		if not (textChatMessage.TextSource and textChatMessage.TextSource.UserId == Players.LocalPlayer.UserId) then
			return
		end

		if String.startsWith(textChatMessage.Text, "/cmdr") then
			cmdr:Show()
		end
	end))
end

function ChatProviderCommandServiceClient.GetChatTagKeyList(self: ChatProviderCommandServiceClient)
	local tagSet: { [any]: boolean } = {}
	for chatTag, _ in pairs(self._chatTagBinder:GetAllSet()) do
		local tagKey = chatTag.ChatTagKey.Value
		tagSet[tagKey] = true
	end
	return Set.toList(tagSet)
end

return ChatProviderCommandServiceClient
