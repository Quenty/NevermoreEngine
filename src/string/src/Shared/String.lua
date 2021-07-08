--- This module provides utility functions for strings
-- @module String

local String = {}

function String.trim(str, pattern)
	if not pattern then
		return str:match("^%s*(.-)%s*$")
	else
		-- When we find the first non space character defined by ^%s
		-- we yank out anything in between that and the end of the string
		-- Everything else is replaced with %1 which is essentially nothing
		return str:match("^"..pattern.."*(.-)"..pattern.."*$")
	end
end

--- Sets it to UpperCamelCase
function String.toCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.upper)
	str = str:gsub("%p", "")

	return str
end

function String.uppercaseFirstLetter(str)
	return str:gsub("^%a", string.upper)
end

function String.toLowerCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.lower)
	str = str:gsub("%p", "")

	return str
end

function String.toPrivateCase(str)
	return "_" .. str:sub(1, 1):lower() .. str:sub(2, #str)
end

-- Only trims the front of the string...
function String.trimFront(str, pattern)
	pattern = pattern or "%s";
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*", "%1"))
end

function String.checkNumOfCharacterInString(str, char)
	local count = 0
	for _ in string.gmatch(str, char) do
		count = count + 1
	end
	return count
end

--- Checks if a string is empty or nil
function String.isEmptyOrWhitespaceOrNil(str)
	return type(str) ~= "string" or str == "" or String.isWhitespace(str)
end

--- Returns whether or not text is whitespace
function String.isWhitespace(str)
	return string.match(str, "[%s]+") == str
end

--- Converts text to have a ... after it if it's too long.
function String.elipseLimit(str, characterLimit)
	if #str > characterLimit then
		str = str:sub(1, characterLimit-3).."..."
	end
	return str
end

function String.removePrefix(str, prefix)
	if str:sub(1, #prefix) == prefix then
		return str:sub(#prefix + 1)
	else
		return str
	end
end

function String.removePostfix(str, postfix)
	if str:sub(-#postfix) == postfix then
		return str:sub(1, -#(postfix) - 1)
	else
		return str
	end
end

function String.addCommas(number)
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