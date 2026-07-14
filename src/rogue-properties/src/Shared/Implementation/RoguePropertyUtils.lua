--!strict
--[=[
	@class RoguePropertyUtils
]=]

local require = require(script.Parent.loader).load(script)

local JSONUtils = require("JSONUtils")

type RoguePropertyDefinitionLike = {
	GetValueType: (self: RoguePropertyDefinitionLike) -> string,
	GetName: (self: RoguePropertyDefinitionLike) -> string,
	GetDefaultValue: (self: RoguePropertyDefinitionLike) -> any,
	GetEncodedDefaultValue: (self: RoguePropertyDefinitionLike) -> any,
}

local RoguePropertyUtils = {}

function RoguePropertyUtils.decodeProperty(definition: RoguePropertyDefinitionLike, value: any): any
	if definition:GetValueType() == "table" then
		local ok, decoded, err = JSONUtils.jsonDecode(value :: string)
		if not ok then
			warn(string.format("Failed to decode current value of %s. %q", definition:GetName(), tostring(err)))
			return definition:GetDefaultValue()
		end

		return decoded
	else
		return value
	end
end

function RoguePropertyUtils.encodeProperty(definition: RoguePropertyDefinitionLike, value: any): any
	if definition:GetValueType() == "table" then
		local ok, encoded, err = JSONUtils.jsonEncode(value)
		if not ok then
			warn(string.format("Failed to encode current value of %s. %q", definition:GetName(), tostring(err)))
			return definition:GetEncodedDefaultValue()
		end

		return encoded
	else
		return value
	end
end

return RoguePropertyUtils
