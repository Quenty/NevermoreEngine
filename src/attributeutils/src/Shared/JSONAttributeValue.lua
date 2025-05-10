--[=[
	@class JSONAttributeValue
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local BaseObject = require("BaseObject")
local EncodedAttributeValue = require("EncodedAttributeValue")

local JSONAttributeValue = setmetatable({}, BaseObject)
JSONAttributeValue.ClassName = "JSONAttributeValue"
JSONAttributeValue.__index = JSONAttributeValue

--[=[
	Constructs a new JSONAttributeValue
	@param object Instance
	@param attributeName string
	@param defaultValue any
	@return JSONAttributeValue
]=]
function JSONAttributeValue.new(object: Instance, attributeName: string, defaultValue: any)
	return EncodedAttributeValue.new(object, attributeName, function(value)
		if type(value) == "table" or type(value) == "string" then
			return HttpService:JSONEncode(value)
		else
			return nil
		end
	end, function(value)
		if type(value) == "string" then
			return HttpService:JSONDecode(value)
		else
			return nil
		end
	end, defaultValue)
end

return JSONAttributeValue
