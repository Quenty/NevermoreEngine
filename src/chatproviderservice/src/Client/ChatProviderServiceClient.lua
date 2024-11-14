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

		local metadata = textChatMessage.Metadata
		if metadata then
			local isValidColor = pcall(function()
				return Color3.fromHex(metadata)
			end)

			if isValidColor then
				local overrideProperties = Instance.new("TextChatMessageProperties")
				overrideProperties.Text = `<font color="#{metadata}">{textChatMessage.Text}</font>`

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

--[=[
	Sends a system message to the provided TextChannel.
	@param channel TextChannel
	@param message string
	@param color Color3?
]=]
function ChatProviderServiceClient:SendSystemMessage(channel: TextChannel, message: string, color: Color3?)
	assert(typeof(channel) == "Instance" and channel.ClassName == "TextChannel", "[ChatProviderServiceClient.SendSystemMessage] - Bad channel")
	assert(typeof(message) == "string", "[ChatProviderServiceClient.SendSystemMessage] - Bad message")
	assert(typeof(color) == "Color3" or color == nil, "[ChatProviderServiceClient.SendSystemMessage] - Bad color")

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