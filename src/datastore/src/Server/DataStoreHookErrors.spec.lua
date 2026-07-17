--!nonstrict
--[[
	Characterizes how the datastore layer handles user-supplied hooks (saving and removing
	callbacks) that misbehave: throw, return a rejected promise, or yield forever. Several are
	genuine data-integrity failure modes, so pinning them documents the contract callers must honor.

	@class DataStoreHookErrors.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newManager()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	serviceBag:Start()

	local mock = DataStoreMock.new()
	local manager = PlayerDataStoreManager.new(serviceBag, mock, function(userId)
		return "user_" .. tostring(userId)
	end, true)

	return manager, mock, serviceBag
end

describe("DataStore saving callbacks that misbehave", function()
	it("runs a well-behaved saving callback and completes the save", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "key")

		local ran = false
		dataStore:AddSavingCallback(function()
			ran = true
		end)
		dataStore:Store("x", 1)

		local promise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			dataStore:Destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)
		expect(ran).toEqual(true)

		dataStore:Destroy()
	end)

	it("isolates a throwing saving callback into a clean save rejection, preserving the stack trace", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "key")

		dataStore:AddSavingCallback(function()
			error("saving callback boom")
		end)
		dataStore:Store("x", 1)

		local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:Save(), 5)
		expect(outcome).toEqual("rejected")

		-- The rejection preserves the original message and the invoking frame, so the failure stays debuggable.
		expect(string.find(tostring(err), "saving callback boom", 1, true) ~= nil).toEqual(true)
		expect(string.find(tostring(err), "PromiseInvokeSavingCallbacks", 1, true) ~= nil).toEqual(true)

		dataStore:Destroy()
	end)

	it("rejects the save when a saving callback returns a rejected promise (and does not persist)", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "key")

		dataStore:AddSavingCallback(function()
			return Promise.rejected("nope")
		end)
		dataStore:Store("x", 1)

		expect((PromiseTestUtils.awaitOutcome(dataStore:Save(), 5))).toEqual("rejected")
		expect(mock:GetRaw("key")).toEqual(nil)

		dataStore:Destroy()
	end)

	it("blocks the save while a saving callback yields (never resolves)", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "key")

		dataStore:AddSavingCallback(function()
			return Promise.new()
		end)
		dataStore:Store("x", 1)

		local promise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(promise, 2)).toEqual(false)

		dataStore:Destroy()
	end)
end)

-- How a misbehaving removing callback affects (a) whether the player's data is saved on leave, and
-- (b) whether the session lock is released. SaveAndCloseSession is what releases the lock, so when
-- it is skipped the departing session's lock lingers until it goes stale.
describe("PlayerDataStoreManager removal matrix (misbehaving removing callbacks)", function()
	local function storeAndAwaitLock(manager, mock)
		local dataStore = manager:GetDataStore(1)
		dataStore:Store("coins", 5)
		-- The session-locked load acquires the lock (writes the envelope) before we remove.
		return PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("user_1")
			return raw ~= nil and raw.lock ~= nil
		end, 10)
	end

	it("well-behaved callback: saves the data AND releases the lock", function()
		local manager, mock, serviceBag = newManager()
		manager:AddRemovingCallback(function()
			return Promise.resolved()
		end)

		expect(storeAndAwaitLock(manager, mock)).toEqual(true)
		manager:RemovePlayerDataStore(1)

		expect(PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("user_1")
			return raw ~= nil and raw.coins == 5
		end, 10)).toEqual(true)
		-- SaveAndCloseSession stripped the lock as it wrote.
		expect(mock:GetRaw("user_1").lock).toEqual(nil)

		serviceBag:Destroy()
	end)

	it("[FAILURE MODE] rejecting callback: skips the save (data loss) AND leaves the lock held", function()
		local manager, mock, serviceBag = newManager()
		manager:AddRemovingCallback(function()
			return Promise.rejected("removing callback failed")
		end)

		expect(storeAndAwaitLock(manager, mock)).toEqual(true)
		manager:RemovePlayerDataStore(1)

		-- The rejected callback short-circuits PromiseUtils.all before SaveAndCloseSession: coins are
		-- never persisted, and the lock is never released.
		expect(PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("user_1")
			return raw ~= nil and raw.coins == 5
		end, 3)).toEqual(false)
		expect(mock:GetRaw("user_1").lock ~= nil).toEqual(true)

		serviceBag:Destroy()
	end)

	it("[FAILURE MODE] throwing callback: the synchronous throw escapes removal (lock held, stuck)", function()
		local manager, mock, serviceBag = newManager()
		manager:AddRemovingCallback(function()
			error("removing callback boom")
		end)

		expect(storeAndAwaitLock(manager, mock)).toEqual(true)

		-- There is no pcall around removing callbacks, so a synchronous throw escapes removal entirely.
		expect(function()
			manager:RemovePlayerDataStore(1)
		end).toThrow("removing callback boom")
		expect(mock:GetRaw("user_1").lock ~= nil).toEqual(true)

		serviceBag:Destroy()
	end)

	it("[FAILURE MODE] yielding callback: removal blocks forever (no save, lock held)", function()
		local manager, mock, serviceBag = newManager()
		manager:AddRemovingCallback(function()
			return Promise.new()
		end)

		expect(storeAndAwaitLock(manager, mock)).toEqual(true)
		manager:RemovePlayerDataStore(1)

		-- SaveAndCloseSession is gated behind the yielding callback, so neither the save nor the lock
		-- release ever happen.
		expect(PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("user_1")
			return raw ~= nil and raw.coins == 5
		end, 2)).toEqual(false)
		expect(mock:GetRaw("user_1").lock ~= nil).toEqual(true)

		serviceBag:Destroy()
	end)
end)
