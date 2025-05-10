--!strict
--[=[
	@class RxValueBaseUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxValueBaseUtils = {}

--[=[
	Observes a value base underneath a parent (last named child).

	@param parent Instance
	@param className string
	@param name string
	@param predicate callback -- Optional callback
	@return Observable<Brio<any>>
]=]
function RxValueBaseUtils.observeBrio(
	parent: Instance,
	className: string,
	name: string,
	predicate: Rx.Predicate<any>?
): Observable.Observable<Brio.Brio<any>>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad naem")

	return RxInstanceUtils.observeLastNamedChildBrio(parent, className, name):Pipe({
		RxBrioUtils.switchMapBrio(RxValueBaseUtils.observeValue) :: any,
		RxBrioUtils.onlyLastBrioSurvives() :: any,
		if predicate then RxBrioUtils.where(predicate) :: any else nil :: never,
	}) :: any
end

--[=[
	Observes a value base underneath a parent

	@param parent Instance
	@param className string
	@param name string
	@param defaultValue any
	@return Observable<any>
]=]
function RxValueBaseUtils.observe(
	parent: Instance,
	className: string,
	name: string,
	defaultValue: any?
): Observable.Observable<any>
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return RxValueBaseUtils.observeBrio(parent, className, name):Pipe({
		RxBrioUtils.emitOnDeath(defaultValue) :: any,
	}) :: any
end

--[=[
	Observables a given value object's value
	@param valueObject Instance
	@return Observable<T>
]=]
function RxValueBaseUtils.observeValue(valueObject: ValueBase): Observable.Observable<any>
	assert(typeof(valueObject) == "Instance", "Bad valueObject")

	return RxInstanceUtils.observeProperty(valueObject, "Value")
end

return RxValueBaseUtils
