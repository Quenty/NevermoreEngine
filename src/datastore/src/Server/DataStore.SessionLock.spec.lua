--!nonstrict
--[[
	@class DataStoreSessionLock.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function foreignSession(sessionId: string?)
	return {
		SessionId = sessionId or "foreign-session-id",
		PlaceId = 999999,
		JobId = "foreign-job-id",
	}
end

local function lockedBy(session, lastUpdateTime: number?, data: { [string]: any }?)
	local profile = {}
	if data then
		for key, value in data do
			profile[key] = value
		end
	end
	profile.lock = {
		LastUpdateTime = lastUpdateTime,
		ActiveSession = session,
	}
	return profile
end

describe("DataStoreLockHelper.AcquireLock", function()
	it("acquires an unlocked (nil) profile", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock(nil, false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession).toEqual(nil)
		controller:destroy()
	end)

	it("acquires a profile that has no lock, preserving its data", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock({ coins = 5 }, false)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile.coins).toEqual(5)
		expect(type(result.lockedProfile.lock)).toEqual("table")
		controller:destroy()
	end)

	it("re-acquires a profile locked by our own session", function()
		local controller = DataStoreTestUtils.setup()
		local helper, dataStore = controller.newLockHelper()
		local ownProfile = helper:ToLockedProfile({ coins = 3 })
		local result = helper:AcquireLock(ownProfile, false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession).toEqual(nil)
		expect(result.lockedProfile.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())
		controller:destroy()
	end)

	it("is blocked by a fresh lock held by another session", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time()), false)
		expect(result.isValid).toEqual(false)
		expect(result.blockingSession.SessionId).toEqual("foreign-session-id")
		controller:destroy()
	end)

	it("steals a foreign lock when canStealLock is true", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time()), true)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession.SessionId).toEqual("foreign-session-id")
		controller:destroy()
	end)

	it("steals a stale foreign lock (crashed session) without stealing explicitly", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		-- Older than GetAutoSaveTimeSeconds() * 2.1 (300 * 2.1 = 630s).
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time() - 700, { coins = 9 }), false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession.SessionId).toEqual("foreign-session-id")
		expect(result.unlockedProfile.coins).toEqual(9)
		controller:destroy()
	end)

	it("does NOT steal a foreign lock that is only slightly old", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time() - 100, {}), false)
		expect(result.isValid).toEqual(false)
		controller:destroy()
	end)

	it("is blocked by a foreign lock that has no LastUpdateTime (cannot judge staleness)", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), nil, {}), false)
		expect(result.isValid).toEqual(false)
		controller:destroy()
	end)

	it("acquires when the lock envelope has no ActiveSession", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock({ coins = 1, lock = { LastUpdateTime = os.time() } }, false)
		expect(result.isValid).toEqual(true)
		controller:destroy()
	end)

	it("acquires when the lock field is malformed (not a table)", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock({ coins = 1, lock = "not a table" }, false)
		expect(result.isValid).toEqual(true)
		controller:destroy()
	end)

	it("passes through non-table data (locking not applicable)", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:AcquireLock("a raw string", false)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual("a raw string")
		controller:destroy()
	end)
end)

describe("DataStoreLockHelper.ToUnlockedProfile (save-side thief detection)", function()
	it("validates a nil profile", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:ToUnlockedProfile(nil)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual({})
		controller:destroy()
	end)

	it("validates a profile locked by our own session and strips the lock", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local ownProfile = helper:ToLockedProfile({ coins = 5 })
		local result = helper:ToUnlockedProfile(ownProfile)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile.coins).toEqual(5)
		expect(result.unlockedProfile.lock).toEqual(nil)
		controller:destroy()
	end)

	it("invalidates a profile whose lock was stolen by another session", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:ToUnlockedProfile(lockedBy(foreignSession(), os.time(), { coins = 5 }))
		expect(result.isValid).toEqual(false)
		expect(result.thiefSession.SessionId).toEqual("foreign-session-id")
		controller:destroy()
	end)

	it("validates a profile that has no lock", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:ToUnlockedProfile({ coins = 5 })
		expect(result.isValid).toEqual(true)
		controller:destroy()
	end)

	it("passes through non-table data", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local result = helper:ToUnlockedProfile("raw")
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual("raw")
		controller:destroy()
	end)
end)

describe("DataStoreLockHelper.ToLockedProfile / ToRawUnlockedProfile", function()
	it("adds our lock and preserves user data", function()
		local controller = DataStoreTestUtils.setup()
		local helper, dataStore = controller.newLockHelper()
		local locked = helper:ToLockedProfile({ coins = 5 })
		expect(locked.coins).toEqual(5)
		expect(locked.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())
		expect(type(locked.lock.LastUpdateTime)).toEqual("number")
		controller:destroy()
	end)

	it("releases the lock (doCloseSession) and preserves user data", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local released = helper:ToLockedProfile({ coins = 5 }, true)
		expect(released.coins).toEqual(5)
		expect(released.lock).toEqual(nil)
		controller:destroy()
	end)

	it("does not mutate the original profile", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local original: { coins: number, lock: any? } = { coins = 5 }
		helper:ToLockedProfile(original)
		expect(original.lock).toEqual(nil)
		controller:destroy()
	end)

	it("strips the lock via ToRawUnlockedProfile without mutating the original", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local original = { coins = 5, lock = { LastUpdateTime = os.time() } }
		local raw = helper:ToRawUnlockedProfile(original)
		expect(raw.lock).toEqual(nil)
		expect(raw.coins).toEqual(5)
		expect(type(original.lock)).toEqual("table")
		controller:destroy()
	end)

	it("locks nil to an envelope, and closes nil to an empty profile", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		expect(type(helper:ToLockedProfile(nil).lock)).toEqual("table")
		expect(helper:ToLockedProfile(nil, true)).toEqual({})
		controller:destroy()
	end)

	it("round-trips user data through lock then unlock with no corruption", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local data = { coins = 5, nested = { a = 1, b = { 2, 3 } } }
		local roundTripped = helper:ToRawUnlockedProfile(helper:ToLockedProfile(data))
		expect(roundTripped).toEqual(data)
		controller:destroy()
	end)
end)

