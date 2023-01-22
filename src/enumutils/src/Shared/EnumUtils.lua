--[=[
	Helds encode Roblox enums into a string

	@class EnumUtils
]=]

local EnumUtils = {}

--[=[
	Encodes the value as a string. Note the general format will be such that the string is indexed
	using a regular Lua value. For example:

	```lua
	print(EnumUtils.encodeAsString(Enum.KeyCode.E)) --> Enum.KeyCode.E
	```

	@param enumItem EnumItem
	@return EnumItem
]=]
function EnumUtils.encodeAsString(enumItem)
	assert(typeof(enumItem) == "EnumItem", "Bad enumItem")

	return ("Enum.%s.%s"):format(tostring(enumItem.EnumType), enumItem.Name)
end

--[=[
	Returns whether an enum is of the expected type. Useful for asserts.

	```lua
	assert(EnumUtils.isOfType(Enum.KeyCode, enumItem))
	```

	@param expectedEnumType EnumType
	@param enumItem any
	@return boolean -- True if is of type
	@return string -- Error message if there is an error.
]=]
function EnumUtils.isOfType(expectedEnumType, enumItem)
	assert(typeof(expectedEnumType) == "Enum", "Bad enum")

	if typeof(enumItem) ~= "EnumItem" then
		return false, ("Bad enumItem. Expected enumItem to be %s, got %s '%s'"):format(tostring(expectedEnumType), typeof(enumItem), tostring(enumItem))
	end

	if enumItem.EnumType == expectedEnumType then
		return true
	else
		return false, ("Bad enumItem. Expected enumItem to be %s, got %s"):format(tostring(expectedEnumType), EnumUtils.encodeAsString(enumItem))
	end
end

--[=[
	Returns true if the value is an encoded enum

	@param value any? -- String to decode
	@return boolean
]=]
function EnumUtils.isEncodedEnum(value)
	return EnumUtils.decodeFromString(value) ~= nil
end

--[=[
	Decodes the enum from the string name encoding

	@param value string? -- String to decode
	@return EnumItem
]=]
function EnumUtils.decodeFromString(value)
	if type(value) ~= "string" then
		return nil
	end

	local enumType, enumName = string.match(value, "^Enum%.([^%.%s]+)%.([^%.%s]+)$")
	if enumType and enumName then
		local enumValue
		local ok, err = pcall(function()
			enumValue = Enum[enumType][enumName]
		end)
		if not ok then
			warn(err, ("[EnumUtils.decodeFromString] - Failed to decode %q into an enum value due to %q"):format(value, tostring(err)))
			return nil
		end

		return enumValue
	else
		return nil
	end
end

return EnumUtils