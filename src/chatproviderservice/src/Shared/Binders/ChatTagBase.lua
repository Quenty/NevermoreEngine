--!strict
--[=[
	@class ChatTagBase
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local ChatTagConstants = require("ChatTagConstants")
local LocalizedTextUtils = require("LocalizedTextUtils")
local Rx = require("Rx")
local _ChatTagDataUtils = require("ChatTagDataUtils")
local _Observable = require("Observable")

local ChatTagBase = setmetatable({}, BaseObject)
ChatTagBase.ClassName = "ChatTagBase"
ChatTagBase.__index = ChatTagBase

export type ChatTagBase = typeof(setmetatable(
	{} :: {
		_obj: Folder,
		_chatTagText: AttributeValue.AttributeValue<string>,
		_chatTagLocalizedTextData: AttributeValue.AttributeValue<LocalizedTextUtils.LocalizedTextData?>,
		_chatTagColor: AttributeValue.AttributeValue<Color3>,
		_chatTagPriority: AttributeValue.AttributeValue<number>,

		-- Public
		UserDisabled: AttributeValue.AttributeValue<boolean>,
		ChatTagKey: AttributeValue.AttributeValue<boolean>,
	},
	{} :: typeof({ __index = ChatTagBase })
)) & BaseObject.BaseObject

function ChatTagBase.new(obj: Folder): ChatTagBase
	local self: ChatTagBase = setmetatable(BaseObject.new(obj) :: any, ChatTagBase)

	self._chatTagText = AttributeValue.new(self._obj, ChatTagConstants.TAG_TEXT_ATTRIBUTE, "")
	self._chatTagLocalizedTextData = AttributeValue.new(self._obj, ChatTagConstants.TAG_LOCALIZED_TEXT_ATTRIBUTE, nil)
	self._chatTagColor = AttributeValue.new(self._obj, ChatTagConstants.TAG_COLOR_ATTRIBUTE, Color3.new(1, 1, 1))
	self._chatTagPriority = AttributeValue.new(self._obj, ChatTagConstants.TAG_PRIORITY_ATTRIBUTE, 0)

	self.UserDisabled = AttributeValue.new(self._obj, ChatTagConstants.USER_DISABLED_ATTRIBUTE, false)
	self.ChatTagKey = AttributeValue.new(self._obj, ChatTagConstants.TAG_KEY_ATTRIBUTE, false)

	return self
end

function ChatTagBase.ObserveChatTagData(self: ChatTagBase): _Observable.Observable<_ChatTagDataUtils.ChatTagData>
	return Rx.combineLatest({
		UserDisabled = self.UserDisabled:Observe(),
		TagText = self._chatTagText:Observe(),
		TagLocalizedText = self._chatTagLocalizedTextData:Observe():Pipe({
			Rx.map(function(text)
				if type(text) == "string" then
					return LocalizedTextUtils.fromJSON(text)
				else
					return nil
				end
			end) :: any,
		}),
		TagColor = self._chatTagColor:Observe(),
		TagPriority = self._chatTagPriority:Observe(),
	}) :: any
end

return ChatTagBase