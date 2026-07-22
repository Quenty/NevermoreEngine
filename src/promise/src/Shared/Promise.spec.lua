--!nonstrict
--[[
	@class Promise.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Promise.isPromise", function()
	it("returns true for a promise", function()
		expect(Promise.isPromise(Promise.new())).toEqual(true)
		expect(Promise.isPromise(Promise.resolved(1))).toEqual(true)
	end)

	it("returns false for non-promise values", function()
		expect(Promise.isPromise(nil)).toEqual(false)
		expect(Promise.isPromise(5)).toEqual(false)
		expect(Promise.isPromise("Promise")).toEqual(false)
		expect(Promise.isPromise({})).toEqual(false)
		expect(Promise.isPromise({ ClassName = "NotAPromise" })).toEqual(false)
	end)
end)

describe("Promise.new", function()
	it("starts pending with no executor", function()
		local promise = Promise.new()
		expect(promise:IsPending()).toEqual(true)
		expect(promise:IsFulfilled()).toEqual(false)
		expect(promise:IsRejected()).toEqual(false)
	end)

	it("resolves synchronously when the executor calls resolve", function()
		local promise = Promise.new(function(resolve)
			resolve("value")
		end)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("value")
	end)

	it("rejects when the executor calls reject", function()
		local promise = Promise.new(function(_resolve, reject)
			reject("boom")
		end)

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("boom")
	end)
end)

describe("Promise.spawn", function()
	it("resolves from a spawned executor", function()
		local promise = Promise.spawn(function(resolve)
			resolve("spawned")
		end)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("spawned")
	end)
end)

describe("Promise.delay", function()
	it("resolves after the delay elapses", function()
		local promise = Promise.delay(0, function(resolve)
			resolve("delayed")
		end)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("delayed")
	end)

	it("is pending before the delay elapses", function()
		local promise = Promise.delay(10, function(resolve)
			resolve("late")
		end)
		expect(promise:IsPending()).toEqual(true)
	end)
end)

describe("Promise.defer", function()
	it("resolves from a deferred executor", function()
		local promise = Promise.defer(function(resolve)
			resolve("deferred")
		end)

		expect(promise:IsPending()).toEqual(true)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("deferred")
	end)
end)

describe("Promise.resolved", function()
	it("creates an already-fulfilled promise", function()
		local promise = Promise.resolved("done")
		expect(promise:IsFulfilled()).toEqual(true)
		expect(promise:IsPending()).toEqual(false)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("done")
	end)

	it("reuses a single shared promise when resolving with no values", function()
		expect(Promise.resolved()).toBe(Promise.resolved())
	end)

	it("returns the same promise when resolving an already-settled promise", function()
		local inner = Promise.resolved("inner")
		expect(Promise.resolved(inner)).toBe(inner)
	end)
end)

describe("Promise.rejected", function()
	it("creates an already-rejected promise", function()
		local outcome, err = PromiseTestUtils.awaitOutcome(Promise.rejected("nope"))
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("nope")
	end)

	it("reuses a single shared promise when rejecting with no values", function()
		expect(Promise.rejected()).toBe(Promise.rejected())
	end)
end)

describe("Promise:Resolve", function()
	it("fulfills a pending promise", function()
		local promise = Promise.new()
		promise:Resolve(1, 2, 3)

		local ok, a, b, c = promise:GetResults()
		expect(ok).toEqual(true)
		expect(a).toEqual(1)
		expect(b).toEqual(2)
		expect(c).toEqual(3)
	end)

	it("rejects with a TypeError when resolving to itself", function()
		local promise = Promise.new()
		promise:Resolve(promise)

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "Resolved to self", 1, true) ~= nil).toEqual(true)
	end)

	it("adopts the state of a resolved promise", function()
		local promise = Promise.new()
		promise:Resolve(Promise.resolved("adopted"))

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("adopted")
	end)

	it("adopts the rejection of a rejected promise", function()
		local promise = Promise.new()
		promise:Resolve(Promise.rejected("adopted rejection"))

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("adopted rejection")
	end)

	it("adopts the state of a pending promise once it settles", function()
		local inner = Promise.new()
		local promise = Promise.new()
		promise:Resolve(inner)

		expect(promise:IsPending()).toEqual(true)

		inner:Resolve("later")

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("later")
	end)

	it("is a no-op once the promise has settled", function()
		local promise = Promise.resolved("first")
		promise:Resolve("second")

		local _ok, value = promise:GetResults()
		expect(value).toEqual("first")
	end)
end)

describe("Promise:Reject", function()
	it("rejects a pending promise", function()
		local promise = Promise.new()
		promise:Catch(function() end)
		promise:Reject("rejected")

		local ok, err = promise:GetResults()
		expect(ok).toEqual(false)
		expect(err).toEqual("rejected")
	end)

	it("is a no-op once the promise has settled", function()
		local promise = Promise.resolved("value")
		promise:Reject("too late")
		expect(promise:IsFulfilled()).toEqual(true)
		expect(promise:IsRejected()).toEqual(false)
	end)
end)

describe("Promise:Wait", function()
	it("returns the fulfilled values", function()
		local a, b = Promise.resolved(1, 2):Wait()
		expect(a).toEqual(1)
		expect(b).toEqual(2)
	end)

	it("errors when the promise is rejected", function()
		local promise = Promise.rejected("boom")
		local ok, err = pcall(function()
			promise:Wait()
		end)
		expect(ok).toEqual(false)
		expect(string.find(tostring(err), "boom", 1, true) ~= nil).toEqual(true)
	end)

	it("yields until a pending promise resolves", function()
		local promise = Promise.new()
		task.defer(function()
			promise:Resolve("eventually")
		end)
		expect(promise:Wait()).toEqual("eventually")
	end)
end)

