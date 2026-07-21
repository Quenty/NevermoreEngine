--!nonstrict
--[[
	Characterizes how the save-slot system handles the overflow-save failure: when a slot accumulates
	more data than Roblox can serialize under its per-key size ceiling, the save must fail loudly
	instead of silently dropping data or corrupting the slot that was already stored. Driven through the
	same mock-injected PlayerDataStoreService and SaveSlotConstants substore layout the load flow uses
	(see SaveSlotLoadFlow.spec), with the DataStoreMock configured to a small
	[DataStoreMock.SetMaxValueLength] so the overflow triggers without a multi-megabyte payload.

	@class SaveSlotOverflow.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a ServiceBag with a mock-injected PlayerDataStoreService, owned by a Maid so destroy() tears
-- down the service (and the session-locked stores its manager owns). Read controller.mock to seed,
-- fail, or size-limit the datastore.
local function setup(mock)
	local maid = Maid.new()
	mock = mock or DataStoreMock.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService = serviceBag:GetService(require("PlayerDataStoreService"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	return {
		playerDataStoreService = playerDataStoreService,
		mock = mock,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

-- Resolves the session-locked datastore for a userId (bounded); returns nil on failure to settle.
local function resolveDataStore(playerDataStoreService, userId)
	local promise = playerDataStoreService:PromiseDataStore(userId)
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		return nil
	end
	local ok, dataStore = promise:Yield()
	if not ok then
		return nil
	end
	return dataStore
end

-- Slot stores live at SaveSlots.slots.<slotId>, matching HasSaveSlots._getSlotStore.
local function getSlotStore(dataStore, slotId)
	return dataStore
		:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
		:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY)
		:GetSubStore(slotId)
end

describe("save slot overflow save", function()
	it("fails the save when a slot grows past the datastore size limit", function()
		local controller = setup()

		local dataStore = resolveDataStore(controller.playerDataStoreService, 1)
		expect(dataStore).never.toBeNil()

		local slotStore = getSlotStore(dataStore, "slot-abc")

		-- A first, well-sized save acquires the session lock and writes the slot.
		slotStore:Store("coins", 25)
		local firstSave = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(firstSave, 10)).toEqual(true)
		expect((firstSave:Yield())).toEqual(true)

		-- Now overflow the slot with more data than the key can serialize.
		controller.mock:SetMaxValueLength(8192)
		slotStore:Store("blob", string.rep("A", 32768))

		local savePromise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(savePromise, 10)).toEqual(true)
		expect((savePromise:Yield())).toEqual(false)

		-- Lift the limit before teardown so the session lock's final unlock-save can flush and release
		-- cleanly, rather than throwing during cleanup and leaking a retry into a later spec (these all
		-- share one test place).
		controller.mock:SetMaxValueLength(nil)
		controller:destroy()
	end)

	it("preserves the already-saved slot data when an oversized save fails", function()
		local controller = setup()

		local dataStore = resolveDataStore(controller.playerDataStoreService, 1)
		expect(dataStore).never.toBeNil()

		local slotStore = getSlotStore(dataStore, "slot-abc")

		slotStore:Store("coins", 25)
		local firstSave = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(firstSave, 10)).toEqual(true)
		expect((firstSave:Yield())).toEqual(true)

		controller.mock:SetMaxValueLength(8192)
		slotStore:Store("blob", string.rep("A", 32768))

		local savePromise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(savePromise, 10)).toEqual(true)
		expect((savePromise:Yield())).toEqual(false)

		-- The rejected write must not have corrupted the coins we already stored.
		controller.mock:SetMaxValueLength(nil)
		local loadPromise = slotStore:Load("coins")
		expect(PromiseTestUtils.awaitSettled(loadPromise, 10)).toEqual(true)
		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(25)

		controller:destroy()
	end)
end)
