--!nonstrict
--[[
	Integration coverage for DataStore against a mocked Roblox datastore: the load/save round-trip
	and how it behaves when datastore operations fail (e.g. the 509 Personal-RCC block).

	@class DataStore.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Asserts the promise settled within the timeout, so a hung promise fails the test (here) instead of
-- freezing the runner on the following :Yield().
local function expectSettled(promise, timeout: number?)
	expect(PromiseTestUtils.awaitSettled(promise, timeout)).toEqual(true)
end

-- Builds DataStores over a shared mock and owns them with a Maid, so destroy() tears down every store
-- (and the auto-save loop each starts once loaded) the test created. Pass a pre-configured mock for
-- failure-injection tests, or read controller.mock to configure it before creating a store.
local function setup(mock)
	local maid = Maid.new()
	mock = mock or DataStoreMock.new()

	local function newDataStore()
		return maid:Add(DataStore.new(mock, "player_1"))
	end

	return {
		mock = mock,
		newDataStore = newDataStore,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("DataStore without session locking", function()
	it("should load the default value when the key is empty", function()
		local controller = setup()
		local dataStore = controller.newDataStore()

		local promise = dataStore:Load("coins", 99)
		expectSettled(promise)

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(99)

		controller:destroy()
	end)

	it("should round-trip a stored value through the datastore", function()
		local controller = setup()

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
		local controller = setup()

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
		expect((select(2, missingPromise:Yield()))).toEqual("default")

		controller:destroy()
	end)

	it("should round-trip substore values", function()
		local controller = setup()

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
		local controller = setup()

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
		local controller = setup()
		local dataStore = controller.newDataStore()

		expectSettled(dataStore:Load("x"))

		local savePromise = dataStore:Save()
		expectSettled(savePromise)
		expect((savePromise:Yield())).toEqual(true)

		controller:destroy()
	end)

	it("should report load failure (not hang) when the datastore is unavailable", function()
		local controller = setup()
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
		local controller = setup()
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
		local controller = setup()
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
		local controller = setup()

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
		local controller = setup()
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
		local controller = setup()
		controller.mock:FailAllRequests(DataStoreMock.OPERATION_NOT_ALLOWED_509)

		local dataStore = controller.newDataStore()
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		-- PromiseLoadSuccessful maps the error to a boolean, so read the rejection from
		-- PromiseViewUpToDate to assert the underlying datastore error propagates.
		local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:PromiseViewUpToDate())

		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "509", 1, true) ~= nil).toEqual(true)

		controller:destroy()
	end)
end)
