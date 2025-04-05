--[=[
	Helper methods for encoding and decoding input lists into network storage
	@class InputKeyMapSettingUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local EnumUtils = require("EnumUtils")
local JSONUtils = require("JSONUtils")
local InputTypeUtils = require("InputTypeUtils")
local String = require("String")

local InputKeyMapSettingUtils = {}

--[=[
	Returns the canonical setting name for this input key map list.

	@param inputKeyMapList InputKeyMapList
	@param inputModeType InputModeType
	@return string
]=]
function InputKeyMapSettingUtils.getSettingName(inputKeyMapList, inputModeType)
	return string.format("Keybind_%s_%s", String.toCamelCase(inputKeyMapList:GetListName()), inputModeType.Name)
end

--[=[
	Encodes the list into a string which can be decoded later.

	@param list { InputType }
	@return string
]=]
function InputKeyMapSettingUtils.encodeInputTypeList(list)
	local newList = {}

	for _, inputType in list do
		if typeof(inputType) == "EnumItem" then
			table.insert(newList, EnumUtils.encodeAsString(inputType))
		elseif InputTypeUtils.isKnownInputType(inputType) then
			table.insert(newList, inputType)
		else
			warn(string.format("[InputKeyMapSettingUtils] - Unknown inputType %q", tostring(inputType)))
			table.insert(newList, inputType) -- Encode anyway
		end
	end

	return HttpService:JSONEncode(newList)
end

--[=[
	Decodes the list from a string into a safe value.

	@param encoded string?
	@return string
]=]
function InputKeyMapSettingUtils.decodeInputTypeList(encoded)
	if type(encoded) ~= "string" then
		return nil
	end

	local ok, result = JSONUtils.jsonDecode(encoded)
	if not ok then
		return nil
	end

	if type(result) ~= "table" then
		warn("[InputKeyMapSettingUtils] - Failed to decode table")
		return nil
	end

	local decodedList = {}

	for _, inputType in result do
		if EnumUtils.isEncodedEnum(inputType) then
			table.insert(decodedList, EnumUtils.decodeFromString(inputType))
		elseif InputTypeUtils.isKnownInputType(inputType) then
			table.insert(decodedList, inputType)
		else
			warn(string.format("[InputKeyMapSettingUtils] - Unknown inputType %q", tostring(inputType)))
			table.insert(decodedList, inputType) -- Decode anyway
		end
	end

	return decodedList
end

return InputKeyMapSettingUtils