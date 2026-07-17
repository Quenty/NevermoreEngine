--!nonstrict
--[[
	Characterizes the shared load promise and the auto-save loop. The load view is cached
	(PromiseViewUpToDate returns one shared promise), so every Load/LoadAll/Store/Observe attaches
	its own continuation to the same promise; these tests pin that a settled load fans out its
	resolution or rejection to every consumer, including ones attached mid-yield.

	@class DataStoreLoadErrors.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

-- Every DataStore a test creates is tracked here and torn down in afterEach, so its auto-save loop
-- can never outlive the test. These specs share one Roblox place across all packages, so a leaked
-- background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

describe("shared load promise fan-out", function()
	it("delivers the resolution to every consumer of the shared load", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", { a = 1, b = 2 })
		local dataStore = maid:Add(DataStore.new(mock, "key"))

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
	end)

	it("resolves all consumers of a slow (yielding) load attached during the yield", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", { a = 1 })
		mock:SetYieldTime(0.3)
		local dataStore = maid:Add(DataStore.new(mock, "key"))

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
	end)

	it("delivers the rejection to every consumer when the shared load fails", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()
		local dataStore = maid:Add(DataStore.new(mock, "key"))

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
	end)
end)

describe("auto-save loop", function()
	it("persists staged data on the auto-save schedule without an explicit Save", function()
		local mock = DataStoreMock.new()
		local dataStore = maid:Add(DataStore.new(mock, "key"))
		dataStore:SetAutoSaveTimeSeconds(0.2)

		-- Store triggers the initial load; once loaded, the auto-save loop starts and flushes.
		dataStore:Store("coins", 5)

		local saved = PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("key")
			return raw ~= nil and raw.coins == 5
		end, 6)
		expect(saved).toEqual(true)
	end)

	it("stops auto-saving after the datastore is destroyed", function()
		local mock = DataStoreMock.new()
		local dataStore = maid:Add(DataStore.new(mock, "key"))
		dataStore:SetAutoSaveTimeSeconds(0.2)
		dataStore:Store("coins", 5)

		expect(PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("key")
			return raw ~= nil and raw.coins == 5
		end, 6)).toEqual(true)

		dataStore:Destroy()

		-- After destroy the loop is gone: record the call count, wait past several auto-save
		-- intervals, and confirm no new saves land.
		local before = mock:GetCallCount("UpdateAsync")
		local settled = PromiseTestUtils.awaitValue(function()
			return false
		end, 1)
		expect(settled).toEqual(false)
		expect(mock:GetCallCount("UpdateAsync")).toEqual(before)
	end)
end)
