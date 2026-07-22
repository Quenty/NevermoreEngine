--!nonstrict
--[[
	@class DataStoreReentrance.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("in-flight request cancellation (maid teardown)", function()
	it("cancels a yielding load thread when the DataStore is destroyed (no leaked thread)", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:BlockRequests()

		local dataStore = controller.newSessionLockedStore()
		local promise = dataStore:PromiseLoadSuccessful()

		expect(PromiseTestUtils.awaitSettled(promise, 1)).toEqual(false)

		dataStore:Destroy()

		controller.mock:UnblockRequests()
		local everWrote = PromiseTestUtils.awaitValue(function()
			return controller.mock:GetRaw("player_1") ~= nil
		end, 2)
		expect(everWrote).toEqual(false)

		controller:destroy()
	end)

	it("cancels a yielding save thread when the DataStore is destroyed", function()
		local controller = DataStoreTestUtils.setup()

		local dataStore = controller.newSessionLockedStore()
		local loadPromise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("load hung").toEqual("load settled")
			controller:destroy()
			return
		end

		controller.mock:BlockRequests()
		dataStore:Store("coins", 5)
		local savePromise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(savePromise, 1)).toEqual(false)

		local versionsBefore = controller.mock:GetCallCount("UpdateAsync")
		dataStore:Destroy()
		controller.mock:UnblockRequests()

		local extraWrites = PromiseTestUtils.awaitValue(function()
			return controller.mock:GetCallCount("UpdateAsync") > versionsBefore + 1
		end, 2)
		expect(extraWrites).toEqual(false)

		controller:destroy()
	end)
end)

describe("lock command that does not settle", function()
	it("keeps the load pending while the lock command is outstanding, then completes when it settles", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:BlockRequests()

		local dataStore = controller.newSessionLockedStore()
		local promise = dataStore:PromiseLoadSuccessful()

		expect(PromiseTestUtils.awaitSettled(promise, 2)).toEqual(false)

		controller.mock:UnblockRequests()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("hung after unblock").toEqual("settled")
			controller:destroy()
			return
		end
		expect((promise:Wait())).toEqual(true)

		controller:destroy()
	end)

	it("re-loads cleanly on a fresh session after a cancelled in-flight lock command", function()
		local controller = DataStoreTestUtils.setup()
		controller.mock:BlockRequests()

		local first = controller.newSessionLockedStore()
		local firstPromise = first:PromiseLoadSuccessful()
		expect(PromiseTestUtils.awaitSettled(firstPromise, 1)).toEqual(false)
		first:Destroy()
		controller.mock:UnblockRequests()

		local second = controller.newSessionLockedStore()
		local secondPromise = second:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((secondPromise:Wait())).toEqual(true)

		controller:destroy()
	end)
end)
