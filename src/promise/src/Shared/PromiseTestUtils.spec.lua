--!nonstrict
--[[
	@class PromiseTestUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SHORT_TIMEOUT = 0.1

describe("PromiseTestUtils.awaitSettled", function()
	it("returns true for an already-resolved promise", function()
		expect(PromiseTestUtils.awaitSettled(Promise.resolved(1))).toEqual(true)
	end)

	it("returns true for a rejected promise", function()
		expect(PromiseTestUtils.awaitSettled(Promise.rejected("boom"))).toEqual(true)
	end)

	it("returns true once a pending promise resolves", function()
		local promise = Promise.new()
		task.defer(function()
			promise:Resolve(true)
		end)
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)
	end)

	it("returns false when the promise never settles within the timeout", function()
		expect(PromiseTestUtils.awaitSettled(Promise.new(), SHORT_TIMEOUT)).toEqual(false)
	end)
end)

describe("PromiseTestUtils.awaitOutcome", function()
	it("reports a resolved value", function()
		local outcome, value = PromiseTestUtils.awaitOutcome(Promise.resolved(42))
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(42)
	end)

	it("reports a rejection error", function()
		local outcome, err = PromiseTestUtils.awaitOutcome(Promise.rejected("boom"))
		expect(outcome).toEqual("rejected")
		expect(err).toEqual("boom")
	end)

	it("reports pending when the promise never settles within the timeout", function()
		local outcome = PromiseTestUtils.awaitOutcome(Promise.new(), SHORT_TIMEOUT)
		expect(outcome).toEqual("pending")
	end)
end)

describe("PromiseTestUtils.awaitValue", function()
	it("returns true once the predicate becomes true", function()
		local flag = { value = false }
		task.defer(function()
			flag.value = true
		end)
		expect(PromiseTestUtils.awaitValue(function()
			return flag.value
		end)).toEqual(true)
	end)

	it("returns false when the predicate never becomes true within the timeout", function()
		expect(PromiseTestUtils.awaitValue(function()
			return false
		end, SHORT_TIMEOUT)).toEqual(false)
	end)
end)
