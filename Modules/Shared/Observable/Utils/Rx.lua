---
-- @module Rx
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")
local Symbol = require("Symbol")
local fastSpawn = require("fastSpawn")

local RX_NOT_SET = Symbol.named("rxNotSet")
local EMPTY_FUNCTION = function() end

local Rx = {}

function Rx.pipe(transformers)
	assert(type(transformers) == "table")
	for index, transformer in pairs(transformers) do
		if type(transformer) ~= "function" then
			error(("Bad transform of type %q at index %q"):format(type(transformer), tostring(index)))
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

function Rx.transformToFunction(transformer)
	assert(type(transformer) == "function")

	return function(callback, ...)
		assert(type(callback) == "function")

		local observable = transformer(Rx.of(...))
		assert(observable)
		return observable:Subscribe(callback)
	end
end

function Rx.mergeInput(transformer)
	assert(type(transformer) == "function");

	return function(source)
		return Observable.new(function(fire)
			return source:Subscribe(function(...)
				-- on subscription to the source we transform with the spy for the given values
				local sourceValues = table.pack(...)

				local spy = Observable.new(function(spyFire)
					-- spy sends seen values
					return spyFire(table.unpack(sourceValues, 1, sourceValues.n))
				end)

				-- Observe results from the transofmred
				local observed = transformer(spy)
				assert(observed)
				assert(observed.Subscribe)

				return observed:Subscribe(function(value)
					-- Observed values go first, then the sourceValues
					return fire(value, table.unpack(sourceValues, 1, sourceValues.n))
				end)
			end)
		end)
	end;
end

-- Pushes the result of the transformer to the end of the tuple stack
-- but continues to pass along the value.
-- Doesn't switch, so you can get multiple fast!
function Rx.appendLastInput(transformer)
	assert(transformer)

	return function(source)
		return Observable.new(function(fire)
			local lastInput = RX_NOT_SET
			local spy = Observable.new(function(spyFire)
				return source:Subscribe(function(...)
					lastInput = table.pack(...)
					return spyFire(...)
				end)
			end)

			local observable = transformer(spy)
			assert(observable)
			assert(observable.Subscribe)

			return observable:Subscribe(function(...)
				return fire(..., table.unpack(lastInput, 1, lastInput.n))
			end)
		end)
	end
end

-- function Rx.withLatestFrom(observable)
-- 	return function(source)
-- 		return Observable.new(function(fire)
-- 			local maid = Maid.new()

-- 			local lastFrom = RX_NOT_SET

-- 			-- Subscribe first to this incase we have an instant value
-- 			maid:GiveTask(observable:Subscribe(function(value)
-- 				lastFrom = value
-- 				return EMPTY_FUNCTION
-- 			end))

-- 			maid:GiveTask(source:Subscribe(function(value)
-- 				if lastFrom == RX_NOT_SET then
-- 					return EMPTY_FUNCTION
-- 				end

-- 				return fire(value, lastFrom)
-- 			end))

-- 			return maid
-- 		end)
-- 	end
-- end

-- function Rx.withLatestFrom(observable)
-- 	return function(source)
-- 		return Observable.new(function(fire)
-- 			local maid = Maid.new()

-- 			local lastFrom = RX_NOT_SET

-- 			-- Subscribe first to this incase we have an instant value
-- 			maid:GiveTask(observable:Subscribe(function(value)
-- 				lastFrom = value
-- 				return function()
-- 					-- TODO: Handle this properly and clean up the subscription
-- 					-- below...
-- 				end;
-- 			end))

-- 			maid:GiveTask(source:Subscribe(function(value)
-- 				if lastFrom == RX_NOT_SET then
-- 					return EMPTY_FUNCTION
-- 				end

-- 				return fire(value, lastFrom)
-- 			end))

-- 			return maid
-- 		end)
-- 	end
-- end

