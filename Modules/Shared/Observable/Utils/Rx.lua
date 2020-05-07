---
-- @module Rx
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")
local Promise = require("Promise")
local Symbol = require("Symbol")
local Table = require("Table")

local UNSET_VALUE = Symbol.named("unsetValue")

local Rx = {
	EMPTY = Observable.new(function(fire, fail, complete)
		complete()
		return nil
	end);
	NEVER = Observable.new(function(fire, fail, complete)
		return nil
	end);
}

-- https://rxjs-dev.firebaseapp.com/api/index/function/pipe
function Rx.pipe(transformers)
	assert(type(transformers) == "table")
	for index, transformer in pairs(transformers) do
		if type(transformer) ~= "function" then
			error(("[Rx.pipe] Bad pipe value of type %q at index %q, expected function")
				:format(type(transformer), tostring(index)))
		end
	end

	return function(source)
		assert(source)

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

-- http://reactivex.io/documentation/operators/just.html
function Rx.of(...)
	local args = table.pack(...)

	return Observable.new(function(fire, fail, complete)
		for i=1, args.n do
			fire(args[i])
		end

		complete()
	end)
end

-- http://reactivex.io/documentation/operators/from.html
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

-- https://rxjs-dev.firebaseapp.com/api/operators/merge
function Rx.merge(observables)
	assert(type(observables) == "table")

	for _, item in pairs(observables) do
		assert(Observable.isObservable(item), "Not an observable")
	end

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		for _, observable in pairs(observables) do
			maid:GiveTask(observable:Subscribe(fire, fail, complete))
		end

		return maid
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/fromEvent
function Rx.fromSignal(event)
	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()
		-- This stream never completes or fails!
		maid:GiveTask(event:Connect(fire))

		return maid
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/from
function Rx.fromPromise(promise)
	assert(Promise.isPromise(promise))

	return Observable.new(function(fire, fail, complete)
		if promise:IsFulfilled() then
			fire(promise:Wait())
			complete()
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
					fire(...)
					complete()
				end
			end,
			function(...)
				if not pending then
					fail(...)
					complete()
				end
			end)

		return maid
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/operators/tap
function Rx.tap(onFire, onError, onComplete)
	assert(type(onFire) == "function" or onFire == nil)
	assert(type(onError) == "function" or onError == nil)
	assert(type(onComplete) == "function" or onComplete == nil)

	return function(source)
		return Observable.new(function(fire, fail, complete)
			return source:Subscribe(
				function(...)
					if onFire then
						onFire(...)
					end
					fire(...)
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

-- http://reactivex.io/documentation/operators/start.html
function Rx.start(callback)
	return function(source)
		return Observable.new(function(fire, fail, complete)
			fire(callback())

			return source:Subscribe(fire, fail, complete)
		end)
	end
end

-- Like start, but also from (list!)
function Rx.startFrom(callback)
	assert(type(callback) == "function")
	return function(source)
		return Observable.new(function(fire, fail, complete)
			for _, value in pairs(callback()) do
				fire(value)
			end

			return source:Subscribe(fire, fail, complete)
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/startWith
function Rx.startWith(values)
	assert(type(values) == "table")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			for _, item in pairs(values) do
				fire(item)
			end

			return source:Subscribe(fire, fail, complete)
		end)
	end
end

-- https://www.learnrxjs.io/learn-rxjs/operators/combination/endwith
function Rx.endWith(values)
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(
				fire,
				function(...)
					for _, item in pairs(values) do
						fire(item)
					end
					fail(...)
				end),
				function()
					for _, item in pairs(values) do
						fire(item)
					end
					complete()
				end)

			return maid
		end)
	end
end

-- http://reactivex.io/documentation/operators/filter.html
function Rx.where(predicate)
	assert(type(predicate) == "function", "Bad predicate callback")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			return source:Subscribe(
				function(...)
					if predicate(...) then
						fire(...)
					end
				end,
				fail,
				complete
			)
		end)
	end
end

-- https://rxjs.dev/api/operators/mapTo
function Rx.mapTo(...)
	local args = table.pack(...)
	return function(source)
		return Observable.new(function(fire, fail, complete)
			return source:Subscribe(function()
				fire(table.unpack(args, 1, args.n))
			end, fail, complete)
		end)
	end
end

-- http://reactivex.io/documentation/operators/map.html
function Rx.map(project)
	assert(type(project) == "function", "Bad project callback")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			return source:Subscribe(function(...)
				fire(project(...))
			end, fail, complete)
		end)
	end
end

-- Merges higher order observables together
function Rx.mergeAll()
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local maid = Maid.new()

			local pendingCount = 0
			local topComplete = false

			maid:GiveTask(source:Subscribe(
				function(observable)
					assert(Observable.isObservable(observable), "Not an observable")

					pendingCount = pendingCount + 1

					local innerMaid = Maid.new()

					innerMaid:GiveTask(observable:Subscribe(
						fire, -- Merge each inner observable
						fail, -- Emit failure automatically
						function()
							innerMaid:DoCleaning()
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								complete()
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
					fail(...) -- Also reflect failures up to the top!
					maid:DoCleaning()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						complete()
						maid:DoCleaning()
					end
				end))

			return maid
		end)
	end
end

-- Merges higher order observables together
-- https://rxjs.dev/api/operators/switchAll
function Rx.switchAll()
	return function(source)
		return Observable.new(function(fire, fail, complete)
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
						fire, -- Merge each inner observable
						function(...)
							if currentInside == observable then
								fail(...)
							end
						end, -- Emit failure automatically
						function()
							if currentInside == observable then
								insideComplete = true
								if insideComplete and topComplete then
									complete()
									outerMaid:DoCleaning()
								end
							end
						end))

					outerMaid._current = maid
				end,
				function(...)
					fail(...) -- Also reflect failures up to the top!
					outerMaid:DoCleaning()
				end,
				function()
					topComplete = true
					if insideComplete and topComplete then
						complete()
						outerMaid:DoCleaning()
					end
				end))

			return outerMaid
		end)
	end
