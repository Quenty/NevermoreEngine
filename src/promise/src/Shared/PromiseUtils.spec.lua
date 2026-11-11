--!nonstrict
--[[
	@class PromiseUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local PromiseUtils = require("PromiseUtils")
local Signal = require("Signal")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PromiseUtils.any / race", function()
	it("is aliased as race", function()
		expect(PromiseUtils.race).toBe(PromiseUtils.any)
	end)

	it("resolves with the first promise to resolve", function()
		local a = Promise.new()
		local b = Promise.resolved("b wins")

		local outcome, value = PromiseTestUtils.awaitOutcome(PromiseUtils.any({ a, b }))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("b wins")

		a:Resolve("ignored")
	end)

	it("rejects if the first to settle rejects", function()
		local outcome, err =
			PromiseTestUtils.awaitOutcome(PromiseUtils.any({ Promise.new(), Promise.rejected("boom") }))
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("boom")
	end)
end)

describe("PromiseUtils.delayed", function()
	it("resolves after the delay", function()
		local outcome = PromiseTestUtils.awaitOutcome(PromiseUtils.delayed(0))
		expect(outcome).toEqual("resolved")
	end)

	it("is pending before the delay elapses", function()
		local promise = PromiseUtils.delayed(10)
		expect(promise:IsPending()).toEqual(true)
	end)
end)

describe("PromiseUtils.all", function()
	it("resolves an empty list immediately", function()
		expect(PromiseUtils.all({}):IsFulfilled()).toEqual(true)
	end)

	it("returns the same promise for a single-element list", function()
		local only = Promise.resolved("only")
		expect(PromiseUtils.all({ only })).toBe(only)
	end)

	it("resolves with every value once all resolve", function()
		local combined = PromiseUtils.all({ Promise.resolved("a"), Promise.resolved("b"), Promise.resolved("c") })

		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		local ok, a, b, c = combined:GetResults()
		expect(ok).toEqual(true)
		expect(a).toEqual("a")
		expect(b).toEqual("b")
		expect(c).toEqual("c")
	end)

	it("rejects if any promise rejects", function()
		-- all() rejects with the positional results array (resolved values and rejection reasons mixed
		-- by index), so only the rejected outcome itself is asserted here.
		local outcome =
			PromiseTestUtils.awaitOutcome(PromiseUtils.all({ Promise.resolved("a"), Promise.rejected("nope") }))
		expect(outcome).toEqual("rejected")
	end)

	it("waits for pending promises before resolving", function()
		local pending = Promise.new()
		local combined = PromiseUtils.all({ Promise.resolved("a"), pending })
		expect(combined:IsPending()).toEqual(true)

		pending:Resolve("b")
		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		local ok, a, b = combined:GetResults()
		expect(ok).toEqual(true)
		expect(a).toEqual("a")
		expect(b).toEqual("b")
	end)
end)

describe("PromiseUtils.firstSuccessOrLastFailure", function()
	it("resolves with the first success", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(
			PromiseUtils.firstSuccessOrLastFailure({ Promise.rejected("bad"), Promise.resolved("good") })
		)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("good")
	end)

	it("rejects with the last failure when all fail", function()
		local outcome, err = PromiseTestUtils.awaitOutcome(
			PromiseUtils.firstSuccessOrLastFailure({ Promise.rejected("first"), Promise.rejected("last") })
		)
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("last")
	end)

	it("returns the same promise for a single-element list", function()
		local only = Promise.resolved("only")
		expect(PromiseUtils.firstSuccessOrLastFailure({ only })).toBe(only)
	end)
end)

describe("PromiseUtils.combine", function()
	it("passes through a table with no promises", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(PromiseUtils.combine({ a = 1, b = 2 }))
		expect(outcome).toEqual("resolved")
		expect(value.a).toEqual(1)
		expect(value.b).toEqual(2)
	end)

	it("resolves with a table mixing promises and plain values", function()
		local combined = PromiseUtils.combine({ a = Promise.resolved("A"), b = "B" })

		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		local ok, results = combined:GetResults()
		expect(ok).toEqual(true)
		expect(results.a).toEqual("A")
		expect(results.b).toEqual("B")
	end)

	it("rejects if any promise rejects", function()
		local outcome = PromiseTestUtils.awaitOutcome(PromiseUtils.combine({ a = Promise.rejected("bad"), b = "B" }))
		expect(outcome).toEqual("rejected")
	end)

	it("rejects with the results table carrying the error under its key", function()
		local combined = PromiseUtils.combine({
			a = Promise.rejected("bad"),
			b = Promise.resolved("B"),
		})
		combined:Catch(function() end)

		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		local ok, results = combined:GetResults()
		expect(ok).toEqual(false)
		expect(results.a).toEqual("bad")
		expect(results.b).toEqual("B")
	end)

	it("rejects with no values when the only failure is a cancellation", function()
		local pending = Promise.new()
		local combined = PromiseUtils.combine({
			a = pending,
			b = Promise.resolved("B"),
		})

		local rejectionCount = nil
		combined:Then(nil, function(...)
			rejectionCount = select("#", ...)
		end)

		pending:Reject() -- cancellation: rejection with no values

		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		expect(combined:IsRejected()).toEqual(true)
		expect(rejectionCount).toEqual(0)
	end)

	it("still rejects with the results table when a cancellation and a real error mix", function()
		local cancelled = Promise.new()
		local combined = PromiseUtils.combine({
			a = cancelled,
			b = Promise.rejected("bad"),
			c = Promise.resolved("C"),
		})
		combined:Catch(function() end)

		cancelled:Reject()

		expect(PromiseTestUtils.awaitSettled(combined)).toEqual(true)
		local ok, results = combined:GetResults()
		expect(ok).toEqual(false)
		expect(results.a).toEqual(nil)
		expect(results.b).toEqual("bad")
		expect(results.c).toEqual("C")
	end)
end)

describe("PromiseUtils.invert", function()
	it("turns a resolved promise into a rejection", function()
		local outcome, err = PromiseTestUtils.awaitOutcome(PromiseUtils.invert(Promise.resolved("was ok")))
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("was ok")
	end)

	it("turns a rejected promise into a resolution", function()
		local source = Promise.rejected("was bad")

		local outcome, value = PromiseTestUtils.awaitOutcome(PromiseUtils.invert(source))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("was bad")
	end)

	it("inverts a pending promise once it settles", function()
		local source = Promise.new()
		local inverted = PromiseUtils.invert(source)
		expect(inverted:IsPending()).toEqual(true)

		source:Resolve("later")
		local outcome, err = PromiseTestUtils.awaitOutcome(inverted)
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("later")
	end)
end)

describe("PromiseUtils.fromSignal", function()
	it("resolves when the signal fires", function()
		local signal = Signal.new()
		local promise = PromiseUtils.fromSignal(signal)
		expect(promise:IsPending()).toEqual(true)

		signal:Fire("fired")

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("fired")

		signal:Destroy()
	end)

	it("disconnects the signal once settled", function()
		local signal = Signal.new()
		local promise = PromiseUtils.fromSignal(signal)

		signal:Fire("first")
		PromiseTestUtils.awaitSettled(promise)

		-- A second fire must not change the already-resolved value.
		signal:Fire("second")
		local _ok, value = promise:GetResults()
		expect(value).toEqual("first")

		signal:Destroy()
	end)
end)

describe("PromiseUtils.timeout", function()
	it("returns the same promise when it is already settled", function()
		local settled = Promise.resolved("done")
		expect(PromiseUtils.timeout(1, settled)).toBe(settled)
	end)

	it("rejects once the timeout elapses", function()
		local outcome = PromiseTestUtils.awaitOutcome(PromiseUtils.timeout(0, Promise.new()))
		expect(outcome).toEqual("rejected")
	end)

	it("resolves with the underlying value if it settles before the timeout", function()
		local source = Promise.new()
		local promise = PromiseUtils.timeout(10, source)
		expect(promise:IsPending()).toEqual(true)

		source:Resolve("in time")
		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("in time")
	end)
end)
