--!nonstrict
--[[
	Integration coverage for PlayerDataStoreManager against a mocked Roblox datastore. The manager
	auto-enables session locking and session messaging on every DataStore it creates, so even a load
	does an UpdateAsync round-trip through the mock. Tests use numeric userIds, never real Players.

	@class PlayerDataStoreManager.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Asserts the promise settled within the timeout and returns whether it is now safe to :Yield(), so
-- a hung promise fails the test instead of freezing the runner.
local function expectSettled(promise, timeout: number?): boolean
	local settled = PromiseTestUtils.awaitSettled(promise, timeout)
	expect(settled).toEqual(true)
	return settled
end

local function keyGenerator(userId)
	return "user_" .. tostring(userId)
end

-- Builds a real ServiceBag plus a session-locked manager wired to a fresh mock. Everything is owned by
-- a Maid, so destroy() tears down the manager (and the loaded stores whose auto-save loops it owns)
-- along with the bag, and nothing keeps running after the test.
local function setup()
	local maid = Maid.new()

	-- The manager enables session messaging on each DataStore, which pulls PlaceMessagingService
	-- off the bag. Services must be registered before Start, so register it up front.
	local serviceBag = maid:Add(ServiceBag.new())
	serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	serviceBag:Start()

	local mock = DataStoreMock.new()
	local manager = maid:Add(PlayerDataStoreManager.new(serviceBag, mock, keyGenerator, true))

	return {
		manager = manager,
		mock = mock,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("PlayerDataStoreManager.GetDataStore", function()
	it("should return a datastore for a fresh user", function()
		local controller = setup()

		local dataStore = controller.manager:GetDataStore(1)
		expect(dataStore).never.toBeNil()

		controller:destroy()
	end)

	it("should cache the datastore per user", function()
		local controller = setup()

		local first = controller.manager:GetDataStore(1)
		local second = controller.manager:GetDataStore(1)
		expect(first).toEqual(second)

		local other = controller.manager:GetDataStore(2)
		expect((first == other)).toEqual(false)

		controller:destroy()
	end)

	it("should apply the key generator", function()
		local controller = setup()

		local dataStore = controller.manager:GetDataStore(1)
		expect((dataStore:GetKey())).toEqual("user_1")

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager.PromiseDataStore", function()
	it("should resolve the datastore and load successfully against a healthy mock", function()
		local controller = setup()

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
		expect((select(2, loadPromise:Yield()))).toEqual(true)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreManager persistence", function()
	it("should round-trip a stored value across a removal/reload", function()
		local controller = setup()

		local dataStore = controller.manager:GetDataStore(1)
		dataStore:Store("coins", 5)

		-- Removal saves (SaveAndCloseSession) then closes the session, asynchronously.
		controller.manager:RemovePlayerDataStore(1)

		-- PromiseDataStore waits for the in-progress removal to finish before handing back a
		-- fresh datastore for the same user.
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
		local controller = setup()

		local ran = false
		controller.manager:AddRemovingCallback(function()
			ran = true
		end)

		controller.manager:GetDataStore(1)

		-- Drain the removal to be sure the callback fired.
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
		local controller = setup()

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
