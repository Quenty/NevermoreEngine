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
AttributeValue.__index = AttributeValue

export type AttributeValue<T> = typeof(setmetatable(
	{} :: {
		_object: Instance,
		_attributeName: string,
		_defaultValue: T,

		-- Public
		Value: T,
		AttributeName: string,
		Changed: RBXScriptSignal<(T)>,
	},
	{} :: typeof({ __index = AttributeValue })
))

--[=[
	Constructs a new AttributeValue. If a defaultValue that is not nil
	is defined, then this value will be set on the Roblox object.

	@param object Instance
	@param attributeName string
	@param defaultValue T
	@return AttributeValue<T>
]=]
function AttributeValue.new<T>(object: Instance, attributeName: string, defaultValue: T): AttributeValue<T>
	assert(typeof(object) == "Instance", "Bad object")
	assert(type(attributeName) == "string", "Bad attributeName")

	local self = {
		_object = object,
		_attributeName = attributeName,
		_defaultValue = defaultValue,
	}

	if defaultValue ~= nil and self._object:GetAttribute(self._attributeName) == nil then
		self._object:SetAttribute(rawget(self, "_attributeName"), defaultValue)
	end

	return setmetatable(self, AttributeValue) :: any
end

--[=[
	Handles observing the value conditionalli

	@param condition function | nil
	@return Observable<Brio<any>>
]=]
function AttributeValue.ObserveBrio<T>(
	self: AttributeValue<T>,
	condition: Rx.Predicate<T>?
): Observable.Observable<Brio.Brio<any>>
	return RxAttributeUtils.observeAttributeBrio(self._object, self._attributeName, condition)
end

--[=[
	Observes an attribute on an instance.
	@return Observable<any>
]=]
function AttributeValue.Observe<T>(self: AttributeValue<T>): Observable.Observable<T>
	return RxAttributeUtils.observeAttribute(self._object, self._attributeName, rawget(self :: any, "_defaultValue"))
end

--[=[
	The current property of the Attribute. Can be assigned to to write
	the attribute.
	@prop Value T
	@within AttributeValue
]=]

--[=[
	Signal that fires when the attribute changes
	@readonly
	@prop Changed Signal<()>
	@within AttributeValue
]=]
function AttributeValue.__index<T>(self: AttributeValue<T>, index)
	if AttributeValue[index] then
		return AttributeValue[index]
	elseif index == "Value" then
		local result = self._object:GetAttribute(rawget(self :: any, "_attributeName"))
		local default = rawget(self :: any, "_defaultValue")
		if result == nil then
			return default
		else
			return result
		end
	elseif index == "Changed" then
		return self._object:GetAttributeChangedSignal(self._attributeName)
	elseif index == "AttributeName" then
		return rawget(self :: any, "_attributeName")
	else
		error(string.format("%q is not a member of AttributeValue", tostring(index)))
	end
end

function AttributeValue.__newindex<T>(self: AttributeValue<T>, index, value)
	if index == "Value" then
		self._object:SetAttribute(rawget(self :: any, "_attributeName"), value)
	elseif index == "AttributeName" then
		error("Cannot set AttributeName")
	else
		error(string.format("%q is not a member of AttributeValue", tostring(index)))
	end
end

return AttributeValue
