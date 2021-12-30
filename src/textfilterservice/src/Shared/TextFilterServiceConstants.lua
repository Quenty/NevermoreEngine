--[=[
	@class TextFilterServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_FUNCTION_NAME = "TextFilterServiceRemoteFunction";

	REQUEST_NON_CHAT_STRING_FOR_USER = "NonChatStringForUser";
	REQUEST_NON_CHAT_STRING_FOR_BROADCAST = "NonChatStringForBroadcast";
	REQUEST_PREVIEW_NON_CHAT_STRING_FOR_BROADCAST = "PreviewNonChatStringForBroadcast";
})