--[=[
	@class RxValueBaseUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxValueBaseUtils = {}

--[=[
	:::warning
	This caches the last value seen, and may memory leak.
	:::

	@param parent Instance
	@param className string
	@param name string
	@return Observable<any>
	:::
]=]
-- TODO: Handle default value/nothing there, instead of memory leaking!
function RxValueBaseUtils.observe(parent, className, name)
	warn("[RxValueBaseUtils.observe] - Deprecated since 4.0.0. Use RxValueBaseUtils.observeBrio")

	return RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
		:Pipe({
			RxBrioUtils.switchMap(function(valueObject)
				return RxValueBaseUtils.observeValue(valueObject)
			end)
		})
end

--[=[
	Observes a value base underneath a parent (last named child).

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<any>>
]=]
function RxValueBaseUtils.observeBrio(parent, className, name)
	return RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(valueObject)
				return RxValueBaseUtils.observeValue(valueObject)
			end)
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