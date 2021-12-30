--[=[
	Utility methods to observe bound objects on instances. This is what makes the Rx library with
	binders really good.

	:::info
	Using this API, you can query most game-state in very efficient ways, and react to the world
	changing in real-time. This makes programming streaming and other APIs really nice.
	:::

	@class RxBinderUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxLinkUtils = require("RxLinkUtils")

local RxBinderUtils = {}

--[=[
	Observes a structure where a parent has object values with linked objects (for example), maybe
	an AI has a list of linked objectvalue tasks to execute.

	@param linkName string
	@param parent Instance
	@param binder Binder<T>
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeLinkedBoundClassBrio(linkName, parent, binder)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(Binder.isBinder(binder), "Bad binder")

	return RxLinkUtils.observeValidLinksBrio(linkName, parent)
		:Pipe({
			RxBrioUtils.flatMap(function(_, linkValue)
				return RxBinderUtils.observeBoundClassBrio(binder, linkValue)
			end);
		});
end

--[=[
	Observes bound children classes.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeBoundChildClassBrio(binder, instance)
	assert(Binder.isBinder(binder), "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassBrio(binder, child)
			end);
		})
end

--[=[
	Observes ainstance's parent class that is bound.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeBoundParentClassBrio(binder, instance)
	assert(Binder.isBinder(binder), "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

	return RxInstanceUtils.observePropertyBrio(instance, "Parent")
		:Pipe({
			RxBrioUtils.switchMap(function(child)
				if child then
					return RxBinderUtils.observeBoundClassBrio(binder, child)
				else
					return Rx.EMPTY
				end
			end);
		})
end

--[=[
	Observes all bound classes that hit that list of binders

	@param binders { Binder<T> }
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeBoundChildClassesBrio(binders, instance)
	assert(Binder.isBinder(binders), "Bad binders")
	assert(typeof(instance) == "Instance", "Bad instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassesBrio(binders, child)
			end);
		})
end

--[=[
	Observes a bound class on a given instance.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<T?>
]=]
function RxBinderUtils.observeBoundClass(binder, instance)
	assert(type(binder) == "table", "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(binder:ObserveInstance(instance, function(...)
			sub:Fire(...)
		end))
		sub:Fire(binder:Get(instance))

		return maid
	end)
end

--[=[
	Observes a bound class on a given instance.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeBoundClassBrio(binder, instance)
	assert(type(binder) == "table", "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleClassChanged(class)
			if class then
				local brio = Brio.new(class)
				maid._lastBrio = brio

				sub:Fire(brio)
			else
				maid._lastBrio = nil
			end
		end

		maid:GiveTask(binder:ObserveInstance(instance, handleClassChanged))
		handleClassChanged(binder:Get(instance))

		return maid
	end)
end

--[=[
	Observes all bound classes for a given binder.

	@param binders { Binder<T> }
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeBoundClassesBrio(binders, instance)
	assert(Binder.isBinder(binders), "Bad binders")
	assert(typeof(instance) == "Instance", "Bad instance")

	local observables = {}

	for _, binder in pairs(binders) do
		table.insert(observables, RxBinderUtils.observeBoundClassBrio(binder, instance))
	end

	return Rx.of(unpack(observables)):Pipe({
		Rx.mergeAll();
	})
end

--[=[
	Observes all instances bound to a given binder.

	@param binder Binder
	@return Observable<Brio<T>>
]=]
function RxBinderUtils.observeAllBrio(binder)
	assert(Binder.isBinder(binder), "Bad binder")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleNewClass(class)
			local brio = Brio.new(class)
			maid[class] = brio

			sub:Fire(brio)
		end

		maid:GiveTask(binder:GetClassAddedSignal():Connect(handleNewClass))
		maid:GiveTask(binder:GetClassRemovingSignal():Connect(function(class)
			maid[class] = nil
		end))

		for class, _ in pairs(binder:GetAllSet()) do
			handleNewClass(class)
		end

		return maid
	end)
end

return RxBinderUtils