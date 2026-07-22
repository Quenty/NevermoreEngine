--!nonstrict
--[[
	@class PendingPromiseTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PendingPromiseTracker = require("PendingPromiseTracker")
local Promise = require("Promise")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PendingPromiseTracker", function()
	it("starts empty", function()
		local tracker = PendingPromiseTracker.new()
		expect(#tracker:GetAll()).toEqual(0)
	end)

	it("tracks a pending promise", function()
		local tracker = PendingPromiseTracker.new()
		tracker:Add(Promise.new())
		expect(#tracker:GetAll()).toEqual(1)
	end)

	it("ignores an already-settled promise", function()
		local tracker = PendingPromiseTracker.new()
		tracker:Add(Promise.resolved("done"))
		expect(#tracker:GetAll()).toEqual(0)
	end)

	it("drops a promise once it resolves", function()
		local tracker = PendingPromiseTracker.new()
		local promise = Promise.new()
		tracker:Add(promise)
		expect(#tracker:GetAll()).toEqual(1)

		promise:Resolve(true)
		expect(#tracker:GetAll()).toEqual(0)
	end)

	it("drops a promise once it rejects", function()
		local tracker = PendingPromiseTracker.new()
		local promise = Promise.new()
		promise:Catch(function() end)
		tracker:Add(promise)
		expect(#tracker:GetAll()).toEqual(1)

		promise:Reject("boom")
		expect(#tracker:GetAll()).toEqual(0)
	end)

	it("tracks multiple pending promises independently", function()
		local tracker = PendingPromiseTracker.new()
		local a = Promise.new()
		local b = Promise.new()
		tracker:Add(a)
		tracker:Add(b)
		expect(#tracker:GetAll()).toEqual(2)

		a:Resolve(true)
		expect(#tracker:GetAll()).toEqual(1)

		b:Resolve(true)
		expect(#tracker:GetAll()).toEqual(0)
	end)
end)
