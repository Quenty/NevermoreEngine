--!nonstrict
--[[
	@class DataStore.Overflow.spec.lua
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

describe("DataStore overflow save", function()
	it("should reject a save whose serialized value exceeds the datastore size limit", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expectSettled(dataStore:Load("data"))

		controller.mock:SetMaxValueLength(1024)
		dataStore:Store("data", string.rep("A", 8192))

		local savePromise = dataStore:Save()
		expectSettled(savePromise, 5)
		expect((savePromise:Yield())).toEqual(false)

		controller:destroy()
	end)

	it("should leave the previously saved value intact when an oversized save fails", function()
		local controller = DataStoreTestUtils.setup()
		local writer = controller.newDataStore()

		writer:Store("data", "known-good")
		expectSettled(writer:Save())

		controller.mock:SetMaxValueLength(1024)
		writer:Store("data", string.rep("A", 8192))

		local savePromise = writer:Save()
		expectSettled(savePromise, 5)
		expect((savePromise:Yield())).toEqual(false)

		controller.mock:SetMaxValueLength(nil)
		local reader = controller.newDataStore()
		local loadPromise = reader:Load("data")
		expectSettled(loadPromise)

		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual("known-good")

		controller:destroy()
	end)

	it("should still save values that fit within the real 4 MB ceiling", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		controller.mock:SetMaxValueLength(DataStoreMock.MAX_VALUE_LENGTH)
		dataStore:Store("coins", 5)

		local savePromise = dataStore:Save()
		expectSettled(savePromise)
		expect((savePromise:Yield())).toEqual(true)

		local reader = controller.newDataStore()
		local loadPromise = reader:Load("coins")
		expectSettled(loadPromise)
		expect((loadPromise:Yield())).toEqual(true)

		controller:destroy()
	end)

	it("should fail the save when data accumulated across substores overflows the key", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expectSettled(dataStore:Load("data"))

		controller.mock:SetMaxValueLength(1024)
		dataStore:GetSubStore("inventory"):Store("blob", string.rep("A", 8192))

		local savePromise = dataStore:Save()
		expectSettled(savePromise, 5)
		expect((savePromise:Yield())).toEqual(false)

		controller:destroy()
	end)
end)
