--[=[
	@class PromiseRetryUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Math = require("Math")

local PromiseRetryUtils = {}

function PromiseRetryUtils.retry(callback, options)
	assert(type(options.initialWaitTime) == "number", "Bad initialWaitTime")
	assert(type(options.maxAttempts) == "number", "Bad maxAttempts")
	assert(type(options.printWarning) == "boolean", "Bad printWarning")
	assert(options.maxAttempts >= 1, "Bad maxAttempts")

	local promise = Promise.new()
	local isLoopResolved = false

	local running = task.spawn(function()
		local waitTime = options.initialWaitTime
		local lastResults

		for attemptNumber=1, options.maxAttempts do
			lastResults = table.pack(callback():Yield())

			if lastResults[1] then
				isLoopResolved = true
				promise:Resolve(table.unpack(lastResults, 2, lastResults.n))
				return
			end

			if options.printWarning then
				warn(string.format("[PromiseRetryUtils] - Retrying %d/%d due to failure %q", attemptNumber, options.maxAttempts, tostring(lastResults[2])))
			end

			task.wait(Math.jitter(waitTime * 2^attemptNumber))
		end

		isLoopResolved = true
		local errorMessage = string.format("Attempted request %d times before failing with error", tostring(lastResults[2]))
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