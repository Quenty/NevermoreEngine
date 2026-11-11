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

describe("DataStore without session locking", function()
	it("should load the default value when the key is empty", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		local value = PromiseTestUtils.awaitFulfilled(dataStore:Load("coins", 99))
		expect(value).toEqual(99)

		controller:Destroy()
	end)

	it("should round-trip a stored value through the datastore", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("coins", 5)

		PromiseTestUtils.awaitFulfilled(writer:Save())

		local reader = controller.newDataStore()
		local value = PromiseTestUtils.awaitFulfilled(reader:Load("coins"))
		expect(value).toEqual(5)

		controller:Destroy()
	end)

	it("should round-trip multiple keys and load defaults for missing ones", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("coins", 5)
		writer:Store("gems", 10)
		expect(PromiseTestUtils.awaitSettled(writer:Save())).toEqual(true)

		local reader = controller.newDataStore()
		local all = PromiseTestUtils.awaitFulfilled(reader:LoadAll())
		expect(all.coins).toEqual(5)
		expect(all.gems).toEqual(10)

		expect(PromiseTestUtils.awaitFulfilled(reader:Load("missing", "default"))).toEqual("default")

		controller:Destroy()
	end)

	it("should round-trip substore values", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:GetSubStore("inventory"):Store("sword", true)
		expect(PromiseTestUtils.awaitSettled(writer:Save())).toEqual(true)

		local reader = controller.newDataStore()
		local value = PromiseTestUtils.awaitFulfilled(reader:GetSubStore("inventory"):Load("sword"))
		expect(value).toEqual(true)

		controller:Destroy()
	end)

	it("should delete a key so it no longer loads", function()
		local controller = DataStoreTestUtils.setup()

		local writer = controller.newDataStore()
		writer:Store("a", 1)
		writer:Store("b", 2)
		expect(PromiseTestUtils.awaitSettled(writer:Save())).toEqual(true)

		writer:Delete("a")
		expect(PromiseTestUtils.awaitSettled(writer:Save())).toEqual(true)

		local reader = controller.newDataStore()
		local all = PromiseTestUtils.awaitFulfilled(reader:LoadAll())
		expect(all.a).toEqual(nil)
		expect(all.b).toEqual(2)

		controller:Destroy()
	end)

	it("should resolve a save when nothing is staged", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expect(PromiseTestUtils.awaitSettled(dataStore:Load("x"))).toEqual(true)

		PromiseTestUtils.awaitFulfilled(dataStore:Save())

		controller:Destroy()
	end)

	it("should report load failure (not hang) when the datastore is unavailable", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()
		local dataStore = controller.newDataStore()

		local loadedOk = PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 5)
		expect(loadedOk).toEqual(false)

		controller:Destroy()
	end)

	it("should reject a save when the datastore goes down after loading", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expect(PromiseTestUtils.awaitSettled(dataStore:Load("x"))).toEqual(true)

		controller.mock:FailAllRequests()
		dataStore:Store("x", 1)

		PromiseTestUtils.awaitRejected(dataStore:Save(), 5)

		controller:Destroy()
	end)

	it("should mark DidLoadFail after a failed load", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()
		local dataStore = controller.newDataStore()

		expect(PromiseTestUtils.awaitSettled(dataStore:PromiseLoadSuccessful(), 5)).toEqual(true)

		expect(dataStore:DidLoadFail()).toEqual(true)

		controller:Destroy()
	end)
end)

describe("DataStore with session locking", function()
	it("should load successfully against a healthy datastore", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local loadedOk = PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 10)
		expect(loadedOk).toEqual(true)

		controller:Destroy()
	end)

	it("surfaces a persistent datastore failure fast instead of hanging", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:FailAllRequests()

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local loadedOk = PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 5)
		expect(loadedOk).toEqual(false)

		controller:Destroy()
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

		controller:Destroy()
	end)
end)
