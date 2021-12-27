--[=[
	Declarative UI system inspired by Fusion
	@class Blend
]=]

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
local AccelTween = require("AccelTween")

local Blend = {}

Blend.Children = Symbol.named("children")

--[=[
	Creates a new function which will return an observable that, given the props
	in question, will construct a new instance and assign all props. This is the
	equivalent of a pipe-able Rx command.

	```lua
	Blend.New "ScreenGui" {
		Parent = game.Players.LocalPlayer.PlayerGui;
		[Blend.Children] = {
			Blend.New "Frame" {
				Size = UDim2.new(1, 0, 1, 0);
				BackgroundTransparency = 0.5;
			};
		};
	};

	@param className string
	@return (props: { [string]: any; }) -> Observable<Instance>
	```
]=]
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

--[=[
	Creates a new Blend State which is actually just a ValueObject underneath.

	@param defaultValue T
	@return ValueObject<T>
]=]
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
				elseif Observable.isObservable(promise) then
					return promise
				else
					return Rx.of(promise, ...)
				end
			end)
		})
end

--[=[
	Takes a list of variables and uses them to compute an observable that
	will combine into any value. These variables can be any value, and if they
	can be converted into an Observable, they will be, which will be used to compute
	the value.

	```lua
	local verbState = Blend.State("hi")
	local nameState = Blend.State("alice")

	local computed = Blend.Computed(verbState, nameState, function(verb, name)
		return verb .. " " .. name
	end)

	computed:Subscribe(function(sentence)
		print(sentence)
	end) --> "hi alice"

	nameState.Value = "bob" --> "hi bob"
	verbState.Value = "bye" --> "bye bob"
	nameState.Value = "alice" --> "bye alice"
	```

	@param ... A series of convertable states, followed by a function at the end.
	@return Observable<T>
]=]
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

--[=[
	Short hand to register a propertyEvent changing

	```lua
	Blend.mount(workspace, {
		[Blend.OnChange "Name"] = function(name)
			print(name)
		end;
	}) --> Immediately will print "Workspace"

	workspace.Name = "Hello" --> Prints "Hello"
	```

	@param propertyName string
	@return (instance: Instance) -> Observable
]=]
function Blend.OnChange(propertyName)
	assert(type(propertyName) == "string", "Bad propertyName")

	return function(instance)
		return RxInstanceUtils.observeProperty(instance, propertyName)
	end
end

--[=[
	Short hand to register an event from the instance

	```lua
		Blend.mount(workspace, {
			[Blend.OnEvent "ChildAdded"] = function(child)
				print("Child added", child)
			end;
		})

		local folder = Instance.new("Folder")
		folder.Name = "Hi"
		folder.Parent = workspace --> prints "Child added Hi"
	```

	@param eventName string
	@return (instance: Instance) -> Observable
]=]
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

					local cleanup = Blend.mountChildren(parent, brio)
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

--[=[
	Like Blend.Spring, but for AccelTween

	@param source any -- Source observable (or convertable)
	@param acceleration any -- Source acceleration (or convertable)
	@return Observable
]=]
function Blend.AccelTween(source, acceleration)
	local sourceObservable = Blend.toPropertyObservable(source) or Rx.of(source)
	local accelerationObservable = Blend.toNumberObservable(acceleration)

	local function createAccelTween(maid, initialValue)
		local accelTween = AccelTween.new(initialValue)

		if accelerationObservable then
			maid:GiveTask(accelerationObservable:Subscribe(function(value)
				assert(type(value) == "number", "Bad value")
				accelTween.a = value
			end))
		end

		return accelTween
	end

	-- TODO: Centralize and cache
	return Observable.new(function(sub)
		local accelTween
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToRenderStep(function()
			sub:Fire(accelTween.p)
			return accelTween.rtime > 0
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(sourceObservable:Subscribe(function(value)
			accelTween = accelTween or createAccelTween(maid, value)
			accelTween.t = value
			startAnimate()
		end))

		return maid
	end)
end

--[=[
	Converts this arbitrary value into an observable that will initialize a spring
	and interpolate it between values upon subscription.

	```lua
	local percentVisible = Blend.State(0)
	local visibleSpring = Blend.Spring(percentVisible, 30)
	local transparency = Blend.Computed(visibleSpring, function(percent)
		return 1 - percent
	end);

	Blend.mount(frame, {
		BackgroundTransparency = visibleSpring;
	})
	```

	@param source any
	@param speed any
	@param damper any
	@return Observable?
]=]
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
			sub:Fire(SpringUtils.fromLinearIfNeeded(position))
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(sourceObservable:Subscribe(function(value)
			local linearValue = SpringUtils.toLinearIfNeeded(value)
			spring = spring or createSpring(maid, linearValue)
			spring.t = SpringUtils.toLinearIfNeeded(value)
			startAnimate()
		end))

		return maid
	end)
end

--[=[
	Converts this arbitrary value into an observable suitable for use in properties.

	@param value any
	@return Observable?
]=]
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

--[=[
	Converts this arbitrary value into an observable that emits numbers.

	@param value number | any
	@return Observable<number>?
]=]
function Blend.toNumberObservable(value)
	if type(value) == "number" then
		return Rx.of(value)
	else
		return Blend.toPropertyObservable(value)
	end
end

--[=[
	Converts this arbitrary value into an observable that can be used to emit events.

	@param value any
	@return Observable?
]=]
function Blend.toEventObservable(value)
	if Observable.isObservable(value) then
		return value
	elseif typeof(value) == "RBXScriptSignal" then
		return Rx.fromSignal(value)
	else
		return nil
	end
end

--[=[
	Converts this arbitrary value into an event handler, which can be subscribed to

	@param value any
	@return function?
]=]
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

--[=[
	Mounts children to the parent and returns an object which will cleanup and delete
	all children when removed.

	Note that this effectively recursively mounts children and their values, which is
	the heart of the reactive tree.

	@param parent Instance
	@param value any
	@return MaidTask
]=]
function Blend.mountChildren(parent, value)
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
			local cleanup = Blend.mountChildren(parent, value:GetValue())
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
					maid._current = Blend.mountChildren(parent, result)
				end))

				return maid
			else
				local maid = Maid.new()

				-- hope we're actually recursing over a nested table.
				-- this allows us to add arrays into the blend.
				for _, item in pairs(value) do
					local cleanup = Blend.mountChildren(parent, item)
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

--[=[
	Mounts the instance to the props. This handles mounting children, and events.

	The contract is that the props table is turned into observables. Note the following.

	* Keys of strings are turned into properties
		* If this can be turned into an observable, it will be used to subscribe to this event
		* Otherwise, we assign directly
	* Keys of functions are invoked on the instance in question
		* If this returns an observable (or can be turned into one), we subscribe the event immediately
	* If the key is [Blend.Children] then we invoke mountChildren on it

	@param instance Instance
	@param props table
	@return Maid
]=]
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
		local cleanup = Blend.mountChildren(instance, childProp)
		if cleanup then
			maid:GiveTask(cleanup)
		end
	end

	return maid
end


return Blend