--!nonstrict
--[[
	Deep characterization of the session-lock state machine (DataStoreLockHelper) and the
	cross-server scenarios it governs: validate/invalidate a lock, steal a crashed session's lock,
	block a live session, and prevent data duplication when a session is stolen. Two servers are
	modeled as two DataStore objects sharing one DataStoreMock, with distinct SessionIds. The
	blocking cases assume RunService:IsStudio() == false (true in the cloud test runner); in Studio,
	ALWAYS_STEAL_LOCKS_IN_STUDIO makes every foreign lock stealable.

	@class DataStoreSessionLock.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreLockHelper = require("DataStoreLockHelper")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

-- Every object a test creates is tracked here and torn down in afterEach, so a DataStore's auto-save
-- loop can never outlive the test. These specs share one Roblox place across all packages, so a
-- leaked background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

local function newLockHelper()
	local mock = DataStoreMock.new()
	local dataStore = DataStore.new(mock, "player_1")
	local helper = DataStoreLockHelper.new(dataStore)

	-- The helper borrows the store; tear it down before the store it wraps.
	maid:GiveTask(function()
		helper:Destroy()
		dataStore:Destroy()
	end)

	return helper, dataStore, mock
end

local function foreignSession(sessionId: string?)
	return {
		SessionId = sessionId or "foreign-session-id",
		PlaceId = 999999,
		JobId = "foreign-job-id",
	}
end

-- Builds a stored profile locked by an arbitrary session.
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
		local helper = newLockHelper()
		local result = helper:AcquireLock(nil, false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession).toEqual(nil)
	end)

	it("acquires a profile that has no lock, preserving its data", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock({ coins = 5 }, false)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile.coins).toEqual(5)
		expect(type(result.lockedProfile.lock)).toEqual("table")
	end)

	it("re-acquires a profile locked by our own session", function()
		local helper, dataStore = newLockHelper()
		local ownProfile = helper:ToLockedProfile({ coins = 3 })
		local result = helper:AcquireLock(ownProfile, false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession).toEqual(nil)
		expect(result.lockedProfile.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())
	end)

	it("is blocked by a fresh lock held by another session", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time()), false)
		expect(result.isValid).toEqual(false)
		expect(result.blockingSession.SessionId).toEqual("foreign-session-id")
	end)

	it("steals a foreign lock when canStealLock is true", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time()), true)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession.SessionId).toEqual("foreign-session-id")
	end)

	it("steals a stale foreign lock (crashed session) without stealing explicitly", function()
		local helper = newLockHelper()
		-- Older than GetAutoSaveTimeSeconds() * 2.1 (300 * 2.1 = 630s).
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time() - 700, { coins = 9 }), false)
		expect(result.isValid).toEqual(true)
		expect(result.stolenLockFromSession.SessionId).toEqual("foreign-session-id")
		-- The crashed session's data survives the steal.
		expect(result.unlockedProfile.coins).toEqual(9)
	end)

	it("does NOT steal a foreign lock that is only slightly old", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), os.time() - 100, {}), false)
		expect(result.isValid).toEqual(false)
	end)

	it("is blocked by a foreign lock that has no LastUpdateTime (cannot judge staleness)", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock(lockedBy(foreignSession(), nil, {}), false)
		expect(result.isValid).toEqual(false)
	end)

	it("acquires when the lock envelope has no ActiveSession", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock({ coins = 1, lock = { LastUpdateTime = os.time() } }, false)
		expect(result.isValid).toEqual(true)
	end)

	it("acquires when the lock field is malformed (not a table)", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock({ coins = 1, lock = "not a table" }, false)
		expect(result.isValid).toEqual(true)
	end)

	it("passes through non-table data (locking not applicable)", function()
		local helper = newLockHelper()
		local result = helper:AcquireLock("a raw string", false)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual("a raw string")
	end)
end)

describe("DataStoreLockHelper.ToUnlockedProfile (save-side thief detection)", function()
	it("validates a nil profile", function()
		local helper = newLockHelper()
		local result = helper:ToUnlockedProfile(nil)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual({})
	end)

	it("validates a profile locked by our own session and strips the lock", function()
		local helper = newLockHelper()
		local ownProfile = helper:ToLockedProfile({ coins = 5 })
		local result = helper:ToUnlockedProfile(ownProfile)
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile.coins).toEqual(5)
		expect(result.unlockedProfile.lock).toEqual(nil)
	end)

	it("invalidates a profile whose lock was stolen by another session", function()
		local helper = newLockHelper()
		local result = helper:ToUnlockedProfile(lockedBy(foreignSession(), os.time(), { coins = 5 }))
		expect(result.isValid).toEqual(false)
		expect(result.thiefSession.SessionId).toEqual("foreign-session-id")
	end)

	it("validates a profile that has no lock", function()
		local helper = newLockHelper()
		local result = helper:ToUnlockedProfile({ coins = 5 })
		expect(result.isValid).toEqual(true)
	end)

	it("passes through non-table data", function()
		local helper = newLockHelper()
		local result = helper:ToUnlockedProfile("raw")
		expect(result.isValid).toEqual(true)
		expect(result.unlockedProfile).toEqual("raw")
	end)
