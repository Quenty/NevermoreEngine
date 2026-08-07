--!nonstrict
--[[
	Teardown that lands while a datastore request is already in flight.

	[Promise.spawn] runs the request on a thread it does not retain, so the promise a teardown
	cancels is not the call -- Roblox invokes the transform regardless, after [BaseObject.Destroy]
	has stripped the session-locking helper's metatable. Reaching through the field at that point
	raises "attempt to call missing method" from inside the transform, which aborts the write
	Roblox was about to commit. The transform has to notice the store is gone and cancel instead.

	@class DataStore.TeardownDuringRequest.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Waits out the drain by watching for the failure itself: with the guard in place nothing is ever
-- recorded and this spends its whole budget, which is also how long the request needs to land.
local function drain(controller)
	PromiseTestUtils.awaitValue(function()
		return controller.mock:GetLastTransformError() ~= nil
	end, 2)
end

describe("teardown during an in-flight load", function()
	it("cancels the write instead of raising out of the transform", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:BlockRequests()

		local dataStore = controller.newSessionLockedStore()
		local promise = dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(promise, 1)).toEqual(false)

		dataStore:Destroy()
		controller.mock:UnblockRequests()
		drain(controller)

		expect(controller.mock:GetLastTransformError()).toEqual(nil)
		expect(controller.mock:GetRaw("player_1")).toEqual(nil)

		controller:destroy()
	end)

	it("leaves no lock behind for the next session to contend with", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:BlockRequests()

		local dataStore = controller.newSessionLockedStore()
		dataStore:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(dataStore:PromiseLoadSuccessful(), 1)).toEqual(false)

		dataStore:Destroy()
		controller.mock:UnblockRequests()
		drain(controller)

		local raw = controller.mock:GetRaw("player_1")
		expect(raw == nil or raw.lock == nil).toEqual(true)

		controller:destroy()
	end)
end)

describe("teardown during an in-flight save", function()
	it("cancels the write instead of raising out of the transform", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newSessionLockedStore()
		if not controller.awaitOwn(dataStore) then
			expect("load never settled").toEqual("load settled")
			controller:destroy()
			return
		end

		controller.mock:BlockRequests()
		dataStore:Store("coins", 5)
		local savePromise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(savePromise, 1)).toEqual(false)

		dataStore:Destroy()
		controller.mock:UnblockRequests()
		drain(controller)

		expect(controller.mock:GetLastTransformError()).toEqual(nil)

		controller:destroy()
	end)
end)
