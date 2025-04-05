--[=[
	@class ChatProviderServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Maid = require("Maid")
local Signal = require("Signal")
local String = require("String")
local TextChannelUtils = require("TextChannelUtils")
local _ServiceBag = require("ServiceBag")

local ChatProviderServiceClient = {}
ChatProviderServiceClient.ServiceName = "ChatProviderServiceClient"

function ChatProviderServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
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

		local metadata = textChatMessage.Metadata
		if metadata then
			local success, decodedMessageData = pcall(function()
				return HttpService:JSONDecode(metadata)
			end)

			if success and decodedMessageData then
				local color = decodedMessageData.Color or "#ffffff"
				local isValidHex = pcall(function()
					return Color3.fromHex(color)
				end)

				if isValidHex then
					local overrideProperties = Instance.new("TextChatMessageProperties")
					overrideProperties.Text = `<font color="#{color}">{textChatMessage.Text}</font>`

					return overrideProperties
				end
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

		return
	end
end

--[=[
	Sends a system message to the provided TextChannel.
	@param encodedMessageData string
	@param channel TextChannel?
]=]
function ChatProviderServiceClient:SendSystemMessage(message: string, encodedMessageData: string?, channel: TextChannel?)
	assert(typeof(message) == "string", "[ChatProviderServiceClient.SendSystemMessage] - Bad message")

	if not channel then
		channel = TextChannelUtils.getDefaultTextChannel()
	end

	if not channel then
		warn("[ChatProviderServiceClient.SendSystemMessage] - Failed to get default channel")
		return
	end

	channel:DisplaySystemMessage(message, encodedMessageData)
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