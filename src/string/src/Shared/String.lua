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
	if not pattern then
		return str:match("^%s*(.-)%s*$")
	else
		-- When we find the first non space character defined by ^%s
		-- we yank out anything in between that and the end of the string
		-- Everything else is replaced with %1 which is essentially nothing
		return str:match("^"..pattern.."*(.-)"..pattern.."*$")
	end
end

--[=[
	Converts the string to UpperCamelCase
	@param str string
	@return string
]=]
function String.toCamelCase(str: string): string
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.upper)
	str = str:gsub("%p", "")

	return str
end


--[=[
	Uppercases the first letter of the string
	@param str string
	@return string
]=]
function String.uppercaseFirstLetter(str: string): string
	return str:gsub("^%a", string.upper)
end

--[=[
	Converts to the string to lowerCamelCase
	@param str string
	@return string
]=]
function String.toLowerCamelCase(str: string): string
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.lower)
	str = str:gsub("%p", "")

	return str
end

--[=[
	Converts the string to _privateCamelCase
	@param str string
	@return string
]=]
function String.toPrivateCase(str: string): string
	return "_" .. str:sub(1, 1):lower() .. str:sub(2, #str)
end

--[=[
	Like trim, but only applied to the beginning of the setring
	@param str string
	@param pattern string? -- Defaults to whitespace
	@return string
]=]
function String.trimFront(str: string, pattern: string?): string
	pattern = pattern or "%s";
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*", "%1"))
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
		str = str:sub(1, characterLimit-3).."..."
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
	if str:sub(1, #prefix) == prefix then
		return str:sub(#prefix + 1)
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
	if str:sub(-#postfix) == postfix then
		return str:sub(1, -#(postfix) - 1)
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
	return str:sub(-#postfix) == postfix
end

--[=[
	Returns if a string starts with a postfix
	@param str string
	@param prefix string
	@return boolean
]=]
function String.startsWith(str: string, prefix: string): boolean
	return str:sub(1, #prefix) == prefix
end

--[=[
	Adds commas to a number. Not culture aware.
	@param number string | number
	@return string
]=]
function String.addCommas(number: string | number): string
	if type(number) == "number" then
		number = tostring(number)
	end

	local index = -1

	while index ~= 0 do
		number, index = string.gsub(number, "^(-?%d+)(%d%d%d)", '%1,%2')
	end

	return number
end

return String