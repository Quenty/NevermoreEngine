--!strict
--[=[
	This module provides utility functions for strings
	@class String
]=]

local String = {}

--[=[
	Trims the string of the given pattern

	@param str string
	@param pattern string? -- Defaults to whitespace
	@return string
]=]
function String.trim(str: string, pattern: string?): string
	if pattern == nil then
		return string.match(str, "^%s*(.-)%s*$") :: string
	else
		-- When we find the first non space character defined by ^%s
		-- we yank out anything in between that and the end of the string
		-- Everything else is replaced with %1 which is essentially nothing
		return string.match(str, "^" .. pattern .. "*(.-)" .. pattern .. "*$")
	end
end

--[=[
	Converts the string to `UpperCamelCase` from `camelCase` or `snakeCase` or `YELL_CASE`
	@param str string
	@return string
]=]
function String.toCamelCase(str: string): string
	str = string.lower(str)
	str = string.gsub(str, "[ _](%a)", string.upper)
	str = string.gsub(str, "^%a", string.upper)
	str = string.gsub(str, "%p", "")

	return str
end

--[=[
	Uppercases the first letter of the string
	@param str string
	@return string
]=]
function String.uppercaseFirstLetter(str: string): string
	return (string.gsub(str, "^%a", string.upper))
end

--[=[
	Converts to the string to `lowerCamelCase` from `camelCase` or `snakeCase` or `YELL_CASE`
	@param str string
	@return string
]=]
function String.toLowerCamelCase(str: string): string
	str = string.lower(str)
	str = string.gsub(str, "[ _](%a)", string.upper)
	str = string.gsub(str, "^%a", string.lower)
	str = string.gsub(str, "%p", "")

	return str
end

--[=[
	Converts the string to _privateCamelCase
	@param str string
	@return string
]=]
function String.toPrivateCase(str: string): string
	return "_" .. string.lower(string.sub(str, 1, 1)) .. str:sub(2, #str)
end

--[=[
	Like trim, but only applied to the beginning of the setring
	@param str string
	@param pattern string? -- Defaults to whitespace
	@return string
]=]
function String.trimFront(str: string, pattern: string?): string
	local strPattern = pattern or "%s"
	return (string.gsub(str, "^" .. strPattern .. "*(.-)" .. strPattern .. "*", "%1"))
end

--[=[
	Counts the number of times a char appears in a string.

	:::note
	Note that this is not UTF8 safe
	:::

	@param str string
	@param char string
	@return number
]=]
function String.checkNumOfCharacterInString(str: string, char: string): number
	local count = 0
	for _ in string.gmatch(str, char) do
		count = count + 1
	end
	return count
end

--[=[
	Checks if a string is empty or nil
	@param str string
	@return boolean
]=]
function String.isEmptyOrWhitespaceOrNil(str: string): boolean
	return type(str) ~= "string" or str == "" or String.isWhitespace(str)
end

--[=[
	Returns whether or not text is only whitespace
	@param str string
	@return boolean
]=]
function String.isWhitespace(str: string): boolean
	return string.match(str, "[%s]+") == str
end

--[=[
	Converts text to have a ... after it if it's too long.
	@param str string
	@param characterLimit number
	@return string
]=]
function String.elipseLimit(str: string, characterLimit: number): string
	if #str > characterLimit then
		str = string.sub(str, 1, characterLimit - 3) .. "..."
	end
	return str
end

--[=[
	Removes a prefix from a string if it exists

	@param str string
	@param prefix string
	@return string
]=]
function String.removePrefix(str: string, prefix: string): string
	if string.sub(str, 1, #prefix) == prefix then
		return string.sub(str, #prefix + 1)
	else
		return str
	end
end

--[=[
	Removes a postfix from a string if it exists

	@param str string
	@param postfix string
	@return string
]=]
function String.removePostfix(str: string, postfix: string): string
	if string.sub(str, -#postfix) == postfix then
		return string.sub(str, 1, -#postfix - 1)
	else
		return str
	end
end

--[=[
	Returns if a string ends with a postfix

	@param str string
	@param postfix string
	@return boolean
]=]
function String.endsWith(str: string, postfix: string): boolean
	return string.sub(str, -#postfix) == postfix
end

--[=[
	Returns if a string starts with a postfix

	@param str string
	@param prefix string
	@return boolean
]=]
function String.startsWith(str: string, prefix: string): boolean
	return string.sub(str, 1, #prefix) == prefix
end

--[=[
	Adds commas to a number. Not culture aware.

	See [NumberLocalizationUtils.abbreviate] for a culture aware version.

	@param number string | number
	@param seperator string?
	@return string
]=]
function String.addCommas(number: string | number, seperator: string): string
	local strNumber
	if type(number) == "number" then
		strNumber = tostring(number)
	else
		strNumber = number
	end
	seperator = seperator or ","

	local index = -1

	while index ~= 0 do
		strNumber, index = string.gsub(strNumber, "^(-?%d+)(%d%d%d)", "%1" .. seperator .. "%2")
	end

	return strNumber
end

return String
