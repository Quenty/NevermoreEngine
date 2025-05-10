--!strict
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
	Creates a new observable wrapping the brio with the brio lasting for the lifetime of the observable

	@param callback ((Maid.Maid) -> T) | T
	@return Observable<Brio<T>>
]=]
function RxBrioUtils.ofBrio<T>(callback: ((Maid.Maid) -> T) | T): Observable.Observable<Brio.Brio<T>>
	return Observable.new(function(sub)
		local maid = Maid.new()

		if type(callback) == "function" then
			local brio = maid:Add(Brio.new(callback(maid)))
			sub:Fire(brio)
		else
			local brio = maid:Add(Brio.new(callback))
			sub:Fire(brio)
		end

		return maid
	end) :: any
end

--[=[
	Takes a result and converts it to a brio if it is not one.

	@return (source: Observable<Brio<T> | T>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.toBrio<T>(): Observable.Transformer<(Brio.Brio<T> | T), (Brio.Brio<T>)>
	return Rx.map(function(result)
		if Brio.isBrio(result) then
			return result
		end

		return Brio.new(result)
	end) :: any
end

--[=[
	Same as [Rx.of] but wraps it in a Brio.

	@param ... T
	@return Observable<Brio<T>>
]=]
function RxBrioUtils.of<T...>(...: T...): Observable.Observable<Brio.Brio<T...>>
	return Rx.of(...):Pipe({
		RxBrioUtils.toBrio() :: any,
	}) :: any
end

--[=[
	Completes the observable on death

	@param brio Brio
	@param observable Observable<T>
	@return Observable<T>
]=]
function RxBrioUtils.completeOnDeath<T...>(
	brio: Brio.Brio<...any>,
	observable: Observable.Observable<T...>
): Observable.Observable<T...>
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
					warn(string.format("[RxBrioUtils.emitWhileAllDead] - Not a brio, %q", tostring(brio)))
					topMaid._lastBrio = nil
					sub:Fail("Not a brio")
					return
				end

				handleNewBrio(brio)
			end, function(...)
				sub:Fail(...)
			end, function(...)
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
function RxBrioUtils.reduceToAliveList(selectFromBrio: any?)
	assert(type(selectFromBrio) == "function" or selectFromBrio == nil, "Bad selectFromBrio")

	return function(source)
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local subscribed = true
			topMaid:GiveTask(function()
				subscribed = false
			end)
			local aliveBrios: { Brio.Brio<any> } = {}
			local fired = false

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtils.aliveOnly(aliveBrios)
				local values = {}
				if selectFromBrio then
					for _, brio: any in aliveBrios do
						-- Hope for no side effects
						local value = selectFromBrio(brio:GetValue())
						assert(value ~= nil, "Bad value")

						table.insert(values, value)
					end
				else
					for _, brio: any in aliveBrios do
						local value = brio:GetValue()
						assert(value ~= nil, "Bad value")

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
					warn(string.format("[RxBrioUtils.mergeToAliveList] - Not a brio, %q", tostring(brio)))
					topMaid._lastBrio = nil
					sub:Fail("Not a brio")
					return
				end

				handleNewBrio(brio)
			end, function(...)
				sub:Fail(...)
			end, function(...)
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
					warn(string.format("[RxBrioUtils.reemitLastBrioOnDeath] - Not a brio, %q", tostring(brio)))
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
			end, function(...)
				sub:Fail(...)
			end, function(...)
				sub:Complete(...)
			end))

			return maid
		end)
	end
end

