--!strict
--[[
	Export/import coverage for the real HasSaveSlots binder against a mocked datastore. The central
	safety property: export/import never touch the main/default slot (whose store is the shared root
	datastore holding global player data), and imported slots always land at a non-main index.

	@class HasSaveSlots.ExportImport.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
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

	-- A PlayerMock never fires the real Players.PlayerRemoving, and the store the spec loaded is only
	-- destroyed by a removal, so shut it down the way Roblox does or its auto-save loop outlives this spec.
	maid:GiveTask(function()
		DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end)

	local function destroy()
		maid:DoCleaning()
	end

	local controller = {
		serviceBag = serviceBag,
		binder = binder,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		mock = mock,
		destroy = destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

local function runWithContext(body)
	local context = setup()
	local ok, err = pcall(body, context)
	context.destroy()
	if not ok then
		error(err, 0)
	end
end

-- Settles a promise (failing loudly on a hang) and returns its resolved value, throwing on rejection.
local function awaitValueOf(promise)
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	local ok, value = promise:Yield()
	if not ok then
		error(`promise rejected: {tostring(value)}`, 0)
	end
	return value
end

-- Settles a promise and returns whether it resolved (true) or rejected (false).
local function awaitResolved(promise): boolean
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	return (promise:Yield())
end

local function createSelectAndWrite(hasSaveSlots, slotIndex: number): string
	local slotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(slotIndex))
	awaitValueOf(hasSaveSlots:PromiseSelectSlot(slotId))
	local store = awaitValueOf(hasSaveSlots:PromiseActiveSlotStore())
	store:Store("Coins", 7)
	store:GetSubStore("World_2"):Store("Eggs", 3)
	return slotId
end

describe("HasSaveSlots.PromiseExportSlot / PromiseImportSlot", function()
	it("round-trips a non-main slot's data into a fresh non-main slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(sourceSlotId))
			expect(export.data.Coins).toEqual(7)
			expect(export.data.World_2.Eggs).toEqual(3)

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlot(export))
			expect(newSlotId).never.toEqual(sourceSlotId)

			-- Re-export the imported slot to prove its store carries the seeded data (public-API only).
			local reexport = awaitValueOf(hasSaveSlots:PromiseExportSlot(newSlotId))
			expect(reexport.data.Coins).toEqual(7)
			expect(reexport.data.World_2.Eggs).toEqual(3)
		end)
	end)

	it("imports into a non-main index even when the main index is free", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 } }))

			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
			expect(metadata.SlotIndex).toEqual(SaveSlotConstants.DEFAULT_SLOT_INDEX + 1)
			expect(metadata.SlotIndex).never.toEqual(SaveSlotConstants.DEFAULT_SLOT_INDEX)
		end)
	end)

	it("carries slot name and summary through the export", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local sourceSlotId =
				awaitValueOf(hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Hero", Summary = { pct = 42 } }))

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(sourceSlotId))
			expect(export.slotName).toEqual("Hero")
			expect(export.summary.pct).toEqual(42)

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlot(export))
			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
			expect(metadata.SlotName).toEqual("Hero")
		end)
	end)

	it("carries accrued playtime through the export", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local sourceSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(2, { TimePlayed = 3600 }))

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(sourceSlotId))
			expect(export.timePlayed).toEqual(3600)

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlot(export))
			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
			expect(metadata.TimePlayed).toEqual(3600)
		end)
	end)

	it("exports the live session's playtime, not just what was last saved", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

			-- Rewind the live session's clock so the export observes ~120s of unflushed play.
			local tracker: any = hasSaveSlots:GetSlotsDataStore()
			tracker._playSessionStart = os.time() - 120
			tracker._playSessionLastFlush = os.time() - 120

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(sourceSlotId))
			expect(export.timePlayed ~= nil and export.timePlayed >= 120).toEqual(true)
		end)
	end)

	it("imports an export written before playtime was carried", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 }, slotName = "Hero" }))

			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
			expect(metadata.SlotName).toEqual("Hero")
			expect(metadata.TimePlayed).toBeNil()
		end)
	end)

	it("refuses to import an export whose timePlayed is not a number", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			expect(awaitResolved(hasSaveSlots:PromiseImportSlot(({ data = {}, timePlayed = "600" }) :: any))).toEqual(
				false
			)
		end)
	end)

	it("refuses to export the main slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			expect(awaitResolved(hasSaveSlots:PromiseExportSlot(mainSlotId))).toEqual(false)
		end)
	end)

	it("exports the main slot when allowMainSlot is set", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = createSelectAndWrite(hasSaveSlots, SaveSlotConstants.DEFAULT_SLOT_INDEX)

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(mainSlotId, true))
			expect(export.data.Coins).toEqual(7)
			expect(export.data.World_2.Eggs).toEqual(3)
		end)
	end)

	it("strips the SaveSlots system data from a main slot export", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = createSelectAndWrite(hasSaveSlots, SaveSlotConstants.DEFAULT_SLOT_INDEX)
			createSelectAndWrite(hasSaveSlots, 2)

			local export = awaitValueOf(hasSaveSlots:PromiseExportSlot(mainSlotId, true))
			expect(export.data[SaveSlotConstants.SYSTEM_STORE_KEY]).toBeNil()
		end)
	end)

	it("still refuses the main slot when allowMainSlot is false", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			expect(awaitResolved(hasSaveSlots:PromiseExportSlot(mainSlotId, false))).toEqual(false)
		end)
	end)

	it("refuses to export a missing slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			expect(awaitResolved(hasSaveSlots:PromiseExportSlot("does-not-exist"))).toEqual(false)
		end)
	end)

	it("refuses to import a malformed export", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			expect(awaitResolved(hasSaveSlots:PromiseImportSlot(({}) :: any))).toEqual(false)
			expect(awaitResolved(hasSaveSlots:PromiseImportSlot(({ data = 5 }) :: any))).toEqual(false)
		end)
	end)

	it("rejects import when no non-main index is free", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			-- Only the main index is allowed, so there is no safe (non-main) home for an import.
			hasSaveSlots.MaxSlotCount.Value = 1
			expect(awaitResolved(hasSaveSlots:PromiseImportSlot({ data = { Coins = 1 } }))).toEqual(false)
		end)
	end)
end)
