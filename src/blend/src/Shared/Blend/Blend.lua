--[=[
	Declarative UI system inspired by Fusion.
	@class Blend
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BlendDefaultProps = require("BlendDefaultProps")
local Brio = require("Brio")
local BrioUtils = require("BrioUtils")
local Maid = require("Maid")
local MaidTaskUtils = require("MaidTaskUtils")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Signal = require("Signal")
local StepUtils = require("StepUtils")
local ValueBaseUtils = require("ValueBaseUtils")
local ValueObject = require("ValueObject")
local SpringObject

local Blend = {}

export type BlendProps = { [any]: any }

--[=[
	Creates a new function which will return an observable that, given the props
	in question, will construct a new instance and assign all props. This is the
	equivalent of a pipe-able Rx command.

	```lua
	local render = Blend.New "ScreenGui" {
		Parent = game.Players.LocalPlayer.PlayerGui;

		Blend.New "Frame" {
			Size = UDim2.fromScale(1, 1);
			BackgroundTransparency = 0.5;
		};
	};

	maid:GiveTask(render:Subscribe(function(gui)
		print(gui)
	end))
	```

	@param className string
	@return (props: { [string]: any; }) -> Observable<Instance>
]=]
function Blend.New(className: string): (props: BlendProps) -> Observable.Observable<Instance>
	assert(type(className) == "string", "Bad className")

	return function(props: BlendProps)
		return Observable.new(function(sub)
			local instance = Instance.new(className)

			if BlendDefaultProps[className] then
				for key, value in BlendDefaultProps[className] do
					instance[key] = value
				end
			end

			local maid = Blend.mount(instance, props)
			maid:GiveTask(function()
				Blend._safeCleanupInstance(instance)
			end)

			sub:Fire(instance)

			return maid
		end)
	end
end

--[=[
	Creates a new Blend State which is actually just a ValueObject underneath.

	@param defaultValue T
	@param checkType string?
	@return ValueObject<T>
]=]
function Blend.State<T>(defaultValue: T, checkType: ValueObject.ValueObjectTypeArg?): ValueObject.ValueObject<T>
	return ValueObject.new(defaultValue, checkType)
end

--[=[
	Throttles the update to the end of the defer lane. Can help optimize scenarios when
	Compute() can trigger multiple times per a frame.

	Generally not needed.

	@param observable Observable<T>
	@return Observable<T>
]=]
function Blend.Throttled<T>(observable: Observable.Observable<T>): Observable.Observable<T>
	return observable:Pipe({
		Rx.throttleDefer(),
	}) :: any
end

--[=[
	Shares this observables state/computation with all down-stream observables. This can be useful
	when a very expensive computation was done and needs to be shared.

	Generally not needed.

	@param observable Observable<T>
	@return Observable<T>
]=]
function Blend.Shared<T>(observable: Observable.Observable<T>): Observable.Observable<T>
	return observable:Pipe({
		Rx.cache() :: any,
	}) :: any
end

function Blend.Dynamic(...)
	-- stylua: ignore
	return Blend.Computed(...):Pipe({
		-- This switch map is relatively expensive, so we don't do this for defaul computed
		-- and instead force the user to switch to another promise
		Rx.switchMap(function(promise, ...)
			if Promise.isPromise(promise) then
				return Rx.fromPromise(promise) :: any
			elseif Observable.isObservable(promise) then
				return promise
			else
				return Rx.of(promise, ...)
			end
		end) :: any,
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

	maid:GiveTask(computed:Subscribe(function(sentence)
		print(sentence)
	end)) --> "hi alice"

	nameState.Value = "bob" --> "hi bob"
	verbState.Value = "bye" --> "bye bob"
	nameState.Value = "alice" --> "bye alice"
	```

	@param ... A series of convertable states, followed by a function at the end.
	@return Observable<T>
]=]
function Blend.Computed(...)
	local n = select("#", ...)
	local compute = select(n, ...)
	assert(type(compute) == "function", "Bad compute")

	if n == 1 then
		-- static value?
		return Observable.new(function(sub)
			sub:Fire(compute())
		end)
	elseif n == 2 then
		local arg = ...
		local observable = Blend.toPropertyObservable(arg) or Rx.of(arg)
		return Rx.map(compute)(observable)
	else
		local args = table.create(n - 1)

		for i = 1, n - 1 do
			local found = select(i, ...)
			local observable = Blend.toPropertyObservable(found)
			if observable then
				args[i] = observable
			else
				args[i] = found
			end
		end

		return Rx.combineLatest(args):Pipe({
			Rx.map(function(result)
				return compute(unpack(result, 1, n - 1))
			end),
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
function Blend.OnChange(propertyName: string): (instance: Instance) -> Observable.Observable<any>
	assert(type(propertyName) == "string", "Bad propertyName")

	return function(instance: Instance)
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
function Blend.OnEvent(eventName: string)
	assert(type(eventName) == "string", "Bad eventName")

	return function(instance)
		return Rx.fromSignal(instance[eventName])
	end
end

--[=[
	Uses the constructor to attach a class or resource to the actual object
	for the lifetime of the subscription of that object.

	```lua
	return Blend.New "Frame" {
		Parent = variables.Parent;
		[Blend.Attached(function(parent)
			local maid = Maid.new()

			print("Got", parent)

			maid:GiveTask(function()
				print("Dead!")
			end)

			return maid
		end)] = true;
	}
	```

	@param constructor T
	@return (parent: Instance) -> Observable<T>
]=]
function Blend.Attached(constructor)
	return function(parent: Instance)
		return Observable.new(function(sub)
			local resource = constructor(parent)

			local cleanup = nil
			if MaidTaskUtils.isValidTask(resource) then
				cleanup = resource
			end

			sub:Fire(resource)

			return cleanup
		end)
	end
end

--[=[
	Similiar to Fusion's ComputedPairs, where the changes are cached, and the lifetime limited.
	@param source Observable<T> | any
	@param compute (key: any, value: any, innerMaid: Maid) -> Instance | Observable<Instance>
	@return Observable<Brio<Instance>>
]=]
function Blend.ComputedPairs(source, compute)
	local sourceObservable = Blend.toPropertyObservable(source) or Rx.of(source)

	return Observable.new(function(sub)
		local cache = {}
		local topMaid = Maid.new()

		local maidForKeys = Maid.new()
		topMaid:GiveTask(maidForKeys)

		topMaid:GiveTask(
			sourceObservable:Subscribe(function(newValue)
				-- It's gotta be a table
				assert(type(newValue) == "table", "Bad value emitted from source")

				local excluded = {}
				for key, _ in cache do
					excluded[key] = true
				end

				for key, value in newValue do
					excluded[key] = nil

					if cache[key] ~= value then
						local innerMaid = Maid.new()
						local result = compute(key, value, innerMaid)

						local brio = Brio.new(result)
						innerMaid:GiveTask(brio)

						sub:Fire(brio)

						maidForKeys[key] = innerMaid
						cache[key] = value
					end
				end

				for key, _ in excluded do
					maidForKeys[key] = nil
					cache[key] = nil
				end
			end),
			sub:GetFailComplete()
		)

		return topMaid
	end)
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
		local accelTween = AccelTween.new()

		if initialValue then
			accelTween.p = initialValue
			accelTween.t = initialValue
			accelTween.v = 0
		end

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
	if not SpringObject then
		SpringObject = (require :: any)("SpringObject")
	end

	return Observable.new(function(sub)
		local spring = SpringObject.new(source, speed, damper)
		spring.Epsilon = 1e-3

		spring._maid:GiveTask(spring:Observe():Subscribe(sub:GetFireFailComplete()))

		return spring
	end)
end

--[=[
	Converts this arbitrary value into an observable suitable for use in properties.

	@param value any
	@return Observable?
]=]
function Blend.toPropertyObservable(value)
	if type(value) == "table" then
		if Observable.isObservable(value) then
			return value
		elseif Promise.isPromise(value) then
			return Rx.fromPromise(value)
		elseif value.Observe then
			return value:Observe()
		else
			return nil
		end
	elseif typeof(value) == "Instance" then
		-- IntValue, ObjectValue, et cetera
		if ValueBaseUtils.isValueBase(value) then
			return RxValueBaseUtils.observeValue(value)
		else
			return nil
		end
	else
		return nil
	end
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
	elseif typeof(value) == "RBXScriptSignal" or Signal.isSignal(value) then
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
				(value :: any).Value = result
			end
		end
	elseif type(value) == "table" then
		if Signal.isSignal(value) then
			return function(...)
				value:Fire(...)
			end
		elseif value.ClassName == "ValueObject" then
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

	```lua
	Blend.New "ScreenGui" {
		Parent = game.Players.LocalPlayer.PlayerGui;
		[Blend.Children] = {
			Blend.New "Frame" {
				Size = UDim2.fromScale(1, 1);
				BackgroundTransparency = 0.5;
			};
		};
	};
	```

	Note since 6.14 you don't need to be explicit about [Blend.Children]. Any number-based
	index in the mounting process will be automatically inferred as children to mount.

	```lua
	Blend.New "ScreenGui" {
		Parent = game.Players.LocalPlayer.PlayerGui;

		Blend.New "Frame" {
			Size = UDim2.fromScale(1, 1);
			BackgroundTransparency = 0.5;
		};
	};
	```

	Rules:

	* `{ Instance }` - Tables of instances are all parented to the parent
	* Brio<Instance> will last for the lifetime of the brio
	* Brio<Observable<Instance>> will last for the lifetime of the brio
		* Brio<Signal<Instance>> will also act as above
		* Brio<Promise<Instance>> will also act as above
		* Brio<{ Instance } will also act as above
	* Observable<Instance> will parent to the parent
		* Signal<Instance> will act as Observable<Instance>
		* ValueObject<Instance> will act as an Observable<Instance>
		* Promise<Instance> will act as an Observable<Instance>
	*  will parent all instances to the parent
	* Observables may emit non-observables (in form of Computed/Dynamic)
		* Observable<Brio<Instance>> will last for the lifetime of the brio, and parent the instance.
		* Observable<Observable<Instance>> occurs when computed returns a value.
	* ValueObject<Instance> will switch to the current value
	* function - Will be invoked as `func(parent)` and then the standard scheme will be applied

	Cleanup:
	* Instances will be cleaned up on unsubscribe

	@param parent Instance
	@param value any
	@return Observable
]=]
function Blend.Children(parent: Instance, value)
	assert(typeof(parent) == "Instance", "Bad parent")

	local observe = Blend._observeChildren(value, parent)

	if observe then
		return Observable.new(function(_sub)
			return observe:Subscribe(function(child)
				child.Parent = parent
			end)
		end)
	else
		return Rx.EMPTY
	end
end

--[=[
	Allows you to add [CollectionService] tags to a Blend object.

	```lua
	Blend.New "ScreenGui" {
		[Blend.Tags] = { "Hide", "ScreenGui" };
	};
	```

	@param parent Instance
	@param value any
	@return Observable
]=]
function Blend.Tags(parent: Instance, value)
	assert(typeof(parent) == "Instance", "Bad parent")

	local observe = Blend._observeTags(value)

	if observe then
		return observe:Pipe({
			Rx.tap(function(tag)
				if type(tag) == "string" then
					parent:AddTag(tag)
				else
					error("Bad tag")
				end
			end),
		})
	else
		return Rx.EMPTY
	end
end

function Blend._observeTags(tags)
	if type(tags) == "string" then
		return Rx.of(tags)
	elseif type(tags) == "table" then
		if Observable.isObservable(tags) then
			return tags
		else
			error("Bad tags")
		end
	else
		error("Bad tags")
	end
end

--[=[
	Mounts Blend objects into an existing instance.

	:::tip
	Normally specifying ClassName as a property breaks mounting, since you
	can't write to ClassName. However, if you specify ClassName here, it will only
	listen to changes on children with that class name.
	:::

	If multiple instances are named the same thing, then this will
	bind to both.

	:::tip
	This explicitly listens for any children underneath the mounted
	instance with the name passed in here. This is fine for small amounts
	of instances, like in most Gui hierarchies. However, it will be way less
	performance friendly for large class hierarchies.
	:::

	```lua
	maid:GiveTask(Blend.mount(frame, {
		Size = UDim2.fromScale(0.5, 0.5);

		Blend.Find "UIScale" {
			Scale = 2;
		};
	}))
	```

	:::tip

	:::

	@param className string
	@return function
]=]
function Blend.Find(className: string)
	assert(type(className) == "string", "Bad className")

	return function(props)
		assert(type(props) == "table", "Bad props")
		assert(type(props.Name) == "string", "No props.Name")

		-- Return observable and assume we're being used in anexternal context
		-- TODO: Maybe not this
		if props.Parent then
			local propertyObservable = Blend.toPropertyObservable(props.Parent)

			local function handleChildBrio(brio)
				if brio:IsDead() then
					return
				end

				local maid, instance = brio:ToMaidAndValue()

				maid:GiveTask(Blend.mount(instance, props))

				if brio:IsDead() then
					maid:DoCleaning()
				end

				-- Emit back found value (we're used in property scenario)
				return Rx.of(instance)
			end

			if propertyObservable then
				return propertyObservable:Pipe({
					RxBrioUtils.switchToBrio(function(parent)
						return parent ~= nil
					end),
					RxBrioUtils.switchMapBrio(function(parent)
						assert(typeof(parent) == "Instance", "Bad parent retrieved during find spec")

						return RxInstanceUtils.observeChildrenOfNameBrio(parent, className, props.Name)
					end),
					Rx.flatMap(handleChildBrio),
				})
			else
				return RxInstanceUtils.observeChildrenOfNameBrio(props.Parent, className, props.Name):Pipe({
					Rx.flatMap(handleChildBrio),
				})
			end
		end

		-- Return callback
		return function(parent)
			-- TODO: Swap based upon name
			-- TODO: Avoid assigning name
			return RxInstanceUtils.observeChildrenOfNameBrio(parent, className, props.Name):Pipe({
				Blend._mountToFinding(props),
			})
		end
	end
end

function Blend._mountToFinding(props)
	return Rx.flatMap(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, instance = brio:ToMaidAndValue()

		maid:GiveTask(Blend.mount(instance, props))

		-- Dead after mounting? Clean up...
		-- Probably caused by name change.
		if brio:IsDead() then
			maid:DoCleaning()
		end

		-- Avoid emitting anything else so we don't get cleaned up
		return Rx.EMPTY
	end)
end

--[=[
	An event emitter that emits the instance that was actually created. This is
	useful for a variety of things.

	Using this to track an instance

	```lua
	local currentCamera = Blend.State()

	return Blend.New "ViewportFrame" {
		CurrentCamera = currentCamera;
		[Blend.Children] = {
			self._current;
			Blend.New "Camera" {
				[Blend.Instance] = currentCamera;
			};
		};
	};
	```

	Note that since 6.14 you should also be able to just use the reification scheme of
	[Blend.Children] implicitly in [Blend.mount] to get somewhat equivalent behavior.

	```lua
	Blend.mount(frame, {
		-- Array indexed methods get treated as children-constructors, which get the parent
		-- in them;

		function(parent)
			print("Got parent!", parent)
		end;
	})
	```

	You can also use this to execute code against an instance.

	```lua
	return Blend.New "Frame" {
		[Blend.Instance] = function(frame)
			print("We got a new frame!")
		end;
	};
	```

	Note that if you subscribe twice to the resulting observable, the internal function
	will execute twice.

	@param parent Instance
	@return Observable<Instance>
]=]
function Blend.Instance(parent: Instance): Observable.Observable<Instance>
	return Observable.new(function(sub)
		sub:Fire(parent)
	end)
end

--[=[
	Ensures the computed version of a value is limited by lifetime instead
	of multiple. Used in conjunction with [Blend.Children] and [Blend.Computed].

	:::warning
	In general, cosntructing new instances like this is a bad idea, so it's recommended against it.
	:::

	```
	local render = Blend.New "ScreenGui" {
		Parent = game.Players.LocalPlayer.PlayerGui;
		[Blend.Children] = {
			Blend.Single(Blend.Computed(percentVisible, function()
				-- you generally would not want to do this anyway because this reconstructs a new frame
				-- every frame.

				Blend.New "Frame" {
					Size = UDim2.fromScale(1, 1);
					BackgroundTransparency = 0.5;
				};
			end)
		};
	};

	maid:GiveTask(render:Subscribe(function(gui)
		print(gui)
	end))
	```

	@function Single
	@param Observable<Instance | Brio<Instance>>
	@return Observable<Brio<Instance>>
	@within Blend
]=]
function Blend.Single(observable)
	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(observable:Subscribe(function(result)
			if Brio.isBrio(result) then
				local copy = BrioUtils.clone(result)
				maid._current = copy
				sub:Fire(copy)
				return copy
			end

			local current = Brio.new(result)
			maid._current = current
			sub:Fire(current)

			return current
		end))

		return maid
	end)
end

function Blend._safeCleanupInstance(result: Instance)
	-- Unparent all children incase we want to resurrect them
	for _, child in result:GetChildren() do
		child.Parent = nil
	end
	result:Destroy()
end

--[=[
	Observes children and ensures that the value is cleaned up
	afterwards.
	@param value any
	@param parent Instance
	@return Observable<Instance>
]=]
function Blend._observeChildren(value, parent)
	if typeof(value) == "Instance" then
		-- Should be uncommon
		return Observable.new(function(sub)
			sub:Fire(value)
			-- don't complete, as this would clean everything up
			return value
		end)
	end

	if type(value) == "function" then
		value = Blend._observeChildren(value(parent), parent)
	end

	if ValueObject.isValueObject(value) then
		return Observable.new(function(sub)
			local maid = Maid.new()

			-- Switch instead of emitting every value.
			local function update()
				local result = value.Value
				if typeof(result) == "Instance" then
					maid._current = result
					sub:Fire(result)
					return
				end

				local observe = Blend._observeChildren(result, parent)
				if observe then
					maid._current = nil

					local doCleanup = false
					local cleanup
					cleanup = observe:Subscribe(function(inst)
						sub:Fire(inst)
					end, function(...)
						sub:Fail(...)
					end, function()
						-- incase of immediate execution
						doCleanup = true

						-- Do not pass complete through to the end
						if maid._current == cleanup then
							maid._current = nil
						end
					end)

					-- TODO: Complete when valueobject cleans up

					if doCleanup then
						if cleanup then
							MaidTaskUtils.doCleanup(cleanup)
						end
					else
						maid._current = cleanup
					end

					return
				end

				maid._current = nil
			end
			maid:GiveTask(value.Changed:Connect(update))
			update()

			return maid
		end)
	end

	if Brio.isBrio(value) then
		return Observable.new(function(sub)
			if value:IsDead() then
				return nil
			end

			local result = value:GetValue()
			if typeof(result) == "Instance" then
				local maid = value:ToMaid()
				maid:GiveTask(function()
					Blend._safeCleanupInstance(result)
				end)
				sub:Fire(result)

				return maid
			end

			local observe = Blend._observeChildren(result, parent)
			if observe then
				local maid = value:ToMaid()

				-- Subscription is for lifetime of brio, so we do
				-- not need to specifically add these results to the maid, and
				-- risk memory leak of the maid with a lot of items in it.
				maid:GiveTask(observe:Subscribe(function(inst)
					sub:Fire(inst)
				end, function(...)
					sub:Fail(...)
				end, function()
					-- completion should not result more than maid cleaning up
					maid:DoCleaning()
				end))

				return maid
			end

			warn(string.format("Unknown type in brio %q", typeof(result)))
			return nil
		end)
	end

	-- Handle like observable
	if Promise.isPromise(value) then
		value = Rx.fromPromise(value)
	end

	-- Handle like observable
	if Signal.isSignal(value) or typeof(value) == "RBXScriptSignal" then
		value = Rx.fromSignal(value)
	end

	if Observable.isObservable(value) then
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GiveTask(value:Subscribe(function(result)
				if typeof(result) == "Instance" then
					-- lifetime of subscription
					maid:GiveTask(function()
						Blend._safeCleanupInstance(result)
					end)
					sub:Fire(result)
					return
				end

				local observe = Blend._observeChildren(result, parent)

				if observe then
					local innerMaid = Maid.new()

					-- Note: I think this still memory leaks
					innerMaid:GiveTask(observe:Subscribe(function(inst)
						sub:Fire(inst)
					end, function(...)
						innerMaid:DoCleaning()
						sub:Fail(...)
					end, function()
						innerMaid:DoCleaning()
					end))

					innerMaid:GiveTask(function()
						maid[innerMaid] = nil
					end)
					maid[innerMaid] = innerMaid
				else
					warn(string.format("Failed to convert %q into children", tostring(result)))
				end
			end, function(...)
				sub:Fire(...)
			end, function()
				-- Drop completion, other inner components may have completed.
			end))

			return maid
		end)
	end

	if type(value) == "table" and not getmetatable(value) then
		local observables = {}
		for key, item in value do
			local observe = Blend._observeChildren(item, parent)
			if observe then
				table.insert(observables, observe)
			else
				warn(string.format("Failed to convert [%s] %q into children", tostring(key), tostring(item)))
			end
		end

		if next(observables) then
			return Rx.merge(observables)
		else
			return nil
		end
	end

	return nil
end

--[=[
	Mounts the instance to the props. This handles mounting children, and events.

	The contract is that the props table is turned into observables. Note the following.

	* Keys of strings are turned into properties
		* If this can be turned into an observable, it will be used to subscribe to this event
		* Otherwise, we assign directly
	* Keys of functions are invoked on the instance in question
		* `(instance, value) -> Observable
		* If this returns an observable (or can be turned into one), we subscribe the event immediately
	* Keys of numbers (array components) are treated as implicit children
	* If the key is [Blend.Children] then we invoke mountChildren on it.

	```lua
	maid:GiveTask(Blend.mount(frame, {
		BackgroundTransparency = 1;

		-- All items named InventoryFrame
		Blend.Find "Frame" {
			Name = "InventoryFrame"

			-- Apply the following properties
			Blend.New "UIScale" {
				Scale = 0.5;
			};
		};
	}))
	```

	@param instance Instance
	@param props table
	@return Maid
]=]
function Blend.mount(instance: Instance, props: BlendProps): Maid.Maid
	assert(typeof(instance) == "Instance", "Bad instance")

	local maid = Maid.new()

	local parent = nil
	local dependentObservables = {}
	local children = {}

	for key, value in props do
		if type(key) == "string" then
			if key == "Parent" then
				parent = value
			else
				local observable = Blend.toPropertyObservable(value)
				if observable then
					maid:GiveTask(observable:Subscribe(function(result)
						instance[key] = result
						-- task.spawn(function()
						-- 	instance[key] = result
						-- end)
					end))
				else
					-- task.spawn(function()
					-- 	instance[key] = value
					-- end)
					instance[key] = value
				end
			end
		elseif type(key) == "function" then
			local observable = Blend.toEventObservable(key(instance, value))

			if Observable.isObservable(observable) then
				table.insert(dependentObservables, { observable, value })
			else
				warn(string.format("Unable to apply event listener %q", tostring(key)))
			end
		elseif type(key) == "number" then
			-- Treat this as an implicit children contract
			-- Thus, we don't need an explicit [Blend.Children] call.
			table.insert(children, value)
		else
			warn(string.format("Unable to apply property %q", tostring(key)))
		end
	end

	if #children > 0 then
		maid:GiveTask(Blend.Children(instance, children):Subscribe())
	end

	-- Subscribe dependentObservables (which includes adding children)
	for _, event in dependentObservables do
		maid:GiveTask(event[1]:Subscribe(Blend.toEventHandler(event[2])))
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

	return maid
end

return Blend
