--[=[
	For when attributes don't work

	@class ValueBaseValue
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Rx = require("Rx")
local RxSignal = require("RxSignal")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ValueBaseUtils = require("ValueBaseUtils")

local ValueBaseValue = {}
ValueBaseValue.ClassName = "ValueBaseValue"
ValueBaseValue.__index = ValueBaseValue

function ValueBaseValue.new(parent, className, name, defaultValue)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(className) == "string", "Bad argument 'className'")
	assert(type(name) == "string", "Bad argument 'name'")

	local self = {}

	self._parent = parent
	self._name = name
	self._className = className
	self._defaultValue = defaultValue

	-- Initialize on the server
	if RunService:IsServer() then
		ValueBaseUtils.getOrCreateValue(parent, self._className, self._name, self._defaultValue)
	end

	return setmetatable(self, ValueBaseValue)
end

function ValueBaseValue:ObserveBrio(predicate)
	return RxValueBaseUtils.observeBrio(self._parent, self._className, self._name, predicate)
end

function ValueBaseValue:Observe()
	return RxValueBaseUtils.observe(self._parent, self._className, self._name, self._defaultValue)
end

function ValueBaseValue:__index(index)
	if index == "Value" then
		return ValueBaseUtils.getValue(self._parent, self._className, self._name, self._defaultValue)
	elseif index == "Changed" then
		return RxSignal.new(self:Observe():Pipe({
			Rx.skip(1)
		}))
	elseif ValueBaseValue[index] or index == "_defaultValue" then
		return ValueBaseValue[index]
	else
		error(string.format("%q is not a member of ValueBaseValue", tostring(index)))
	end
end

function ValueBaseValue:__newindex(index, value)
	if index == "Value" then
		ValueBaseUtils.setValue(self._parent, self._className, self._name, value)
	else
		error(string.format("%q is not a member of ValueBaseValue", tostring(index)))
	end
end

return ValueBaseValue