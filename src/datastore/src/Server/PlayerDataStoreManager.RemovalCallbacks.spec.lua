--!nonstrict
--[[
	@class PlayerDataStoreManager.RemovalCallbacks.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerDataStoreManager removal matrix (misbehaving removing callbacks)", function()
	it("well-behaved callback: saves the data AND releases the lock", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()
		controller.manager:AddRemovingCallback(function()
			return Promise.resolved()
		end)

		expect(controller.storeAndAwaitLock()).toEqual(true)
		controller.manager:RemovePlayerDataStore(1)

		expect(PromiseTestUtils.awaitValue(function()
			local raw = controller.mock:GetRaw("user_1")
			return raw ~= nil and raw.coins == 5
		end, 10)).toEqual(true)
		expect(controller.mock:GetRaw("user_1").lock).toEqual(nil)

		controller:destroy()
	end)

	describe("failure modes", function()
		it("rejecting callback: skips the save (data loss) AND leaves the lock held", function()
			local controller = DataStoreTestUtils.setupDataStoreManager()
			controller.manager:AddRemovingCallback(function()
				return Promise.rejected("removing callback failed")
			end)

			expect(controller.storeAndAwaitLock()).toEqual(true)
			controller.manager:RemovePlayerDataStore(1)

			expect(PromiseTestUtils.awaitValue(function()
				local raw = controller.mock:GetRaw("user_1")
				return raw ~= nil and raw.coins == 5
			end, 3)).toEqual(false)
			expect(controller.mock:GetRaw("user_1").lock ~= nil).toEqual(true)

			controller:destroy()
		end)

		it("throwing callback: the synchronous throw escapes removal (lock held, stuck)", function()
			local controller = DataStoreTestUtils.setupDataStoreManager()
			controller.manager:AddRemovingCallback(function()
				error("removing callback boom")
			end)

			expect(controller.storeAndAwaitLock()).toEqual(true)

			expect(function()
				controller.manager:RemovePlayerDataStore(1)
			end).toThrow("removing callback boom")
			expect(controller.mock:GetRaw("user_1").lock ~= nil).toEqual(true)

			controller:destroy()
		end)

		it("yielding callback: removal blocks forever (no save, lock held)", function()
			local controller = DataStoreTestUtils.setupDataStoreManager()
			controller.manager:AddRemovingCallback(function()
				return Promise.new()
			end)

			expect(controller.storeAndAwaitLock()).toEqual(true)
			controller.manager:RemovePlayerDataStore(1)

			expect(PromiseTestUtils.awaitValue(function()
				local raw = controller.mock:GetRaw("user_1")
				return raw ~= nil and raw.coins == 5
			end, 2)).toEqual(false)
			expect(controller.mock:GetRaw("user_1").lock ~= nil).toEqual(true)

			controller:destroy()
		end)
	end)
end)
