--!strict
--[[
	Coverage for saving/importing slots through the shared store: the real HasSaveSlots binder
	composed with SharedSaveSlotDataStoreService, each backed by its own mocked datastore.

	@class HasSaveSlots.SharedStore.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")
local SharedSaveSlotDataStoreService = require("SharedSaveSlotDataStoreService")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup()
	local playerMock = DataStoreMock.new()
	local sharedMock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local sharedService: SharedSaveSlotDataStoreService.SharedSaveSlotDataStoreService =
		serviceBag:GetService(SharedSaveSlotDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(playerMock)
	sharedService:SetRobloxDataStore(sharedMock)
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
		hasSaveSlots = hasSaveSlots,
		sharedService = sharedService,
		sharedMock = sharedMock,
		destroy = destroy,
	}
end

local function runWithContext(body)
	local context = setup()
	local ok, err = pcall(body, context)
	context.destroy()
	if not ok then
		error(err, 0)
	end
end

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

describe("HasSaveSlots shared-store save/import", function()
	it("saves a non-main slot to the shared store and imports it into a fresh non-main slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)
			awaitValueOf(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-abc"))

			local newSlotId = awaitValueOf(hasSaveSlots:PromiseImportSlotFromSharedDataStore("code-abc"))
			expect(newSlotId).never.toEqual(sourceSlotId)

			local reexport = awaitValueOf(hasSaveSlots:PromiseExportSlot(newSlotId))
			expect(reexport.data.Coins).toEqual(7)
			expect(reexport.data.World_2.Eggs).toEqual(3)
		end)
	end)

	it("rejects import from a missing key", function()
		runWithContext(function(context)
			expect(awaitResolved(context.hasSaveSlots:PromiseImportSlotFromSharedDataStore("nope"))).toEqual(false)
		end)
	end)

	it("propagates the main-slot guard through a shared-store save", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots

			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			expect(awaitResolved(hasSaveSlots:PromiseSaveSlotToSharedDataStore(mainSlotId, "k"))).toEqual(false)
		end)
	end)

	it("rejects a save when the shared store write fails", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

			context.sharedMock:FailNextRequests(1)
			expect(awaitResolved(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-fail"))).toEqual(
				false
			)
		end)
	end)

	it("rejects an import when the shared store read fails", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)
			awaitValueOf(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-read"))

			context.sharedMock:FailNextRequests(1)
			expect(awaitResolved(hasSaveSlots:PromiseImportSlotFromSharedDataStore("code-read"))).toEqual(false)
		end)
	end)
end)
