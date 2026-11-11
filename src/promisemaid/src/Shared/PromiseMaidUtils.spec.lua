--!nonstrict
--[[
	@class PromiseMaidUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PromiseMaidUtils.whilePromise", function()
	it("invokes the callback with a maid while the promise is pending", function()
		local promise = Promise.new()
		local received = { maid = nil }

		PromiseMaidUtils.whilePromise(promise, function(maid)
			received.maid = maid
		end)

		expect(received.maid).never.toEqual(nil)

		promise:Resolve()
	end)

	it("cleans up the maid when the promise settles", function()
		local promise = Promise.new()
		local cleaned = { value = false }

		PromiseMaidUtils.whilePromise(promise, function(maid)
			maid:GiveTask(function()
				cleaned.value = true
			end)
		end)

		expect(cleaned.value).toEqual(false)

		promise:Resolve()
		expect(cleaned.value).toEqual(true)
	end)

	it("cleans up the maid when the promise rejects", function()
		local promise = Promise.new()
		promise:Catch(function() end)
		local cleaned = { value = false }

		PromiseMaidUtils.whilePromise(promise, function(maid)
			maid:GiveTask(function()
				cleaned.value = true
			end)
		end)

		promise:Reject("boom")
		expect(cleaned.value).toEqual(true)
	end)

	it("does not invoke the callback when the promise is already settled", function()
		local called = { value = false }

		PromiseMaidUtils.whilePromise(Promise.resolved(), function()
			called.value = true
		end)

		expect(called.value).toEqual(false)
	end)

	it("cleans up immediately when the callback resolves the promise synchronously", function()
		local promise = Promise.new()
		local cleaned = { value = false }

		PromiseMaidUtils.whilePromise(promise, function(maid)
			maid:GiveTask(function()
				cleaned.value = true
			end)
			promise:Resolve()
		end)

		expect(cleaned.value).toEqual(true)
	end)

	it("throws when given something that is not a promise", function()
		expect(function()
			PromiseMaidUtils.whilePromise(nil, function() end)
		end).toThrow()
	end)

	it("throws when the callback is not a function", function()
		expect(function()
			PromiseMaidUtils.whilePromise(Promise.new(), nil)
		end).toThrow()
	end)
end)
