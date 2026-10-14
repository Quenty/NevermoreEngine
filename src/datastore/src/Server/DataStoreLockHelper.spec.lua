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

		local loadedOk = PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 10)
		expect(loadedOk).toEqual(true)

		local raw = controller.mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(type(raw.lock)).toEqual("table")
		expect(raw.lock.ActiveSession).never.toBeNil()
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		controller:Destroy()
	end)

	it("releases the lock on SaveAndCloseSession so a new session can load", function()
		local controller = DataStoreTestUtils.setup()

		local sessionA = controller.newDataStore()
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })

		PromiseTestUtils.awaitFulfilled(sessionA:PromiseLoadSuccessful(), 10)

		PromiseTestUtils.awaitFulfilled(sessionA:SaveAndCloseSession(), 10)

		local raw = controller.mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(raw.lock).toEqual(nil)

		local sessionB = controller.newDataStore()
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		PromiseTestUtils.awaitFulfilled(sessionB:PromiseLoadSuccessful(), 10)

		controller:Destroy()
	end)

	it("preserves user data across a lock/unlock round-trip", function()
		local controller = DataStoreTestUtils.setup()

		local sessionA = controller.newDataStore()
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })
		sessionA:Store("coins", 5)

		PromiseTestUtils.awaitFulfilled(sessionA:SaveAndCloseSession(), 10)

		local sessionB = controller.newDataStore()
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		local value = PromiseTestUtils.awaitFulfilled(sessionB:Load("coins"), 10)
		expect(value).toEqual(5)

		controller:Destroy()
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

		PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 10)

		local raw = controller.mock:GetRaw("player_1")
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		expect(PromiseTestUtils.awaitFulfilled(dataStore:Load("coins"), 10)).toEqual(7)

		controller:Destroy()
	end)

	it("fires SessionStolen when saving over a lock held by another session", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 10)

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
		expect(PromiseTestUtils.awaitSettled(dataStore:Save(), 10)).toEqual(true)

		expect(stolenBy).never.toBeNil()
		expect(stolenBy.SessionId).toEqual("thief-session-id")

		controller:Destroy()
	end)

	it("surfaces a locked-load datastore failure fast instead of hanging", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local loadedOk = PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 5)
		expect(loadedOk).toEqual(false)

		controller:Destroy()
	end)
end)
