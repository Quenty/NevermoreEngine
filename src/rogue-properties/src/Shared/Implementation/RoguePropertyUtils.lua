--!strict
--[=[
	@class RoguePropertyUtils
]=]

local require = require(script.Parent.loader).load(script)

local JSONUtils = require("JSONUtils")
local RoguePropertyTypes = require("RoguePropertyTypes")

local RoguePropertyUtils = {}

function RoguePropertyUtils.decodeProperty(definition: RoguePropertyTypes.RoguePropertyDefinition, value: any): any
	if definition:GetValueType() == "table" then
		local ok, decoded, err = JSONUtils.jsonDecode(value)
		if not ok then
			warn(string.format("Failed to decode current value of %s. %q", definition:GetName(), tostring(err)))
			return definition:GetDefaultValue()
		end

		return decoded
	else
		return value
	end
end

function RoguePropertyUtils.encodeProperty(definition: RoguePropertyTypes.RoguePropertyDefinition, value: any): any
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
