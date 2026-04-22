--!strict
--[=[
	@class PromiseRetryUtils
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")
local Promise = require("Promise")

local PromiseRetryUtils = {}

export type RetryOptions = {
	exponential: number?,
	initialWaitTime: number,
	maxAttempts: number,
	printWarning: boolean,
}

--[=[
	Returns a promise that will retry the given callback until it succeeds or the max attempts
	is reached.

	https://exponentialbackoffcalculator.com/

	@param callback function -- Callback that returns a promise
	@param options RetryOptions -- Options for retrying
	@return Promise<T>
]=]
function PromiseRetryUtils.retry<T...>(callback: () -> Promise.Promise<T...>, options: RetryOptions): Promise.Promise<T...>
	assert(type(options.initialWaitTime) == "number", "Bad initialWaitTime")
	assert(type(options.maxAttempts) == "number", "Bad maxAttempts")
	assert(type(options.printWarning) == "boolean", "Bad printWarning")
	assert(options.maxAttempts >= 1, "Bad maxAttempts")

	local promise = Promise.new()
	local isLoopResolved = false
	local start = os.clock()

	local running = task.spawn(function()
		local waitTime = options.initialWaitTime
		local lastResults

		for attemptNumber = 1, options.maxAttempts do
			if not promise:IsPending() then
				return
			end

			lastResults = table.pack(callback():Yield())

			if lastResults[1] then
				isLoopResolved = true
				promise:Resolve(table.unpack(lastResults, 2, lastResults.n))
				return
			end

			if attemptNumber ~= options.maxAttempts then
				local thisWaitTime = Math.jitter(waitTime * ((options.exponential or 2) ^ (attemptNumber - 1)))
				if options.printWarning then
					warn(
						string.format(
							"[PromiseRetryUtils] - Retrying %d/%d (in %fs) due to failure %q",
							attemptNumber,
							options.maxAttempts,
							thisWaitTime,
							tostring(lastResults[2])
						)
					)
				end

				task.wait(thisWaitTime)
			end
		end

		isLoopResolved = true
		local totalTime = os.clock() - start
		local errorMessage = string.format(
			"Attempted request %d times (over %0.2fs) before failing with error %s",
			options.maxAttempts,
			totalTime,
			tostring(lastResults[2])
		)
		promise:Reject(errorMessage, table.unpack(lastResults, 3, lastResults.n))
	end)

	-- Esnure cleanup, but only when we're out of here
	promise:Finally(function()
		if not isLoopResolved then
			task.cancel(running)
		end
	end)

	return promise
end

return PromiseRetryUtils
