--[=[
	For when attributes don't work

	@class ValueBaseValue
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxSignal = require("RxSignal")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ValueBaseUtils = require("ValueBaseUtils")

local ValueBaseValue = {}
ValueBaseValue.ClassName = "ValueBaseValue"
ValueBaseValue.__index = ValueBaseValue

export type ValueBaseValue = typeof(setmetatable(
	{} :: {
		_parent: Instance,
		_className: ValueBaseUtils.ValueBaseType,
		_name: string,
		_defaultValue: any?,
		Value: any?,
		Changed: RxSignal.RxSignal<any>,
	},
	{} :: typeof({ __index = ValueBaseValue })
))

--[=[
	Constructs a ValueBaseValue object. This is a wrapper around the value base
	underneath the parent. It will create the value base if it does not exist.

	@param parent Instance
	@param className string
	@param name string
	@param defaultValue any?
	@return ValueBaseValue
]=]
function ValueBaseValue.new(
	parent: Instance,
	className: ValueBaseUtils.ValueBaseType,
	name: string,
	defaultValue: any?
): ValueBaseValue
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

	return setmetatable(self, ValueBaseValue) :: any
end

--[=[
	Observes the value base value. This will return a brio of the value base
	underneath the parent.

	@param predicate ((any) -> boolean)? -- Optional callback
	@return Observable<Brio<any>>
]=]
function ValueBaseValue.ObserveBrio(
	self: ValueBaseValue,
	predicate: Rx.Predicate<any>?
): Observable.Observable<Brio.Brio<any>>
	return RxValueBaseUtils.observeBrio(self._parent, self._className, self._name, predicate)
end

--[=[
	Observes the value base value's

	@return Observable<any>
]=]
function ValueBaseValue.Observe(self: ValueBaseValue): Observable.Observable<any>
	return RxValueBaseUtils.observe(self._parent, self._className, self._name, self._defaultValue)
end

(ValueBaseValue :: any).__index = function(self: any, index)
	if index == "Value" then
		return ValueBaseUtils.getValue(self._parent, self._className, self._name, self._defaultValue)
	elseif index == "Changed" then
		return RxSignal.new(self:Observe():Pipe({
			Rx.skip(1),
		}))
	elseif ValueBaseValue[index] or index == "_defaultValue" then
		return ValueBaseValue[index]
	else
		error(string.format("%q is not a member of ValueBaseValue", tostring(index)))
	end
end

function ValueBaseValue.__newindex(self: ValueBaseValue, index, value)
	if index == "Value" then
		ValueBaseUtils.setValue(self._parent, self._className, self._name, value)
	else
		error(string.format("%q is not a member of ValueBaseValue", tostring(index)))
	end
end

return ValueBaseValue
