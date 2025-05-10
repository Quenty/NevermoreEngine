--!strict
--[=[
	Proxies a property in Roblox

	@class PropertyValue
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local PropertyValue = {}
PropertyValue.ClassName = "PropertyValue"
PropertyValue.__index = PropertyValue

export type PropertyValue<T> = typeof(setmetatable(
	{} :: {
		--[=[
			The value of the property

			@prop Value T
			@within PropertyValue
		]=]
		Value: T,

		--[=[
			The signal that fires when the property changes

			@prop Changed RBXScriptSignal
			@within PropertyValue
		]=]
		Changed: RBXScriptSignal<T>,

		_obj: Instance,
		_propertyName: string,
	},
	{} :: typeof({ __index = PropertyValue })
))

--[=[
	Creates a new PropertyValue

	@param instance Instance
	@param propertyName string
	@return PropertyValue
]=]
function PropertyValue.new<T>(instance: Instance, propertyName: string): PropertyValue<T>
	assert(typeof(instance) == "Instance", "Bad argument 'instance'")
	assert(type(propertyName) == "string", "Bad argument 'propertyName'")

	local self = {}

	self._obj = instance
	self._propertyName = propertyName

	return setmetatable(self :: any, PropertyValue)
end

--[=[
	Observes the property of the object.

	@return Observable<Brio<T>>
]=]
function PropertyValue.ObserveBrio<T>(
	self: PropertyValue<T>,
	condition: Rx.Predicate<T>?
): Observable.Observable<Brio.Brio<T>>
	return RxInstanceUtils.observePropertyBrio(self._obj, self._propertyName, condition)
end

--[=[
	Observes the property of the object.

	@return Observable<any>
]=]
function PropertyValue.Observe<T>(self: PropertyValue<T>): Observable.Observable<any>
	return RxInstanceUtils.observeProperty(self._obj, self._propertyName)
end

(PropertyValue :: any).__index = function<T>(self: PropertyValue<T>, index)
	if index == "Value" then
		return (self._obj :: any)[self._propertyName]
	elseif index == "Changed" then
		return self._obj:GetPropertyChangedSignal(self._propertyName)
	elseif PropertyValue[index] or index == "_obj" then
		return PropertyValue[index]
	else
		error(string.format("%q is not a member of PropertyValue", tostring(index)))
	end
end

function PropertyValue.__newindex<T>(self: PropertyValue<T>, index, value)
	if index == "Value" then
		(self._obj :: any)[self._propertyName] = value
	elseif PropertyValue[index] then
		error(string.format("%q is not writable", tostring(index)))
	else
		error(string.format("%q is not a member of PropertyValue", tostring(index)))
	end
end

return PropertyValue