function Rx.combineLatest(transformers)
	assert(type(transformers) == "table")
	for _, transformer in pairs(transformers) do
		assert(type(transformer) == "function")
	end

	return function(source)
		local observers = {}
		for key, transformer in pairs(transformers) do
			observers[key] = transformer(source)
		end

		return Observable.new(function(fire)
			local maid = Maid.new()

			local latest = {}
			for key, _ in pairs(observers) do
				latest[key] = RX_NOT_SET
			end

			local function fireIfAllSet()
				for _, item in pairs(latest) do
					if item == RX_NOT_SET then
						return
					end
				end

				maid._lastFire = fire(unpack(latest))
			end

			for key, observer in pairs(observers) do
				maid:GiveTask(observer:Subscribe(function(value)
					latest[key] = value
					fireIfAllSet()
				end))
			end

			return maid
		end)
	end
end

function Rx.of(...)
	local args = table.pack(...)

	return Observable.new(function(fire)
		local maid = Maid.new()

		for i=1, args.n do
			maid[i] = fire(args[i])
		end

		return maid
	end)
end

-- function Rx.when(transformer)
-- 	return function(source)
-- 		return Observable.new(function(fireReal)
-- 			local lastFiredWith = RX_NOT_SET
-- 			local ourFire = nil

-- 			local spy = Observable.new(function(fire)
-- 				return source:Subscribe(function(...)
-- 					lastFiredWith = table.pack(...)
-- 					return fire(...)
-- 				end)
-- 			end)

-- 			local requirementObservable = transformer(spy)

-- 			return requirementObservable:Subscribe(function(...)
-- 				if lastFiredWith == RX_NOT_SET then
-- 					-- Guess some external event occured here
-- 					return EMPTY_FUNCTION
-- 				end

-- 				-- We discard the "..." results and return with the spy lastFiredWith
-- 				return fireReal(table.unpack(lastFiredWith, 1, lastFiredWith.n))
-- 			end)
-- 		end)
-- 	end
-- end

function Rx.tap(onFiring)
	assert(onFiring)

	return function(source)
		return Observable.new(function(fire)
			return source:Subscribe(function(...)
				local maid = Maid.new()
				maid._onFiring = onFiring(...) -- could be nil (what if we pass print in!?)
				maid:GiveTask(fire(...))
				return maid
			end)
		end)
	end
end

function Rx.filter(predicate)
	assert(type(predicate) == "function")

	return function(source)
		return source:Lift(function(fire, ...)
			local maid = Maid.new()

			if predicate(...) then
				maid._firedMaid = fire(...)
			end

			return maid
		end)
	end
end

function Rx.map(project)
	assert(type(project) == "function")

	return function(source)
		return source:Lift(function(fire, ...)
			return fire(project(...))
		end)
	end
end

-- Merges higher order observables together
function Rx.mergeAll()
	return function(source)
		return Observable.new(function(fire)
			return source:Subscribe(function(observable)
				assert(type(observable) == "table")
				assert(type(observable.Subscribe) == "function")

				return observable:Subscribe(fire)
			end)
		end)
	end
end

function Rx.switchMapTo(observable)
	assert(observable, "Bad observable")
	assert(observable.Subscribe, "Bad observable")

	return function(source)
		return source:Lift(function(fire, value)
			-- Resubscribe
			return observable:Subscribe(fire)
		end)
	end
end

function Rx.switchMap(project)
	assert(type(project) == "function")

	return function(source)
		return source:Lift(function(fire, ...)
			local observable = project(...)
			assert(observable, "Project returned bad value")
			assert(observable.Subscribe, "Project returned bad value")

			-- Resubscribe
			return observable:Subscribe(fire)
		end)
	end
end

function Rx.interval(seconds)
	assert(type(seconds) == "number")

	return Observable.new(function(fire)
		local count = 0
		local alive = true

		delay(seconds, function()
			while alive do
				fire(count)
				count = count + 1
				wait(seconds)
			end
		end)

		return function()
			alive = false
		end
	end)
end

