--!strict
--[=[
	@class RxSignal
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Rx = require("Rx")
local Subscription = require("Subscription")

local RxSignal = {}
RxSignal.ClassName = "RxSignal"
RxSignal.__index = RxSignal

export type RxSignal<T...> = typeof(setmetatable(
	{} :: {
		_observable: Observable.Observable<T...> | () -> Observable.Observable<T...>,
	},
	{} :: typeof({ __index = RxSignal })
))

--[=[
	Converts an observable to the Signal interface

	@param observable Observable<T> | () -> Observable<T>
	@return RxSignal<T>
]=]
function RxSignal.new<T...>(observable: Observable.Observable<T...> | () -> Observable.Observable<T...>): RxSignal<T...>
	assert(observable, "No observable")

	local self = setmetatable({}, RxSignal)

	self._observable = observable

	return self
end

--[=[
	Connects to the signal and returns a subscription
]=]
function RxSignal.Connect<T...>(self: RxSignal<T...>, callback: (T...) -> ()): Subscription.Subscription<T...>
	return self:_getObservable():Subscribe(callback)
end

--[=[
	Waits for the signal to fire and returns the values
]=]
function RxSignal.Wait<T...>(self: RxSignal<T...>): T...
	local waitingCoroutine = coroutine.running()

	local subscription: Subscription.Subscription<T...>
	subscription = self:Connect(function(...)
		subscription:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)

	return coroutine.yield()
end

--[=[
	Connects once to the signal and returns a subscription
]=]
function RxSignal.Once<T...>(self: RxSignal<T...>, callback: (T...) -> ()): Subscription.Subscription<T...>
	return self:_getObservable()
		:Pipe({
			Rx.take(1) :: any,
		})
		:Subscribe(callback)
end

function RxSignal._getObservable<T...>(self: RxSignal<T...>): Observable.Observable<T...>
	if Observable.isObservable(self._observable) then
		return self._observable :: Observable.Observable<T...>
	end

	if type(self._observable) == "function" then
		local result = self._observable()

		assert(Observable.isObservable(result), "Result should be observable")

		return result
	else
		error("Could not convert self._observable to observable")
	end
end

return RxSignal
