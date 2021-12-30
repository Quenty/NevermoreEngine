--[=[
	Utility functions involving brios and rx. Brios encapsulate the lifetime of resources,
	which could be expired by the time a subscription occurs. These functions allow us to
	manipulate the state of these at a higher order.

	@class RxBrioUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local BrioUtils = require("BrioUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")

local RxBrioUtils = {}

--[=[
	Takes a result and converts it to a brio if it is not one.

	@return (source: Observable<Brio<T> | T>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.toBrio()
	return Rx.map(function(result)
		if Brio.isBrio(result) then
			return result
		end

		return Brio.new(result)
	end)
end

--[=[
	Completes the observable on death

	@param brio Brio
	@param observable Observable<T>
	@return Observable<T>
]=]
function RxBrioUtils.completeOnDeath(brio, observable)
	assert(Brio.isBrio(brio))
	assert(Observable.isObservable(observable))

	return Observable.new(function(sub)
		if brio:IsDead() then
			sub:Complete()
			return
		end

		local maid = brio:ToMaid()

		maid:GiveTask(function()
			sub:Complete()
		end)
		maid:GiveTask(observable:Subscribe(sub:GetFireFailComplete()))

		return maid
	end)
end

--[=[
	Whenever all returned brios are dead, emits this value wrapped
	in a brio.

	@param valueToEmitWhileAllDead T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtils.emitWhileAllDead(valueToEmitWhileAllDead)
	return function(source)
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local subscribed = true
			topMaid:GiveTask(function()
				subscribed = false
			end)
			local aliveBrios = {}
			local fired = false

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtils.aliveOnly(aliveBrios)
				if next(aliveBrios) then
					topMaid._lastBrio = nil
				else
					local newBrio = Brio.new(valueToEmitWhileAllDead)
					topMaid._lastBrio = newBrio
					sub:Fire(newBrio)
				end

				fired = true
			end

			local function handleNewBrio(brio)
				-- Could happen due to throttle or delay...
				if brio:IsDead() then
					return
				end

				local maid = Maid.new()
				topMaid[maid] = maid -- Use maid as key so it's unique (reemitted brio)

				maid:GiveTask(function() -- GC properly
					topMaid[maid] = nil
					updateBrios()
				end)
				maid:GiveTask(brio:GetDiedSignal():Connect(function()
					topMaid[maid] = nil
				end))

				table.insert(aliveBrios, brio)
				updateBrios()
			end

			topMaid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.emitWhileAllDead] - Not a brio, %q"):format(tostring(brio)))
					topMaid._lastBrio = nil
					sub:Fail("Not a brio")
					return
				end

				handleNewBrio(brio)
			end, function(...)
				sub:Fail(...)
			end,
			function(...)
				sub:Complete(...)
			end))

			-- Make sure we emit an empty list if we discover nothing
			if not fired then
				updateBrios()
			end

			return topMaid
		end)
	end
end

--[=[
	This can't be cheap. Consider deeply if you want this or not.

	@param selectFromBrio ((value: T) -> U)?
	@return (source: Observable<Brio<T>>) -> Observable<Brio{U}>
]=]
function RxBrioUtils.reduceToAliveList(selectFromBrio)
	assert(type(selectFromBrio) == "function" or selectFromBrio == nil, "Bad selectFromBrio")

	return function(source)
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local subscribed = true
			topMaid:GiveTask(function()
				subscribed = false
			end)
			local aliveBrios = {}
			local fired = false

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtils.aliveOnly(aliveBrios)
				local values = {}
				if selectFromBrio then
					for _, brio in pairs(aliveBrios) do
						-- Hope for no side effects
						local value = assert(selectFromBrio(brio:GetValue()), "Bad value")
						table.insert(values, value)
					end
				else
					for _, brio in pairs(aliveBrios) do
						local value = assert(brio:GetValue())
						table.insert(values, value)
					end
				end

				local newBrio = BrioUtils.first(aliveBrios, values)
				topMaid._lastBrio = newBrio

				fired = true
				sub:Fire(newBrio)
			end

			local function handleNewBrio(brio)
				-- Could happen due to throttle or delay...
				if brio:IsDead() then
					return
				end

				local maid = Maid.new()
				topMaid[maid] = maid -- Use maid as key so it's unique (reemitted brio)

				maid:GiveTask(function() -- GC properly
					topMaid[maid] = nil
					updateBrios()
				end)
				maid:GiveTask(brio:GetDiedSignal():Connect(function()
					topMaid[maid] = nil
				end))

				table.insert(aliveBrios, brio)
				updateBrios()
			end

			topMaid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.mergeToAliveList] - Not a brio, %q"):format(tostring(brio)))
					topMaid._lastBrio = nil
					sub:Fail("Not a brio")
					return
				end

				handleNewBrio(brio)
			end,
			function(...)
				sub:Fail(...)
			end,
			function(...)
				sub:Complete(...)
			end))

			-- Make sure we emit an empty list if we discover nothing
			if not fired then
				updateBrios()
			end

			return topMaid
		end)
	end
end

--[=[
	Whenever the last brio dies, reemit it as a dead brio

	@return (source Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.reemitLastBrioOnDeath()
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(brio)
				maid._conn = nil

				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.reemitLastBrioOnDeath] - Not a brio, %q"):format(tostring(brio)))
					sub:Fail("Not a brio")
					return
				end

				if brio:IsDead() then
					sub:Fire(brio)
					return
				end

				-- Setup conn!
				maid._conn = brio:GetDiedSignal():Connect(function()
					sub:Fire(brio)
				end)

				sub:Fire(brio)
			end,
			function(...)
				sub:Fail(...)
			end,
			function(...)
				sub:Complete(...)
			end))

			return maid
		end)
	end
