--[=[
	@class RxValueBaseUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxValueBaseUtils = {}

--[=[
	Observes a value base underneath a parent (last named child).

	@param parent Instance
	@param className string
	@param name string
	@param predicate callback -- Optional callback
	@return Observable<Brio<any>>
]=]
function RxValueBaseUtils.observeBrio(parent, className, name, predicate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad naem")

	return RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(valueObject)
				return RxValueBaseUtils.observeValue(valueObject)
			end),
			RxBrioUtils.onlyLastBrioSurvives(),
			predicate and RxBrioUtils.where(predicate) or nil;
		})
end

--[=[
	Observes a value base underneath a parent

	@param parent Instance
	@param className string
	@param name string
	@param defaultValue any
	@return Observable<any>
]=]
function RxValueBaseUtils.observe(parent, className, name, defaultValue)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return RxValueBaseUtils.observeBrio(parent, className, name)
		:Pipe({
			RxBrioUtils.emitOnDeath(defaultValue)
		})
end


--[=[
	Observables a given value object's value
	@param valueObject Instance
	@return Observable<T>
]=]
function RxValueBaseUtils.observeValue(valueObject)
	return RxInstanceUtils.observeProperty(valueObject, "Value")
end

return RxValueBaseUtils