--!strict
--[[
	@class PlayerDataStoreManager.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

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

describe("PlayerDataStoreManager teardown", function()
	it("destroys the datastores it still owns when the manager is destroyed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		if not expectSettled(dataStore:PromiseLoadSuccessful(), 10) then
			controller:destroy()
			return
		end

		controller.manager:Destroy()

		expect(getmetatable(dataStore)).toBeNil()

		controller:destroy()
	end)

	it("flushes staged data synchronously to the underlying store when destroyed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		local dataStore = controller.manager:GetDataStore(1)
		if not expectSettled(dataStore:PromiseLoadSuccessful(), 10) then
			controller:destroy()
			return
		end

		dataStore:Store("coins", 5)

		controller.manager:Destroy()

		local raw = controller.mock:GetRaw("user_1")
		expect(raw).never.toBeNil()
		expect(raw.coins).toEqual(5)

		controller:destroy()
	end)

	it("releases the session lock when destroyed, not just the staged data", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		if not controller.storeAndAwaitLock() then
			expect("lock was never acquired").toEqual("lock was acquired")
			controller:destroy()
			return
		end

		controller.manager:Destroy()

		expect(PromiseTestUtils.awaitValue(function()
			local raw = controller.mock:GetRaw("user_1")
			return raw ~= nil and raw.lock == nil
		end, 5)).toEqual(true)
		expect(controller.mock:GetRaw("user_1").coins).toEqual(5)

		controller:destroy()
	end)

	it("releases the lock for every store it still owns", function()
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

		controller.manager:Destroy()

		expect(PromiseTestUtils.awaitValue(function()
			local rawOne = controller.mock:GetRaw("user_1")
			local rawTwo = controller.mock:GetRaw("user_2")
			return rawOne ~= nil and rawOne.lock == nil and rawTwo ~= nil and rawTwo.lock == nil
		end, 5)).toEqual(true)
		expect(controller.mock:GetRaw("user_1").coins).toEqual(1)
		expect(controller.mock:GetRaw("user_2").coins).toEqual(2)

		controller:destroy()
	end)

	it("tears down cleanly when a store's load failed, leaking no rejection and writing no lock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:FailAllRequests()

		local dataStore = controller.manager:GetDataStore(1)

		local loaded = dataStore:PromiseLoadSuccessful()
		if not expectSettled(loaded, 10) then
			controller:destroy()
			return
		end
		expect((loaded:Wait())).toEqual(false)

		controller.manager:Destroy()

		expect(controller.mock:GetRaw("user_1")).toBeNil()

		controller:destroy()
	end)
end)
