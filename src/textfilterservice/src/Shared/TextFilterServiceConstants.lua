---
-- @module TextFilterServiceConstants
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.readonly({
	REMOTE_FUNCTION_NAME = "TextFilterServiceRemoteFunction";

	REQUEST_NON_CHAT_STRING_FOR_USER = "NonChatStringForUser";
	REQUEST_NON_CHAT_STRING_FOR_BROADCAST = "NonChatStringForBroadcast";
	REQUEST_PREVIEW_NON_CHAT_STRING_FOR_BROADCAST = "PreviewNonChatStringForBroadcast";
})