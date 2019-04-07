--- This module provides utility functions for strings
-- @module String

local lib = {}

function lib.Trim(str, pattern)
	pattern = pattern or "%s";
	-- %S is whitespaces
	-- When we find the first non space character defined by ^%s
	-- we yank out anything in between that and the end of the string
	-- Everything else is replaced with %1 which is essentially nothing
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*$", "%1"))
end

--- Sets it to UpperCamelCase
function lib.ToCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.upper)
	str = str:gsub("%p", "")

	return str
end

function lib.ToLowerCamelCase(str)
	str = str:lower()
	str = str:gsub("[ _](%a)", string.upper)
	str = str:gsub("^%a", string.lower)
	str = str:gsub("%p", "")

	return str
end

function lib.ToPrivateCase(str)
	return "_" .. str:sub(1, 1):lower() .. str:sub(2, #str)
end

-- Only trims the front of the string...
function lib.TrimFront(str, pattern)
	pattern = pattern or "%s";
	return (str:gsub("^"..pattern.."*(.-)"..pattern.."*", "%1"))
end

function lib.CheckNumOfCharacterInString(str, char)
	local count = 0
	for _ in string.gmatch(str, char) do
		count = count + 1
	end
	return count
end

--- Checks if a string is empty or nil
function lib.IsEmptyOrWhitespaceOrNil(str)
	return type(str) ~= "string" or str == "" or lib.IsWhitespace(str)
end

--- Returns whether or not text is whitespace
function lib.IsWhitespace(str)
	return string.match(str, "[%s]+") == str
end

--- Converts text to have a ... after it if it's too long.
function lib.ElipseLimit(str, characterLimit)
	if #str > characterLimit then
		str = str:sub(1, characterLimit-3).."..."
	end
	return str
end

function lib.AddCommas(number)
	if type(number) == "number" then
		number = tostring(number)
	end

	local index = -1

	while index ~= 0 do
		number, index = string.gsub(number, "^(-?%d+)(%d%d%d)", '%1,%2')
	end

	return number
end

return lib