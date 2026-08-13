--!strict
--[[
	@class PlayerDataStoreManager.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local PromiseUtils = require("PromiseUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function expectSettled(promise, timeout: number?): boolean
	local settled = PromiseTestUtils.awaitSettled(promise, timeout)
	expect(settled).toEqual(true)
	return settled
end

describe("PlayerDataStoreManager.GetDataStore", function()
	it("should return a datastore for a fresh user", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		expect(dataStore).never.toBeNil()

		controller:destroy()
	end)

	it("should cache the datastore per user", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local first = controller.manager:GetDataStore(1)
		local second = controller.manager:GetDataStore(1)
		expect(first).toEqual(second)

		local other = controller.manager:GetDataStore(2)
		expect((first == other)).toEqual(false)

		controller:destroy()
	end)

	it("should apply the key generator", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetKey())).toEqual("user_1")

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager PlayerMock support", function()
	it("resolves a datastore for a PlayerMock keyed by its seeded UserId", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local player = PlayerMock.new({ UserId = 42 })
		local dataStore = controller.manager:GetDataStore(player)
		expect(dataStore).never.toBeNil()
		expect((dataStore:GetKey())).toEqual("user_42")

		player:Destroy()
		controller:destroy()
	end)

	it("shares the same datastore between the mock and its numeric userId (unified state)", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local player = PlayerMock.new({ UserId = 42 })
		local viaMock = controller.manager:GetDataStore(player)
		local viaUserId = controller.manager:GetDataStore(42)
		expect(viaMock).toEqual(viaUserId)

		player:Destroy()
		controller:destroy()
	end)

	it("rejects a plain Folder that is not a PlayerMock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local folder = Instance.new("Folder")
		expect(function()
			controller.manager:GetDataStore(folder)
		end).toThrow()

		folder:Destroy()
		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager.PromiseDataStore", function()
	it("should resolve the datastore and load successfully against a healthy mock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local promise = controller.manager:PromiseDataStore(1)
		if not expectSettled(promise, 10) then
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not expectSettled(loadPromise, 10) then
			controller:destroy()
			return
		end
		expect((loadPromise:Wait())).toEqual(true)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager persistence", function()
	it("should round-trip a stored value across a removal/reload", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		dataStore:Store("coins", 5)

		controller.manager:RemovePlayerDataStore(1)

		local promise = controller.manager:PromiseDataStore(1)
		if not expectSettled(promise, 10) then
			controller:destroy()
			return
		end

		local ok, reloaded = promise:Yield()
		expect(ok).toEqual(true)

		local loadPromise = reloaded:Load("coins")
		if not expectSettled(loadPromise, 10) then
			controller:destroy()
			return
		end

		local loadOk, value = loadPromise:Yield()
		expect(loadOk).toEqual(true)
		expect(value).toEqual(5)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager.AddRemovingCallback", function()
	it("should invoke the removing callback when a user's datastore is removed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local ran = false
		controller.manager:AddRemovingCallback(function()
			ran = true
		end)

		controller.manager:GetDataStore(1)

		local promise = controller.manager:PromiseAllSaves()
		if not expectSettled(promise, 10) then
			controller:destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		expect(ran).toEqual(true)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager.PromiseAllSaves", function()
	it("should resolve after removing all datastores and flushing pending saves", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:GetDataStore(1):Store("coins", 1)
		controller.manager:GetDataStore(2):Store("coins", 2)

		local promise = controller.manager:PromiseAllSaves()
		if not expectSettled(promise, 10) then
			controller:destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		controller:destroy()
	end)
end)

-- Models a closing server the way Roblox actually behaves: PlayerRemoving fires for everyone still in
-- the server and does the save-and-close, and the close is held open until those removals flush.
describe("PlayerDataStoreManager server shutdown", function()
	it("saves the staged data and releases the lock for the leaving player", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		if not controller.storeAndAwaitLock() then
			expect("lock was never acquired").toEqual("lock was acquired")
			controller:destroy()
			return
		end

		if not expectSettled(controller.promiseShutdown({ 1 }), 10) then
			controller:destroy()
			return
		end

		local raw = controller.mock:GetRaw("user_1")
		expect(raw.coins).toEqual(5)
		expect(raw.lock).toEqual(nil)

		controller:destroy()
	end)

	it("releases the lock for every player still in the server", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:GetDataStore(1):Store("coins", 1)
		controller.manager:GetDataStore(2):Store("coins", 2)

		local locked = PromiseTestUtils.awaitValue(function()
			local rawOne = controller.mock:GetRaw("user_1")
			local rawTwo = controller.mock:GetRaw("user_2")
			return rawOne ~= nil and rawOne.lock ~= nil and rawTwo ~= nil and rawTwo.lock ~= nil
		end, 10)
		if not locked then
			expect("both locks were never acquired").toEqual("both locks were acquired")
			controller:destroy()
			return
		end

		if not expectSettled(controller.promiseShutdown({ 1, 2 }), 10) then
			controller:destroy()
			return
		end

		expect(controller.mock:GetRaw("user_1").lock).toEqual(nil)
		expect(controller.mock:GetRaw("user_2").lock).toEqual(nil)
		expect(controller.mock:GetRaw("user_1").coins).toEqual(1)
		expect(controller.mock:GetRaw("user_2").coins).toEqual(2)

		controller:destroy()
	end)

	it("destroys each store once its removal has flushed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		if not expectSettled(dataStore:PromiseLoadSuccessful(), 10) then
			controller:destroy()
			return
		end

		if not expectSettled(controller.promiseShutdown({ 1 }), 10) then
			controller:destroy()
			return
		end

		expect(getmetatable(dataStore)).toBeNil()

		controller:destroy()
	end)

	it("does not resolve the close while a PlayerRemoving save is still in flight", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		-- An async removing callback pushes the write past the moment the close is requested, which is
		-- exactly the window where waiting on pending saves alone finds nothing to wait for.
		controller.manager:AddRemovingCallback(function()
			return PromiseUtils.delayed(0.5)
		end)

		if not controller.storeAndAwaitLock() then
			expect("lock was never acquired").toEqual("lock was acquired")
			controller:destroy()
			return
		end

		-- PlayerRemoving lands first, then the server begins closing.
		controller.manager:RemovePlayerDataStore(1)

		local closePromise = controller.manager:PromiseAllSaves()
		expect(closePromise:IsPending()).toEqual(true)

		if not expectSettled(closePromise, 10) then
			controller:destroy()
			return
		end

		-- The close resolving has to mean the write landed. If it can resolve first, the real server
		-- dies here with the session still locked and no other server able to release it.
		local raw = controller.mock:GetRaw("user_1")
		expect(raw.coins).toEqual(5)
		expect(raw.lock).toEqual(nil)

		controller:destroy()
	end)

	it("closes cleanly when a store's load failed, leaking no rejection and writing no lock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:FailAllRequests()

		local dataStore = controller.manager:GetDataStore(1)

		local loaded = dataStore:PromiseLoadSuccessful()
		if not expectSettled(loaded, 10) then
			controller:destroy()
			return
		end
		expect((loaded:Wait())).toEqual(false)

		if not expectSettled(controller.promiseShutdown({ 1 }), 10) then
			controller:destroy()
			return
		end

		expect(controller.mock:GetRaw("user_1")).toBeNil()

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager datastore configuration", function()
	it("applies the configured autosave interval to created datastores", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:SetAutoSaveTimeSeconds(14)

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetAutoSaveTimeSeconds())).toEqual(14)

		controller:destroy()
	end)

	it("leaves the datastore default alone when unconfigured", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetAutoSaveTimeSeconds())).toEqual(60 * 5)

		controller:destroy()
	end)

	it("applies nil autosave (syncing disabled) rather than treating it as unconfigured", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:SetAutoSaveTimeSeconds(nil)

		local dataStore = controller.manager:GetDataStore(1)
		expect(dataStore:GetAutoSaveTimeSeconds()).toBeNil()

		controller:destroy()
	end)

	it("configures every datastore it creates, not just the first", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:SetAutoSaveTimeSeconds(14)

		controller.manager:GetDataStore(1)
		local second = controller.manager:GetDataStore(2)
		expect((second:GetAutoSaveTimeSeconds())).toEqual(14)

		controller:destroy()
	end)

	it("rejects configuration once a datastore has been created", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:GetDataStore(1)

		expect(function()
			controller.manager:SetAutoSaveTimeSeconds(14)
		end).toThrow()
		expect(function()
			controller.manager:SetLoadRetryOptions({ initialWaitTime = 1, maxAttempts = 2, printWarning = false })
		end).toThrow()
		expect(function()
			controller.manager:SetSessionMessagingCloseDelaySeconds(0.5)
		end).toThrow()

		controller:destroy()
	end)

	it("forwards load retry options to created datastores", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local retryOptions = { exponential = 1, initialWaitTime = 0.1, maxAttempts = 2, printWarning = false }
		controller.manager:SetLoadRetryOptions(retryOptions)

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetLoadRetryOptions())).toEqual(retryOptions)

		controller:destroy()
	end)

	it("forwards the session messaging close delay to created datastores", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.manager:SetSessionMessagingCloseDelaySeconds(0.5)

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetSessionMessagingCloseDelaySeconds())).toEqual(0.5)

		controller:destroy()
	end)
end)
