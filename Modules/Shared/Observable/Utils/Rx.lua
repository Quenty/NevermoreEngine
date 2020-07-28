---
-- @module Rx
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")
local Promise = require("Promise")
local Symbol = require("Symbol")
local Table = require("Table")
local ThrottledFunction = require("ThrottledFunction")

local UNSET_VALUE = Symbol.named("unsetValue")

local Rx = {
	EMPTY = Observable.new(function(sub)
		sub:Complete()
	end);
	NEVER = Observable.new(function(sub)

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

	return Observable.new(function(sub)
		for i=1, args.n do
			sub:Fire(args[i])
		end

		sub:Complete()
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

	return Observable.new(function(sub)
		local maid = Maid.new()

		for _, observable in pairs(observables) do
			maid:GiveTask(observable:Subscribe(sub:GetFireFailComplete()))
		end

		return maid
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/fromEvent
function Rx.fromSignal(event)
	return Observable.new(function(sub)
		local maid = Maid.new()
		-- This stream never completes or fails!
		maid:GiveTask(event:Connect(function(...)
			sub:Fire(...)
		end))

		return maid
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/from
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
				if not pending then
					sub:Fail(...)
					sub:Complete()
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

-- http://reactivex.io/documentation/operators/start.html
function Rx.start(callback)
	return function(source)
		return Observable.new(function(sub)
			sub:Fire(callback())

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

-- Like start, but also from (list!)
function Rx.startFrom(callback)
	assert(type(callback) == "function")
	return function(source)
		return Observable.new(function(sub)
			for _, value in pairs(callback()) do
				sub:Fire(value)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/startWith
function Rx.startWith(values)
	assert(type(values) == "table")

	return function(source)
		return Observable.new(function(sub)
			for _, item in pairs(values) do
				sub:Fire(item)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

function Rx.defaultsToNil()
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
				sub:Fire(nil)
			end

			return maid
		end)
	end
end


-- https://www.learnrxjs.io/learn-rxjs/operators/combination/endwith
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

-- http://reactivex.io/documentation/operators/filter.html
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

-- http://reactivex.io/documentation/operators/distinct.html
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

-- https://rxjs.dev/api/operators/mapTo
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

-- http://reactivex.io/documentation/operators/map.html
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

-- Merges higher order observables together
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

-- Merges higher order observables together
-- https://rxjs.dev/api/operators/switchAll
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

-- Sort of equivalent of promise.then()
function Rx.flatMap(project, resultSelector)
	assert(type(project) == "function")

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

function Rx.packed(...)
	local args = table.pack(...)

	return Observable.new(function(sub)
		sub:Fire(unpack(args, 1, args.n))
		sub:Complete()
	end)
end

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

-- http://reactivex.io/documentation/operators/do.html
-- https://rxjs-dev.firebaseapp.com/api/operators/finalize
-- https://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts
function Rx.finalize(finalizerCallback)
	assert(type(finalizerCallback) == "function")

	return function(source)
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(sub:GetFireFailComplete()))
			maid:GiveTask(finalizerCallback)

			return maid
		end)
	end
end

-- https://rxjs.dev/api/operators/combineAll
function Rx.combineAll()
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

function Rx.combineLatest(observables)
	assert(type(observables) == "table")

	for _, observable in pairs(observables) do
		assert(Observable.isObservable(observable), "Not an observable")
	end

	return Observable.new(function(sub)
		if not next(observables) then
			sub:Complete()
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

			sub:Fire(Table.copy(latest))
		end

		for key, observer in pairs(observables) do
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

		return maid
	end)
end

-- http://reactivex.io/documentation/operators/using.html
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

-- https://rxjs.dev/api/operators/take
function Rx.take(number)
	assert(type(number) == "number")
	assert(number >= 0)

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

-- https://rxjs-dev.firebaseapp.com/api/index/function/defer
-- https://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09
function Rx.defer(observableFactory)
	return Observable.new(function(sub)
		local observable = observableFactory()
		assert(Observable.isObservable(observable))

		return observable:Subscribe(sub:GetFireFailComplete())
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

-- https://rxjs-dev.firebaseapp.com/api/operators/scan
function Rx.scan(accumulator, seed)
	assert(type(accumulator) == "function")

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

-- https://rxjs-dev.firebaseapp.com/api/operators/debounceTime
-- @param throttleConfig { leading = true; trailing = true; }
-- Note that on complete, the last item is not included, for now, unlike the existing version in rxjs.
function Rx.throttleTime(duration, throttleConfig)
	assert(type(duration) == "number")
	assert(type(throttleConfig) == "table" or throttleConfig == nil)

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