describe("Promise:Yield", function()
	it("returns true and the values when fulfilled", function()
		local ok, value = Promise.resolved("ok"):Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual("ok")
	end)

	it("returns false and the error when rejected", function()
		local promise = Promise.rejected("bad")
		local ok, err = promise:Yield()
		expect(ok).toEqual(false)
		expect(err).toEqual("bad")
	end)

	it("yields until a pending promise settles", function()
		local promise = Promise.new()
		task.defer(function()
			promise:Resolve("settled")
		end)
		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual("settled")
	end)
end)

describe("Promise:Then", function()
	it("calls onFulfilled with the resolved value", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved(10):Then(function(n)
			return n * 2
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(20)
	end)

	it("calls onRejected with the rejection reason", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.rejected("err"):Then(nil, function(err)
			return "recovered from " .. err
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("recovered from err")
	end)

	it("propagates fulfillment when onFulfilled is omitted", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved("passthrough"):Then(nil, function() end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("passthrough")
	end)

	it("propagates rejection when onRejected is omitted", function()
		local source = Promise.rejected("still bad")
		-- Then with no onRejected does not consume the source rejection, so handle it separately to
		-- avoid an uncaught-exception warning.
		source:Catch(function() end)

		local outcome, err = PromiseTestUtils.awaitOutcome(source:Then(function() end))
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("still bad")
	end)

	it("runs handlers attached while pending", function()
		local promise = Promise.new()
		local chained = promise:Then(function(n)
			return n + 1
		end)

		task.defer(function()
			promise:Resolve(41)
		end)

		local outcome, value = PromiseTestUtils.awaitOutcome(chained)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(42)
	end)

	it("chains when the handler returns a promise", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved(1):Then(function()
			return Promise.resolved("from inner promise")
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("from inner promise")
	end)
end)

describe("Promise:Catch", function()
	it("handles a rejection", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.rejected("caught"):Catch(function(err)
			return "handled " .. err
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("handled caught")
	end)

	it("does not fire for a fulfilled promise", function()
		local called = { value = false }
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved("fine"):Catch(function()
			called.value = true
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("fine")
		expect(called.value).toEqual(false)
	end)
end)

describe("Promise:Tap", function()
	it("passes the original value through regardless of the handler return", function()
		local seen = {}
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved("original"):Tap(function(v)
			seen.value = v
			return "ignored"
		end))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("original")
		expect(seen.value).toEqual("original")
	end)
end)

describe("Promise:Finally", function()
	it("runs on fulfillment", function()
		local ran = { value = false }
		Promise.resolved("x"):Finally(function()
			ran.value = true
		end)
		expect(ran.value).toEqual(true)
	end)

	it("runs on rejection", function()
		local ran = { value = false }
		Promise.rejected("x"):Finally(function()
			ran.value = true
		end)
		expect(ran.value).toEqual(true)
	end)
end)

describe("Promise:Destroy", function()
	it("rejects the promise", function()
		local promise = Promise.new()
		promise:Catch(function() end)
		promise:Destroy()
		expect(promise:IsRejected()).toEqual(true)
	end)
end)

describe("Promise:GetResults", function()
	it("errors while pending", function()
		local ok, err = pcall(function()
			Promise.new():GetResults()
		end)
		expect(ok).toEqual(false)
		expect(string.find(tostring(err), "pending", 1, true) ~= nil).toEqual(true)
	end)

	it("returns true and the values when fulfilled", function()
		local ok, a, b = Promise.resolved("a", "b"):GetResults()
		expect(ok).toEqual(true)
		expect(a).toEqual("a")
		expect(b).toEqual("b")
	end)

	it("returns false and the error when rejected", function()
		local promise = Promise.rejected("failure")
		local ok, err = promise:GetResults()
		expect(ok).toEqual(false)
		expect(err).toEqual("failure")
	end)

	it("consumes the rejection", function()
		local promise = Promise.rejected("failure")
		promise:GetResults()
		expect((promise :: any)._unconsumedException).toEqual(false)
	end)
end)

describe("Promise._toHumanReadable", function()
	local promise = Promise.new()

	it("stringifies non-table values", function()
		expect(promise:_toHumanReadable("failure")).toEqual("failure")
		expect(promise:_toHumanReadable(5)).toEqual("5")
		expect(promise:_toHumanReadable(nil)).toEqual("nil")
		expect(promise:_toHumanReadable(false)).toEqual("false")
	end)

	it("uses a table's custom __tostring when present", function()
		local data = setmetatable({}, {
			__tostring = function()
				return "CustomError<oops>"
			end,
		})
		expect(promise:_toHumanReadable(data)).toEqual("CustomError<oops>")
	end)

	it("JSON-encodes a plain table instead of returning its address", function()
		expect(promise:_toHumanReadable({ code = 500 })).toEqual('{"code":500}')
		expect(promise:_toHumanReadable({})).toEqual("[]")
	end)

	it("falls back to tostring when the table cannot be JSON-encoded", function()
		local data = {}
		data.cycle = data
		local result = promise:_toHumanReadable(data)
		expect(string.sub(result, 1, 9)).toEqual("table: 0x")
	end)
end)