--[=[
	Unpacks the brio, and then repacks it. Ignored items
	still invalidate the previous brio

	@since 3.6.0
	@param predicate (T) -> boolean
	@return (source: Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtils.where<T>(predicate: Rx.Predicate<T>)
	assert(type(predicate) == "function", "Bad predicate")
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(brio)
				assert(Brio.isBrio(brio), "Not a brio")
				if brio:IsDead() then
					return
				end

				if predicate(brio:GetValue()) then
					sub:Fire(brio)
				end
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	Same as [RxBrioUtils.where]. Here to keep backwards compatability.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@function filter
	@param predicate (T) -> boolean
	@return (source: Observable<Brio<T>>) -> Observable<Brio<T>>
	@within RxBrioUtils
]=]
RxBrioUtils.filter = RxBrioUtils.where

--[=[
	Flattens all the brios in one brio and combines them. Note that this method leads to
	gaps in the lifetime of the brio.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<Brio<{ [any]: T }>>
]=]
function RxBrioUtils.combineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	warn("[RxBrioUtils.combineLatest] - Deprecated since 3.6.0. Use RxBrioUtils.flatCombineLatest")

	return Rx.combineLatest(observables):Pipe({
		Rx.map(BrioUtils.flatten) :: any,
		RxBrioUtils.onlyLastBrioSurvives() :: any,
	})
end

--[=[
	Flattens all the brios in one brio and combines them, and then switches it to
	a brio so only the last state is valid.

	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@param filter function | nil
	@return Observable<Brio<{ [any]: T }>>
]=]
function RxBrioUtils.flatCombineLatestBrio<T>(observables, filter: Rx.Predicate<T>?)
	assert(type(observables) == "table", "Bad observables")

	return RxBrioUtils.flatCombineLatest(observables):Pipe({
		RxBrioUtils.switchToBrio() :: any,
		filter and RxBrioUtils.where(filter) :: any or nil :: never,
	})
end

--[=[
	Flat map equivalent for brios. The resulting observables will
	be disconnected at the end of the brio.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@return (source: Observable<Brio<TBrio>> -> Observable<TResult>)
]=]
function RxBrioUtils.flatMap(project)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.flatMap] - Deprecated since 3.6.0. Use RxBrioUtils.flatMapBrio")

	return Rx.flatMap(RxBrioUtils.mapBrio(project) :: any)
end

--[=[
	Flat map equivalent for brios. The resulting observables will
	be disconnected at the end of the brio.

	Like [RxBrioUtils.flatMap], but emitted values are wrapped in brios.
	The lifetime of this brio is limited by the lifetime of the
	input brios, which are unwrapped and repackaged.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (source: Observable<Brio<TBrio>> -> Observable<Brio<TResult>>)
]=]
function RxBrioUtils.flatMapBrio(project)
	return Rx.flatMap(RxBrioUtils.mapBrioBrio(project) :: any)
end

--[=[
	Switch map but for brios. The resulting observable will be
	disconnected on the end of the brio's life.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@return (source: Observable<Brio<TBrio>>) -> Observable<TResult>
]=]
function RxBrioUtils.switchMap(project)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.switchMap] - Deprecated since 3.6.0. Use RxBrioUtils.switchMapBrio")

	return Rx.switchMap(RxBrioUtils.mapBrio(project) :: any)
end

--[=[
	Switch map but for brios. The resulting observable will be
	disconnected on the end of the brio's life.

	Like [RxBrioUtils.switchMap] but emitted values are wrapped in brios.
	The lifetime of this brio is limited by the lifetime of the
	input brios, which are unwrapped and repackaged.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (source: Observable<Brio<TBrio>>) -> Observable<Brio<TResult>>
]=]
function RxBrioUtils.switchMapBrio(project)
	assert(type(project) == "function", "Bad project")

	return Rx.switchMap(RxBrioUtils.mapBrioBrio(project) :: any)
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

	@since 3.6.0
	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<{ [any]: T? }>
]=]
function RxBrioUtils.flatCombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	local newObservables = {}
	for key, observable in observables do
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

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@return (brio<TBrio>) -> TProject
]=]
function RxBrioUtils.mapBrio(project)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.mapBrio] - Deprecated since 3.6.0. Use RxBrioUtils.mapBrioBrio")

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
	Prepends the value onto the emitted brio
	@since 3.6.0
	@param ... T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtils.prepend(...)
	local args = table.pack(...)

	return Rx.map(function(brio)
		assert(Brio.isBrio(brio), "Bad brio")

		return BrioUtils.prepend(brio, table.unpack(args, 1, args.n))
	end)
end

