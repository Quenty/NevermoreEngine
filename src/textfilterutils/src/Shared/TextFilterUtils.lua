--- Utility functions for filtering text
-- @module TextFilterUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local TextService = game:GetService("TextService")
local Chat = game:GetService("Chat")

local Promise = require("Promise")

local TextFilterUtils = {}

function TextFilterUtils.promiseNonChatStringForBroadcast(str, fromUserId, textContext)
	assert(type(str) == "string", "Bad str")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(typeof(textContext) == "EnumItem", "Bad textContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForBroadcastAsync,
		str,
		fromUserId,
		textContext)
end

function TextFilterUtils.promiseLegacyChatFilter(playerFrom, text)
	assert(typeof(playerFrom) == "Instance" and playerFrom:IsA("Player"), "Bad playerFrom")
	assert(type(text) == "string", "Bad text")

	return Promise.defer(function(resolve, reject)
		local filteredText
		local ok, err = pcall(function()
			filteredText = Chat:FilterStringForBroadcast(text, playerFrom)
		end)
		if not ok then
			return reject(err)
		end
		if type(filteredText) ~= "string" then
			return reject("Not a string")
		end

		return resolve(filteredText)
	end)
end

function TextFilterUtils.promiseNonChatStringForUserAsync(str, fromUserId, toUserId, textContext)
	assert(type(str) == "string", "Bad str")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(type(toUserId) == "number", "Bad toUserId")
	assert(typeof(textContext) == "EnumItem", "Bad textContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForUserAsync,
		str,
		fromUserId,
		toUserId,
		textContext)
end

function TextFilterUtils.getNonChatStringForBroadcastAsync(str, fromUserId, textContext)
	assert(type(str) == "string", "Bad str")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(typeof(textContext) == "EnumItem", "Bad textContext")

	local text = nil
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(str, fromUserId, textContext)
		if not result then
			error("No TextFilterResult")
		end

		text = result:GetNonChatStringForBroadcastAsync()
	end)

	if not ok then
		return false, err
	end

	return text
end

function TextFilterUtils.getNonChatStringForUserAsync(str, fromUserId, toUserId, textContext)
	assert(type(str) == "string", "Bad str")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(type(toUserId) == "number", "Bad toUserId")
	assert(typeof(textContext) == "EnumItem", "Bad textContext")

	local text = nil
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(str, fromUserId, textContext)
		if not result then
			error("No TextFilterResult")
		end

		text = result:GetNonChatStringForUserAsync(toUserId)
	end)

	if not ok then
		return false, err
	end

	return text
end

function TextFilterUtils._promiseTextResult(getResult, ...)
	local args = {...}

	local promise = Promise.defer(function(resolve, reject)
		local text, err = getResult(unpack(args))
		if not text then
			return reject(err or "Pcall failed")
		end

		if type(text) ~= "string" then
			return reject("Bad text result")
		end

		resolve(text)
	end)

	return promise
end

return TextFilterUtils