--[=[
	Observable rx library for Roblox by Quenty. This provides a variety of
	composition classes to be used, and is the primary entry point for an
	observable.

	Most of these functions return either a function that takes in an
	observable (curried for piping) or an [Observable](/api/Observable)
	directly.

	@class Rx
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Symbol = require("Symbol")
local Table = require("Table")
local ThrottledFunction = require("ThrottledFunction")

local UNSET_VALUE = Symbol.named("unsetValue")

--[=[
	An empty observable that completes immediately
	@prop EMPTY Observable<()>
	@readonly
	@within Rx
]=]

--[=[
	An observable that never completes.
	@prop NEVER Observable<()>
	@readonly
	@within Rx
]=]
local Rx = {
	EMPTY = Observable.new(function(sub)
		sub:Complete()
	end);
	NEVER = Observable.new(function(_)

	end);
}

--[=[
	Pipes the tranformers through each other
	https://rxjs-dev.firebaseapp.com/api/index/function/pipe

	@param transformers { Observable<any> }
	@return (source: Observable<T>) -> Observable<U>
]=]
function Rx.pipe(transformers)
	assert(type(transformers) == "table", "Bad transformers")
	for index, transformer in pairs(transformers) do
		if type(transformer) ~= "function" then
			error(("[Rx.pipe] Bad pipe value of type %q at index %q, expected function")
				:format(type(transformer), tostring(index)))
		end
	end

	return function(source)
		assert(source, "Bad source")

		local current = source
		for key, transformer in pairs(transformers) do
			current = transformer(current)

			if not (type(current) == "table" and current.ClassName == "Observable") then
				error(("[Rx.pipe] - Failed to transform %q in pipe, made %q (%s)")
					:format(tostring(key), tostring(current), tostring(type(current) == "table" and current.ClassName or "")))
			end
		end

		return current
	end
end

--[=[
	http://reactivex.io/documentation/operators/just.html

	```lua
	Rx.of(1, 2, 3):Subscribe(print, function()
		print("Complete")
	end)) --> 1, 2, 3, "Complete"
	```

	@param ... any -- Arguments to emit
	@return Observable
]=]
function Rx.of(...)
	local args = table.pack(...)

	return Observable.new(function(sub)
		for i=1, args.n do
			sub:Fire(args[i])
		end

		sub:Complete()
	end)
end

--[=[
	Converts an item
	http://reactivex.io/documentation/operators/from.html

	@param item Promise | table
	@return Observable
]=]
function Rx.from(item)
	if Promise.isPromise(item) then
		return Rx.fromPromise(item)
	elseif type(item) == "table" then
		return Rx.of(unpack(item))
	else
		-- TODO: Iterator?
		error("[Rx.from] - cannot convert")
	end
end

--[=[
	https://rxjs-dev.firebaseapp.com/api/operators/merge

	@param observables { Observable }
	@return Observable
]=]
function Rx.merge(observables)
	assert(type(observables) == "table", "Bad observables")

	for _, item in pairs(observables) do
		assert(Observable.isObservable(item), "Not an observable")
	end

	return Observable.new(function(sub)
		local maid = Maid.new()

		for _, observable in pairs(observables) do
			maid:GiveTask(observable:Subscribe(sub:GetFireFailComplete()))
		end

		return maid
	end)
end

--[=[
	Converts a Signal into an observable.
	https://rxjs-dev.firebaseapp.com/api/index/function/fromEvent

	@param event Signal<T>
	@return Observable<T>
]=]
function Rx.fromSignal(event)
	return Observable.new(function(sub)
		-- This stream never completes or fails!
		return event:Connect(function(...)
			sub:Fire(...)
		end)
	end)
end

--[=[
	Converts a Promise into an observable.
	https://rxjs-dev.firebaseapp.com/api/index/function/from

	@param promise Promise<T>
	@return Observable<T>
]=]
function Rx.fromPromise(promise)
	assert(Promise.isPromise(promise))

	return Observable.new(function(sub)
		if promise:IsFulfilled() then
			sub:Fire(promise:Wait())
			sub:Complete()
			return nil
		end

		local maid = Maid.new()

		local pending = true
		maid:GiveTask(function()
			pending = false
		end)

		promise:Then(
			function(...)
				if pending then
					sub:Fire(...)
					sub:Complete()
				end
			end,
			function(...)
				if pending then
					sub:Fail(...)
					sub:Complete()
				end
			end)

		return maid
	end)
end

--[=[
	Taps into the observable and executes the onFire/onError/onComplete
	commands.

	https://rxjs-dev.firebaseapp.com/api/operators/tap

	@param onFire function?
	@param onError function?
	@param onComplete function?
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.tap(onFire, onError, onComplete)
	assert(type(onFire) == "function" or onFire == nil, "Bad onFire")
	assert(type(onError) == "function" or onError == nil, "Bad onError")
	assert(type(onComplete) == "function" or onComplete == nil, "Bad onComplete")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(
				function(...)
					if onFire then
						onFire(...)
					end
					sub:Fire(...)
				end,
				function(...)
					if onError then
						onError(...)
					end
					error(...)
				end,
				function(...)
					if onComplete then
						onComplete(...)
					end
					onComplete(...)
				end)
		end)
	end
end

--[=[
	Starts the observable with the given value from the callback

	http://reactivex.io/documentation/operators/start.html

	@param callback function
	@return (source: Observable) -> Observable
]=]
function Rx.start(callback)
	return function(source)
		return Observable.new(function(sub)
			sub:Fire(callback())

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Like start, but also from (list!)

	@param callback () -> { T }
	@return (source: Observable) -> Observable
]=]
function Rx.startFrom(callback)
	assert(type(callback) == "function", "Bad callback")
	return function(source)
		return Observable.new(function(sub)
			for _, value in pairs(callback()) do
				sub:Fire(value)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Starts with the given values
	https://rxjs-dev.firebaseapp.com/api/operators/startWith

	@param values { T }
	@return (source: Observable) -> Observable
]=]
function Rx.startWith(values)
	assert(type(values) == "table", "Bad values")

	return function(source)
		return Observable.new(function(sub)
			for _, item in pairs(values) do
				sub:Fire(item)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Defaults the observable to a value if it isn't fired immediately

	```lua
	Rx.NEVER:Pipe({
		Rx.defaultsTo("Hello")
	}):Subscribe(print) --> Hello
	```

	@param value any
	@return (source: Observable) -> Observable
]=]
function Rx.defaultsTo(value)
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local fired = false

			maid:GiveTask(source:Subscribe(
				function(...)
					fired = true
					sub:Fire(...)
				end,
				sub:GetFailComplete()))

			if not fired then
				sub:Fire(value)
			end

			return maid
		end)
	end
