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
local afterEach = Jest.Globals.afterEach

-- Each ServiceBag (and the session-locked stores its manager owns) is torn down in afterEach so an
-- auto-save loop can never outlive the test. These specs share one Roblox place across all packages,
-- so a leaked background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

-- Builds a ServiceBag with the service registered and initialized, but NOT started, so callers can
-- configure it (SetDataStoreName/Scope/SetRobloxDataStore) first.
local function initService()
	local serviceBag = ServiceBag.new()
	local service = serviceBag:GetService(require("PlayerDataStoreService"))
	serviceBag:Init()
	maid:Add(serviceBag)
	return service, serviceBag
end

-- Injects the mock through the seam between Init and Start, before the manager is first built, then
-- starts the bag.
local function newService(mock)
	local service, serviceBag = initService()
	service:SetRobloxDataStore(mock)
	serviceBag:Start()
	return service, serviceBag
end

describe("PlayerDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore and load successfully against a healthy mock", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		local promise = service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((select(2, loadPromise:Yield()))).toEqual(true)
	end)
end)

describe("PlayerDataStoreService configuration guards", function()
	it("should throw when SetDataStoreName is called after start", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		expect(function()
			service:SetDataStoreName("X")
		end).toThrow("Already started, cannot configure")
	end)

	it("should throw when SetDataStoreScope is called after start", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		expect(function()
			service:SetDataStoreScope("X")
		end).toThrow("Already started, cannot configure")
	end)

	it("should throw when SetRobloxDataStore is called after the manager is built", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		-- Building the manager (via PromiseDataStore) locks out further overrides.
		local promise = service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end

		expect(function()
			service:SetRobloxDataStore(mock)
		end).toThrow("Already built manager")
	end)

	it("should throw when SetRobloxDataStore is given a bad datastore", function()
		local service = initService()

		expect(function()
			service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")

		expect(function()
			service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")
	end)
end)

describe("PlayerDataStoreService.PromiseAddRemovingCallback", function()
	it("should resolve after registering the removing callback", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		local promise = service:PromiseAddRemovingCallback(function() end)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end
		expect((promise:Yield())).toEqual(true)
	end)
end)

describe("PlayerDataStoreService failure handling", function()
	it("surfaces a datastore failure to the player fast instead of hanging", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local service = newService(mock)

		-- PromiseDataStore resolves synchronously; the session-locked load underneath is what must
		-- settle rather than hang against a failing datastore.
		local promise = service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(loadPromise, 5)).toEqual(true)
		expect((select(2, loadPromise:Yield()))).toEqual(false)
	end)
end)
