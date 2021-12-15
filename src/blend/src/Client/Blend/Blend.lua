---
-- @module Blend
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BlendDefaultProps = require("BlendDefaultProps")
local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local StepUtils = require("StepUtils")
local Symbol = require("Symbol")
local ValueBaseUtils = require("ValueBaseUtils")
local ValueObject = require("ValueObject")
local ValueObjectUtils = require("ValueObjectUtils")

local Blend = {}

Blend.Children = Symbol.named("children")

function Blend.New(className)
	assert(type(className) == "string", "Bad className")

	local defaults = BlendDefaultProps[className]

	return function(props)
		return Observable.new(function(sub)
			local maid = Maid.new()

			local instance = Instance.new(className)

			if defaults then
				for key, value in pairs(defaults) do
					instance[key] = value
				end
			end

			maid:GiveTask(Blend.mount(instance, props))

			sub:Fire(instance)

			return maid
		end)
	end
end

function Blend.State(defaultValue)
	return ValueObject.new(defaultValue)
end

function Blend.Dynamic(...)
	return Blend.Computed(...)
		:Pipe({
			-- This switch map is relatively expensive, so we don't do this for defaul computed
			-- and instead force the user to switch to another promise
			Rx.switchMap(function(promise, ...)
				if Promise.isPromise(promise) then
					return Rx.fromPromise(promise)
				else
					return Rx.of(promise, ...)
				end
			end)
		})
end

function Blend.Computed(...)
	local values = {...}
	local n = select("#", ...)
	local compute = values[n]

	assert(type(compute) == "function", "Bad compute")

	local args = {}
	for i=1, n - 1 do
		local observable = Blend.toPropertyObservable(values[i])
		if observable then
			args[i] = observable
		else
			args[i] = Rx.of(values[i])
		end
	end

	if #args == 0 then
		-- static value?
		return Rx.start(compute)
	elseif #args == 1 then
		return args[1]:Pipe({
			Rx.map(compute)
		})
	else
		return Rx.combineLatest(args)
			:Pipe({
				Rx.map(function(result)
					return compute(unpack(result, 1, n - 1))
				end);
			})
	end
end

function Blend.OnChange(propertyName)
	assert(type(propertyName) == "string", "Bad propertyName")

	return function(instance)
		return RxInstanceUtils.observeProperty(instance, propertyName)
	end
end

function Blend.OnEvent(eventName)
	assert(type(eventName) == "string", "Bad eventName")

	return function(instance)
		return Rx.fromSignal(instance[eventName])
	end
end

function Blend.ComputedPairs(source, compute)
	local sourceObservable = Blend.toPropertyObservable(source) or Rx.of(source)

	return function(parent)
		assert(typeof(parent) == "Instance", "Bad parent")

		local cache = {}
		local topMaid = Maid.new()

		local maidForKeys = Maid.new()
		topMaid:GiveTask(maidForKeys)

		topMaid:GiveTask(sourceObservable:Subscribe(function(newValue)
			-- It's gotta be a table
			assert(type(newValue) == "table", "Bad value emitted from source")

			local excluded = {}
			for key, _ in pairs(cache) do
				excluded[key] = true
			end

			for key, value in pairs(newValue) do
				excluded[key] = nil

				if cache[key] ~= value then
					local innerMaid = Maid.new()
					local result = compute(key, value, innerMaid)

					local brio = Brio.new(result)
					innerMaid:GiveTask(brio)

					local cleanup = Blend.addChildren(parent, brio)
					if cleanup then
						innerMaid:GiveTask(cleanup)
					end

					maidForKeys[key] = innerMaid
					cache[key] = value
				end
			end

			for key, _ in pairs(excluded) do
				maidForKeys[key] = nil
				cache[key] = nil
			end
		end))

		return topMaid
	end
end

