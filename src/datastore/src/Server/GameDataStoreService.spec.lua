--!nonstrict
--[[
	Integration coverage for GameDataStoreService wired through a real ServiceBag, with the underlying
	datastore injected via the SetRobloxDataStore test seam. It is not session-locking, so a failing
	load rejects promptly rather than hanging.

	@class GameDataStoreService.spec.lua
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
	mock = mock or DataStoreMock.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(require("GameDataStoreService"))
	serviceBag:Init()
	service:SetRobloxDataStore(mock)
	serviceBag:Start()

	return {
		service = service,
		mock = mock,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("GameDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore that loads successfully against a healthy mock", function()
		local controller = setup()

		local promise = controller.service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadPromise:Wait())).toEqual(true)

		controller:destroy()
	end)

	it("should return the same cached promise on repeated calls", function()
		local controller = setup()

		local first = controller.service:PromiseDataStore()
		local second = controller.service:PromiseDataStore()
		expect((first == second)).toEqual(true)

		controller:destroy()
	end)
end)

describe("GameDataStoreService persistence", function()
	it("should round-trip a stored value into the mock under the version1 key", function()
		local controller = setup()

		local promise = controller.service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		dataStore:Store("motd", "hello")

		local savePromise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(savePromise) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		-- Non-session-locking, so the raw persisted value is the plain data table.
		local raw = controller.mock:GetRaw("version1")
		expect(raw).never.toBeNil()
		expect(raw.motd).toEqual("hello")

		controller:destroy()
	end)
end)

describe("GameDataStoreService.SetRobloxDataStore", function()
	it("should throw when injected twice (already resolved)", function()
		local controller = setup()

		expect(function()
			controller.service:SetRobloxDataStore(DataStoreMock.new())
		end).toThrow("Already resolved robloxDataStore")

		controller:destroy()
	end)

	it("should throw on a non-datastore argument", function()
		local controller = setup()

		-- isDataStore is validated before the already-resolved check, so a bad arg throws regardless.
		expect(function()
			controller.service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")

		expect(function()
			controller.service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")

		controller:destroy()
	end)
end)

describe("GameDataStoreService failure handling", function()
	it("should resolve load as false (not hang) when the datastore is down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local controller = setup(mock)

		local promise = controller.service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		-- Non-session-locking: a failing load rejects promptly, so this settles false rather than hanging.
		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 5) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end

		local loadOk, loadedOk = loadPromise:Yield()
		expect(loadOk).toEqual(true)
		expect(loadedOk).toEqual(false)

		controller:destroy()
	end)
end)