end

--[=[
	Defaults the observable value to nil

	```lua
	Rx.NEVER:Pipe({
		Rx.defaultsToNil
	}):Subscribe(print) --> nil
	```

	Great for defaulting Roblox attributes and objects

	@function defaultsToNil
	@param source Observable
	@return Observable
	@within Rx
]=]
Rx.defaultsToNil = Rx.defaultsTo(nil)

--[=[
	Ends the observable with these values before cancellation
	https://www.learnrxjs.io/learn-rxjs/operators/combination/endwith

	@param values { T }
	@return (source: Observable) -> Observable
]=]
function Rx.endWith(values)
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(
				function(...)
					sub:Fire(...)
				end,
				function(...)
					for _, item in pairs(values) do
						sub:Fire(item)
					end
					sub:Fail(...)
				end),
				function()
					for _, item in pairs(values) do
						sub:Fire(item)
					end
					sub:Complete()
				end)

			return maid
		end)
	end
end

--[=[
	http://reactivex.io/documentation/operators/filter.html

	Filters out values

	```lua
	Rx.of(1, 2, 3, 4, 5):Pipe({
		Rx.where(function(value)
			return value % 2 == 0;
		end)
	}):Subscribe(print) --> 2, 4
	```
	@param predicate (value: T) -> boolean
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.where(predicate)
	assert(type(predicate) == "function", "Bad predicate callback")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(
				function(...)
					if predicate(...) then
						sub:Fire(...)
					end
				end,
				sub:GetFailComplete()
			)
		end)
	end
end

--[=[
	Only takes distinct values from the observable stream.

	http://reactivex.io/documentation/operators/distinct.html

	```lua
	Rx.of(1, 1, 2, 3, 3, 1):Pipe({
		Rx.distinct();
	}):Subscribe(print) --> 1, 2, 3, 1
	```
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.distinct()
	return function(source)
		return Observable.new(function(sub)
			local last = UNSET_VALUE

			return source:Subscribe(
				function(value)
					-- TODO: Support tuples
					if last == value then
						return
					end

					last = value
					sub:Fire(last)
				end,
				sub:GetFailComplete()
			)
		end)
	end
end

--[=[
	https://rxjs.dev/api/operators/mapTo
	@param ... any -- The value to map each source value to.
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.mapTo(...)
	local args = table.pack(...)
	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function()
				sub:Fire(table.unpack(args, 1, args.n))
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	http://reactivex.io/documentation/operators/map.html

	Maps one value to another

	```lua
	Rx.of(1, 2, 3, 4, 5):Pipe({
		Rx.map(function(x)
			return x + 1
		end)
	}):Subscribe(print) -> 2, 3, 4, 5, 6
	```

	@param project (T) -> U
	@return (source: Observable<T>) -> Observable<U>
]=]
function Rx.map(project)
	assert(type(project) == "function", "Bad project callback")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function(...)
				sub:Fire(project(...))
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Merges higher order observables together.

	Basically, if you have an observable that is emitting an observable,
	this subscribes to each emitted observable and combines them into a
	single observable.

	```lua
	Rx.of(Rx.of(1, 2, 3), Rx.of(4))
		:Pipe({
			Rx.mergeAll();
		})
		:Subscribe(print) -> 1, 2, 3, 4
	```

	@return (source: Observable<Observable<T>>) -> Observable<T>
]=]
function Rx.mergeAll()
	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local pendingCount = 0
			local topComplete = false

			maid:GiveTask(source:Subscribe(
				function(observable)
					assert(Observable.isObservable(observable), "Not an observable")

					pendingCount = pendingCount + 1

					local innerMaid = Maid.new()

					innerMaid:GiveTask(observable:Subscribe(
						function(...)
							-- Merge each inner observable
							sub:Fire(...)
						end,
						function(...)
							-- Emit failure automatically
							sub:Fail(...)
						end,
						function()
							innerMaid:DoCleaning()
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								sub:Complete()
								maid:DoCleaning()
							end
						end))

					local key = maid:GiveTask(innerMaid)

					-- Cleanup
					innerMaid:GiveTask(function()
						maid[key] = nil
					end)
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					maid:DoCleaning()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						sub:Complete()
						maid:DoCleaning()
					end
				end))

			return maid
		end)
	end