function Rx.scan(accumulator, seed)
	assert(type(accumulator) == "function")

	return function(source)
		return Observable.new(function(fire)
			local current = seed
			return source:Subscribe(function(value)
				current = accumulator(current, value)
				fire(current)
			end)
		end)
	end
end

function Rx.mergeScan(accumulator, seed)
	return Rx.pipe({
		Rx.scan(accumulator, seed);
		Rx.mergeAll();
	})
end

function Rx.flatMap(project)
	return Rx.pipe({
		Rx.map(project);
		Rx.mergeAll();
	})
end

function Rx.observeProperty(propertyName)
	assert(type(propertyName) == "string")

	return function(source)
		return source:Lift(function(fire, instance, ...)
			if typeof(instance) ~= "Instance" then
				warn("[Rx.observeProperty] - Cannot observeProperty of non-instance")
				return EMPTY_FUNCTION
			end

			local maid = Maid.new()
			local otherArgs = table.pack(...)

			local function handlePropertyChanged()
				local value = instance[propertyName]
				if value ~= nil then
					maid._fireEvent = fire(value, table.unpack(otherArgs, 1, otherArgs.n))
				else
					maid._fireEvent = nil
				end
			end

			maid:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(handlePropertyChanged))
			handlePropertyChanged()

			return maid
		end)
	end
end

function Rx.requirePropertyValue(propertyName, expectedValue)
	assert(type(propertyName) == "string")

	return function(source)
		return source:Lift(function(fire, instance, ...)
			if typeof(instance) ~= "Instance" then
				warn("[Rx.requirePropertyValue] - Cannot requirePropertyValue of non-instance")
				return EMPTY_FUNCTION
			end

			local maid = Maid.new()
			local otherArgs = table.pack(...)

			local function handlePropertyChanged()
				if instance[propertyName] == expectedValue then
					maid._fireEvent = fire(instance, table.unpack(otherArgs, 1, otherArgs.n))
				else
					maid._fireEvent = nil
				end
			end

			maid:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(handlePropertyChanged))
			handlePropertyChanged()

			return maid
		end)
	end
end

function Rx.observeBoundClass(binder)
	assert(binder)

	return function(source)
		return source:Lift(function(fire, instance, ...)
			if typeof(instance) ~= "Instance" then
				return EMPTY_FUNCTION
			end

			local maid = Maid.new()
			local otherArgs = table.pack(...)

			maid:GiveTask(binder:ObserveInstance(instance, function(class)
				if class then
					maid._fireEvent = fire(class, table.unpack(otherArgs, 1, otherArgs.n))
				else
					maid._fireEvent = nil
				end
			end))

			local class = binder:Get(instance)
			if class then
				maid._fireEvent = fire(class, table.unpack(otherArgs, 1, otherArgs.n))
			end

			return maid
		end)
	end
end

function Rx.wrapMaid()
	return function(source)
		return source:Lift(function(fire, ...)
			local maid = Maid.new()
			maid._fireEvent = fire(maid, ...)
			return maid
		end)
	end
end

function Rx.observeChildrenOfClass(className)
	assert(typeof(className) == "string")

	return function(source)
		return Observable.new(function(fire)
			return source:Subscribe(function(instance, ...)
				if typeof(instance) ~= "Instance" then
					return EMPTY_FUNCTION
				end

				local maid = Maid.new()
				local otherArgs = table.pack(...)

				local function handleChildAdded(child)
					if not child:IsA(className) then
						return
					end

					fastSpawn(function()
						maid[child] = fire(child, table.unpack(otherArgs, 1, otherArgs.n))
					end)
				end

				maid:GiveTask(instance.ChildAdded:Connect(handleChildAdded))
				maid:GiveTask(instance.ChildRemoved:Connect(function(child)
					maid[child] = nil
				end))

				for _, child in pairs(instance:GetChildren()) do
					handleChildAdded(child)
				end

				return maid
			end)
		end)
	end
end

return Rx