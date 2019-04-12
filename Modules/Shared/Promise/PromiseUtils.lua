--- Utility methods for promise
-- @module PromiseUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local lib = {}

--- Returns the value of the first promise resolved
-- @constructor First
-- @tparam Array(Promise) promises
-- @treturn Promise Promise that resolves with first result
function lib.race(promises)
	local returnPromise = Promise.new()

	local function syncronize(method)
		return function(...)
			returnPromise[method](returnPromise, ...)
		end
	end

	for _, promise in pairs(promises) do
		promise:Then(syncronize("Resolve"), syncronize("Reject"))
	end

	return returnPromise
end

--- Executes all promises. If any fails, the result will be rejected. However, it yields until
--  every promise is complete
-- @constructor First
-- @treturn Promise
function lib.all(promises)
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

	if #promises == 0 then
		returnPromise:Resolve()
	end

	return returnPromise
end

return lib