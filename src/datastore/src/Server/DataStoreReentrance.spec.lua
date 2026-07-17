--!nonstrict
--[[
	Re-entrance and cancellation: when a datastore request is in flight (yielding) and its owning
	maid is torn down (the DataStore is destroyed / the player leaves), the request thread must be
	cancelled and never resume to write. A session-locked load can legitimately stay pending for a
	long time while a lock command is outstanding.

	@class DataStoreReentrance.spec.lua
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

-- Builds session-locked DataStores over a shared mock and owns them with a Maid, so destroy() tears
-- down every store the test created. A test that destroys a store mid-test (the cancellation under
-- test) stays as-is; the maid simply skips an already-destroyed store. Read controller.mock to
-- block/unblock requests before creating a store.
local function setup(mock)
	local maid = Maid.new()
	mock = mock or DataStoreMock.new()

	local function newSessionLockedStore()
		local dataStore = maid:Add(DataStore.new(mock, "player_1"))
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })
		return dataStore
	end

	return {
		mock = mock,
		newSessionLockedStore = newSessionLockedStore,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("in-flight request cancellation (maid teardown)", function()
	it("cancels a yielding load thread when the DataStore is destroyed (no leaked thread)", function()
		local controller = setup()
		controller.mock:BlockRequests() -- the lock-acquire request hangs, so the load is stuck in flight

		local dataStore = controller.newSessionLockedStore()
		local promise = dataStore:PromiseLoadSuccessful()

		expect(PromiseTestUtils.awaitSettled(promise, 1)).toEqual(false)

		-- Destroy while the request thread is yielding -- its maid must cancel it.
		dataStore:Destroy()

		-- A properly cancelled thread never resumes, so the lock is never written. A leaked thread
		-- would resume on unblock and write the lock envelope.
		controller.mock:UnblockRequests()
		local everWrote = PromiseTestUtils.awaitValue(function()
			return controller.mock:GetRaw("player_1") ~= nil
		end, 2)
		expect(everWrote).toEqual(false)

		controller:destroy()
	end)

	it("cancels a yielding save thread when the DataStore is destroyed", function()
		local controller = setup()

		-- Load cleanly first (acquires the lock), then block so the SAVE request hangs in flight.
		local dataStore = controller.newSessionLockedStore()
		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("load hung").toEqual("load settled")
			controller:destroy()
			return
		end

		controller.mock:BlockRequests()
		dataStore:Store("coins", 5)
		local savePromise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(savePromise, 1)).toEqual(false)

		local versionsBefore = controller.mock:GetCallCount("UpdateAsync")
		dataStore:Destroy()
		controller.mock:UnblockRequests()

		-- The cancelled save thread must not resume and perform another UpdateAsync write.
		local extraWrites = PromiseTestUtils.awaitValue(function()
			return controller.mock:GetCallCount("UpdateAsync") > versionsBefore + 1
		end, 2)
		expect(extraWrites).toEqual(false)

		controller:destroy()
	end)
end)

describe("lock command that does not settle", function()
	it("keeps the load pending while the lock command is outstanding, then completes when it settles", function()
		local controller = setup()
		controller.mock:BlockRequests() -- simulate a lock command that hasn't propagated yet (up to ~30s)

		local dataStore = controller.newSessionLockedStore()
		local promise = dataStore:PromiseLoadSuccessful()

		-- Must NOT spuriously resolve or error while the lock command is outstanding.
		expect(PromiseTestUtils.awaitSettled(promise, 2)).toEqual(false)

		controller.mock:UnblockRequests()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung after unblock").toEqual("settled")
			controller:destroy()
			return
		end
		expect((select(2, promise:Yield()))).toEqual(true)

		controller:destroy()
	end)

	it("re-loads cleanly on a fresh session after a cancelled in-flight lock command", function()
		local controller = setup()
		controller.mock:BlockRequests()

		local first = controller.newSessionLockedStore()
		local firstPromise = first:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(firstPromise, 1)).toEqual(false)
		first:Destroy() -- cancel the in-flight lock command
		controller.mock:UnblockRequests()

		-- The cancelled attempt left no lock, so a fresh session acquires cleanly.
		local second = controller.newSessionLockedStore()
		local secondPromise = second:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((select(2, secondPromise:Yield()))).toEqual(true)

		controller:destroy()
	end)
end)