end

-- Sort of equivalent of promise.then()
function Rx.flatMap(project, resultSelector)
	assert(type(project) == "function")

	return function(source)
		return Observable.new(function(fire, fail, complete)
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
								fire(resultSelector(outerValue, ...))
							else
								fire(...)
							end
						end,
						fail, -- Emit failure automatically
						function()
							innerMaid:DoCleaning()
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								complete()
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
					fail(...) -- Also reflect failures up to the top!
					maid:DoCleaning()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						complete()
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
		return Observable.new(function(fire, fail, complete)
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
			maid:GiveTask(source:Subscribe(fire, fail, complete))

			return maid
		end)
	end
end

function Rx.packed(...)
	local args = table.pack(...)

	return Observable.new(function(fire, fail, complete)
		fire(unpack(args, 1, args.n))
		complete()
	end)
end

function Rx.unpacked(observable)
	assert(Observable.isObservable(observable))

	return Observable.new(function(fire, fail, complete)
		return observable:Subscribe(function(value)
			if type(value) == "table" then
				fire(unpack(value))
			else
				warn(("[Rx.unpacked] - Observable didn't return a table got type %q")
					:format(type(value)))
			end
		end, fail, complete)
	end)
end

-- http://reactivex.io/documentation/operators/do.html
-- https://rxjs-dev.firebaseapp.com/api/operators/finalize
-- https://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts
function Rx.finalize(finalizerCallback)
	assert(type(finalizerCallback) == "function")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(fire, fail, complete))
			maid:GiveTask(finalizerCallback)

			return maid
		end)
	end
end

-- https://rxjs.dev/api/operators/combineAll
function Rx.combineAll()
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local observables = {}
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(
				function(value)
					assert(Observable.isObservable(value))

					table.insert(observables, value)
				end,
				fail,
				function()
					maid:GiveTask(Rx.combineLatest(observables))
						:Subscribe(fire, fail, complete)
				end))

			return maid
		end)
	end
end

function Rx.combineLatest(observables)
	assert(type(observables) == "table")

	for _, observable in pairs(observables) do
		assert(Observable.isObservable(observable))
	end

	return Observable.new(function(fire, fail, complete)
		if not next(observables) then
			complete()
			return
		end

		local maid = Maid.new()
		local pending = 0

		local latest = {}
		for key, _ in pairs(observables) do
			pending = pending + 1
			latest[key] = UNSET_VALUE
		end

		local function fireIfAllSet()
			for _, value in pairs(latest) do
				if value == UNSET_VALUE then
					return
				end
			end

			fire(Table.copy(latest))
		end

		for key, observer in pairs(observables) do
			maid:GiveTask(observer:Subscribe(
				function(value)
					latest[key] = value
					fireIfAllSet()
				end,
				function(...)
					pending = pending - 1
					fail(...)
				end,
				function()
					pending = pending - 1
					if pending == 0 then
						complete()
					end
				end))
		end

		return maid
	end)
end

-- http://reactivex.io/documentation/operators/using.html
function Rx.using(resourceFactory, observableFactory)
	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		local resource = resourceFactory()
		maid:GiveTask(resource)

		local observable = observableFactory(resource)
		assert(Observable.isObservable(observable))

		maid:GiveTask(observable:Subscribe(fire, fail, complete))

		return maid
	end)
end

-- https://rxjs.dev/api/operators/take
function Rx.take(number)
	assert(type(number) == "number")
	assert(number >= 0)

	return function(source)
		return Observable.new(function(fire, fail, complete)
			if number == 0 then
				complete()
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
				fire(...)

				if taken == number then
					complete()
				end
			end, fail, complete))

			return maid
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/defer
-- https://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09
function Rx.defer(observableFactory)
	return Observable.new(function(fire, fail, complete)
		local observable = observableFactory()
		assert(Observable.isObservable(observable))

		return observable:Subscribe(fire, fail, complete)
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/operators/withLatestFrom
-- https://medium.com/js-in-action/rxjs-nosy-combinelatest-vs-selfish-withlatestfrom-a957e1af42bf
function Rx.withLatestFrom(inputObservables)
	assert(inputObservables)

	for _, observable in pairs(inputObservables) do
		assert(Observable.isObservable(observable))
	end

	return function(source)
		return Observable.new(function(fire, fail, complete)
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

				fire({value, unpack(latest)})
			end, fail, complete))

			return maid
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/scan
function Rx.scan(accumulator, seed)
	assert(type(accumulator) == "function")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			local current = seed

			return source:Subscribe(function(value)
				current = accumulator(current, value)
				fire(current)
			end, fail, complete)
		end)
	end;
end

return Rx