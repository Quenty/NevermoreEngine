--!nonstrict
--[[
	@class DataStoreLockHelper.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStore session locking", function()
	it("wraps the stored profile in a lock envelope on a healthy acquire", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(true)

		local raw = controller.mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(type(raw.lock)).toEqual("table")
		expect(raw.lock.ActiveSession).never.toBeNil()
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		controller:destroy()
	end)

	it("releases the lock on SaveAndCloseSession so a new session can load", function()
		local controller = DataStoreTestUtils.setup()

		local sessionA = controller.newDataStore()
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })

		local loadA = sessionA:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadA, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadA:Yield())).toEqual(true)

		local closePromise = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closePromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((closePromise:Yield())).toEqual(true)

		local raw = controller.mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(raw.lock).toEqual(nil)

		local sessionB = controller.newDataStore()
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		local loadB = sessionB:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadB, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadB:Yield())).toEqual(true)

		controller:destroy()
	end)

	it("preserves user data across a lock/unlock round-trip", function()
		local controller = DataStoreTestUtils.setup()

		local sessionA = controller.newDataStore()
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })
		sessionA:Store("coins", 5)

		local closePromise = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closePromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((closePromise:Yield())).toEqual(true)

		local sessionB = controller.newDataStore()
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		local loadPromise = sessionB:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(5)

		controller:destroy()
	end)

	it("steals a stale lock left by a dead session", function()
		local controller = DataStoreTestUtils.setup()

		controller.mock:SetRaw("player_1", {
			coins = 7,
			lock = {
				LastUpdateTime = os.time() - 1000000,
				ActiveSession = {
					SessionId = "stale-session-id",
					PlaceId = 987654321,
					JobId = "stale-job-id",
				},
			},
		})

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		local raw = controller.mock:GetRaw("player_1")
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		local loadPromise = dataStore:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadPromise:Wait())).toEqual(7)

		controller:destroy()
	end)

	it("fires SessionStolen when saving over a lock held by another session", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadPromise:Yield())).toEqual(true)

		controller.mock:SetRaw("player_1", {
			coins = 1,
			lock = {
				LastUpdateTime = os.time(),
				ActiveSession = {
					SessionId = "thief-session-id",
					PlaceId = 111222333,
					JobId = "thief-job-id",
				},
			},
		})

		local stolenBy = nil
		dataStore.SessionStolen:Connect(function(session)
			stolenBy = session
		end)

		dataStore:Store("coins", 2)
		local savePromise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(savePromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		expect(stolenBy).never.toBeNil()
		expect(stolenBy.SessionId).toEqual("thief-session-id")

		controller:destroy()
	end)

	it("surfaces a locked-load datastore failure fast instead of hanging", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		controller:destroy()
	end)
end)
