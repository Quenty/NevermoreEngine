--[=[
	Proxies a property in Roblox

	@class PropertyValue
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")

local DEFAULT_PREDICATE = function(value)
	return value
end

local PropertyValue = {}
PropertyValue.ClassName = "PropertyValue"
PropertyValue.__index = PropertyValue

function PropertyValue.new(instance, propertyName)
	assert(typeof(instance) == "Instance", "Bad argument 'instance'")
	assert(type(propertyName) == "string", "Bad argument 'propertyName'")

	local self = {}

	self._obj = instance
	self._propertyName = propertyName

	return setmetatable(self, PropertyValue)
end

function PropertyValue:ObserveBrio(condition)
	condition = condition or DEFAULT_PREDICATE
	return RxInstanceUtils.observePropertyBrio(self._obj, self._propertyName, condition)
end

function PropertyValue:Observe()
	return RxInstanceUtils.observeProperty(self._obj, self._propertyName)
end

function PropertyValue:__index(index)
	if index == "Value" then
		return self._obj[self._propertyName]
	elseif index == "Changed" then
		return self._obj:GetPropertyChangedSignal(self._propertyName)
	elseif PropertyValue[index] or index == "_obj" then
		return PropertyValue[index]
	else
		error(("%q is not a member of PropertyValue"):format(tostring(index)))
	end
end

function PropertyValue:__newindex(index, value)
	if index == "Value" then
		self._obj[self._propertyName] = value
	else
		error(("%q is not a member of PropertyValue"):format(tostring(index)))
	end
end


return PropertyValue