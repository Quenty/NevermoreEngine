--!nonstrict
--[[
	Characterization coverage for the DataStoreStage staging layer, exercised through a real root
	(`DataStore.new(DataStoreMock.new(), key)`) since a bare stage has no load parent. Stores here are
	non-session-locking, so staging is deterministic.

	@class DataStoreStage.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStoreStage staging (through a DataStore root)", function()
	describe("Store / Load", function()
		it("should Load back a value that was Stored", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("coins", 25)

			local promise = dataStore:Load("coins")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			expect(value).toEqual(25)

			dataStore:Destroy()
		end)

		it("should Load a deep-equal table that was Stored", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("profile", { level = 3, name = "Egg" })

			local promise = dataStore:Load("profile")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			expect(value).toEqual({ level = 3, name = "Egg" })

			dataStore:Destroy()
		end)

		it("should return the default value for a missing key", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local promise = dataStore:Load("missing", "fallback")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			expect((promise:Wait())).toEqual("fallback")

			dataStore:Destroy()
		end)
	end)

	describe("LoadAll", function()
		it("should return the whole staged view", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("coins", 5)
			dataStore:Store("gems", 10)

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ coins = 5, gems = 10 })

			dataStore:Destroy()
		end)

		it("should return the default when the stage is empty", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local promise = dataStore:LoadAll("empty")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			expect((promise:Wait())).toEqual("empty")

			dataStore:Destroy()
		end)
	end)

	describe("GetSubStore", function()
		it("should return the same substore instance for the same key", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local first = dataStore:GetSubStore("inv")
			local second = dataStore:GetSubStore("inv")
			expect(first).toEqual(second)

			dataStore:Destroy()
		end)

		it("should surface a substore value under its key in the parent LoadAll", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:GetSubStore("inv"):Store("sword", true)

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ inv = { sword = true } })

			dataStore:Destroy()
		end)

		it("should support deep nesting (substore of a substore)", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:GetSubStore("a"):GetSubStore("b"):Store("c", 1)

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ a = { b = { c = 1 } } })

			dataStore:Destroy()
		end)
	end)

	describe("View priority", function()
		it("should prioritize staged save data over loaded base data", function()
			local mock = DataStoreMock.new()
			-- Seed base data BEFORE constructing the reader so it loads through getAsync.
			mock:SetRaw("player_1", { coins = 1, gems = 2 })

			local dataStore = DataStore.new(mock, "player_1")

			-- Base data loads first
			local basePromise = dataStore:Load("coins")
			if not PromiseTestUtils.awaitSettled(basePromise) then
				expect("hung").toEqual("settled")
				return
			end
			expect((basePromise:Wait())).toEqual(1)

			-- Staged value overrides base; untouched base key stays visible
			dataStore:Store("coins", 999)

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ coins = 999, gems = 2 })

			dataStore:Destroy()
		end)
	end)

	describe("Overwrite / OverwriteMerge / Wipe", function()
		it("should replace the whole staged view with Overwrite", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)
			dataStore:Store("b", 2)

			dataStore:Overwrite({ c = 3 })

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ c = 3 })

			dataStore:Destroy()
		end)

		it("should clear the staged view with Overwrite(nil)", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)

			dataStore:Overwrite(nil)

			local promise = dataStore:LoadAll("cleared")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			expect((promise:Wait())).toEqual("cleared")

			dataStore:Destroy()
		end)

		it("should clear even loaded base data with Wipe", function()
			local mock = DataStoreMock.new()
			mock:SetRaw("player_1", { coins = 5 })

			local dataStore = DataStore.new(mock, "player_1")

			-- Force base to load first
			local basePromise = dataStore:Load("coins")
			if not PromiseTestUtils.awaitSettled(basePromise) then
				expect("hung").toEqual("settled")
				return
			end
			expect((basePromise:Wait())).toEqual(5)

			dataStore:Wipe()

			local promise = dataStore:LoadAll("wiped")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			expect((promise:Wait())).toEqual("wiped")

			dataStore:Destroy()
		end)

		it("should merge without wiping missing keys via OverwriteMerge", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)
			dataStore:Store("b", 2)

			dataStore:OverwriteMerge({ b = 3, c = 4 })

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ a = 1, b = 3, c = 4 })

			dataStore:Destroy()
		end)
	end)

	describe("Delete", function()
		it("should remove a key so it no longer loads", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)
			dataStore:Store("b", 2)

			dataStore:Delete("a")

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all).toEqual({ b = 2 })

			dataStore:Destroy()
		end)
	end)

	describe("Observe", function()
		it("should emit the initial value for a key", function()
			local mock = DataStoreMock.new()
			mock:SetRaw("player_1", { coins = 7 })

			local dataStore = DataStore.new(mock, "player_1")

			local promise = Rx.toPromise(dataStore:Observe("coins", 0))
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			expect(value).toEqual(7)

			dataStore:Destroy()
		end)

		it("should emit the default for a missing key", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local promise = Rx.toPromise(dataStore:Observe("coins", 0))
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			expect((promise:Wait())).toEqual(0)

			dataStore:Destroy()
		end)

		it("should fire the observer with the new value after a Store on a key", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local captured
			local sub = dataStore:Observe("coins", 0):Subscribe(function(value)
				captured = value
			end)

			dataStore:Store("coins", 42)

			expect(PromiseTestUtils.awaitValue(function()
				return captured == 42
			end)).toEqual(true)

			sub:Destroy()
			dataStore:Destroy()
		end)

		it("should fire the whole-view observer with the new snapshot after a Store", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			-- The initial emission of an empty store is nil, so count emissions (not value) to
			-- confirm the Changed connection is established before we Store.
			local emissions = 0
			local captured
			local sub = dataStore:Observe():Subscribe(function(snapshot)
				emissions += 1
				captured = snapshot
			end)

			expect(PromiseTestUtils.awaitValue(function()
				return emissions >= 1
			end)).toEqual(true)

			dataStore:Store("coins", 1)

			expect(PromiseTestUtils.awaitValue(function()
				return type(captured) == "table" and captured.coins == 1
			end)).toEqual(true)

			sub:Destroy()
			dataStore:Destroy()
		end)
	end)

	describe("PromiseKeyList / PromiseKeySet", function()
		it("should report the set of staged keys", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)
			dataStore:Store("b", 2)

			local promise = dataStore:PromiseKeySet()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, keys = promise:Yield()
			expect(ok).toEqual(true)
			expect(keys).toEqual({ a = true, b = true })

			dataStore:Destroy()
		end)

		it("should report the list of staged keys", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:Store("a", 1)
			dataStore:Store("b", 2)

			local promise = dataStore:PromiseKeyList()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, list = promise:Yield()
			expect(ok).toEqual(true)

			-- Order is not guaranteed; compare as a set
			local asSet = {}
			for _, key in list do
				asSet[key] = true
			end
			expect(asSet).toEqual({ a = true, b = true })

			dataStore:Destroy()
		end)
	end)

	describe("StoreOnValueChange", function()
		it("should stage the value whenever the ValueObject changes", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			-- Ensure the stage is loaded before wiring up the value object
			if not PromiseTestUtils.awaitSettled(dataStore:Load("level")) then
				expect("hung").toEqual("settled")
				return
			end

			local valueObject = ValueObject.new(0)
			dataStore:StoreOnValueChange("level", valueObject)

			-- Construction does not stage; a change does
			valueObject.Value = 7

			local promise = dataStore:LoadAll()
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, all = promise:Yield()
			expect(ok).toEqual(true)
			expect(all.level).toEqual(7)

			dataStore:Destroy()
		end)
	end)

	describe("Persistence round-trip", function()
		it("should persist a staged value across a fresh DataStore on the same mock", function()
			local mock = DataStoreMock.new()

			local writer = DataStore.new(mock, "player_1")
			writer:Store("coins", 5)

			local savePromise = writer:Save()
			if not PromiseTestUtils.awaitSettled(savePromise) then
				expect("hung").toEqual("settled")
				return
			end
			expect((savePromise:Yield())).toEqual(true)

			local reader = DataStore.new(mock, "player_1")
			local loadPromise = reader:Load("coins")
			if not PromiseTestUtils.awaitSettled(loadPromise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, value = loadPromise:Yield()
			expect(ok).toEqual(true)
			expect(value).toEqual(5)

			writer:Destroy()
			reader:Destroy()
		end)
	end)

	describe("Deep-copy isolation", function()
		it("should not reflect mutations to the input table after Store", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

			local input = { count = 1 }
			dataStore:Store("data", input)

			-- Mutating the caller's table must not change the frozen staged copy
			input.count = 999

			local promise = dataStore:Load("data")
			if not PromiseTestUtils.awaitSettled(promise) then
				expect("hung").toEqual("settled")
				return
			end

			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			expect(value).toEqual({ count = 1 })

			dataStore:Destroy()
		end)
	end)

	describe("PromiseInvokeSavingCallbacks with promise-returning callbacks", function()
		it("resolves when a callback's returned promise resolves", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:AddSavingCallback(function()
				return Promise.resolved()
			end)

			local outcome = PromiseTestUtils.awaitOutcome(dataStore:PromiseInvokeSavingCallbacks())
			expect(outcome).toEqual("resolved")

			dataStore:Destroy()
		end)

		it("rejects when a callback's returned promise rejects, so the save fails", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:AddSavingCallback(function()
				return Promise.rejected("removing callback boom")
			end)

			local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:PromiseInvokeSavingCallbacks())
			expect(outcome).toEqual("rejected")
			expect(string.find(tostring(err), "removing callback boom", 1, true) ~= nil).toEqual(true)

			dataStore:Destroy()
		end)

		it("never settles when a callback's returned promise never resolves, so the save hangs", function()
			local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
			dataStore:AddSavingCallback(function()
				return Promise.new()
			end)

			expect(PromiseTestUtils.awaitSettled(dataStore:PromiseInvokeSavingCallbacks(), 0.25)).toEqual(false)

			dataStore:Destroy()
		end)
	end)
end)
