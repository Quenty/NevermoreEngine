--!strict
--[=[
	Observables are like an [signal](/api/Signal), except they do not execute code
	until the observable is subscribed to. This follows the standard
	Rx API surface for an observable.

	Observables use a [Subscription](/api/Subscription) to emit values.

	```lua
	-- Constucts an observable which will emit a, b, c via a subscription
	local observable = Observable.new(function(sub)
		print("Connected")
		sub:Fire("a")
		sub:Fire("b")
		sub:Fire("c")
		sub:Complete() -- ends stream
	end)

	local sub1 = observable:Subscribe() --> Connected
	local sub2 = observable:Subscribe() --> Connected
	local sub3 = observable:Subscribe() --> Connected

	sub1:Destroy()
	sub2:Destroy()
	sub3:Destroy()
	```

	Note that emitted values may be observed like this

	```lua
	observable:Subscribe(function(value)
		print("Got ", value)
	end)

	--> Got a
	--> Got b
	--> Got c
	```

	Note that also, observables return a [MaidTask](/api/MaidTask) which
	should be used to clean up the resulting subscription.

	```lua
	maid:GiveTask(observable:Subscribe(function(value)
		-- do work here!
	end))
	```

	Observables over signals are nice because observables may be chained and manipulated
	via the Pipe operation.

	:::tip
	You should always clean up the subscription using a [Maid](/api/Maid), otherwise
	you may memory leak.
	:::
	@class Observable
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local MaidTaskUtils = require("MaidTaskUtils")
local Subscription = require("Subscription")

local ENABLE_STACK_TRACING = false

local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

export type OnSubscribe<T...> = (subscription: Subscription.Subscription<T...>) -> MaidTaskUtils.MaidTask?

export type Transformer<T..., U...> = (observable: Observable<T...>) -> Observable<U...>

export type Observable<T...> = typeof(setmetatable(
	{} :: {
		_source: string?,
		_onSubscribe: OnSubscribe<T...>,
	},
	{} :: typeof({ __index = Observable })
))

--[=[
	Returns whether or not a value is an observable.
	@param item any
	@return boolean
]=]
function Observable.isObservable(item: any): boolean
	return DuckTypeUtils.isImplementation(Observable, item)
end

--[=[
	Constructs a new Observable

	```lua
	local function observeAllChildren(parent)
		return Observable.new(function(sub)
			local maid = Maid.new()

			for _, item in parent:GetChildren() do
				sub:Fire(item)
			end
			maid:GiveTask(parent.ChildAdded:Connect(function(child)
				sub:Fire(child)
			end))

			return maid
		end)
	end

	-- Prints out all current children, and whenever a new
	-- child is added to workspace
	local maid = Maid.new()
	maid:GiveTask(observeAllChildren(workspace):Subscribe(print))
	```

	@param onSubscribe (subscription: Subscription<T>) -> MaidTask
	@return Observable<T>
]=]
function Observable.new<T...>(onSubscribe: OnSubscribe<T...>): Observable<T...>
	assert(type(onSubscribe) == "function", "Bad onSubscribe")

	return setmetatable({
		_source = if ENABLE_STACK_TRACING then debug.traceback("Observable.new()", 2) else nil,
		_onSubscribe = onSubscribe,
	}, Observable)
end

--[=[
	Transforms the observable with the following transformers

	```lua
	Rx.of(1, 2, 3):Pipe({
		Rx.map(function(result)
			return result + 1
		end);
		Rx.map(function(value)
			return string.format("%0.2f", value)
		end);
	}):Subscribe(print)

	--> 2.00
	--> 3.00
	--> 4.00
	```
	@param transformers { (observable: Observable<T>) -> Observable<T> }
	@return Observable<T>
]=]
function Observable.Pipe<T...>(self: Observable<T...>, transformers: { Transformer<T..., ...any> }): Observable<...any>
	assert(type(transformers) == "table", "Bad transformers")

	local current: any = self
	for _, transformer in transformers do
		assert(type(transformer) == "function", "Bad transformer")
		current = transformer(current)
		assert(Observable.isObservable(current), "Transformer must return an observable")
	end

	return current
end

--[=[
	Subscribes immediately, fireCallback may return a maid (or a task a maid can handle)
	to clean up

	@param fireCallback function?
	@param failCallback function?
	@param completeCallback function?
	@return MaidTask
]=]
function Observable.Subscribe<T...>(
	self: Observable<T...>,
	fireCallback: Subscription.FireCallback<T...>?,
	failCallback: Subscription.FailCallback?,
	completeCallback: Subscription.CompleteCallback?
): Subscription.Subscription<T...>
	local sub = Subscription.new(fireCallback, failCallback, completeCallback, self._source)

	sub:_assignCleanup(self._onSubscribe(sub))

	return sub :: any
end

return Observable
