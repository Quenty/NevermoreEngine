--!strict
--[[
	Export/import coverage for the real HasSaveSlots binder against a mocked datastore. The central
	safety property: export/import never touch the main/default slot (whose store is the shared root
	datastore holding global player data), and imported slots always land at a non-main index.

	@class HasSaveSlots.exportImport.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
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
	local mock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
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

	local function destroy()
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end

	return {
		serviceBag = serviceBag,
		binder = binder,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		mock = mock,
		destroy = destroy,
	}
end

-- Runs the body against a fresh bound player and ALWAYS tears the world down afterwards, even when
-- the body throws (a leaked ServiceBag's background work fails a later suite). Rethrows so the test
-- still reports the original failure.
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

	it("refuses to export the main slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			expect(awaitResolved(hasSaveSlots:PromiseExportSlot(mainSlotId))).toEqual(false)
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
