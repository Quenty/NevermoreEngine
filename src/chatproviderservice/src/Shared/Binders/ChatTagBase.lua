--[=[
	@class ChatTagBase
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local ChatTagConstants = require("ChatTagConstants")
local LocalizedTextUtils = require("LocalizedTextUtils")
local Rx = require("Rx")

local ChatTagBase = setmetatable({}, BaseObject)
ChatTagBase.ClassName = "ChatTagBase"
ChatTagBase.__index = ChatTagBase

function ChatTagBase.new(obj)
	local self = setmetatable(BaseObject.new(obj), ChatTagBase)

	self._chatTagText = AttributeValue.new(self._obj, ChatTagConstants.TAG_TEXT_ATTRIBUTE, "")
	self._chatTagLocalizedTextData = AttributeValue.new(self._obj, ChatTagConstants.TAG_LOCALIZED_TEXT_ATTRIBUTE, nil)
	self._chatTagColor = AttributeValue.new(self._obj, ChatTagConstants.TAG_COLOR_ATTRIBUTE, Color3.new(1, 1, 1))
	self._chatTagPriority = AttributeValue.new(self._obj, ChatTagConstants.TAG_PRIORITY_ATTRIBUTE, 0)

	self.UserDisabled = AttributeValue.new(self._obj, ChatTagConstants.USER_DISABLED_ATTRIBUTE, false)
	self.ChatTagKey = AttributeValue.new(self._obj, ChatTagConstants.TAG_KEY_ATTRIBUTE, false)

	return self
end

function ChatTagBase:ObserveChatTagData()
	return Rx.combineLatest({
		UserDisabled = self.UserDisabled:Observe();
		TagText = self._chatTagText:Observe();
		TagLocalizedText = self._chatTagLocalizedTextData:Observe():Pipe({
			Rx.map(function(text)
				if type(text) == "string" then
					return LocalizedTextUtils.fromJSON(text)
				else
					return nil
				end;
			end);
		});
		TagColor = self._chatTagColor:Observe();
		TagPriority = self._chatTagPriority:Observe();
	})
end

return ChatTagBase