end

--[=[
	Merges higher order observables together

	https://rxjs.dev/api/operators/switchAll

	Works like mergeAll, where you subscribe to an observable which is
	emitting observables. However, when another observable is emitted it
	disconnects from the other observable and subscribes to that one.

	@return (source: Observable<Observable<T>>) -> Observable<T>
]=]
function Rx.switchAll()
	return function(source)
		return Observable.new(function(sub)
			local outerMaid = Maid.new()
			local topComplete = false
			local insideComplete = false
			local currentInside = nil

			outerMaid:GiveTask(source:Subscribe(
				function(observable)
					assert(Observable.isObservable(observable))

					insideComplete = false
					currentInside = observable
					outerMaid._current = nil

					local maid = Maid.new()
					maid:GiveTask(observable:Subscribe(
						function(...)
							sub:Fire(...)
						end, -- Merge each inner observable
						function(...)
							if currentInside == observable then
								sub:Fail(...)
							end
						end, -- Emit failure automatically
						function()
							if currentInside == observable then
								insideComplete = true
								if insideComplete and topComplete then
									sub:Complete()
									outerMaid:DoCleaning()
								end
							end
						end))

					outerMaid._current = maid
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					outerMaid:DoCleaning()
				end,
				function()
					topComplete = true
					if insideComplete and topComplete then
						sub:Complete()
						outerMaid:DoCleaning()
					end
				end))

			return outerMaid
		end)
	end
