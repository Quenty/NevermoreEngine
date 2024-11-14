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

	self._systemMessageColors = {}

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

		local metadata = textChatMessage.Metadata
		if metadata then
			local systemColorProperties = self._systemMessageColors[metadata]
			if systemColorProperties then
				local overrideProperties = Instance.new("TextChatMessageProperties")
				overrideProperties.Text = string.format(systemColorProperties.Text, textChatMessage.Text)

				return overrideProperties
			end
		end

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

function ChatProviderServiceClient:SendSystemMessage(channel, message, color)
	if not message then
		return
	end

	assert(typeof(channel) == "Instance" and channel.ClassName == "TextChannel", "[ChatProviderServiceClient.SendSystemMessage] - Bad channel")
	assert(typeof(color) == "Color3" or color == nil, "[ChatProviderServiceClient.SendSystemMessage] - Bad color")

	if color then
		local hex = color:ToHex()

		if not self._systemMessageColors[hex] then
			local overrideProperties = Instance.new("TextChatMessageProperties")
			overrideProperties.Text = `<font color="#{hex}">%s</font>`

			self._systemMessageColors[hex] = overrideProperties
		end
	end

	channel:DisplaySystemMessage(message, color and color:ToHex())
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