--[=[
	Utility functions for filtering text wrapping [TextService] and legacy [Chat] API surfaces.

	@class TextFilterUtils
]=]

local require = require(script.Parent.loader).load(script)

local TextService = game:GetService("TextService")
local Chat = game:GetService("Chat")

local Promise = require("Promise")

local TextFilterUtils = {}

--[=[
	Returns a filtered string for broadcast. Tends to look like this:

	```lua
	TextFilterUtils.promiseNonChatStringForBroadcast(text, player.UserId, Enum.TextFilterContext.PublicChat)
		:Then(function(filtered)
			print(filtered)
		end)
	```

	The two options for textFilterContext are `Enum.TextFilterContext.PublicChat` and `Enum.TextFilterContext.PrivateChat`.

	@param text string
	@param fromUserId number
	@param textFilterContext TextFilterContext
	@return Promise<string>
]=]
function TextFilterUtils.promiseNonChatStringForBroadcast(text, fromUserId, textFilterContext)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForBroadcastAsync,
		text,
		fromUserId,
		textFilterContext)
end

--[=[
	Legacy filter broadcast using the `Chat:FilterStringForBroadcast` API call. It's recommended
	you use [TextFilterUtils.promiseNonChatStringForBroadcast] instead.


	@param playerFrom Player
	@param text string
	@return Promise<string>
]=]
function TextFilterUtils.promiseLegacyChatFilter(playerFrom, text)
	assert(typeof(playerFrom) == "Instance" and playerFrom:IsA("Player"), "Bad playerFrom")
	assert(type(text) == "string", "Bad text")

	return Promise.spawn(function(resolve, reject)
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

--[=[
	Returns a filtered string for a specific user to another user. This is preferable over broadcast if
	possible.

	@param text string
	@param fromUserId number
	@param toUserId number
	@param textFilterContext TextFilterContext
	@return Promise<string>
]=]
function TextFilterUtils.promiseNonChatStringForUserAsync(text, fromUserId, toUserId, textFilterContext)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(type(toUserId) == "number", "Bad toUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForUserAsync,
		text,
		fromUserId,
		toUserId,
		textFilterContext)
end

--[=[
	Blocking call to get a non-chat string for broadcast. Wraps [TextService.FilterStringAsync].

	@param text string
	@param fromUserId number
	@param textFilterContext TextFilterContext
	@return Promise<string>
]=]
function TextFilterUtils.getNonChatStringForBroadcastAsync(text, fromUserId, textFilterContext)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	local resultText = nil
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(text, fromUserId, textFilterContext)
		if not result then
			error("No TextFilterResult")
		end

		resultText = result:GetNonChatStringForBroadcastAsync()
	end)

	if not ok then
		return false, err
	end

	return resultText
end

--[=[
	Blocking call to get a non-chat string for a user.

	@param text string
	@param fromUserId number
	@param toUserId number
	@param textFilterContext TextFilterContext
	@return Promise<string>
]=]
function TextFilterUtils.getNonChatStringForUserAsync(text, fromUserId, toUserId, textFilterContext)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(type(toUserId) == "number", "Bad toUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	local textResult = nil
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(text, fromUserId, textFilterContext)
		if not result then
			error("No TextFilterResult")
		end

		textResult = result:GetNonChatStringForUserAsync(toUserId)
	end)

	if not ok then
		return false, err
	end

	return textResult
end

function TextFilterUtils._promiseTextResult(getResult, ...)
	local args = {...}

	local promise = Promise.spawn(function(resolve, reject)
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