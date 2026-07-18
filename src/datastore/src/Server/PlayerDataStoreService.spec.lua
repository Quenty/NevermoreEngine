--!nonstrict
--[[
	Integration coverage for PlayerDataStoreService, the ServiceBag-driven wrapper around one
	PlayerDataStoreManager, with the underlying datastore injected via the SetRobloxDataStore test
	seam. The manager auto-enables session locking, so even a load does an UpdateAsync round-trip
	through the mock. Tests use numeric userIds, never real Players.

	@class PlayerDataStoreService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(mock)
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(require("PlayerDataStoreService"))
	serviceBag:Init()

	if mock then
		service:SetRobloxDataStore(mock)
		serviceBag:Start()
	end

	return {
		service = service,
		mock = mock,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("PlayerDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore and load successfully against a healthy mock", function()
		local controller = setup(DataStoreMock.new())

		local promise = controller.service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadPromise:Wait())).toEqual(true)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreService configuration guards", function()
	it("should throw when SetDataStoreName is called after start", function()
		local controller = setup(DataStoreMock.new())

		expect(function()
			controller.service:SetDataStoreName("X")
		end).toThrow("Already started, cannot configure")

		controller:destroy()
	end)

	it("should throw when SetDataStoreScope is called after start", function()
		local controller = setup(DataStoreMock.new())

		expect(function()
			controller.service:SetDataStoreScope("X")
		end).toThrow("Already started, cannot configure")

		controller:destroy()
	end)

	it("should throw when SetRobloxDataStore is called after the manager is built", function()
		local controller = setup(DataStoreMock.new())

		-- Building the manager (via PromiseDataStore) locks out further overrides.
		local promise = controller.service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		expect(function()
			controller.service:SetRobloxDataStore(controller.mock)
		end).toThrow("Already built manager")

		controller:destroy()
	end)

	it("should throw when SetRobloxDataStore is given a bad datastore", function()
		local controller = setup()

		expect(function()
			controller.service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")

		expect(function()
			controller.service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")

		controller:destroy()
	end)
end)

describe("PlayerDataStoreService.PromiseAddRemovingCallback", function()
	it("should resolve after registering the removing callback", function()
		local controller = setup(DataStoreMock.new())

		local promise = controller.service:PromiseAddRemovingCallback(function() end)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		controller:destroy()
	end)
end)

describe("PlayerDataStoreService failure handling", function()
	it("surfaces a datastore failure to the player fast instead of hanging", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local controller = setup(mock)

		-- PromiseDataStore resolves synchronously; the session-locked load underneath is what must
		-- settle rather than hang against a failing datastore.
		local promise = controller.service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(loadPromise, 5)).toEqual(true)
		expect((loadPromise:Wait())).toEqual(false)

		controller:destroy()
	end)
end)