end

--[=[
	Unpacks the brio, and then repacks it. Ignored items
	still invalidate the previous brio

	@param predicate (T) -> boolean
	@return (source: Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.filter(predicate)
	assert(type(predicate) == "function", "Bad predicate")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(brio)
				maid._lastBrio = nil

				if Brio.isBrio(brio) then
					if brio:IsDead() then
						return
					end

					if predicate(brio:GetValue()) then
						local newBrio = BrioUtils.clone(brio)
						maid._lastBrio = newBrio
						sub:Fire(newBrio)
					end
				else
					if predicate(brio) then
						local newBrio = Brio.new(brio)
						maid._lastBrio = newBrio
						sub:Fire(newBrio)
					end
				end
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	Flattens all the brios in one brio and combines them. Note that this method leads to
	gaps in the lifetime of the brio.

	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<Brio<{ [any]: T }>>
]=]
function RxBrioUtils.combineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	return Rx.combineLatest(observables)
		:Pipe({
			Rx.map(BrioUtils.flatten);
			RxBrioUtils.onlyLastBrioSurvives();
		})
end

--[=[
	Flat map equivalent for brios

	@param project (value: TBrio) -> TProject
	@param resultSelector ((value: TProject) -> TResult)?
	@return (source: Observable<Brio<TBrio>> -> Observable<Brio<TResult>>)
]=]
function RxBrioUtils.flatMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return Rx.flatMap(RxBrioUtils.mapBrio(project), resultSelector)
end

--[=[
	Switch map but for Brio.

	@param project (value: TBrio) -> TProject
	@param resultSelector ((value: TProject) -> TResult)?
	@return (source: Observable<Brio<TBrio>>) -> Observable<Brio<TResult>>
]=]
function RxBrioUtils.switchMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return Rx.switchMap(RxBrioUtils.mapBrio(project), resultSelector)
end

--[=[
	Works line combineLatest, but allow the transformation of a brio into an observable
	that emits the value, and then nil, on death.

	The issue here is this:

	1. Resources are found with combineLatest()
	2. One resource dies
	3. All resources are invalidated
	4. We still wanted to be able to use most of the resources

	With this method we are able to do this, as we'll re-emit a table with all resoruces
	except the invalidated one.

	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<Brio<{ [any]: T }>>
]=]
function RxBrioUtils.flatCombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	local newObservables = {}
	for key, observable in pairs(observables) do
		if Observable.isObservable(observable) then
			newObservables[key] = RxBrioUtils.flattenToValueAndNil(observable)
		else
			newObservables[key] = observable
		end
	end

	return Rx.combineLatest(newObservables)
end

--[=[
	Takes in a brio and returns an observable that emits the brio, and then completes
	on death.

	@param project (value: TBrio) -> TProject
	@return (brio<TBrio>) -> Brio<TProject>
]=]
function RxBrioUtils.mapBrio(project)
	assert(type(project) == "function", "Bad project")

	return function(brio)
		assert(Brio.isBrio(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.isObservable(observable), "Not an observable")

		return RxBrioUtils.completeOnDeath(brio, observable)
	end
end

--[=[
	Transforms the brio into an observable that emits the initial value of the brio, and then another value on death
	@param brio Brio<T> | T
	@param emitOnDeathValue U
	@return Observable<T | U>
]=]
function RxBrioUtils.toEmitOnDeathObservable(brio, emitOnDeathValue)
	if not Brio.isBrio(brio) then
		return Rx.of(brio)
	else
		return Observable.new(function(sub)
			if brio:IsDead() then
				sub:Fire(emitOnDeathValue)
				sub:Complete()
			else
				sub:Fire(brio:GetValue())

				return brio:GetDiedSignal():Connect(function()
					sub:Fire(emitOnDeathValue)
					sub:Complete()
				end)
			end
		end)
	end
end

--[=[
	Returns a mapping function that emits the given value.

	@param emitOnDeathValue U
	@return (brio: Brio<T> | T) -> Observable<T | U>
]=]
function RxBrioUtils.mapBrioToEmitOnDeathObservable(emitOnDeathValue)
	return function(brio)
		return RxBrioUtils.toEmitOnDeathObservable(brio, emitOnDeathValue)
	end
end

--[=[
	Takes in an observable of brios and returns an observable of the inner values that will also output
	nil if there is no other value for the brio.

	@param emitOnDeathValue U
	@return (source: Observable<Brio<T> | T>) -> Observable<T | U>
]=]
function RxBrioUtils.emitOnDeath(emitOnDeathValue)
	return Rx.switchMap(RxBrioUtils.mapBrioToEmitOnDeathObservable(emitOnDeathValue));
end

--[=[
	Flattens the observable to nil and the value

	@function flattenToValueAndNil
	@param source Observable<Brio<T> | T>
	@return T | nil
	@within RxBrioUtils
]=]
RxBrioUtils.flattenToValueAndNil = RxBrioUtils.emitOnDeath(nil)

--[=[
	Ensures only the last brio survives.

	@return (source Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.onlyLastBrioSurvives()
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.onlyLastBrioSurvives] - Not a brio, %q"):format(tostring(brio)))
					maid._lastBrio = nil
					sub:Fail("Not a brio")
					return
				end

				local wrapperBrio = BrioUtils.clone(brio)
				maid._lastBrio = wrapperBrio

				sub:Fire(wrapperBrio)
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

return RxBrioUtils