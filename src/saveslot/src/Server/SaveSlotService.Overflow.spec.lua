--!strict
--[[
	Characterizes how the save-slot system handles the overflow-save failure: when a slot accumulates
	more data than Roblox can serialize under its per-key size ceiling, the save must fail loudly
	instead of silently dropping data or corrupting the slot that was already stored. Driven through the
	same mock-injected PlayerDataStoreService and SaveSlotConstants substore layout the load flow uses
	(see SaveSlotService.LoadFlow.spec), with the DataStoreMock configured to a small
	[DataStoreMock.SetMaxValueLength] so the overflow triggers without a multi-megabyte payload.

	@class SaveSlotService.Overflow.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID = 1
local MAX_VALUE_LENGTH = 8192
local OVERSIZED_LENGTH = 32768

local function setup()
	local maid = Maid.new()
	local mock = DataStoreMock.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	local status, resolved = PromiseTestUtils.awaitOutcome(playerDataStoreService:PromiseDataStore(USER_ID), 10)
	assert(status == "resolved", `Failed to resolve the player data store ({status})`)

	local dataStore: DataStore.DataStore = resolved
	local slotStore = dataStore
		:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
		:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY)
		:GetSubStore("slot-abc")

	local function Destroy(_self)
		-- Lift the limit before teardown so the session lock's final unlock-save can flush and release
		-- cleanly, rather than throwing during cleanup and leaking a retry into a later spec (these all
		-- share one test place).
		mock:SetMaxValueLength(nil)
		-- The store the spec loaded is only destroyed by a removal, and a PlayerMock never fires the
		-- real Players.PlayerRemoving, so shut down the way Roblox does or its auto-save loop outlives
		-- this spec and fires inside a later package's window.
		DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
		maid:DoCleaning()
	end

	local controller = {
		mock = mock,
		dataStore = dataStore,
		slotStore = slotStore,
		-- Stores a slot value and saves it, so the spec starts from data that is already in the store.
		saveSlotValue = function(key: string, value: any): string
			slotStore:Store(key, value)
			return (PromiseTestUtils.awaitOutcome(dataStore:Save(), 10))
		end,
		-- Grows the slot past the (lowered) per-key ceiling and saves.
		saveOversizedSlot = function(): string
			mock:SetMaxValueLength(MAX_VALUE_LENGTH)
			slotStore:Store("blob", string.rep("A", OVERSIZED_LENGTH))
			return (PromiseTestUtils.awaitOutcome(dataStore:Save(), 10))
		end,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("save slot overflow save", function()
	it("fails the save when a slot grows past the datastore size limit", function()
		local controller = setup()

		expect(controller.saveSlotValue("coins", 25)).toEqual("resolved")
		expect(controller.saveOversizedSlot()).toEqual("rejected")

		controller:Destroy()
	end)

	it("preserves the already-saved slot data when an oversized save fails", function()
		local controller = setup()

		expect(controller.saveSlotValue("coins", 25)).toEqual("resolved")
		expect(controller.saveOversizedSlot()).toEqual("rejected")

		controller.mock:SetMaxValueLength(nil)

		local loadStatus, coins = PromiseTestUtils.awaitOutcome(controller.slotStore:Load("coins"), 10)
		expect(loadStatus).toEqual("resolved")
		expect(coins).toEqual(25)

		controller:Destroy()
	end)
end)