end)

describe("DataStoreLockHelper.ToLockedProfile / ToRawUnlockedProfile", function()
	it("adds our lock and preserves user data", function()
		local helper, dataStore = newLockHelper()
		local locked = helper:ToLockedProfile({ coins = 5 })
		expect(locked.coins).toEqual(5)
		expect(locked.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())
		expect(type(locked.lock.LastUpdateTime)).toEqual("number")
	end)

	it("releases the lock (doCloseSession) and preserves user data", function()
		local helper = newLockHelper()
		local released = helper:ToLockedProfile({ coins = 5 }, true)
		expect(released.coins).toEqual(5)
		expect(released.lock).toEqual(nil)
	end)

	it("does not mutate the original profile", function()
		local helper = newLockHelper()
		local original: { coins: number, lock: any? } = { coins = 5 }
		helper:ToLockedProfile(original)
		expect(original.lock).toEqual(nil)
	end)

	it("strips the lock via ToRawUnlockedProfile without mutating the original", function()
		local helper = newLockHelper()
		local original = { coins = 5, lock = { LastUpdateTime = os.time() } }
		local raw = helper:ToRawUnlockedProfile(original)
		expect(raw.lock).toEqual(nil)
		expect(raw.coins).toEqual(5)
		expect(type(original.lock)).toEqual("table")
	end)

	it("locks nil to an envelope, and closes nil to an empty profile", function()
		local helper = newLockHelper()
		expect(type(helper:ToLockedProfile(nil).lock)).toEqual("table")
		expect(helper:ToLockedProfile(nil, true)).toEqual({})
	end)

	it("round-trips user data through lock then unlock with no corruption", function()
		local helper = newLockHelper()
		local data = { coins = 5, nested = { a = 1, b = { 2, 3 } } }
		local roundTripped = helper:ToRawUnlockedProfile(helper:ToLockedProfile(data))
		expect(roundTripped).toEqual(data)
	end)
end)

describe("DataStoreLockHelper.PromiseCloseSession", function()
	it("is pending until the session is closed", function()
		local helper = newLockHelper()
		expect(helper:PromiseCloseSession():IsPending()).toEqual(true)
	end)

	it("resolves once ToLockedProfile closes the session", function()
		local helper = newLockHelper()
		local promise = helper:PromiseCloseSession()
		helper:ToLockedProfile({ coins = 5 }, true)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		expect((promise:Yield())).toEqual(true)
	end)
end)

describe("session lock cross-server scenarios (full DataStore)", function()
	it("blocks a new session's load while another session holds a fresh lock", function()
		local mock = DataStoreMock.new()

		-- A fresh, live foreign lock is present in the datastore.
		mock:SetRaw("player_1", lockedBy(foreignSession(), os.time(), { coins = 1 }))

		local dataStore = maid:Add(DataStore.new(mock, "player_1"))
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		-- The load is legitimately blocked (retrying to acquire), so it must NOT settle quickly.
		local promise = dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(promise, 3)).toEqual(false)
	end)

	it("acquires the lock once the holding session releases it (retry resolves genuine contention)", function()
		-- GUARD for the load-hang fix: a blocked load must still RESOLVE via retry when the holder
		-- releases -- only genuine op FAILURES should fail fast, not lock contention (a successful op
		-- that returns a locked profile).
		local mock = DataStoreMock.new()

		-- Session A acquires and holds the lock.
		local sessionA = maid:Add(DataStore.new(mock, "player_1"))
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })
		local loadA = sessionA:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadA, 10) then
			expect("A load hung").toEqual("A load settled")
			return
		end
		expect((loadA:Yield())).toEqual(true)

		-- Session B starts loading; A's fresh lock blocks it, so B is retrying (not yet settled). Use a
		-- tiny retry backoff so the test exercises the retry quickly instead of the ~6.5s production one.
		local sessionB = maid:Add(DataStore.new(mock, "player_1"))
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })
		sessionB:SetLoadRetryOptions({ exponential = 1, initialWaitTime = 0.1, maxAttempts = 100, printWarning = false })
		local loadB = sessionB:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(loadB, 0.5)).toEqual(false)

		-- A releases the lock; B's next retry attempt should acquire it and the load resolves.
		local closeA = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closeA, 10) then
			expect("A close hung").toEqual("A close settled")
			return
		end

		if not PromiseTestUtils.awaitSettled(loadB, 20) then
			expect("B never acquired the released lock").toEqual("B acquired the released lock")
			return
		end
		expect((loadB:Yield())).toEqual(true)
	end)

	it("prevents data duplication: a stolen session's save is cancelled and the owner's data wins", function()
		local mock = DataStoreMock.new()

		local sessionA = maid:Add(DataStore.new(mock, "player_1"))
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })

		local loadA = sessionA:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadA, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((loadA:Yield())).toEqual(true)

		-- Another live session steals the lock and writes its own value directly into the datastore.
		mock:SetRaw("player_1", lockedBy(foreignSession("winner-session"), os.time(), { coins = 20 }))

		-- Session A tries to save its own (now-orphaned) change.
		sessionA:Store("coins", 10)
		local saveA = sessionA:Save()
		if not PromiseTestUtils.awaitSettled(saveA, 10) then
			expect("hung").toEqual("settled")
			return
		end

		-- A's write was cancelled, so the datastore still holds the winner's data -- not A's, and not
		-- a merged/duplicated mix.
		local raw = mock:GetRaw("player_1")
		expect(raw.coins).toEqual(20)
		expect(raw.lock.ActiveSession.SessionId).toEqual("winner-session")
	end)
