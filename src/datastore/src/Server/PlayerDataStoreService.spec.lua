--!nonstrict
--[[
	@class PlayerDataStoreService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local Promise = require("Promise")
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

	-- Drives the real close path: the manager the service owns, shut down the way Roblox does. Without a
	-- mock the bag was never started, so there is no manager to reach and nothing to shut down.
	local function promiseShutdown(userIds)
		if not mock then
			return Promise.resolved()
		end

		return service:PromiseManager():Then(function(manager)
			return DataStoreTestUtils.promiseSimulatedShutdown(manager, userIds)
		end)
	end

	return {
		service = service,
		mock = mock,
		promiseShutdown = promiseShutdown,
		destroy = function()
			-- Otherwise a store the spec loaded outlives it with its auto-save loop running, and fires
			-- inside a later package's window in the shared test place.
			PromiseTestUtils.awaitSettled(promiseShutdown(), 5)
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

-- The service registers manager:PromiseAllSaves() as its BindToClose callback, so a closing server is
-- PlayerRemoving doing the save-and-close with that callback held open until it flushes.
describe("PlayerDataStoreService server shutdown", function()
	it("saves the staged data and destroys the store when the server closes", function()
		local controller = setup(DataStoreMock.new())

		local promise = controller.service:PromiseDataStore(1)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		local _ok, dataStore = promise:Yield()

		if not PromiseTestUtils.awaitSettled(dataStore:PromiseLoadSuccessful(), 10) then
			expect("load hung").toEqual("load settled")
			controller:destroy()
			return
		end

		dataStore:Store("coins", 7)

		if not PromiseTestUtils.awaitSettled(controller.promiseShutdown({ 1 }), 10) then
			expect("shutdown never flushed").toEqual("shutdown flushed")
			controller:destroy()
			return
		end

		local raw = controller.mock:GetRaw("1")
		expect(raw).never.toBeNil()
		expect(raw.coins).toEqual(7)
		expect(getmetatable(dataStore)).toBeNil()

		controller:destroy()
	end)
end)
