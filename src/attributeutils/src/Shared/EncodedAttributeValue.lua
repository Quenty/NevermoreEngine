--!strict
--[=[
	Allows access to an attribute like a ValueObject, but also encoded or decoded

	@class EncodedAttributeValue
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")

local EncodedAttributeValue = {}
EncodedAttributeValue.ClassName = "EncodedAttributeValue"

export type EncodedAttributeValue<TEncoded, TValue> = typeof(setmetatable(
	{} :: {
		--[=[
			The current value of the attribute, decoded. Can be assigned to to write
			the attribute.
			@prop Value TValue
			@within EncodedAttributeValue
		]=]
		Value: TValue,

		--[=[
			Name of the attribute being read and written.
			@readonly
			@prop AttributeName string
			@within EncodedAttributeValue
		]=]
		AttributeName: string,

		--[=[
			Signal that fires when the attribute changes
			@readonly
			@prop Changed RBXScriptSignal
			@within EncodedAttributeValue
		]=]
		Changed: RBXScriptSignal<>,

		_object: Instance,
		_attributeName: string,
		_encode: (TValue) -> TEncoded,
		_decode: (TEncoded) -> TValue,
		-- Kept, not merely written below: Value and Observe both fall back to it whenever the attribute is
		-- absent, which is any time it is cleared after construction.
		_defaultValue: TValue?,
	},
	{} :: typeof({ __index = EncodedAttributeValue })
))

--[=[
	Constructs a new EncodedAttributeValue. If a defaultValue that is not nil
	is defined, then this value will be set on the Roblox object.

	@param object Instance
	@param attributeName string
	@param encode (TValue) -> TEncoded
	@param decode (TEncoded) -> TValue
	@param defaultValue TValue?
	@return EncodedAttributeValue<TEncoded, TValue>
]=]
function EncodedAttributeValue.new<TEncoded, TValue>(
	object: Instance,
	attributeName: string,
	encode: (TValue) -> TEncoded,
	decode: (TEncoded) -> TValue,
	defaultValue: TValue?
): EncodedAttributeValue<TEncoded, TValue>
	assert(typeof(object) == "Instance", "Bad object")
	assert(type(attributeName) == "string", "Bad attributeName")
	assert(type(decode) == "function", "Bad decode")
	assert(type(encode) == "function", "Bad encode")

	local self: EncodedAttributeValue<TEncoded, TValue> = setmetatable(
		{
			_object = object,
			_attributeName = attributeName,
			_decode = decode,
			_encode = encode,
			_defaultValue = defaultValue,
		} :: any,
		EncodedAttributeValue
	)

	if defaultValue ~= nil and object:GetAttribute(attributeName) == nil then
		object:SetAttribute(attributeName, encode(defaultValue) :: any)
	end

	return self
end

--[=[
	Handles observing the value conditionally. The condition runs against the
	encoded attribute value, before it is decoded.

	@param condition ((TEncoded) -> boolean)?
	@return Observable<Brio<TValue>>
]=]
function EncodedAttributeValue.ObserveBrio<TEncoded, TValue>(
	self: EncodedAttributeValue<TEncoded, TValue>,
	condition: Rx.Predicate<TEncoded>?
): Observable.Observable<Brio.Brio<TValue>>
	return RxAttributeUtils.observeAttributeBrio(self._object, self._attributeName, condition):Pipe({
		RxBrioUtils.map(self._decode) :: any,
	}) :: any
end

--[=[
	Observes the decoded attribute on an instance, falling back to the default
	value whenever the attribute is not set.

	@return Observable<TValue>
]=]
function EncodedAttributeValue.Observe<TEncoded, TValue>(self: EncodedAttributeValue<TEncoded, TValue>): Observable.Observable<TValue>
	local decode = self._decode
	-- rawget since the key is absent whenever the default is nil, and __index errors on unknown members
	local defaultValue = rawget(self :: any, "_defaultValue") :: TValue?

	return RxAttributeUtils.observeAttribute(self._object, self._attributeName, nil):Pipe({
		Rx.map(function(value: TEncoded?): TValue?
			if value == nil then
				return defaultValue
			else
				return decode(value :: TEncoded)
			end
		end) :: any,
	}) :: any
end

function EncodedAttributeValue:__index(index)
	if EncodedAttributeValue[index] then
		return EncodedAttributeValue[index]
	elseif index == "Value" then
		local object = rawget(self :: any, "_object") :: Instance
		local result = object:GetAttribute(rawget(self :: any, "_attributeName") :: string)
		if result == nil then
			return rawget(self :: any, "_defaultValue")
		else
			local decode = rawget(self :: any, "_decode") :: (any) -> any
			return decode(result)
		end
	elseif index == "Changed" then
		local object = rawget(self :: any, "_object") :: Instance
		return object:GetAttributeChangedSignal(rawget(self :: any, "_attributeName") :: string)
	elseif index == "AttributeName" then
		return rawget(self :: any, "_attributeName")
	else
		error(string.format("%q is not a member of EncodedAttributeValue", tostring(index)))
	end
end

function EncodedAttributeValue:__newindex(index, value)
	if index == "Value" then
		local object = rawget(self :: any, "_object") :: Instance
		local encode = rawget(self :: any, "_encode") :: (any) -> any
		object:SetAttribute(rawget(self :: any, "_attributeName") :: string, encode(value))
	elseif index == "AttributeName" then
		error("Cannot set AttributeName")
	else
		error(string.format("%q is not a member of EncodedAttributeValue", tostring(index)))
	end
end

return EncodedAttributeValue
