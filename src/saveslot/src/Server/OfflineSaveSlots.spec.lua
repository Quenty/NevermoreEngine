--!strict
--[[
	Save slots opened for a player who is not in this server. What is worth pinning down is that the
	roster read is the same one the player would have seen, that writes land in their real datastore,
	and that the borrowed session is handed back -- a session left open is a player who cannot rejoin.

	@class OfflineSaveSlots.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotService = require("SaveSlotService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local ABSENT_USER_ID = 90210

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local saveSlotService: SaveSlotService.SaveSlotService = serviceBag:GetService(SaveSlotService) :: any
	serviceBag:Init()

	local mock = DataStoreMock.new()
	playerDataStoreService:SetRobloxDataStore(mock)
	saveSlotService:SetMaxSlotCount(5)
	serviceBag:Start()

	local function await(promise, label: string): any
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect(`{label} hung`).toEqual(`{label} settled`)
			return nil
		end
		local ok, value = promise:Yield()
		if not ok then
			expect(`{label} rejected: {tostring(value)}`).toEqual(`{label} fulfilled`)
			return nil
		end
		return value
	end

	local controller = {
		serviceBag = serviceBag,
		saveSlotService = saveSlotService,
		mock = mock,
		await = await,
		-- Opens the offline slots and waits for the roster to load, which is what every caller wants;
		-- the sync read accessors see an empty roster until it has.
		openSlots = function(userId: number?): any
			local offline = await(saveSlotService:PromiseOfflineSaveSlots(userId or ABSENT_USER_ID), "open")
			if offline then
				await(offline:PromiseSlotsLoaded(), "load")
			end
			return offline
		end,
		Destroy = function(_self)
			-- A PlayerMock never fires the real Players.PlayerRemoving, and an offline store is only
			-- released by its handle, so shut down the way Roblox does before tearing the bag down.
			DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("SaveSlotService.PromiseOfflineSaveSlots", function()
	it("reads the absent player's stored slots", function()
		local controller = setup()

		controller.mock:SetRaw(tostring(ABSENT_USER_ID), {
			SaveSlots = {
				slotMetadata = {
					["slot-b"] = { SlotIndex = 2, SlotName = "Beta" },
					["slot-a"] = { SlotIndex = 1, SlotName = "Alpha" },
				},
				activeSlotId = "slot-a",
			},
		})

		local offline = controller.openSlots()
		local slots = offline:GetSlotsDataStore()

		local slotList = slots:GetSlotList()
		expect(#slotList).toEqual(2)
		-- Ordered by index, since the backing map is not.
		expect(slotList[1].SlotName).toEqual("Alpha")
		expect(slotList[2].SlotName).toEqual("Beta")

		-- Nothing selects in an offline session, so the stored pointer surfaces as the slot they would
		-- resume on rather than as an active one.
		expect(slots:GetActiveSlotId()).toBeNil()
		expect(slots:GetLastActiveSlotId()).toEqual("slot-a")

		offline:Destroy()
		controller:Destroy()
	end)

	it("writes a slot created offline into the player's datastore", function()
		local controller = setup()

		local offline = controller.openSlots()
		local slotId = controller.await(offline:GetSlotsDataStore():PromiseCreateSlot(1), "create")
		expect(type(slotId)).toEqual("string")

		-- Releasing the session is what flushes it, so read the store only after the destroy settles.
		offline:Destroy()

		local reopened = controller.openSlots()
		local slotList = reopened:GetSlotsDataStore():GetSlotList()
		expect(#slotList).toEqual(1)
		expect(slotList[1].SlotIndex).toEqual(1)

		reopened:Destroy()
		controller:Destroy()
	end)

	it("releases the borrowed session, so the next open builds a fresh one", function()
		local controller = setup()

		local first = controller.openSlots()
		local firstStore = first:GetSlotsDataStore()
		first:Destroy()

		local second = controller.openSlots()
		-- A released session is gone, so this had to open its own rather than share the last one.
		expect(second:GetSlotsDataStore() == firstStore).toEqual(false)

		second:Destroy()
		controller:Destroy()
	end)

	-- The refusal for a player who *is* in this server is not covered: the guard reads
	-- Players:GetPlayerByUserId, which only ever sees a real Player, and a PlayerMock is a Folder. An
	-- attempt to stand one in by parenting it under Players collides with PlayerMockService instead.

	it("does not accrue playtime, because an admin edit is not a play session", function()
		local controller = setup()

		local offline = controller.openSlots()
		local slots = offline:GetSlotsDataStore()

		local slotId = controller.await(slots:PromiseCreateSlot(1), "create")
		controller.await(slots:PromiseSelectSlot(slotId), "select")

		local metadata = slots:GetSlotMetadata(slotId)
		expect(metadata.PlayCount).toBeNil()
		expect(metadata.TimePlayed).toBeNil()

		offline:Destroy()
		controller:Destroy()
	end)

	it("survives being destroyed twice", function()
		local controller = setup()

		local offline = controller.openSlots()
		offline:Destroy()

		expect(function()
			offline:Destroy()
		end).never.toThrow()

		controller:Destroy()
	end)
end)
