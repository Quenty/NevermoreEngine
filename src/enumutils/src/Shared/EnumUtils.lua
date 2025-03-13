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
function EnumUtils.encodeAsString(enumItem: EnumItem): string
	assert(typeof(enumItem) == "EnumItem", "Bad enumItem")

	return string.format("Enum.%s.%s", tostring(enumItem.EnumType), enumItem.Name)
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
function EnumUtils.isOfType(expectedEnumType: Enum, enumItem: EnumItem): (boolean, string?)
	assert(typeof(expectedEnumType) == "Enum", "Bad enum")

	if typeof(enumItem) ~= "EnumItem" then
		return false,
			string.format(
				"Bad enumItem. Expected enumItem to be %s, got %s '%s'",
				tostring(expectedEnumType),
				typeof(enumItem),
				tostring(enumItem)
			)
	end

	if enumItem.EnumType == expectedEnumType then
		return true, nil
	else
		return false,
			string.format(
				"Bad enumItem. Expected enumItem to be %s, got %s",
				tostring(expectedEnumType),
				EnumUtils.encodeAsString(enumItem)
			)
	end
end

--[=[
	Attempts to cast an item into an enum

	@param enumType EnumType
	@param value any
	@return EnumItem
]=]
function EnumUtils.toEnum(enumType: Enum, value: any): EnumItem?
	assert(typeof(enumType) == "Enum", "Bad enum")

	if typeof(value) == "EnumItem" then
		if value.EnumType == enumType then
			return value
		else
			return nil
		end
	elseif type(value) == "number" then
		return (enumType :: any):FromValue(value)
	elseif type(value) == "string" then
		local result = (enumType :: any):FromName(value)
		if result then
			return result
		end

		-- Check full string name qualifier
		local decoded = EnumUtils.decodeFromString(value)
		if decoded and decoded.EnumType == enumType then
			return decoded
		else
			return nil
		end
	end

	return nil
end

--[=[
	Returns true if the value is an encoded enum

	@param value any? -- String to decode
	@return boolean
]=]
function EnumUtils.isEncodedEnum(value: any): boolean
	return EnumUtils.decodeFromString(value) ~= nil
end

--[=[
	Decodes the enum from the string name encoding

	@param value string? -- String to decode
	@return EnumItem
]=]
function EnumUtils.decodeFromString(value: string?): EnumItem?
	if type(value) ~= "string" then
		return nil
	end

	local enumType, enumName = string.match(value, "^Enum%.([^%.%s]+)%.([^%.%s]+)$")
	if enumType and enumName then
		local enumValue
		local ok, err = pcall(function()
			enumValue = Enum[enumType]:FromName(enumName)
		end)
		if not ok then
			warn(
				err,
				string.format(
					"[EnumUtils.decodeFromString] - Failed to decode %q into an enum value due to %q",
					value,
					tostring(err)
				)
			)
			return nil
		end

		return enumValue
	else
		return nil
	end
end

return EnumUtils
