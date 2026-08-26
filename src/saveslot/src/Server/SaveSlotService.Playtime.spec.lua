--!strict
--[[
	Playtime accrual persists on the save that asked for it. The flush runs from a saving callback,
	so a value that only reached the store through the deferred attribute listener would land one
	save late -- and the final save-on-leave would drop the tail of the session entirely.

	@class SaveSlotService.Playtime.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local HasSaveSlotsDataStore = require("HasSaveSlotsDataStore")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID = 4242
local SESSION_SECONDS = 120

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local sharedDataStoreService: SaveSlotSharedDataStoreService.SaveSlotSharedDataStoreService =
		serviceBag:GetService(SaveSlotSharedDataStoreService) :: any
	serviceBag:Init()

	local mock = DataStoreMock.new()
	playerDataStoreService:SetRobloxDataStore(mock)
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

	local dataStore = await(playerDataStoreService:PromiseDataStore(USER_ID), "data store")

	local slotsDataStore = maid:Add(HasSaveSlotsDataStore.new(Promise.resolved(dataStore), {
		ActiveSlotId = maid:Add(ValueObject.new(nil)),
		LastActiveSlotId = maid:Add(ValueObject.new(nil)),
		ActiveTransferableEphemeralKey = maid:Add(ValueObject.new(nil)),
		MaxSlotCount = maid:Add(ValueObject.new(5)),
		SharedDataStoreService = sharedDataStoreService,
		UserId = USER_ID,
	}))
	await(slotsDataStore:PromiseSlotsLoaded(), "slots loaded")

	local controller = {
		await = await,
		mock = mock,
		dataStore = dataStore,
		slotsDataStore = slotsDataStore,
		-- Selects a fresh slot and backdates the session so the next flush accrues real time without
		-- the spec waiting it out.
		beginBackdatedSession = function(): string
			local slotId = await(slotsDataStore:PromiseCreateSlot(1), "create")
			await(slotsDataStore:PromiseSelectSlot(slotId), "select")
			slotsDataStore._playSessionStart = assert(slotsDataStore._playSessionStart, "No _playSessionStart")
				- SESSION_SECONDS
			slotsDataStore._playSessionLastFlush = assert(
				slotsDataStore._playSessionLastFlush,
				"No _playSessionLastFlush"
			) - SESSION_SECONDS
			return slotId
		end,
		storedMetadata = function(slotId: string): any
			local raw = mock:GetRaw(tostring(USER_ID))
			local system = raw and raw[SaveSlotConstants.SYSTEM_STORE_KEY]
			local metadata = system and system[SaveSlotConstants.METADATA_STORE_KEY]
			return metadata and metadata[slotId]
		end,
		destroy = function()
			DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("save slot playtime", function()
	it("persists accrued playtime on the save that triggered the flush", function()
		local controller = setup()
		local slotId = controller.beginBackdatedSession()

		controller.await(controller.dataStore:Save(), "save")

		local stored = controller.storedMetadata(slotId)
		expect(stored).never.toBeNil()
		-- At least the backdated span: the save's own latency can push os.time one second further.
		expect(stored.TimePlayed).toBeGreaterThanOrEqual(SESSION_SECONDS)
		expect(stored.LastSessionLength).toBeGreaterThanOrEqual(SESSION_SECONDS)

		controller.destroy()
	end)

	it("keeps the replicated attribute and the stored value in step", function()
		local controller = setup()
		local slotId = controller.beginBackdatedSession()

		controller.await(controller.dataStore:Save(), "save")

		local metadata = assert(controller.slotsDataStore:GetSlotMetadata(slotId), "No slot metadata")
		expect(metadata.TimePlayed).toEqual(controller.storedMetadata(slotId).TimePlayed)

		controller.destroy()
	end)
end)