describe("DataStoreLockHelper.PromiseCloseSession", function()
	it("is pending until the session is closed", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		expect(helper:PromiseCloseSession():IsPending()).toEqual(true)
		controller:destroy()
	end)

	it("resolves once ToLockedProfile closes the session", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newLockHelper()
		local promise = helper:PromiseCloseSession()
		helper:ToLockedProfile({ coins = 5 }, true)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		expect((promise:Yield())).toEqual(true)
		controller:destroy()
	end)
end)

describe("session lock cross-server scenarios (full DataStore)", function()
	it("blocks a new session's load while another session holds a fresh lock", function()
		local controller = DataStoreTestUtils.setup()

		controller.mock:SetRaw("player_1", lockedBy(foreignSession(), os.time(), { coins = 1 }))

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(promise, 3)).toEqual(false)

		controller:destroy()
	end)

	it("acquires the lock once the holding session releases it (retry resolves genuine contention)", function()
		local controller = DataStoreTestUtils.setup()

		local sessionA = controller.newDataStore()
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })
		local loadA = sessionA:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadA, 10) then
			expect("A load hung").toEqual("A load settled")
			controller:destroy()
			return
		end
		expect((loadA:Yield())).toEqual(true)

		local sessionB = controller.newDataStore()
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })
		sessionB:SetLoadRetryOptions({ exponential = 1, initialWaitTime = 0.1, maxAttempts = 100, printWarning = false })
		local loadB = sessionB:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(loadB, 0.5)).toEqual(false)

		local closeA = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closeA, 10) then
			expect("A close hung").toEqual("A close settled")
			controller:destroy()
			return
		end

		if not PromiseTestUtils.awaitSettled(loadB, 20) then
			expect("B never acquired the released lock").toEqual("B acquired the released lock")
			controller:destroy()
			return
		end
		expect((loadB:Yield())).toEqual(true)

		controller:destroy()
	end)

	it("prevents data duplication: a stolen session's save is cancelled and the owner's data wins", function()
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

		controller.mock:SetRaw("player_1", lockedBy(foreignSession("winner-session"), os.time(), { coins = 20 }))

		sessionA:Store("coins", 10)
		local saveA = sessionA:Save()
		if not PromiseTestUtils.awaitSettled(saveA, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local raw = controller.mock:GetRaw("player_1")
		expect(raw.coins).toEqual(20)
		expect(raw.lock.ActiveSession.SessionId).toEqual("winner-session")

		controller:destroy()
	end)
end)

describe("session lock edge cases and failure modes", function()
	it("acquires the lock only once across repeated loads (no double-acquire)", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local first = dataStore:PromiseLoadSuccessful()
		local second = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(first, 10) or not PromiseTestUtils.awaitSettled(second, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((first:Yield())).toEqual(true)

		expect(controller.mock:GetCallCount("UpdateAsync")).toEqual(1)

		controller:destroy()
	end)

	it("keeps stored data consistent under two concurrent saves", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local load = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(load, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		dataStore:Store("coins", 1)
		local saveOne = dataStore:Save()
		dataStore:Store("coins", 2)
		local saveTwo = dataStore:Save()

		if not PromiseTestUtils.awaitSettled(saveOne, 10) or not PromiseTestUtils.awaitSettled(saveTwo, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local raw = controller.mock:GetRaw("player_1")
		expect(type(raw.coins)).toEqual("number")
		expect(raw.coins).toEqual(2)
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		controller:destroy()
	end)
end)

describe("why session locking exists (unlocked stores can duplicate)", function()
	it("allows item duplication under a read-before-store race, without session locking", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:SetRaw("player_1", { items = { "rare_sword" } })

		local serverA = controller.newDataStore()
		local serverB = controller.newDataStore()

		local aLoad = serverA:Load("items")
		local bLoad = serverB:Load("items")
		if not PromiseTestUtils.awaitSettled(aLoad, 5) or not PromiseTestUtils.awaitSettled(bLoad, 5) then
			expect("load hung").toEqual("load settled")
			controller:destroy()
			return
		end
		expect((aLoad:Wait())).toEqual({ "rare_sword" })
		expect((bLoad:Wait())).toEqual({ "rare_sword" })

		serverA:Store("items", {})
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 5) then
			expect("A save hung").toEqual("A save settled")
			controller:destroy()
			return
		end
		expect(controller.mock:GetRaw("player_1").items).toEqual({})

		serverB:Store("items", { "rare_sword" })
		if not PromiseTestUtils.awaitSettled(serverB:Save(), 5) then
			expect("B save hung").toEqual("B save settled")
			controller:destroy()
			return
		end

		expect(controller.mock:GetRaw("player_1").items).toEqual({ "rare_sword" })

		controller:destroy()
	end)
end)
