--!strict
--[=[
	Allows access to an attribute like a ValueObject.

	```lua
	local attributeValue = AttributeValue.new(workspace, "Version", "1.0.0")
	print(attributeValue.Value) --> 1.0.0
	print(workspace:GetAttribute("version")) --> 1.0.0

	attributeValue.Changed:Connect(function()
		print(attributeValue.Value)
	end)

	workspace:SetAttribute("1.1.0") --> 1.1.0
	attributeValue.Value = "1.2.0" --> 1.2.0
	```

	@class AttributeValue
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")

local AttributeValue = {}
AttributeValue.ClassName = "AttributeValue"

export type AttributeValue<T> = typeof(setmetatable(
	{} :: {
		--[=[
			The current value of the attribute. Can be assigned to to write
			the attribute.
			@prop Value T
			@within AttributeValue
		]=]
		Value: T,

		--[=[
			Name of the attribute being read and written.
			@readonly
			@prop AttributeName string
			@within AttributeValue
		]=]
		AttributeName: string,

		--[=[
			Signal that fires when the attribute changes
			@readonly
			@prop Changed RBXScriptSignal
			@within AttributeValue
		]=]
		Changed: RBXScriptSignal<>,

		_object: Instance,
		_attributeName: string,
		_defaultValue: T?,
	},
	{} :: typeof({ __index = AttributeValue })
))

--[=[
	Constructs a new AttributeValue. If a defaultValue that is not nil
	is defined, then this value will be set on the Roblox object.

	@param object Instance
	@param attributeName string
	@param defaultValue T?
	@return AttributeValue<T>
]=]
function AttributeValue.new<T>(object: Instance, attributeName: string, defaultValue: T?): AttributeValue<T>
	assert(typeof(object) == "Instance", "Bad object")
	assert(type(attributeName) == "string", "Bad attributeName")

	local self: AttributeValue<T> = setmetatable(
		{
			_object = object,
			_attributeName = attributeName,
			_defaultValue = defaultValue,
		} :: any,
		AttributeValue
	)

	if defaultValue ~= nil and object:GetAttribute(attributeName) == nil then
		object:SetAttribute(attributeName, defaultValue :: any)
	end

	return self
end

--[=[
	Handles observing the value conditionally

	@param condition ((T) -> boolean)?
	@return Observable<Brio<T>>
]=]
function AttributeValue.ObserveBrio<T>(
	self: AttributeValue<T>,
	condition: Rx.Predicate<T>?
): Observable.Observable<Brio.Brio<T>>
	return RxAttributeUtils.observeAttributeBrio(self._object, self._attributeName, condition)
end

--[=[
	Observes an attribute on an instance, falling back to the default value
	whenever the attribute is not set.

	@return Observable<T>
]=]
function AttributeValue.Observe<T>(self: AttributeValue<T>): Observable.Observable<T>
	-- rawget since the key is absent whenever the default is nil, and __index errors on unknown members
	local defaultValue = rawget(self :: any, "_defaultValue") :: T?

	return RxAttributeUtils.observeAttribute(self._object, self._attributeName, defaultValue) :: any
end

function AttributeValue:__index(index)
	if AttributeValue[index] then
		return AttributeValue[index]
	elseif index == "Value" then
		local object = rawget(self :: any, "_object") :: Instance
		local result = object:GetAttribute(rawget(self :: any, "_attributeName") :: string)
		if result == nil then
			return rawget(self :: any, "_defaultValue")
		else
			return result
		end
	elseif index == "Changed" then
		local object = rawget(self :: any, "_object") :: Instance
		return object:GetAttributeChangedSignal(rawget(self :: any, "_attributeName") :: string)
	elseif index == "AttributeName" then
		return rawget(self :: any, "_attributeName")
	else
		error(string.format("%q is not a member of AttributeValue", tostring(index)))
	end
end

function AttributeValue:__newindex(index, value)
	if index == "Value" then
		local object = rawget(self :: any, "_object") :: Instance
		object:SetAttribute(rawget(self :: any, "_attributeName") :: string, value)
	elseif index == "AttributeName" then
		error("Cannot set AttributeName")
	else
		error(string.format("%q is not a member of AttributeValue", tostring(index)))
	end
end

return AttributeValue