--[=[
	Extends the value onto the emitted brio
	@since 3.6.0
	@param ... T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtils.extend(...)
	local args = table.pack(...)

	return Rx.map(function(brio)
		assert(Brio.isBrio(brio), "Bad brio")

		return BrioUtils.extend(brio, table.unpack(args, 1, args.n))
	end)
end

--[=[
	Maps the input brios to the output observables
	@since 3.6.0
	@param project project (Brio<T> | T) -> Brio<U> | U
	@return (source: Observable<Brio<T> | T>) -> Observable<Brio<U>>
]=]
function RxBrioUtils.map(project)
	return Rx.map(function(...)
		local n = select("#", ...)
		local brios = {}
		local args

		if n == 1 then
			if Brio.isBrio(...) then
				table.insert(brios, (...))
				args = (...):GetPackedValues()
			else
				args = { [1] = ... }
			end
		else
			args = {}
			for index, item in { ... } do
				if Brio.isBrio(item) then
					table.insert(brios, item)
					args[index] = item:GetValue() -- we lose data here, but I think this is fine
				else
					args[index] = item
				end
			end
			args.n = n
		end

		local results = table.pack(project(table.unpack(args, 1, args.n)))
		local transformedResults = {}
		for i = 1, results.n do
			local item = results[i]
			if Brio.isBrio(item) then
				table.insert(brios, item) -- add all subsequent brios into this table...
				transformedResults[i] = ((item :: any) :: Brio.Brio<unknown>):GetValue()
			else
				transformedResults[i] = item
			end
		end

		return BrioUtils.first(brios, table.unpack(transformedResults, 1, results.n))
	end)
end

function RxBrioUtils._mapResult(brio)
	return function(...)
		local n = select("#", ...)
		if n == 0 then
			return BrioUtils.withOtherValues(brio)
		elseif n == 1 then
			if Brio.isBrio(...) then
				return BrioUtils.first({ brio, (...) }, (...):GetValue())
			else
				return BrioUtils.withOtherValues(brio, ...)
			end
		else
			local brios = { brio }
			local args = {}

			for index, item in { ... } do
				if Brio.isBrio(item) then
					table.insert(brios, item)
					args[index] = item:GetValue() -- we lose data here, but I think this is fine
				else
					args[index] = item
				end
			end

			return BrioUtils.first(brios, unpack(args, 1, n))
		end
	end
end

--[=[
	Takes in a brio and returns an observable that emits the brio, and then completes
	on death.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (Brio<TBrio>) -> Brio<TProject>
]=]
function RxBrioUtils.mapBrioBrio(project)
	assert(type(project) == "function", "Bad project")

	return function(brio)
		assert(Brio.isBrio(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.isObservable(observable), "Not an observable")

		return RxBrioUtils.completeOnDeath(brio, observable):Pipe({
			Rx.map(RxBrioUtils._mapResult(brio)) :: any,
		}) :: any
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

				return nil
			end

			sub:Fire(brio:GetValue())

			-- Firing killed the subscription
			if not sub:IsPending() then
				return nil
			end

			-- Firing this event actually killed the brio
			if brio:IsDead() then
				sub:Fire(emitOnDeathValue)
				sub:Complete()

				return nil
			end

			return brio:GetDiedSignal():Connect(function()
				sub:Fire(emitOnDeathValue)
				sub:Complete()
			end)
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
	return Rx.switchMap(function(brio)
		return RxBrioUtils.toEmitOnDeathObservable(brio, emitOnDeathValue) :: any
	end)
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
					warn(string.format("[RxBrioUtils.onlyLastBrioSurvives] - Not a brio, %q", tostring(brio)))
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

--[=[
	Switches the result to a brio, and ensures only the last brio lives.

	@since 3.6.0
	@function switchToBrio
	@param predicate ((T) -> boolean)?
	@return (source: Observable<T | Brio<T>>) -> Observable<Brio<T>>
	@within RxBrioUtils
]=]
function RxBrioUtils.switchToBrio<T>(predicate: Rx.Predicate<T>?)
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return function(source)
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			topMaid:GiveTask(source:Subscribe(function(result, ...)
				-- Always kill previous brio first
				topMaid._last = nil

				if Brio.isBrio(result) then
					if result:IsDead() then
						return
					end

					if predicate == nil or predicate(result:GetValue()) then
						local newBrio = BrioUtils.clone(result)
						topMaid._last = newBrio
						sub:Fire(newBrio)
					end
				else
					if predicate == nil or predicate(result, ...) then
						local newBrio = Brio.new(result, ...)
						topMaid._last = newBrio
						sub:Fire(newBrio)
					end
				end
			end, sub:GetFailComplete()))

			return topMaid
		end)
	end
end

return RxBrioUtils
