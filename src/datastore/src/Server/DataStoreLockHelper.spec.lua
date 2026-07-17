--!nonstrict
--[[
	Characterization coverage for DataStore session locking, exercised through a real DataStore
	against a mocked Roblox datastore. It pins the observable behaviour of the lock lifecycle: a
	healthy acquire wraps the stored profile in a lock envelope, SaveAndCloseSession releases it,
	user data survives a lock/unlock round-trip, and a stale lock left by a dead session is stolen.

	@class DataStoreLockHelper.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStore session locking", function()
	it("wraps the stored profile in a lock envelope on a healthy acquire", function()
		local mock = DataStoreMock.new()

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(true)

		local raw = mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(type(raw.lock)).toEqual("table")
		expect(raw.lock.ActiveSession).never.toBeNil()
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		dataStore:Destroy()
	end)

	it("releases the lock on SaveAndCloseSession so a new session can load", function()
		local mock = DataStoreMock.new()

		local sessionA = DataStore.new(mock, "player_1")
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })

		local loadA = sessionA:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadA, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((loadA:Yield())).toEqual(true)

		local closePromise = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closePromise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((closePromise:Yield())).toEqual(true)

		-- Closing strips the lock envelope back off the stored value.
		local raw = mock:GetRaw("player_1")
		expect(type(raw)).toEqual("table")
		expect(raw.lock).toEqual(nil)

		sessionA:Destroy()

		local sessionB = DataStore.new(mock, "player_1")
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		local loadB = sessionB:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadB, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((loadB:Yield())).toEqual(true)

		sessionB:Destroy()
	end)

	it("preserves user data across a lock/unlock round-trip", function()
		local mock = DataStoreMock.new()

		local sessionA = DataStore.new(mock, "player_1")
		sessionA:SetSessionLockingEnabled(true)
		sessionA:SetUserIdList({ 1 })
		sessionA:Store("coins", 5)

		local closePromise = sessionA:SaveAndCloseSession()
		if not PromiseTestUtils.awaitSettled(closePromise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((closePromise:Yield())).toEqual(true)
		sessionA:Destroy()

		local sessionB = DataStore.new(mock, "player_1")
		sessionB:SetSessionLockingEnabled(true)
		sessionB:SetUserIdList({ 1 })

		local loadPromise = sessionB:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(5)

		sessionB:Destroy()
	end)

	it("steals a stale lock left by a dead session", function()
		local mock = DataStoreMock.new()

		-- Seed a lock owned by a long-dead session. LastUpdateTime is far enough in the past that
		-- os.time() - LastUpdateTime exceeds GetAutoSaveTimeSeconds() * 2.1 (default 300 * 2.1 = 630s),
		-- so the lock is stolen on the first acquire attempt (no retry backoff). Seed user data too,
		-- to prove it survives the steal.
		mock:SetRaw("player_1", {
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

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((promise:Yield())).toEqual(true)

		local raw = mock:GetRaw("player_1")
		expect(raw.lock.ActiveSession.SessionId).toEqual(dataStore:GetSessionId())

		-- The dead session's user data survived the steal.
		local loadPromise = dataStore:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((select(2, loadPromise:Yield()))).toEqual(7)

		dataStore:Destroy()
	end)

	it("fires SessionStolen when saving over a lock held by another session", function()
		local mock = DataStoreMock.new()

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((loadPromise:Yield())).toEqual(true)

		-- Another session steals the lock out from under us directly in the datastore.
		mock:SetRaw("player_1", {
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
			return
		end

		expect(stolenBy).never.toBeNil()
		expect(stolenBy.SessionId).toEqual("thief-session-id")

		dataStore:Destroy()
	end)

	it("surfaces a locked-load datastore failure fast instead of hanging", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		dataStore:Destroy()
	end)
end)
