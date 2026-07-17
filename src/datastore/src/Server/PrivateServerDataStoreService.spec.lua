--!nonstrict
--[[
	Integration coverage for PrivateServerDataStoreService wired through a real ServiceBag, with the
	underlying datastore injected via the SetRobloxDataStore test seam. It is not session-locking, so a
	failing load rejects promptly rather than hanging. The datastore key defaults to "main" (or the
	private-server id) unless a custom key is set via SetCustomKey before the datastore is resolved.

	@class PrivateServerDataStoreService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a real ServiceBag with PrivateServerDataStoreService and injects the given mock between Init
-- and Start, before any PromiseDataStore call. Returns the service and bag for teardown.
local function newService(mock)
	local serviceBag = ServiceBag.new()
	local service = serviceBag:GetService(require("PrivateServerDataStoreService"))
	serviceBag:Init()
	service:SetRobloxDataStore(mock)
	serviceBag:Start()
	return service, serviceBag
end

describe("PrivateServerDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore that loads successfully against a healthy mock", function()
		local service, serviceBag = newService(DataStoreMock.new())

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(dataStore).never.toBeNil()

		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end
		expect((select(2, loadPromise:Yield()))).toEqual(true)

		serviceBag:Destroy()
	end)

	it("should return the same cached promise on repeated calls", function()
		local service, serviceBag = newService(DataStoreMock.new())

		local first = service:PromiseDataStore()
		local second = service:PromiseDataStore()
		expect((first == second)).toEqual(true)

		serviceBag:Destroy()
	end)
end)

describe("PrivateServerDataStoreService.SetCustomKey", function()
	it("should key the datastore by the custom key when set before resolving", function()
		local service, serviceBag = newService(DataStoreMock.new())

		service:SetCustomKey("mykey")

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect((dataStore:GetKey())).toEqual("mykey")

		serviceBag:Destroy()
	end)
end)

describe("PrivateServerDataStoreService persistence", function()
	it("should round-trip a stored value into the mock under the datastore key", function()
		local mock = DataStoreMock.new()
		local service, serviceBag = newService(mock)

		service:SetCustomKey("mykey")

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		local key = dataStore:GetKey()
		dataStore:Store("motd", "hello")

		local savePromise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(savePromise) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		-- Non-session-locking, so the raw persisted value is the plain data table.
		local raw = mock:GetRaw(key)
		expect(raw).never.toBeNil()
		expect(raw.motd).toEqual("hello")

		serviceBag:Destroy()
	end)
end)

describe("PrivateServerDataStoreService.SetRobloxDataStore", function()
	it("should throw when injected twice (already resolved)", function()
		local service, serviceBag = newService(DataStoreMock.new())

		expect(function()
			service:SetRobloxDataStore(DataStoreMock.new())
		end).toThrow("Already resolved robloxDataStore")

		serviceBag:Destroy()
	end)

	it("should throw on a non-datastore argument", function()
		local service, serviceBag = newService(DataStoreMock.new())

		-- isDataStore is validated before the already-resolved check, so a bad arg throws regardless.
		expect(function()
			service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")

		expect(function()
			service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")

		serviceBag:Destroy()
	end)
end)

describe("PrivateServerDataStoreService failure handling", function()
	it("should resolve load as false (not hang) when the datastore is down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local service, serviceBag = newService(mock)

		local promise = service:PromiseDataStore()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)

		-- Non-session-locking: a failing load rejects promptly, so this settles false rather than hanging.
		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 5) then
			expect("hung").toEqual("settled")
			serviceBag:Destroy()
			return
		end

		local loadOk, loadedOk = loadPromise:Yield()
		expect(loadOk).toEqual(true)
		expect(loadedOk).toEqual(false)

		serviceBag:Destroy()
	end)
end)
