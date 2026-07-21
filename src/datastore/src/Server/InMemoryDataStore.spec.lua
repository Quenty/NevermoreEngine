--!nonstrict
--[[
	Coverage for InMemoryDataStore.

	The bulk is a *matrix* suite: one shared battery of DataStoreStage-surface behaviors run against both
	store roots -- the real DataStore (over a DataStoreMock) and InMemoryDataStore -- so the in-memory store
	is proven to behave identically to the persisted one on every read/write/substore/observe path they share.
	The store-specific describe blocks then cover what only the in-memory store guarantees: isolation between
	instances, a no-op save, and never reaching a datastore at all.

	@class InMemoryDataStore.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local InMemoryDataStore = require("InMemoryDataStore")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Asserts the promise settled within the timeout and returns its resolved value, so a hung promise fails
-- the test here instead of freezing the runner on a later :Yield().
local function resolve(promise, timeout: number?)
	expect(PromiseTestUtils.awaitSettled(promise, timeout or 10)).toEqual(true)
	local ok, value = promise:Yield()
	expect(ok).toEqual(true)
	return value
end

-- A controller exposes makeStore() (a fresh store root) and destroy() (tears down everything it created).
-- The matrix runs the same suite against one of these per store implementation.
local function newInMemoryController()
	local maid = Maid.new()
	return {
		makeStore = function()
			return maid:Add(InMemoryDataStore.new())
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

local function newDataStoreController()
	local controller = DataStoreTestUtils.setup()
	return {
		makeStore = function()
			return controller.newDataStore()
		end,
		destroy = controller.destroy,
	}
end

-- The shared behavior battery. `newController` returns a fresh controller so each test is isolated.
local function describeSharedBehavior(caseName: string, newController)
	describe(caseName, function()
		it("loads the default value when the key is empty", function()
			local c = newController()
			expect(resolve(c.makeStore():Load("coins", 99))).toEqual(99)
			c.destroy()
		end)

		it("round-trips a stored value", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("coins", 5)
			expect(resolve(store:Load("coins"))).toEqual(5)
			c.destroy()
		end)

		it("round-trips multiple keys and loads defaults for missing ones", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("coins", 5)
			store:Store("gems", 10)

			local all = resolve(store:LoadAll())
			expect(all.coins).toEqual(5)
			expect(all.gems).toEqual(10)
			expect(resolve(store:Load("missing", "default"))).toEqual("default")
			c.destroy()
		end)

		it("deletes a key so it no longer loads", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("a", 1)
			store:Store("b", 2)
			store:Delete("a")

			local all = resolve(store:LoadAll())
			expect(all.a).toEqual(nil)
			expect(all.b).toEqual(2)
			c.destroy()
		end)

		it("overwrites the whole view", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("a", 1)
			store:Store("b", 2)
			store:Overwrite({ c = 3 })

			local all = resolve(store:LoadAll())
			expect(all.a).toEqual(nil)
			expect(all.b).toEqual(nil)
			expect(all.c).toEqual(3)
			c.destroy()
		end)

		it("wipes to empty", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("a", 1)
			store:Wipe()
			expect(resolve(store:LoadAll({}))).toEqual({})
			c.destroy()
		end)

		it("round-trips substore values and nests them under the parent", function()
			local c = newController()
			local store = c.makeStore()
			store:GetSubStore("inventory"):Store("sword", true)

			expect(resolve(store:GetSubStore("inventory"):Load("sword"))).toEqual(true)

			local all = resolve(store:LoadAll())
			expect(all.inventory.sword).toEqual(true)
			c.destroy()
		end)

		it("lists the top-level keys", function()
			local c = newController()
			local store = c.makeStore()
			store:Store("a", 1)
			store:Store("b", 2)

			local keys = resolve(store:PromiseKeyList())
			table.sort(keys)
			expect(keys).toEqual({ "a", "b" })
			c.destroy()
		end)

		it("stores table values by deep copy, immune to later mutation of the source", function()
			local c = newController()
			local store = c.makeStore()
			local source = { count = 1 }
			store:Store("data", source)
			source.count = 999 -- Mutating after the store must not change what was stored.

			expect(resolve(store:Load("data")).count).toEqual(1)
			c.destroy()
		end)

		it("observes a key: emits the initial value then updates on store", function()
			local c = newController()
			local store = c.makeStore()

			local maid = Maid.new()
			local seen = {}
			maid:GiveTask(store:Observe("coins", 0):Subscribe(function(value)
				table.insert(seen, value)
			end))

			expect(PromiseTestUtils.awaitValue(function()
				return #seen >= 1
			end, 5)).toEqual(true)
			expect(seen[1]).toEqual(0) -- default before anything is stored

			store:Store("coins", 7)
			expect(PromiseTestUtils.awaitValue(function()
				return seen[#seen] == 7
			end, 5)).toEqual(true)

			maid:DoCleaning()
			c.destroy()
		end)
	end)
end

describeSharedBehavior("matrix: DataStore over DataStoreMock", newDataStoreController)
describeSharedBehavior("matrix: InMemoryDataStore", newInMemoryController)

-- A single test that runs an identical op sequence against both roots at once and asserts they land on the
-- exact same view -- the matrix's consistency guarantee stated directly, not just implied by parallel suites.
describe("matrix: cross-implementation consistency", function()
	it("yields the same view for the same op sequence on both roots", function()
		local dataStoreController = newDataStoreController()
		local inMemoryController = newInMemoryController()

		local function runOps(store)
			store:Store("coins", 5)
			store:Store("gems", 10)
			store:GetSubStore("inventory"):Store("sword", true)
			store:Delete("gems")
			return resolve(store:LoadAll())
		end

		local persistedView = runOps(dataStoreController.makeStore())
		local inMemoryView = runOps(inMemoryController.makeStore())

		expect(inMemoryView).toEqual(persistedView)

		dataStoreController.destroy()
		inMemoryController.destroy()
	end)
end)

describe("InMemoryDataStore isolation and non-persistence", function()
	it("does not share data between separate instances", function()
		local maid = Maid.new()
		local first = maid:Add(InMemoryDataStore.new())
		first:Store("coins", 5)

		local second = maid:Add(InMemoryDataStore.new())
		expect(resolve(second:Load("coins", 0))).toEqual(0)

		maid:DoCleaning()
	end)

	it("resolves Save as a no-op", function()
		local maid = Maid.new()
		local store = maid:Add(InMemoryDataStore.new())
		store:Store("coins", 5)

		expect(resolve(store:Save())).toEqual(nil)
		-- Data is still readable in memory after the (no-op) save.
		expect(resolve(store:Load("coins"))).toEqual(5)

		maid:DoCleaning()
	end)

	it("resolves reads immediately with no parent to sync from", function()
		local maid = Maid.new()
		local store = maid:Add(InMemoryDataStore.new())

		-- The base class errors on Load for a parentless stage; this proves the override took.
		expect(resolve(store:LoadAll({}))).toEqual({})

		maid:DoCleaning()
	end)
end)

return nil
