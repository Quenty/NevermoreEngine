--[=[
	Allows access to an attribute like a ValueObject, but also encoded or decoded

	@class EncodedAttributeValue
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")

local EncodedAttributeValue = {}
EncodedAttributeValue.ClassName = "EncodedAttributeValue"
EncodedAttributeValue.__index = EncodedAttributeValue

--[=[
	Constructs a new EncodedAttributeValue. If a defaultValue that is not nil
	is defined, then this value will be set on the Roblox object.

	@param object Instance
	@param attributeName string
	@param encode (TValue) -> T
	@param decode (T) -> TValue
	@param defaultValue T?
	@return EncodedAttributeValue<T, TValue>
]=]
function EncodedAttributeValue.new(object: Instance, attributeName: string, encode, decode, defaultValue)
	assert(typeof(object) == "Instance", "Bad object")
	assert(type(attributeName) == "string", "Bad attributeName")
	assert(type(decode) == "function", "Bad decode")
	assert(type(encode) == "function", "Bad encode")

	local self = {
		_object = object,
		_attributeName = attributeName,
		_decode = decode,
		_encode = encode,
	}

	if defaultValue ~= nil and self._object:GetAttribute(self._attributeName) == nil then
		self._object:SetAttribute(rawget(self, "_attributeName"), encode(defaultValue))
	end
	return setmetatable(self, EncodedAttributeValue)
end

--[=[
	Handles observing the value conditionalli

	@param condition function | nil
	@return Observable<Brio<any>>
]=]
function EncodedAttributeValue:ObserveBrio(condition)
	return RxAttributeUtils.observeAttributeBrio(self._object, self._attributeName, condition):Pipe({
		RxBrioUtils.map(rawget(self, "_decode")),
	})
end

--[=[
	Observes an attribute on an instance.
	@return Observable<any>
]=]
function EncodedAttributeValue:Observe()
	return RxAttributeUtils.observeAttribute(self._object, self._attributeName, rawget(self, "_defaultValue")):Pipe({
		Rx.map(rawget(self, "_decode")),
	})
end

--[=[
	The current property of the Attribute. Can be assigned to to write
	the attribute.
	@prop Value T
	@within EncodedAttributeValue
]=]

--[=[
	Signal that fires when the attribute changes
	@readonly
	@prop Changed Signal<()>
	@within EncodedAttributeValue
]=]
function EncodedAttributeValue:__index(index)
	if EncodedAttributeValue[index] then
		return EncodedAttributeValue[index]
	elseif index == "Value" then
		local result = self._object:GetAttribute(rawget(self, "_attributeName"))
		local default = rawget(self, "_defaultValue")
		if result == nil then
			return default
		else
			local decode = rawget(self, "_decode")
			return decode(result)
		end
	elseif index == "Changed" then
		return self._object:GetAttributeChangedSignal(self._attributeName)
	elseif index == "AttributeName" then
		return rawget(self, "_attributeName")
	else
		error(string.format("%q is not a member of EncodedAttributeValue", tostring(index)))
	end
end

function EncodedAttributeValue:__newindex(index, value)
	if index == "Value" then
		local encode = rawget(self, "_encode")
		self._object:SetAttribute(rawget(self, "_attributeName"), encode(value))
	else
		error(string.format("%q is not a member of EncodedAttributeValue", tostring(index)))
	end
end

return EncodedAttributeValue
