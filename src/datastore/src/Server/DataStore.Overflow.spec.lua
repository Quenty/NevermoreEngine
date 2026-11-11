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

describe("DataStore overflow save", function()
	it("should reject a save whose serialized value exceeds the datastore size limit", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expect(PromiseTestUtils.awaitSettled(dataStore:Load("data"))).toEqual(true)

		controller.mock:SetMaxValueLength(1024)
		dataStore:Store("data", string.rep("A", 8192))

		PromiseTestUtils.awaitRejected(dataStore:Save(), 5)

		controller:Destroy()
	end)

	it("should leave the previously saved value intact when an oversized save fails", function()
		local controller = DataStoreTestUtils.setup()
		local writer = controller.newDataStore()

		writer:Store("data", "known-good")
		expect(PromiseTestUtils.awaitSettled(writer:Save())).toEqual(true)

		controller.mock:SetMaxValueLength(1024)
		writer:Store("data", string.rep("A", 8192))

		PromiseTestUtils.awaitRejected(writer:Save(), 5)

		controller.mock:SetMaxValueLength(nil)
		local reader = controller.newDataStore()
		local value = PromiseTestUtils.awaitFulfilled(reader:Load("data"))
		expect(value).toEqual("known-good")

		controller:Destroy()
	end)

	it("should still save values that fit within the real 4 MB ceiling", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		controller.mock:SetMaxValueLength(DataStoreMock.MAX_VALUE_LENGTH)
		dataStore:Store("coins", 5)

		PromiseTestUtils.awaitFulfilled(dataStore:Save())

		local reader = controller.newDataStore()
		PromiseTestUtils.awaitFulfilled(reader:Load("coins"))

		controller:Destroy()
	end)

	it("should fail the save when data accumulated across substores overflows the key", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expect(PromiseTestUtils.awaitSettled(dataStore:Load("data"))).toEqual(true)

		controller.mock:SetMaxValueLength(1024)
		dataStore:GetSubStore("inventory"):Store("blob", string.rep("A", 8192))

		PromiseTestUtils.awaitRejected(dataStore:Save(), 5)

		controller:Destroy()
	end)
end)
