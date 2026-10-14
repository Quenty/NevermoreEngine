--!strict
--[[
	The raw session-lock path: reading and writing the lock on a key without opening a session on it.
	Usually the target is a player who is not in this server, but the write is deliberately permitted
	against a live local session too -- see the last describe block.

	@class PlayerDataStoreManager.SessionLockTools.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FOREIGN_SESSION = {
	SessionId = "foreign-session",
	PlaceId = 123,
	JobId = "foreign-job",
}

local function seedForeignLock(mock, key: string, profile: { [string]: any }?)
	local data: { [string]: any } = profile or {}
	data.lock = {
		LastUpdateTime = os.time(),
		ActiveSession = FOREIGN_SESSION,
	}
	mock:SetRaw(key, data)
end

-- Returns the resolved value, or fails the spec and returns nil.

describe("PlayerDataStoreManager.PromiseReadSessionLock", function()
	it("resolves nil for a key that was never written", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).toBeNil()

		controller:Destroy()
	end)

	it("reports the session holding a foreign lock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		seedForeignLock(controller.mock, "user_1", { coins = 5 })

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).never.toBeNil()
		expect(lock.ActiveSession).toEqual(FOREIGN_SESSION)

		controller:Destroy()
	end)

	it("resolves nil for a stored profile with no lock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).toBeNil()

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreManager.PromiseUnlockSession", function()
	it("clears a foreign lock and reports what it cleared", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		seedForeignLock(controller.mock, "user_1", { coins = 5 })

		local previous = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseUnlockSession(1))
		expect(previous).never.toBeNil()
		expect(previous.ActiveSession).toEqual(FOREIGN_SESSION)

		expect(controller.mock:GetRaw("user_1").lock).toBeNil()

		controller:Destroy()
	end)

	it("leaves the rest of the profile untouched", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		seedForeignLock(controller.mock, "user_1", { coins = 5, level = 3 })

		PromiseTestUtils.awaitFulfilled(controller.manager:PromiseUnlockSession(1))

		local raw = controller.mock:GetRaw("user_1")
		expect(raw.coins).toEqual(5)
		expect(raw.level).toEqual(3)

		controller:Destroy()
	end)

	it("resolves nil on an already-unlocked key", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local previous = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseUnlockSession(1))
		expect(previous).toBeNil()

		controller:Destroy()
	end)

	it("does not create an entry for a key that was never written", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		PromiseTestUtils.awaitFulfilled(controller.manager:PromiseUnlockSession(1))

		expect(controller.mock:GetRaw("user_1")).toBeNil()

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreManager.PromiseLockSession", function()
	it("claims an unlocked key", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local previous = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseLockSession(1))
		expect(previous).toBeNil()

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).never.toBeNil()
		expect(lock.ActiveSession.PlaceId).toEqual(game.PlaceId)
		expect(controller.mock:GetRaw("user_1").coins).toEqual(5)

		controller:Destroy()
	end)

	it("reports the lock it replaced", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		seedForeignLock(controller.mock, "user_1", { coins = 5 })

		local previous = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseLockSession(1))
		expect(previous).never.toBeNil()
		expect(previous.ActiveSession).toEqual(FOREIGN_SESSION)

		controller:Destroy()
	end)

	it("claims a key that was never written", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		PromiseTestUtils.awaitFulfilled(controller.manager:PromiseLockSession(1))

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).never.toBeNil()

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreManager raw lock writes against a live session", function()
	-- Allowed on purpose: pulling the key out from under a live local session is the failure the
	-- lock/unlock debug tools exist to provoke. See PlayerDataStoreManager._promiseWriteRawSessionLock.
	it("writes the lock while this server holds a session for that user", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		expect(controller.storeAndAwaitLock()).toEqual(true)

		local previous = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseUnlockSession(1))
		expect(previous).never.toBeNil()
		expect(previous.ActiveSession.JobId).toEqual(game.JobId)
		expect(controller.mock:GetRaw("user_1").lock).toBeNil()

		controller:Destroy()
	end)

	it("still serves a read while this server holds a session", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		expect(controller.storeAndAwaitLock()).toEqual(true)

		local lock = PromiseTestUtils.awaitFulfilled(controller.manager:PromiseReadSessionLock(1))
		expect(lock).never.toBeNil()
		expect(lock.ActiveSession.JobId).toEqual(game.JobId)

		controller:Destroy()
	end)

	it("writes once the session has been removed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		expect(controller.storeAndAwaitLock()).toEqual(true)

		controller.manager:RemovePlayerDataStore(1)
		PromiseTestUtils.awaitFulfilled(controller.bindToCloseService:PromiseClose(), 10)

		PromiseTestUtils.awaitFulfilled(controller.manager:PromiseLockSession(1))
		expect(controller.mock:GetRaw("user_1").lock).never.toBeNil()

		controller:Destroy()
	end)
end)
