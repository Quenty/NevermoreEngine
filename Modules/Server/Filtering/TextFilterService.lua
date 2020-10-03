---
-- @module TextFilterService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Chat = game:GetService("Chat")

local GetRemoteFunction = require("GetRemoteFunction")
local TextFilterServiceConstants = require("TextFilterServiceConstants")

local TextFilterService = {}

function TextFilterService:Init()
	self._remoteFunction = GetRemoteFunction(TextFilterServiceConstants.REMOTE_FUNCTION_NAME)
	self._remoteFunction.OnServerInvoke = function(player, ...)
		return self:_handleServerInvoke(player, ...)
	end
end

function TextFilterService:_handleServerInvoke(player, text)
	assert(type(text) == "string")

	local result = Chat:FilterStringForBroadcast(text, player)
	assert(type(result) == "string")

	return result
end

return TextFilterService