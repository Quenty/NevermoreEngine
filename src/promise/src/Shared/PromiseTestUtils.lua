--!strict
--[=[
	Test helpers for awaiting promises with a bounded timeout, so a hung promise fails the test
	instead of freezing the runner. Awaiting races the promise against a timeout rather than polling
	with `task.wait()`.

	@class PromiseTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")

local PromiseTestUtils = {}

local DEFAULT_TIMEOUT = 5

--[=[
	Yields until the promise settles (resolves or rejects) or the timeout elapses. Races the promise
	against a timeout instead of polling.

	@param promise Promise
	@param timeout number? -- Defaults to 5 seconds
	@return boolean -- true if the promise settled, false if it timed out
]=]
function PromiseTestUtils.awaitSettled<T...>(promise: Promise.Promise<T...>, timeout: number?): boolean
	if not promise:IsPending() then
		-- Attach a handler so an already-rejected promise is not flagged as an uncaught exception.
		promise:Catch(function() end)
		return true
	end

	local settled = Promise.new()
	local function markSettled()
		settled:Resolve(true)
	end
	promise:Then(markSettled, markSettled)

	local timedOut = PromiseUtils.delayed(timeout or DEFAULT_TIMEOUT):Then(function()
		return false
	end)

	return (PromiseUtils.race({ settled, timedOut }):Wait())
end

--[=[
	Yields until the predicate returns a truthy value or the timeout elapses. Used when the awaited
	condition is observable state rather than a promise.

	@param predicate () -> boolean
	@param timeout number? -- Defaults to 5 seconds
	@return boolean -- The final predicate result
]=]
function PromiseTestUtils.awaitValue(predicate: () -> boolean, timeout: number?): boolean
	local deadline = os.clock() + (timeout or DEFAULT_TIMEOUT)
	while not predicate() and os.clock() < deadline do
		task.wait()
	end
	return predicate()
end

--[=[
	Attaches resolve/reject handlers synchronously (so the rejection is always handled and never
	surfaces as an uncaught error) and yields for the outcome.

	@param promise Promise
	@param timeout number? -- Defaults to 5 seconds
	@return "resolved" | "rejected" | "pending"
	@return any -- The resolved value or rejection error
]=]
function PromiseTestUtils.awaitOutcome<T...>(promise: Promise.Promise<T...>, timeout: number?): (string, any)
	local outcome: string?
	local payload: any
	promise:Then(function(value)
		outcome, payload = "resolved", value
	end, function(err)
		outcome, payload = "rejected", err
	end)

	PromiseTestUtils.awaitSettled(promise, timeout)

	return outcome or "pending", payload
end

return PromiseTestUtils
