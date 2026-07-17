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
local afterEach = Jest.Globals.afterEach

-- Each ServiceBag (and the DataStore it owns) is torn down in afterEach so its auto-save loop can
-- never outlive the test. These specs share one Roblox place across all packages, so a leaked
-- background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

-- Builds a real ServiceBag with GameDataStoreService and injects the given mock between Init and
-- Start, before any PromiseDataStore call. Returns the service and bag.
local function newService(mock)
	local serviceBag = ServiceBag.new()
	local service = serviceBag:GetService(require("GameDataStoreService"))
	serviceBag:Init()
	service:SetRobloxDataStore(mock)
	serviceBag:Start()
	maid:Add(serviceBag)
	return service, serviceBag
end

describe("GameDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore that loads successfully against a healthy mock", function()
		local service = newService(DataStoreMock.new())

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise) then
			expect("hung").toEqual("settled")
			return
		end
		expect((select(2, loadPromise:Yield()))).toEqual(true)
	end)

	it("should return the same cached promise on repeated calls", function()
		local service = newService(DataStoreMock.new())

		local first = service:PromiseDataStore()
		local second = service:PromiseDataStore()
		expect((first == second)).toEqual(true)
	end)
end)

describe("GameDataStoreService persistence", function()
	it("should round-trip a stored value into the mock under the version1 key", function()
		local mock = DataStoreMock.new()
		local service = newService(mock)

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		dataStore:Store("motd", "hello")

		local savePromise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(savePromise) then
			expect("hung").toEqual("settled")
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		-- Non-session-locking, so the raw persisted value is the plain data table.
		local raw = mock:GetRaw("version1")
		expect(raw).never.toBeNil()
		expect(raw.motd).toEqual("hello")
	end)
end)

describe("GameDataStoreService.SetRobloxDataStore", function()
	it("should throw when injected twice (already resolved)", function()
		local service = newService(DataStoreMock.new())

		expect(function()
			service:SetRobloxDataStore(DataStoreMock.new())
		end).toThrow("Already resolved robloxDataStore")
	end)

	it("should throw on a non-datastore argument", function()
		local service = newService(DataStoreMock.new())

		-- isDataStore is validated before the already-resolved check, so a bad arg throws regardless.
		expect(function()
			service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")

		expect(function()
			service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")
	end)
end)

describe("GameDataStoreService failure handling", function()
	it("should resolve load as false (not hang) when the datastore is down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local service = newService(mock)

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		-- Non-session-locking: a failing load rejects promptly, so this settles false rather than hanging.
		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 5) then
			expect("hung").toEqual("settled")
			return
		end

		local loadOk, loadedOk = loadPromise:Yield()
		expect(loadOk).toEqual(true)
		expect(loadedOk).toEqual(false)
	end)
end)