function Blend.Spring(source, speed, damper)
	local sourceObservable = Blend.toPropertyObservable(source) or Rx.of(source)
	local speedObservable = Blend.toNumberObservable(speed)
	local damperObservable = Blend.toNumberObservable(damper)

	local function createSpring(maid, initialValue)
		local spring = Spring.new(initialValue)

		if speedObservable then
			maid:GiveTask(speedObservable:Subscribe(function(value)
				assert(type(value) == "number", "Bad value")
				spring.Speed = value
			end))
		end

		if damperObservable then
			maid:GiveTask(damperObservable:Subscribe(function(value)
				assert(type(value) == "number", "Bad value")

				spring.Damper = value
			end))
		end

		return spring
	end

	-- TODO: Centralize and cache
	return Observable.new(function(sub)
		local spring
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToRenderStep(function()
			local animating, position = SpringUtils.animating(spring)
			sub:Fire(position)
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(sourceObservable:Subscribe(function(value)
			spring = spring or createSpring(maid, value)
			spring.t = value
			startAnimate()
		end))

		return maid
	end)
end

function Blend.toPropertyObservable(value)
	if Observable.isObservable(value) then
		return value
	elseif typeof(value) == "Instance" then
		-- IntValue, ObjectValue, et cetera
		if ValueBaseUtils.isValueBase(value) then
			return RxValueBaseUtils.observeValue(value)
		end
	elseif type(value) == "table" then
		if value.ClassName == "ValueObject" then
			return ValueObjectUtils.observeValue(value)
		elseif Promise.isPromise(value) then
			return Rx.fromPromise(value)
		end
	end

	return nil
end

function Blend.toNumberObservable(value)
	if type(value) == "number" then
		return Rx.of(value)
	else
		return Blend.toPropertyObservable(value)
	end
end

function Blend.toEventObservable(value)
	if Observable.isObservable(value) then
		return value
	elseif typeof(value) == "RBXScriptSignal" then
		return Rx.fromSignal(value)
	else
		return nil
	end
end

function Blend.toEventHandler(value)
	if type(value) == "function" then
		return value
	elseif typeof(value) == "Instance" then
		-- IntValue, ObjectValue, et cetera
		if ValueBaseUtils.isValueBase(value) then
			return function(result)
				value.Value = result
			end
		end
	elseif type(value) == "table" then
		if value.ClassName == "ValueObject" then
			return function(result)
				value.Value = result
			end
		end
	end

	return nil
end

function Blend.addChildren(parent, value)
	if typeof(value) == "Instance" then
		value.Parent = parent

		-- ensure we cleanup the actual child
		return value
	end

	if type(value) == "table" then
		if Brio.isBrio(value) then
			if value:IsDead() then
				return nil
			end

			local maid = Maid.new()

			-- Add for lifetime
			local cleanup = Blend.addChildren(parent, value:GetValue())
			if cleanup then
				maid:GiveTask(cleanup)
			end

			-- Cleanup after death
			maid:GiveTask(value:GetDiedSignal():Connect(function()
				maid:DoCleaning()
			end))

			return maid
		else
			local observable = Blend.toPropertyObservable(value)
			if observable then
				-- observable of observables. we will keep these children alive
				-- until the point that we emit a new observed value.
				local maid = Maid.new()

				maid:GiveTask(observable:Subscribe(function(result)
					maid._current = Blend.addChildren(parent, result)
				end))

				return maid
			else
				local maid = Maid.new()

				-- hope we're actually recursing over a nested table.
				-- this allows us to add arrays into the blend.
				for _, item in pairs(value) do
					local cleanup = Blend.addChildren(parent, item)
					if cleanup then
						maid:GiveTask(cleanup)
					end
				end

				return maid
			end
		end
	elseif type(value) == "function" then
		-- hope we aren't iterating over a table
		return value(parent)
	end

	warn("[Blend] - Failed to convert result to children")

	return nil
end

function Blend.mount(instance, props)
	local maid = Maid.new()

	local parent = nil
	for key, value in pairs(props) do
		if type(key) == "string" then
			if key == "Parent" then
				parent = value
			else
				local observable = Blend.toPropertyObservable(value)
				if observable then
					maid:GiveTask(observable:Subscribe(function(result)
						task.spawn(function()
							instance[key] = result
						end)
					end))
				else
					task.spawn(function()
						instance[key] = value
					end)
				end
			end
		elseif type(key) == "function" then
			local observable = Blend.toEventObservable(key(instance))

			if Observable.isObservable(observable) then
				maid:GiveTask(observable:Subscribe(Blend.toEventHandler(value)))
			else
				warn(("Unable to apply event listener %q"):format(tostring(key)))
			end
		elseif key ~= Blend.Children then
			warn(("Unable to apply property %q"):format(tostring(key)))
		end
	end

	if parent then
		local observable = Blend.toPropertyObservable(parent)
		if observable then
			maid:GiveTask(observable:Subscribe(function(result)
				instance.Parent = result
			end))
		else
			instance.Parent = parent
		end
	end

	local childProp = props[Blend.Children]
	if childProp then
		local cleanup = Blend.addChildren(instance, childProp)
		if cleanup then
			maid:GiveTask(cleanup)
		end
	end

	return maid
end


return Blend