--!nonstrict
--[[
	@class promiseWait.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local promiseWait = require("promiseWait")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("promiseWait", function()
	it("resolves after the delay elapses", function()
		local outcome = PromiseTestUtils.awaitOutcome(promiseWait(0))
		expect(outcome).toEqual("resolved")
	end)

	it("is pending before the delay elapses", function()
		local promise = promiseWait(10)
		expect(promise:IsPending()).toEqual(true)
	end)
end)
