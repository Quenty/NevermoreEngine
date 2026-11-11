--!strict
--[[
	Coverage for saving/importing slots through the shared store: the real HasSaveSlots binder
	composed with SaveSlotSharedDataStoreService, each backed by its own mocked datastore.

	@class HasSaveSlots.SharedStore.spec.lua
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
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup()
	local maid = Maid.new()

	local playerMock = DataStoreMock.new()
	local sharedMock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
	local bindToCloseService: BindToCloseService.BindToCloseService = serviceBag:GetService(BindToCloseService) :: any
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local sharedService: SaveSlotSharedDataStoreService.SaveSlotSharedDataStoreService =
		serviceBag:GetService(SaveSlotSharedDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(playerMock)
	sharedService:SetRobloxDataStore(sharedMock)
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
		hasSaveSlots = hasSaveSlots,
		sharedService = sharedService,
		sharedMock = sharedMock,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function createSelectAndWrite(hasSaveSlots, slotIndex: number): string
	local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(slotIndex))
	PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(slotId))
	local store = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseActiveSlotStore())
	store:Store("Coins", 7)
	store:GetSubStore("World_2"):Store("Eggs", 3)
	return slotId
end

describe("HasSaveSlots shared-store save/import", function()
	it("saves a non-main slot to the shared store and imports it into a fresh non-main slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-abc"))

		local newSlotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportSlotFromSharedDataStore("code-abc"))
		expect(newSlotId).never.toEqual(sourceSlotId)

		local reexport = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSlot(newSlotId))
		expect(reexport.data.Coins).toEqual(7)
		expect(reexport.data.World_2.Eggs).toEqual(3)

		context:Destroy()
	end)

	it("rejects import from a missing key", function()
		local context = setup()
		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseImportSlotFromSharedDataStore("nope"))

		context:Destroy()
	end)

	it("tags what it writes as a share code, keeping it out of the teleport arrival path", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-kind"))

		local stored = PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseRead("code-kind"))
		expect(stored.kind).toEqual(SaveSlotExportUtils.Kind.CODE)

		context:Destroy()
	end)

	it("refuses to import a transfer snapshot, whose key every client can read", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(
			context.sharedService:PromiseWrite(
				"transfer-key",
				SaveSlotExportUtils.withKind({ data = { Coins = 5 } }, SaveSlotExportUtils.Kind.TRANSFER)
			)
		)

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseImportSlotFromSharedDataStore("transfer-key"))

		context:Destroy()
	end)

	it("still imports an entry written before kinds existed", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseWrite("legacy-code", { data = { Coins = 5 } }))

		local newSlotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseImportSlotFromSharedDataStore("legacy-code"))
		local reexport = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseExportSlot(newSlotId))
		expect(reexport.data.Coins).toEqual(5)

		context:Destroy()
	end)

	it("propagates the main-slot guard through a shared-store save", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots

		local mainSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseSaveSlotToSharedDataStore(mainSlotId, "k"))

		context:Destroy()
	end)

	it("rejects a save when the shared store write fails", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

		context.sharedMock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-fail"))

		context:Destroy()
	end)

	it("rejects an import when the shared store read fails", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSaveSlotToSharedDataStore(sourceSlotId, "code-read"))

		context.sharedMock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportSlotFromSharedDataStore("code-read"))

		context:Destroy()
	end)
end)
