--!strict
--[[
	Counted datastore handles. Opening a store for an absent player takes their session lock, so the
	thing worth pinning down is that the session is released once nothing is holding it -- and not
	before, while another holder is still using it.

	@class PlayerDataStoreManager.Handles.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Returns the resolved value, or fails the spec and returns nil.
local function awaitValue(promise, label: string): any
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		expect(`{label} hung`).toEqual(`{label} settled`)
		return nil
	end

	local ok, value = promise:Yield()
	expect(ok).toEqual(true)
	return value
end

-- Drains the removals a test left in flight, so none of them settle during teardown. Note that this
-- also *removes* every remaining store, so it belongs at the end of a test and nowhere else.
local function settleSaves(controller): ()
	if not PromiseTestUtils.awaitSettled(controller.manager:PromiseAllSaves(), 10) then
		expect("saves hung").toEqual("saves settled")
	end
end

describe("PlayerDataStoreManager.PromiseDataStoreHandle", function()
	it("hands back the store for the player", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local handle = awaitValue(controller.manager:PromiseDataStoreHandle(1), "handle")
		expect(handle).never.toBeNil()
		expect(handle:GetDataStore()).never.toBeNil()

		handle:Destroy()
		settleSaves(controller)

		controller:Destroy()
	end)

	-- Whether the session is still open is read through store identity rather than the stored lock:
	-- the lock is written asynchronously as the load settles, so asserting on it here would be timing
	-- dependent. A released session is gone, so the next handle has to build a new store object.
	it("releases the session once the handle is destroyed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local first = awaitValue(controller.manager:PromiseDataStoreHandle(1), "first")
		local released = first:GetDataStore()

		first:Destroy()

		local second = awaitValue(controller.manager:PromiseDataStoreHandle(1), "second")
		expect(second:GetDataStore() == released).toEqual(false)

		second:Destroy()
		settleSaves(controller)

		controller:Destroy()
	end)

	it("holds the session while another handle is still open", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local first = awaitValue(controller.manager:PromiseDataStoreHandle(1), "first")
		local second = awaitValue(controller.manager:PromiseDataStoreHandle(1), "second")

		local shared = first:GetDataStore()

		-- Both name the same session rather than opening a second one.
		expect(second:GetDataStore() == shared).toEqual(true)

		first:Destroy()

		-- Still the same store, because the second handle never let go of it.
		local third = awaitValue(controller.manager:PromiseDataStoreHandle(1), "third")
		expect(third:GetDataStore() == shared).toEqual(true)

		second:Destroy()
		third:Destroy()

		local fourth = awaitValue(controller.manager:PromiseDataStoreHandle(1), "fourth")
		expect(fourth:GetDataStore() == shared).toEqual(false)

		fourth:Destroy()
		settleSaves(controller)

		controller:Destroy()
	end)

	it("survives being destroyed twice", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local handle = awaitValue(controller.manager:PromiseDataStoreHandle(1), "handle")
		handle:Destroy()
		handle:Destroy()
		settleSaves(controller)

		controller:Destroy()
	end)

	it("refuses to hand back a store once destroyed", function()
		local controller = DataStoreTestUtils.setupDataStoreManager()

		controller.mock:SetRaw("user_1", { coins = 5 })

		local handle = awaitValue(controller.manager:PromiseDataStoreHandle(1), "handle")
		handle:Destroy()
		settleSaves(controller)

		expect(function()
			handle:GetDataStore()
		end).toThrow()

		controller:Destroy()
	end)
end)
