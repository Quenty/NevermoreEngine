--!strict
--[[
	Export/import coverage for the real HasSaveSlots binder against a mocked datastore. The central
	safety property: export/import never touch the main/default slot (whose store is the shared root
	datastore holding global player data), and imported slots always land at a non-main index.

	@class HasSaveSlots.ExportImport.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local BindToCloseService = require("BindToCloseService")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup()
	local maid = Maid.new()

	local mock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
	serviceBag:GetService(require("SaveSlotSharedDataStoreService"))
	local bindToCloseService: BindToCloseService.BindToCloseService = serviceBag:GetService(BindToCloseService) :: any
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	local fakePlayer = PlayerMock.new({ UserId = FAKE_USER_ID })
	fakePlayer.Parent = Workspace

	local hasSaveSlots = assert(binder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
	hasSaveSlots.MaxSlotCount.Value = 5

	maid:GiveTask(function()
		PromiseTestUtils.awaitFulfilled(bindToCloseService:PromiseClose())
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end)

	local function Destroy(_self)
		maid:DoCleaning()
	end

	local controller = {
		serviceBag = serviceBag,
		binder = binder,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		mock = mock,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

-- Settles a promise (failing loudly on a hang) and returns its resolved value, throwing on rejection.

-- Settles a promise and returns whether it resolved (true) or rejected (false).

local function createSelectAndWrite(hasSaveSlots, slotIndex: number): string
	local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(slotIndex))
	PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(slotId))
	local store = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseActiveSlotStore())
	store:Store("Coins", 7)
	store:GetSubStore("World_2"):Store("Eggs", 3)
	return slotId
end

describe("HasSaveSlots.PromiseExportSlot / PromiseImportSlot", function()
	it("round-trips a non-main slot's data into a fresh non-main slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(sourceSlotId))
		expect(export.data.Coins).toEqual(7)
		expect(export.data.World_2.Eggs).toEqual(3)

		local newSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlot(export))
		expect(newSlotId).never.toEqual(sourceSlotId)

		-- Re-export the imported slot to prove its store carries the seeded data (public-API only).
		local reexport = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(newSlotId))
		expect(reexport.data.Coins).toEqual(7)
		expect(reexport.data.World_2.Eggs).toEqual(3)

		context:Destroy()
	end)

	it("imports into a non-main index even when the main index is free", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local newSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 } }))

		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
		expect(metadata.SlotIndex).toEqual(SaveSlotConstants.DEFAULT_SLOT_INDEX + 1)
		expect(metadata.SlotIndex).never.toEqual(SaveSlotConstants.DEFAULT_SLOT_INDEX)

		context:Destroy()
	end)

	it("carries slot name and summary through the export", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local sourceSlotId = PromiseTestUtils.awaitFulfilled(
			hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Hero", Summary = { pct = 42 } })
		)

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(sourceSlotId))
		expect(export.slotName).toEqual("Hero")
		expect(export.summary.pct).toEqual(42)

		local newSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlot(export))
		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
		expect(metadata.SlotName).toEqual("Hero")

		context:Destroy()
	end)

	it("carries accrued playtime through the export", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local sourceSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(2, { TimePlayed = 3600 }))

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(sourceSlotId))
		expect(export.timePlayed).toEqual(3600)

		local newSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlot(export))
		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
		expect(metadata.TimePlayed).toEqual(3600)

		context:Destroy()
	end)

	it("exports the live session's playtime, not just what was last saved", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

		-- Rewind the live session's clock so the export observes ~120s of unflushed play.
		local tracker: any = hasSaveSlots:GetSlotsDataStore()
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(sourceSlotId))
		expect(export.timePlayed ~= nil and export.timePlayed >= 120).toEqual(true)

		context:Destroy()
	end)

	it("imports an export written before playtime was carried", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local newSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 }, slotName = "Hero" }))

		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
		expect(metadata.SlotName).toEqual("Hero")
		expect(metadata.TimePlayed).toBeNil()

		context:Destroy()
	end)

	it("refuses to import an export whose timePlayed is not a number", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportSlot(({ data = {}, timePlayed = "600" }) :: any))

		context:Destroy()
	end)

	it("refuses to export the main slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local mainSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSlot(mainSlotId))

		context:Destroy()
	end)

	it("exports the main slot when allowMainSlot is set", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local mainSlotId = createSelectAndWrite(hasSaveSlots, SaveSlotConstants.DEFAULT_SLOT_INDEX)

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(mainSlotId, true))
		expect(export.data.Coins).toEqual(7)
		expect(export.data.World_2.Eggs).toEqual(3)

		context:Destroy()
	end)

	it("strips the SaveSlots system data from a main slot export", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local mainSlotId = createSelectAndWrite(hasSaveSlots, SaveSlotConstants.DEFAULT_SLOT_INDEX)
		createSelectAndWrite(hasSaveSlots, 2)

		local export = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(mainSlotId, true))
		expect(export.data[SaveSlotConstants.SYSTEM_STORE_KEY]).toBeNil()

		context:Destroy()
	end)

	it("still refuses the main slot when allowMainSlot is false", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local mainSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSlot(mainSlotId, false))

		context:Destroy()
	end)

	it("refuses to export a missing slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSlot("does-not-exist"))

		context:Destroy()
	end)

	it("refuses to import a malformed export", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportSlot(({}) :: any))
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportSlot(({ data = 5 }) :: any))

		context:Destroy()
	end)

	it("rejects import when no non-main index is free", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		-- Only the main index is allowed, so there is no safe (non-main) home for an import.
		hasSaveSlots.MaxSlotCount.Value = 1
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 } }))

		context:Destroy()
	end)
end)