end)

describe("session lock edge cases and failure modes", function()
	it("acquires the lock only once across repeated loads (no double-acquire)", function()
		local mock = DataStoreMock.new()

		local dataStore = maid:Add(DataStore.new(mock, "player_1"))
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local first = dataStore:PromiseLoadSuccessful()
		local second = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(first, 10) or not PromiseTestUtils.awaitSettled(second, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((first:Yield())).toEqual(true)

		-- The load is cached (_firstLoadPromise), so exactly one UpdateAsync acquires the lock -- a
		-- second acquire would risk two "owners" of the session.
		expect(mock:GetCallCount("UpdateAsync")).toEqual(1)
	end)

	it("keeps stored data consistent under two concurrent saves", function()
		local mock = DataStoreMock.new()

		local dataStore = maid:Add(DataStore.new(mock, "player_1"))
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local load = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(load, 10) then
			expect("hung").toEqual("settled")
			return
		end

		dataStore:Store("coins", 1)
		local saveOne = dataStore:Save()
		dataStore:Store("coins", 2)
		local saveTwo = dataStore:Save()

		if not PromiseTestUtils.awaitSettled(saveOne, 10) or not PromiseTestUtils.awaitSettled(saveTwo, 10) then
			expect("hung").toEqual("settled")
			return
		end

		-- No corruption/duplication: the stored value is a valid number still owned by us, and the
		-- last staged value won.
		local raw = mock:GetRaw("player_1")
		expect(type(raw.coins)).toEqual("number")
		expect(raw.coins).toEqual(2)
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())
	end)
end)

describe("why session locking exists (unlocked stores can duplicate)", function()
	it("allows item duplication under a read-before-store race, without session locking", function()
		-- The classic dupe that session locking prevents: two servers load the same profile, one
		-- trades an item away and saves, but the other loaded BEFORE that save (or is a crashed
		-- server's stale session) and writes its stale view back -- restoring the traded-away item.
		-- This is EXPECTED behavior for unlocked stores; it is the whole motivation for locking.
		local mock = DataStoreMock.new()
		mock:SetRaw("player_1", { items = { "rare_sword" } })

		-- Two servers, NO session locking, both load the same starting state (B reads before A stores).
		local serverA = maid:Add(DataStore.new(mock, "player_1"))
		local serverB = maid:Add(DataStore.new(mock, "player_1"))

		local aLoad = serverA:Load("items")
		local bLoad = serverB:Load("items")
		if not PromiseTestUtils.awaitSettled(aLoad, 5) or not PromiseTestUtils.awaitSettled(bLoad, 5) then
			expect("load hung").toEqual("load settled")
			return
		end
		expect((select(2, aLoad:Yield()))).toEqual({ "rare_sword" })
		expect((select(2, bLoad:Yield()))).toEqual({ "rare_sword" })

		-- Server A: the player trades the sword away, and A saves it gone.
		serverA:Store("items", {})
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 5) then
			expect("A save hung").toEqual("A save settled")
			return
		end
		expect(mock:GetRaw("player_1").items).toEqual({})

		-- Server B still holds the stale sword and writes it back on its own save.
		serverB:Store("items", { "rare_sword" })
		if not PromiseTestUtils.awaitSettled(serverB:Save(), 5) then
			expect("B save hung").toEqual("B save settled")
			return
		end

		-- The traded-away sword is back: duplicated. An unlocked store cannot prevent this.
		expect(mock:GetRaw("player_1").items).toEqual({ "rare_sword" })
	end)
end)
