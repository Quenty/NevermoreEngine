--!nonstrict
--[[
	Characterizes the shared load promise and the auto-save loop. The load view is cached
	(PromiseViewUpToDate returns one shared promise), so every Load/LoadAll/Store/Observe attaches
	its own continuation to the same promise; these tests pin that a settled load fans out its
	resolution or rejection to every consumer, including ones attached mid-yield.

	@class DataStoreLoadErrors.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

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

		expect(PromiseTestUtils.awaitValue(function()
			return valueA ~= nil and valueB ~= nil and all ~= nil
		end, 5)).toEqual(true)
		expect(valueA).toEqual(1)
		expect(valueB).toEqual(2)
		expect(all).toEqual({ a = 1, b = 2 })

		controller:destroy()
	end)

	it("resolves all consumers of a slow (yielding) load attached during the yield", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:SetRaw("key", { a = 1 })
		controller.mock:SetYieldTime(0.3)
		local dataStore = controller.newDataStore("key")

		local results = {}
		for i = 1, 3 do
			dataStore:Load("a"):Then(function(value)
				results[i] = value
			end)
		end

		expect(PromiseTestUtils.awaitValue(function()
			return results[1] ~= nil and results[2] ~= nil and results[3] ~= nil
		end, 5)).toEqual(true)
		expect(results[1]).toEqual(1)
		expect(results[2]).toEqual(1)
		expect(results[3]).toEqual(1)

		controller:destroy()
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

		expect(PromiseTestUtils.awaitValue(function()
			return aRejected and bRejected
		end, 5)).toEqual(true)

		controller:destroy()
	end)
end)

describe("auto-save loop", function()
	it("persists staged data on the auto-save schedule without an explicit Save", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")
		dataStore:SetAutoSaveTimeSeconds(0.2)

		-- Store triggers the initial load; once loaded, the auto-save loop starts and flushes.
		dataStore:Store("coins", 5)

		local saved = PromiseTestUtils.awaitValue(function()
			local raw = controller.mock:GetRaw("key")
			return raw ~= nil and raw.coins == 5
		end, 6)
		expect(saved).toEqual(true)

		controller:destroy()
	end)

	it("stops auto-saving after the datastore is destroyed", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")
		dataStore:SetAutoSaveTimeSeconds(0.2)
		dataStore:Store("coins", 5)

		expect(PromiseTestUtils.awaitValue(function()
			local raw = controller.mock:GetRaw("key")
			return raw ~= nil and raw.coins == 5
		end, 6)).toEqual(true)

		dataStore:Destroy()

		-- After destroy the loop is gone: record the call count, wait past several auto-save
		-- intervals, and confirm no new saves land.
		local before = controller.mock:GetCallCount("UpdateAsync")
		local settled = PromiseTestUtils.awaitValue(function()
			return false
		end, 1)
		expect(settled).toEqual(false)
		expect(controller.mock:GetCallCount("UpdateAsync")).toEqual(before)

		controller:destroy()
	end)
end)
