--!nonstrict
--[[
	@class DataStoreLoadErrors.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local jest = Jest.Globals.jest

describe("shared load promise fan-out", function()
	it("delivers the resolution to every consumer of the shared load", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:SetRaw("key", { a = 1, b = 2 })
		local dataStore = controller.newDataStore("key")

		local valueA, valueB, all
		dataStore:Load("a"):Then(function(value)
			valueA = value
		end)
		dataStore:Load("b"):Then(function(value)
			valueB = value
		end)
		dataStore:LoadAll():Then(function(value)
			all = value
		end)

		expect(valueA).toEqual(1)
		expect(valueB).toEqual(2)
		expect(all).toEqual({ a = 1, b = 2 })

		controller:Destroy()
	end)

	it("resolves all consumers of a slow (yielding) load attached during the yield", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:SetRaw("key", { a = 1 })
		controller.mock:SetYieldTime(0.3)
		local dataStore = controller.newDataStore("key")

		local loads = {}
		for i = 1, 3 do
			loads[i] = dataStore:Load("a")
		end

		for _, load in loads do
			expect(PromiseTestUtils.awaitFulfilled(load)).toEqual(1)
		end

		controller:Destroy()
	end)

	it("delivers the rejection to every consumer when the shared load fails", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()
		local dataStore = controller.newDataStore("key")

		local aRejected, bRejected = false, false
		dataStore:Load("a"):Then(nil, function()
			aRejected = true
		end)
		dataStore:Load("b"):Then(nil, function()
			bRejected = true
		end)

		expect(aRejected and bRejected).toBe(true)

		controller:Destroy()
	end)
end)

describe("auto-save loop", function()
	it("persists staged data on the auto-save schedule without an explicit Save", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")
		dataStore:SetAutoSaveTimeSeconds(0.2)

		dataStore:Store("coins", 5)

		PromiseTestUtils.awaitFulfilled(dataStore.Saving:Wait())
		expect(controller.mock:GetRaw("key").coins).toEqual(5)

		controller:Destroy()
	end)

	it("stops auto-saving after the datastore is destroyed", function()
		JestUtils.useFakeTimers()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")
		dataStore:SetAutoSaveTimeSeconds(0.2)
		dataStore:Store("coins", 5)

		jest.advanceTimersByTime(250)
		expect(controller.mock:GetRaw("key").coins).toEqual(5)

		dataStore:Destroy()

		local before = controller.mock:GetCallCount("UpdateAsync")
		jest.advanceTimersByTime(1000)
		expect(controller.mock:GetCallCount("UpdateAsync")).toEqual(before)

		controller:Destroy()
	end)
end)
