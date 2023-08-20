--[=[
	@class RxSignal
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")

local RxSignal = {}
RxSignal.ClassName = "RxSignal"
RxSignal.__index = RxSignal

--[=[
	Converts an observable to the Signal interface

	@param observable Observable<T>
	@return RxSignal<T>
]=]
function RxSignal.new(observable)
	assert(observable, "No observable")

	local self = setmetatable({}, RxSignal)

	self._observable = observable:Pipe({
		Rx.skip(1);
	})

	return self
end

function RxSignal:Connect(callback)
	return self._observable:Subscribe(callback)
end

function RxSignal:Once(callback)
	return self._observable:Pipe({
		Rx.take(1);
	}):Subscribe(callback)
end

return RxSignal