--!nonstrict
--[[
	@class PromiseRetryUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseRetryUtils = require("PromiseRetryUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAST_OPTIONS = {
	initialWaitTime = 0,
	maxAttempts = 3,
	printWarning = false,
}

-- Returns a callback that rejects with `errorMessage` for its first `failureCount` attempts, then
-- resolves with `value`, and a counter table exposing how many attempts were made.
local function newFlakyCallback(failureCount: number, errorMessage: string, value: any)
	local attempts = { count = 0 }
	local function callback()
		attempts.count += 1
		if attempts.count <= failureCount then
			-- Reject asynchronously so retry attaches a rejection handler (consuming the exception)
			-- rather than reading an already-rejected promise, which would be flagged as uncaught.
			return Promise.defer(function(_resolve, reject)
				reject(errorMessage)
			end)
		end
		return Promise.resolved(value)
	end
	return callback, attempts
end

describe("PromiseRetryUtils.retry", function()
	it("resolves on the first attempt without retrying", function()
		local callback, attempts = newFlakyCallback(0, "boom", "done")

		local outcome, value = PromiseTestUtils.awaitOutcome(PromiseRetryUtils.retry(callback, FAST_OPTIONS))

		expect(outcome).toEqual("resolved")
		expect(value).toEqual("done")
		expect(attempts.count).toEqual(1)
	end)

	it("retries after a failure and resolves once the callback succeeds", function()
		local callback, attempts = newFlakyCallback(2, "boom", "done")

		local outcome, value = PromiseTestUtils.awaitOutcome(PromiseRetryUtils.retry(callback, FAST_OPTIONS))

		expect(outcome).toEqual("resolved")
		expect(value).toEqual("done")
		expect(attempts.count).toEqual(3)
	end)

	it("rejects after exhausting maxAttempts", function()
		local callback, attempts = newFlakyCallback(math.huge, "always fails", nil)

		local outcome, err = PromiseTestUtils.awaitOutcome(PromiseRetryUtils.retry(callback, FAST_OPTIONS))

		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "always fails", 1, true) ~= nil).toEqual(true)
		expect(attempts.count).toEqual(3)
	end)

	it("stops immediately and rejects with the error when shouldRetry returns false", function()
		local callback, attempts = newFlakyCallback(math.huge, "fatal 509", nil)

		local outcome, err = PromiseTestUtils.awaitOutcome(PromiseRetryUtils.retry(callback, {
			initialWaitTime = 0,
			maxAttempts = 5,
			printWarning = false,
			shouldRetry = function()
				return false
			end,
		}))

		expect(outcome).toEqual("rejected")
		expect(err).toEqual("fatal 509")
		expect(attempts.count).toEqual(1)
	end)

	it("keeps retrying while shouldRetry returns true", function()
		local callback, attempts = newFlakyCallback(math.huge, "retryable", nil)
		local consulted = { count = 0 }

		local outcome = PromiseTestUtils.awaitOutcome(PromiseRetryUtils.retry(callback, {
			initialWaitTime = 0,
			maxAttempts = 3,
			printWarning = false,
			shouldRetry = function(err)
				consulted.count += 1
				expect(err).toEqual("retryable")
				return true
			end,
		}))

		expect(outcome).toEqual("rejected")
		expect(attempts.count).toEqual(3)
		-- Consulted after every failure, including the final attempt.
		expect(consulted.count).toEqual(3)
	end)
end)
