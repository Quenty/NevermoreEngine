--!nonstrict
--[[
	@class DataStore.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function expectSettled(promise, timeout: number?)
	expect(PromiseTestUtils.awaitSettled(promise, timeout)).toEqual(true)
end

describe("DataStore without session locking", function()
	it("should load the default value when the key is empty", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		local promise = dataStore:Load("coins", 99)
		expectSettled(promise)

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(99)

		controller:destroy()
	end)

	it("should round-trip a stored value through the datastore", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("coins", 5)

		local savePromise = writer:Save()
		expectSettled(savePromise)
		expect((savePromise:Yield())).toEqual(true)

		local reader = controller.newDataStore()
		local loadPromise = reader:Load("coins")
		expectSettled(loadPromise)

		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(5)

		controller:destroy()
	end)

	it("should round-trip multiple keys and load defaults for missing ones", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("coins", 5)
		writer:Store("gems", 10)
		expectSettled(writer:Save())

		local reader = controller.newDataStore()
		local promise = reader:LoadAll()
		expectSettled(promise)

		local ok, all = promise:Yield()
		expect(ok).toEqual(true)
		expect(all.coins).toEqual(5)
		expect(all.gems).toEqual(10)

		local missingPromise = reader:Load("missing", "default")
		expectSettled(missingPromise)
		expect((missingPromise:Wait())).toEqual("default")

		controller:destroy()
	end)

	it("should round-trip substore values", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:GetSubStore("inventory"):Store("sword", true)
		expectSettled(writer:Save())

		local reader = controller.newDataStore()
		local promise = reader:GetSubStore("inventory"):Load("sword")
		expectSettled(promise)

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(true)

		controller:destroy()
	end)

	it("should delete a key so it no longer loads", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("a", 1)
		writer:Store("b", 2)
		expectSettled(writer:Save())

		writer:Delete("a")
		expectSettled(writer:Save())

		local reader = controller.newDataStore()
		local promise = reader:LoadAll()
		expectSettled(promise)

		local ok, all = promise:Yield()
		expect(ok).toEqual(true)
		expect(all.a).toEqual(nil)
		expect(all.b).toEqual(2)

		controller:destroy()
	end)

	it("should resolve a save when nothing is staged", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expectSettled(dataStore:Load("x"))

		local savePromise = dataStore:Save()
		expectSettled(savePromise)
		expect((savePromise:Yield())).toEqual(true)

		controller:destroy()
	end)

	it("should report load failure (not hang) when the datastore is unavailable", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()
		local dataStore = controller.newDataStore()

		local promise = dataStore:PromiseLoadSuccessful()
		expectSettled(promise, 5)

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		controller:destroy()
	end)

	it("should reject a save when the datastore goes down after loading", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expectSettled(dataStore:Load("x"))

		controller.mock:FailAllRequests()
		dataStore:Store("x", 1)

		local savePromise = dataStore:Save()
		expectSettled(savePromise, 5)
		expect((savePromise:Yield())).toEqual(false)

		controller:destroy()
	end)

	it("should mark DidLoadFail after a failed load", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()
		local dataStore = controller.newDataStore()

		local promise = dataStore:PromiseLoadSuccessful()
		expectSettled(promise, 5)

		expect(dataStore:DidLoadFail()).toEqual(true)

		controller:destroy()
	end)
end)

describe("DataStore with session locking", function()
	it("should load successfully against a healthy datastore", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		expectSettled(promise, 10)

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(true)

		controller:destroy()
	end)

	it("surfaces a persistent datastore failure fast instead of hanging", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		expectSettled(promise, 5)

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		controller:destroy()
	end)

	it("rejects a failed session-locked load with the preserved datastore error", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests(DataStoreMock.OPERATION_NOT_ALLOWED_509)

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:PromiseViewUpToDate())

		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "509", 1, true) ~= nil).toEqual(true)

		controller:destroy()
	end)
end)
