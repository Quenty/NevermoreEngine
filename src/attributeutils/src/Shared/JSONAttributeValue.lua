--!strict
--[=[
	Stores a JSON encoded value in an attribute, and allows access to it like
	a ValueObject.

	@class JSONAttributeValue
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local EncodedAttributeValue = require("EncodedAttributeValue")

local JSONAttributeValue = {}
JSONAttributeValue.ClassName = "JSONAttributeValue"

export type JSONAttributeValue<T> = EncodedAttributeValue.EncodedAttributeValue<string?, T>

--[=[
	Constructs a new JSONAttributeValue

	@param object Instance
	@param attributeName string
	@param defaultValue T?
	@return JSONAttributeValue<T>
]=]
function JSONAttributeValue.new<T>(object: Instance, attributeName: string, defaultValue: T?): JSONAttributeValue<T>
	return EncodedAttributeValue.new(
		object,
		attributeName,
		JSONAttributeValue._encode :: (T) -> string?,
		JSONAttributeValue._decode :: (string?) -> T,
		defaultValue
	)
end

function JSONAttributeValue._encode(value: any): string?
	if type(value) == "table" or type(value) == "string" then
		return HttpService:JSONEncode(value)
	else
		return nil
	end
end

function JSONAttributeValue._decode(value: any): any
	if type(value) == "string" then
		return HttpService:JSONDecode(value)
	else
		return nil
	end
end

return JSONAttributeValue
