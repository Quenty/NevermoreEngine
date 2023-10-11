--[=[
	@class RxSignal
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local Observable = require("Observable")

local RxSignal = {}
RxSignal.ClassName = "RxSignal"
RxSignal.__index = RxSignal

--[=[
	Converts an observable to the Signal interface

	@param observable Observable<T> | () -> Observable<T>
	@return RxSignal<T>
]=]
function RxSignal.new(observable)
	assert(observable, "No observable")

	local self = setmetatable({}, RxSignal)

	self._observable = observable

	return self
end

function RxSignal:Connect(callback)
	return self:_getObservable():Subscribe(callback)
end

function RxSignal:_getObservable()
	if Observable.isObservable(self._observable) then
		return self._observable
	end

	if type(self._observable) == "function" then
		local result = self._observable()

		assert(Observable.isObservable(result), "Result should be observable")

		return result
	else
		error("Could not convert self._observable to observable")
	end
end

function RxSignal:Once(callback)
	return self:_getObservable():Pipe({
		Rx.take(1);
	}):Subscribe(callback)
end

return RxSignal