--[=[
	@class ChatProviderServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local Maid = require("Maid")
local Signal = require("Signal")
local String = require("String")

local ChatProviderServiceClient = {}
ChatProviderServiceClient.ServiceName = "ChatProviderServiceClient"

function ChatProviderServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- State
	self.MessageIncoming = self._maid:Add(Signal.new())

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Binders
	self._serviceBag:GetService(require("ChatTagClient"))
	self._serviceBag:GetService(require("ChatProviderTranslator"))
	self._serviceBag:GetService(require("ChatProviderCommandServiceClient"))
	self._hasChatTagsBinder = self._serviceBag:GetService(require("HasChatTagsClient"))
end

function ChatProviderServiceClient:Start()
	TextChatService.OnIncomingMessage = function(textChatMessage)
		self.MessageIncoming:Fire(textChatMessage)

		local textSource =  textChatMessage.TextSource
		if not textSource then
			return
		end

		local tags = self:_renderTags(textSource)
		if tags then
			local properties = Instance.new("TextChatMessageProperties")
			local name = String.removePostfix(textChatMessage.PrefixText, ":")

			properties.PrefixText = name .. " " .. tags .. ":"

			return properties
		end
	end
end

function ChatProviderServiceClient:_renderTags(textSource)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player then
		return nil
	end

	local hasChatTags = self._hasChatTagsBinder:Get(player)
	if not hasChatTags then
		warn("[ChatProviderServiceClient._renderTags] - No HasChatTags")
		return nil
	end

	return hasChatTags:GetAsRichText()
end

function ChatProviderServiceClient:Destroy()
	self._maid:DoCleaning()
end

return ChatProviderServiceClient