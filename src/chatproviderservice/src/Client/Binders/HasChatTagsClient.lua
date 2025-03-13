--[=[
	@class HasChatTagsClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local ChatProviderTranslator = require("ChatProviderTranslator")
local ChatTagClient = require("ChatTagClient")
local Color3Utils = require("Color3Utils")
local HasChatTagsBase = require("HasChatTagsBase")
local LocalizedTextUtils = require("LocalizedTextUtils")
local RichTextUtils = require("RichTextUtils")

local HasChatTagsClient = setmetatable({}, HasChatTagsBase)
HasChatTagsClient.ClassName = "HasChatTagsClient"
HasChatTagsClient.__index = HasChatTagsClient

function HasChatTagsClient.new(player: Player, serviceBag)
	local self = setmetatable(HasChatTagsBase.new(player), HasChatTagsClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._chatTagBinder = self._serviceBag:GetService(ChatTagClient)
	self._translator = self._serviceBag:GetService(ChatProviderTranslator)

	return self
end

function HasChatTagsClient:GetChatTagBinder()
	return self._chatTagBinder
end

function HasChatTagsClient:GetAsRichText(): string?
	local lastChatTags = self._lastChatTags.Value
	if not (lastChatTags and #lastChatTags > 0) then
		return nil
	end

	local output: string = "<b>"
	for index, tagData in lastChatTags do
		output = output .. string.format("<font color='%s'>", Color3Utils.toWebHexString(tagData.TagColor))

		local translatedText
		if tagData.TagLocalizedText then
			translatedText = LocalizedTextUtils.localizedTextToString(self._translator, tagData.TagLocalizedText)
		else
			translatedText = tagData.TagText
		end

		output = output .. RichTextUtils.sanitizeRichText(translatedText)

		if index ~= #lastChatTags then
			output = output .. " "
		end

		output = output .. "</font>"
	end

	output = output .. "</b>"

	return output
end


return Binder.new("HasChatTags", HasChatTagsClient)