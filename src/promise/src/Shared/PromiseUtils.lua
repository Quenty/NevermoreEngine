--[=[
	Utility methods for promise
	@class PromiseUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local PromiseUtils = {}

--[=[
	Returns the value of the first promise resolved
	@param promises { Promise<T> }
	@return Promise<T> -- Promise that resolves with first result
]=]
function PromiseUtils.any(promises)
	local returnPromise = Promise.new()

	local function resolve(...)
		returnPromise:Resolve(...)
	end

	local function reject(...)
		returnPromise:Reject(...)
	end

	for _, promise in pairs(promises) do
		promise:Then(resolve, reject)
	end

	return returnPromise
end

--[=[
	Returns a promise that will resolve after the set amount of seconds

	@param seconds number
	@return Promise
]=]
function PromiseUtils.delayed(seconds)
	assert(type(seconds) == "number", "Bad seconds")

	return Promise.delay(seconds, function(resolve, _reject)
		resolve()
	end)
end

--[=[
	Executes all promises. If any fails, the result will be rejected. However, it yields until
	every promise is complete.

	:::warning
	Passing in a spare array (i.e. {nil, promise}) will result in undefined behavior here.
	:::

	@param promises { Promise<T> }
	@return Promise<T>
]=]
function PromiseUtils.all(promises)
	if #promises == 0 then
		return Promise.resolved()
	elseif #promises == 1 then
		return promises[1]
	end

	local remainingCount = #promises
	local returnPromise = Promise.new()
	local results = {}
	local allFulfilled = true

	local function syncronize(index, isFullfilled)
		return function(value)
			allFulfilled = allFulfilled and isFullfilled
			results[index] = value
			remainingCount = remainingCount - 1
			if remainingCount == 0 then
				local method = allFulfilled and "Resolve" or "Reject"
				returnPromise[method](returnPromise, unpack(results, 1, #promises))
			end
		end
	end

	for index, promise in pairs(promises) do
		promise:Then(syncronize(index, true), syncronize(index, false))
	end

	return returnPromise
end

--[=[
	Combines the result of promises together

	@param stateTable any
	@return Promise<any>
]=]
function PromiseUtils.combine(stateTable)
	assert(type(stateTable) == "table", "Bad stateTable")

	local remainingCount = 0
	local results = {}

	for key, value in pairs(stateTable) do
		if Promise.isPromise(value) then
			remainingCount = remainingCount + 1
		else
			results[key] = value
		end
	end

	if remainingCount == 0 then
		return Promise.resolved(stateTable)
	end

	local returnPromise = Promise.new()
	local allFulfilled = true

	local function syncronize(key, isFullfilled)
		return function(value)
			allFulfilled = allFulfilled and isFullfilled
			results[key] = value
			remainingCount = remainingCount - 1

			if remainingCount == 0 then
				local method = allFulfilled and "Resolve" or "Reject"
				returnPromise[method](returnPromise, results)
			end
		end
	end

	for key, value in pairs(stateTable) do
		if Promise.isPromise(value) then
			value:Then(syncronize(key, true), syncronize(key, false))
		end
	end

	return returnPromise
end

--[=[
	Inverts the result of a promise, turning a resolved promise
	into a rejected one, and a rejected one into a resolved one.

	@param promise Promise<T>
	@return Promise<T>
]=]
function PromiseUtils.invert(promise)
	if promise:IsPending() then
		return promise:Then(function(...)
			return Promise.rejected(...)
		end, function(...)
			return Promise.resolved(...)
		end)
	else
		local results = {promise:GetResults()}
		if results[1] then
			return Promise.rejected(unpack(results, 2))
		else
			return Promise.resolved(unpack(results, 2))
		end
	end
end

--[=[
	Creates a promise from a signal

	@param signal Signal<T>
	@return Promise<T>
]=]
function PromiseUtils.fromSignal(signal)
	local promise = Promise.new()
	local conn

	promise:Finally(function()
		conn:Disconnect()
		conn = nil
	end)

	conn = signal:Connect(function(...)
		promise:Resolve(...)
	end)

	return promise
end

--[=[
	Creates a new promise from the given promise that will
	reject after the given `timeoutTime`

	@param timeoutTime number
	@param fromPromise Promise<T>
	@return Promise<T>
]=]
function PromiseUtils.timeout(timeoutTime, fromPromise)
	assert(type(timeoutTime) == "number", "Bad timeoutTime")
	assert(fromPromise, "Bad fromPromise")

	if not fromPromise:IsPending() then
		return fromPromise
	end

	local promise = Promise.new()

	promise:Resolve(fromPromise)

	task.delay(timeoutTime, function()
		promise:Reject()
	end)

	return promise
end

return PromiseUtils