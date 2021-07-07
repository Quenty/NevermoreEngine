---
-- @module TextFilterService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GetRemoteFunction = require("GetRemoteFunction")
local TextFilterServiceConstants = require("TextFilterServiceConstants")
local TextFilterUtils = require("TextFilterUtils")

local TextFilterService = {}

function TextFilterService:Init()
	self._remoteFunction = GetRemoteFunction(TextFilterServiceConstants.REMOTE_FUNCTION_NAME)
	self._remoteFunction.OnServerInvoke = function(player, ...)
		return self:_handleServerInvoke(player, ...)
	end
end

function TextFilterService:_handleServerInvoke(...)
	local promise = self:_turnRequestToPromise(...)
	local ok, filteredName = promise:Yield()
	if not ok then
		return false, filteredName
	end

	return true, filteredName
end

function TextFilterService:_turnRequestToPromise(player, request, ...)
	assert(player)
	assert(type(request) == "string")

	if request == TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_USER then
		return self:_promiseNonChatStringForUser(player, ...)
	elseif request == TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_BROADCAST then
		return self:_promiseNonChatStringForBroadcast(player, ...)
	elseif request == TextFilterServiceConstants.REQUEST_PREVIEW_NON_CHAT_STRING_FOR_BROADCAST then
		return self:_promisePreviewNonChatStringForBroadcast(player, ...)
	else
		error("[TextFilterService] -Unknown request %q")
	end
end

function TextFilterService:_promiseNonChatStringForUser(player, text, fromUserId)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(type(text) == "string")
	assert(type(fromUserId) == "number")

	return TextFilterUtils.promiseNonChatStringForUserAsync(
			text,
			fromUserId,
			player.UserId,
			Enum.TextFilterContext.PublicChat)
		:Catch(function(err)
			-- Error occurs due to player having left the game, but we still need to display their text, so let's fallback
			-- to this text
			return TextFilterUtils.promiseLegacyChatFilter(player, text)
		end)
end

function TextFilterService:_promiseNonChatStringForBroadcast(player, text, fromUserId)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(type(text) == "string")
	assert(type(fromUserId) == "number")

	return TextFilterUtils.promiseNonChatStringForBroadcast(
			text,
			fromUserId,
			Enum.TextFilterContext.PublicChat)
		:Catch(function(err)
			-- Error occurs due to player having left the game, but we still need to display their text, so let's fallback
			-- to this text
			return TextFilterUtils.promiseLegacyChatFilter(player, text)
		end)
end

function TextFilterService:_promisePreviewNonChatStringForBroadcast(player, text)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(type(text) == "string")

	-- Use the old legacy API to show preview
	return TextFilterUtils.promiseLegacyChatFilter(player, text)
end

return TextFilterService