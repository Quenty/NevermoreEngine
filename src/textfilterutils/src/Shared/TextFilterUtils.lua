--!strict
--[=[
	Utility functions for filtering text wrapping [TextService] and legacy [Chat] API surfaces.

	@class TextFilterUtils
]=]

local require = require(script.Parent.loader).load(script)

local TextService = game:GetService("TextService")
local Chat = game:GetService("Chat")

local Promise = require("Promise")
local TypeUtils = require("TypeUtils")

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
function TextFilterUtils.promiseNonChatStringForBroadcast(
	text: string,
	fromUserId: number,
	textFilterContext: Enum.TextFilterContext
): Promise.Promise<string>
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForBroadcastAsync,
		text,
		fromUserId,
		textFilterContext
	)
end

--[=[
	Legacy filter broadcast using the `Chat:FilterStringForBroadcast` API call. It's recommended
	you use [TextFilterUtils.promiseNonChatStringForBroadcast] instead.


	@param playerFrom Player
	@param text string
	@return Promise<string>
]=]
function TextFilterUtils.promiseLegacyChatFilter(playerFrom: Player, text: string)
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
function TextFilterUtils.promiseNonChatStringForUserAsync(
	text: string,
	fromUserId: number,
	toUserId: number,
	textFilterContext: Enum.TextFilterContext
)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")
	assert(type(toUserId) == "number", "Bad toUserId")
	assert(typeof(textFilterContext) == "EnumItem", "Bad textFilterContext")

	return TextFilterUtils._promiseTextResult(
		TextFilterUtils.getNonChatStringForUserAsync,
		text,
		fromUserId,
		toUserId,
		textFilterContext
	)
end

--[=[
	Blocking call to get a non-chat string for broadcast. Wraps [TextService.FilterStringAsync].

	@param text string
	@param fromUserId number
	@param textFilterContext TextFilterContext
	@return (string?, string?)
]=]
function TextFilterUtils.getNonChatStringForBroadcastAsync(
	text: string,
	fromUserId: number,
	textFilterContext: Enum.TextFilterContext
): (string?, string?)
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
		return nil, err
	end

	return resultText
end

--[=[
	Blocking call to get a non-chat string for a user.

	@param text string
	@param fromUserId number
	@param toUserId number
	@param textFilterContext TextFilterContext
	@return (string?, string?)
]=]
function TextFilterUtils.getNonChatStringForUserAsync(
	text: string,
	fromUserId: number,
	toUserId: number,
	textFilterContext: Enum.TextFilterContext
): (string?, string?)
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
		return nil, err
	end

	return textResult
end

function TextFilterUtils._promiseTextResult<T...>(getResult: (T...) -> (string?, string?), ...: T...): Promise.Promise<string>
	local args = table.pack(...)

	local promise = Promise.spawn(function(resolve, reject)
		local text, err = getResult(TypeUtils.anyValue(table.unpack(args, 1, args.n)))
		if not text then
			return reject(err or "Pcall failed")
		end

		if type(text) ~= "string" then
			return reject("Bad text result")
		end

		return resolve(text)
	end)

	return promise
end

--[=[
	Returns true if there's non-filtered text or characters in the text
	@return boolean
]=]
function TextFilterUtils.hasNonFilteredText(text: string): boolean
	assert(type(text) == "string", "Bad text")

	return string.find(text, "[^#%s]") ~= nil
end

local WHITESPACE = {
	["\r"] = true,
	["\n"] = true,
	[" "] = true,
	["\t"] = true,
}

--[=[
	Computes proportional text that is filtered ignoring whitespace.

	@param text string
	@return number
]=]
function TextFilterUtils.getProportionFiltered(text: string): number
	local filteredChars, unfilteredChars = TextFilterUtils.countFilteredCharacters(text)
	local total = unfilteredChars + filteredChars
	if total == 0 then
		return 0
	end

	return filteredChars / total
end

--[=[
	Gets the number of filtered characters in the text string

	@param text string
	@return number -- filtered characters
	@return number -- Unfiltered characters
	@return number -- White space characters
]=]
function TextFilterUtils.countFilteredCharacters(text: string): (number, number, number)
	local filteredChars = 0
	local unfilteredChars = 0
	local whitespaceCharacters = 0
	for i = 1, #text do
		local textChar = string.sub(text, i, i)
		if textChar == "#" then
			filteredChars = filteredChars + 1
		elseif WHITESPACE[textChar] then
			whitespaceCharacters = whitespaceCharacters + 1
		else
			unfilteredChars = unfilteredChars + 1
		end
	end

	return filteredChars, unfilteredChars, whitespaceCharacters
end

--[=[
	Adds in new lines and whitespace to the text

	@param text string
	@param filteredText string
	@return string
]=]
function TextFilterUtils.addBackInNewLinesAndWhitespace(text: string, filteredText: string): string
	assert(type(text) == "string", "Bad text")
	assert(type(filteredText) == "string", "Bad filteredText")

	if text == filteredText then
		return text
	end

	-- Assume that any missing characters are actually our newlines.
	local missingCharacters = math.max(0, #text - #filteredText)

	-- TODO: Not all this GC
	local newString = ""
	local filteredTextIndex = 1

	local textIndex = 1
	while filteredTextIndex <= #filteredText or textIndex <= #text do
		local textChar = string.sub(text, textIndex, textIndex)
		local filteredChar = string.sub(filteredText, filteredTextIndex, filteredTextIndex)

		if textChar == "\n" then
			if missingCharacters > 0 then
				missingCharacters = missingCharacters - 1
				newString = newString .. "\n"
			else
				newString = newString .. "\n"
				filteredTextIndex = filteredTextIndex + 1
			end
		elseif textChar == " " and filteredChar == "#" then
			newString = newString .. " "
		elseif textChar == "\t" and filteredChar == "#" then
			newString = newString .. "\t"
		elseif textChar == "\r" and filteredChar == "#" then
			newString = newString .. "\r"
		else
			if filteredChar == "" then
				if missingCharacters > 0 then
					missingCharacters = missingCharacters - 1
					newString = newString .. "\n"
				end
			else
				newString = newString .. filteredChar
			end

			filteredTextIndex = filteredTextIndex + 1
		end

		textIndex = textIndex + 1
	end

	return newString
end

return TextFilterUtils