end

--[=[
	Sort of equivalent of promise.then()

	This takes a stream of observables

	@param project (value: T) -> Observable<U>
	@param resultSelector ((value: T) -> U)?
	@return (source: Observable<T>) -> Observable<U>
]=]
function Rx.flatMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local pendingCount = 0
			local topComplete = false

			maid:GiveTask(source:Subscribe(
				function(...)
					local outerValue = ...

					local observable = project(...)
					assert(Observable.isObservable(observable), "Bad observable from project")

					pendingCount = pendingCount + 1

					local innerMaid = Maid.new()

					innerMaid:GiveTask(observable:Subscribe(
						function(...)
							-- Merge each inner observable
							if resultSelector then
								sub:Fire(resultSelector(outerValue, ...))
							else
								sub:Fire(...)
							end
						end,
						function(...)
							sub:Fail(...)
						end, -- Emit failure automatically
						function()
							innerMaid:DoCleaning()
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								sub:Complete()
								maid:DoCleaning()
							end
						end))

					local key = maid:GiveTask(innerMaid)

					-- Cleanup
					innerMaid:GiveTask(function()
						maid[key] = nil
					end)
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					maid:DoCleaning()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						sub:Complete()
						maid:DoCleaning()
					end
				end))

			return maid
		end)
	end
end

function Rx.switchMap(project)
	return Rx.pipe({
		Rx.map(project);
		Rx.switchAll();
	})
end

function Rx.takeUntil(notifier)
	assert(Observable.isObservable(notifier))

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()
			local cancelled = false

			local function cancel()
				maid:DoCleaning()
				cancelled = true
			end

			-- Any value emitted will cancel (complete without any values allows all values to pass)
			maid:GiveTask(notifier:Subscribe(cancel, cancel, nil))

			-- Cancelled immediately? Oh boy.
			if cancelled then
				maid:DoCleaning()
				return nil
			end

			-- Subscribe!
			maid:GiveTask(source:Subscribe(sub:GetFireFailComplete()))

			return maid
		end)
	end
end

--[=[
	Returns an observable that takes in a tuple, and emits that tuple, then
	completes.

	```lua
	Rx.packed("a", "b")
		:Subscribe(function(first, second)
			print(first, second) --> a, b
		end)
	```

	@param ... any
	@return Observable
]=]
function Rx.packed(...)
	local args = table.pack(...)

	return Observable.new(function(sub)
		sub:Fire(unpack(args, 1, args.n))
		sub:Complete()
	end)
end

--[=[
	Unpacks the observables value if a table is received
	@param observable Observable<{T}>
	@return Observable<T>
]=]
function Rx.unpacked(observable)
	assert(Observable.isObservable(observable))

	return Observable.new(function(sub)
		return observable:Subscribe(function(value)
			if type(value) == "table" then
				sub:Fire(unpack(value))
			else
				warn(("[Rx.unpacked] - Observable didn't return a table got type %q")
					:format(type(value)))
			end
		end, sub:GetFailComplete())
	end)
end

--[=[
	Acts as a finalizer callback once the subscription is unsubscribed.

	```lua
		Rx.of("a", "b"):Pipe({
			Rx.finalize(function()
				print("Subscription done!")
			end);
		})
	```

	http://reactivex.io/documentation/operators/do.html
	https://rxjs-dev.firebaseapp.com/api/operators/finalize
	https://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts

	@param finalizerCallback () -> ()
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.finalize(finalizerCallback)
	assert(type(finalizerCallback) == "function", "Bad finalizerCallback")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(sub:GetFireFailComplete()))
			maid:GiveTask(finalizerCallback)

			return maid
		end)
	end
end

