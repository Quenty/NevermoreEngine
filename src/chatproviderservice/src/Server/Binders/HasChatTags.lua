--[=[
	@class HasChatTags
]=]

local require = require(script.Parent.loader).load(script)

local ChatProviderService = require("ChatProviderService")
local ChatTag = require("ChatTag")
local ChatTagConstants = require("ChatTagConstants")
local ChatTagDataUtils = require("ChatTagDataUtils")
local HasChatTagsBase = require("HasChatTagsBase")
local HasChatTagsConstants = require("HasChatTagsConstants")
local LocalizedTextUtils = require("LocalizedTextUtils")
local PlayerBinder = require("PlayerBinder")
local String = require("String")
local BinderUtils = require("BinderUtils")

local HasChatTags = setmetatable({}, HasChatTagsBase)
HasChatTags.ClassName = "HasChatTags"
HasChatTags.__index = HasChatTags

function HasChatTags.new(player, serviceBag)
	local self = setmetatable(HasChatTagsBase.new(player), HasChatTags)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._chatProviderService = self._serviceBag:GetService(ChatProviderService)
	self._chatTagBinder = self._serviceBag:GetService(ChatTag)

	self._chatTagsContainer = Instance.new("Folder")
	self._chatTagsContainer.Name = HasChatTagsConstants.TAG_CONTAINER_NAME
	self._chatTagsContainer.Archivable = false
	self._chatTagsContainer.Parent = self._obj
	self._maid:GiveTask(self._chatTagsContainer)

	self._maid:GiveTask(self:ObserveLastChatTags():Subscribe(function(tagDataList)
		-- Legacy chat needs this...
		self._chatProviderService:PromiseSetSpeakerTags(self._obj.Name, tagDataList or {})
	end))

	return self
end

function HasChatTags:GetChatTagBinder()
	return self._chatTagBinder
end

--[=[
	Adds chat tags to the player

	@param chatTagData ChatTagData
]=]
function HasChatTags:AddChatTag(chatTagData)
	assert(ChatTagDataUtils.isChatTagData(chatTagData), "Bad chatTagData")

	local tag = self._chatTagBinder:Create("Folder")
	tag.Name = string.format("ChatTag_%s", String.toCamelCase(chatTagData.TagText))
	tag:SetAttribute(ChatTagConstants.TAG_KEY_ATTRIBUTE, String.toCamelCase(chatTagData.TagText))
	tag:SetAttribute(ChatTagConstants.TAG_TEXT_ATTRIBUTE, chatTagData.TagText)
	tag:SetAttribute(ChatTagConstants.TAG_COLOR_ATTRIBUTE, chatTagData.TagColor)
	tag:SetAttribute(ChatTagConstants.TAG_PRIORITY_ATTRIBUTE, chatTagData.TagPriority)

	if chatTagData.TagLocalizedText then
		tag:SetAttribute(ChatTagConstants.TAG_LOCALIZED_TEXT_ATTRIBUTE, LocalizedTextUtils.toJSON(chatTagData.TagLocalizedText))
	end

	tag.Parent = self._chatTagsContainer

	return tag
end

function HasChatTags:GetChatTagByKey(chatTagKey)
	assert(type(chatTagKey) == "string", "Bad chatTagKey")

	for _, item in pairs(BinderUtils.getChildren(self._chatTagBinder, self._chatTagsContainer)) do
		if item.ChatTagKey.Value == chatTagKey then
			return item
		end
	end

	return nil
end

--[=[
	Removes all chat tags from the player
]=]
function HasChatTags:ClearTags()
	for _, item in pairs(self._chatTagsContainer:GetChildren()) do
		if self._chatTagBinder:Get(item) then
			item:Destroy()
		end
	end
end

return PlayerBinder.new("HasChatTags", HasChatTags)