--[=[
	Given an observable that emits observables, emit an
	observable that once the initial observable completes,
	the latest values of each emitted observable will be
	combined into an array that will be emitted.

	https://rxjs.dev/api/operators/combineLatestAll

	@return (source: Observable<Observable<T>>) -> Observable<{ T }>
]=]
function Rx.combineLatestAll()
	return function(source)
		return Observable.new(function(sub)
			local observables = {}
			local maid = Maid.new()

			local alive = true
			maid:GiveTask(function()
				alive = false
			end)

			maid:GiveTask(source:Subscribe(
				function(value)
					assert(Observable.isObservable(value))

					table.insert(observables, value)
				end,
				function(...)
					sub:Fail(...)
				end),
				function()
					if not alive then
						return
					end

					maid:GiveTask(Rx.combineLatest(observables))
						:Subscribe(sub:GetFireFailComplete())
				end)

			return maid
		end)
	end
end

--[=[
	The same as combineLatestAll.

	This is for backwards compatability, and is deprecated.

	@function combineAll
	@deprecated 1.0.0 -- Use Rx.combineLatestAll
	@within Rx
	@return (source: Observable<Observable<T>>) -> Observable<{ T }>
]=]
Rx.combineAll = Rx.combineLatestAll

--[=[
	Catches an error, and allows another observable to be subscribed
	in terms of handling the error.

	:::warning
	This method is not yet tested
	:::

	@param callback (error: TError) -> Observable<TErrorResult>
	@return (source: Observable<T>) -> Observable<T | TErrorResult>
]=]
function Rx.catchError(callback)
	assert(type(callback) == "function", "Bad callback")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			-- Yikes, let's hope event ordering is good
			local alive = true
			maid:GiveTask(function()
				alive = false
			end)

			maid:GiveTask(source:Subscribe(
				function(...)
					sub:Fire(...)
				end,
				function(...)
					if not alive then
						-- if we failed because maid was cancelled, then we'll get called here?
						-- I think.
						return
					end

					-- at this point, we can only have one error, so we need to subscribe to the result
					-- and continue the observiable
					local observable = callback(...)
					assert(Observable.isObservable(observable))

					maid:GiveTask(observable:Subscribe(sub:GetFireFailComplete()))
				end,
				function()
					sub:Complete()
				end));

			return maid
		end)
	end
end

--[=[
	One of the most useful functions this combines the latest values of
	observables at each chance!

	```lua
	Rx.combineLatest({
		child = Rx.fromSignal(Workspace.ChildAdded);
		lastChildRemoved = Rx.fromSignal(Workspace.ChildRemoved);
		value = 5;

	}):Subscribe(function(data)
		print(data.child) --> last child
		print(data.lastChildRemoved) --> other value
		print(data.value) --> 5
	end)

	```

	:::tip
	Note that the resulting observable will not emit until all input
	observables are emitted.
	:::

	@param observables { [TKey]: Observable<TEmitted> | TEmitted }
	@return Observable<{ [TKey]: TEmitted }>
]=]
function Rx.combineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	return Observable.new(function(sub)
		local pending = 0

		local latest = {}
		for key, value in pairs(observables) do
			if Observable.isObservable(value) then
				pending = pending + 1
				latest[key] = UNSET_VALUE
			else
				latest[key] = value
			end
		end

		if pending == 0 then
			sub:Fire(latest)
			sub:Complete()
			return
		end

		local maid = Maid.new()

		local function fireIfAllSet()
			for _, value in pairs(latest) do
				if value == UNSET_VALUE then
					return
				end
			end

			sub:Fire(Table.copy(latest))
		end

		for key, observer in pairs(observables) do
			if Observable.isObservable(observer) then
				maid:GiveTask(observer:Subscribe(
					function(value)
						latest[key] = value
						fireIfAllSet()
					end,
					function(...)
						pending = pending - 1
						sub:Fail(...)
					end,
					function()
						pending = pending - 1
						if pending == 0 then
							sub:Complete()
						end
					end))
			end
		end

		return maid
	end)
end

--[=[
	http://reactivex.io/documentation/operators/using.html

	Each time a subscription occurs, the resource is constructed
	and exists for the lifetime of the observation. The observableFactory
	uses the resource for subscription.

	:::note
	Note from Quenty: I haven't found this that useful.
	:::

	@param resourceFactory () -> MaidTask
	@param observableFactory (MaidTask) -> Observable<T>
	@return Observable<T>
]=]
function Rx.using(resourceFactory, observableFactory)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local resource = resourceFactory()
		maid:GiveTask(resource)

		local observable = observableFactory(resource)
		assert(Observable.isObservable(observable))

		maid:GiveTask(observable:Subscribe(sub:GetFireFailComplete()))

		return maid
	end)
end

--[=[
	Takes n entries and then completes the observation.

	https://rxjs.dev/api/operators/take
	@param number number
	@return (source: Observable<T>) -> Observable<T>
]=]
function Rx.take(number)
	assert(type(number) == "number", "Bad number")
	assert(number >= 0, "Bad number")

	return function(source)
		return Observable.new(function(sub)
			if number == 0 then
				sub:Complete()
				return nil
			end

			local taken = 0
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(...)
				if taken >= number then
					warn("[Rx.take] - Still getting values past subscription")
					return
				end


				taken = taken + 1
				sub:Fire(...)

				if taken == number then
					sub:Complete()
				end
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	Defers the subscription and creation of the observable until the
	actual subscription of the observable.

	https://rxjs-dev.firebaseapp.com/api/index/function/defer
	https://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09

	@param observableFactory () -> Observable<T>
	@return Observable<T>
]=]
function Rx.defer(observableFactory)
	return Observable.new(function(sub)
		local observable
		local ok, err = pcall(function()
			observable = observableFactory()
		end)

		if not ok then
			sub:Fail(err)
			return
		end

		if not Observable.isObservable(observable) then
			sub:Fail("Not an observable")
			return
		end

		return observable:Subscribe(sub:GetFireFailComplete())
	end)
end

--[=[
	Honestly, I have not used this one much.

	https://rxjs-dev.firebaseapp.com/api/operators/withLatestFrom
	https://medium.com/js-in-action/rxjs-nosy-combinelatest-vs-selfish-withlatestfrom-a957e1af42bf

	@param inputObservables {Observable<TInput>}
	@return (source: Observable<T>) -> Observable<{T, ...TInput}>
]=]
function Rx.withLatestFrom(inputObservables)
	assert(inputObservables, "Bad inputObservables")

	for _, observable in pairs(inputObservables) do
		assert(Observable.isObservable(observable))
	end

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local latest = {}

			for key, observable in pairs(inputObservables) do
				latest[key] = UNSET_VALUE

				maid:GiveTask(observable:Subscribe(function(value)
					latest[key] = value
				end, nil, nil))
			end

			maid:GiveTask(source:Subscribe(function(value)
				for _, item in pairs(latest) do
					if item == UNSET_VALUE then
						return
					end
				end

				sub:Fire({value, unpack(latest)})
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	https://rxjs-dev.firebaseapp.com/api/operators/scan

	@param accumulator (current: TSeed, value: TInput) -> TResult
	@param seed TSeed
	@return (source: Observable<TInput>) -> Observable<TResult>
]=]
function Rx.scan(accumulator, seed)
	assert(type(accumulator) == "function", "Bad accumulator")

	return function(source)
		return Observable.new(function(sub)
			local current = seed

			return source:Subscribe(function(value)
				current = accumulator(current, value)
				sub:Fire(current)
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Throttles emission of observables.

	https://rxjs-dev.firebaseapp.com/api/operators/debounceTime

	:::note
	Note that on complete, the last item is not included, for now, unlike the existing version in rxjs.
	:::

	@param duration number
	@param throttleConfig { leading = true; trailing = true; }
	@return (source: Observable) -> Observable
]=]
function Rx.throttleTime(duration, throttleConfig)
	assert(type(duration) == "number", "Bad duration")
	assert(type(throttleConfig) == "table" or throttleConfig == nil, "Bad throttleConfig")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local throttledFunction = ThrottledFunction.new(duration, function(...)
				sub:Fire(...)
			end, throttleConfig)

			maid:GiveTask(throttledFunction)
			maid:GiveTask(source:Subscribe(function(...)
				throttledFunction:Call(...)
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

return Rx