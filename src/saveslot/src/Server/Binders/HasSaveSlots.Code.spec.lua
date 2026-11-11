--!strict
--[[
	Coverage for the code convenience: exporting a slot to a generated code and loading that code into
	a fresh transferable ephemeral slot. Driven against separate player/shared mocked datastores.

	@class HasSaveSlots.Code.spec.lua
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
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")

local HttpService = game:GetService("HttpService")
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

	local controller = {
		hasSaveSlots = hasSaveSlots,
		sharedMock = sharedMock,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
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

local function activeSlotData(hasSaveSlots)
	local store = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseActiveSlotStore())
	return PromiseTestUtils.awaitFulfilled(store:LoadAll({}))
end

describe("HasSaveSlots export-to-code / load-from-code", function()
	it("round-trips a slot through a code into a fresh ephemeral slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

		local code = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToCode(sourceSlotId))
		expect(type(code)).toEqual("string")

		local ephemeralSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code))
		expect(hasSaveSlots.ActiveSlotId.Value).toEqual(ephemeralSlotId)

		local data = activeSlotData(hasSaveSlots)
		expect(data.Coins).toEqual(7)
		expect(data.World_2.Eggs).toEqual(3)

		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(ephemeralSlotId))
		expect(metadata.IsEphemeral).toEqual(true)

		context:Destroy()
	end)

	it("defaults the exported slot to the active slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		createSelectAndWrite(hasSaveSlots, 2)

		local code = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToCode())
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code))
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)

		context:Destroy()
	end)

	it("refuses to export the main slot to a code", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local mainSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(mainSlotId))

		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSaveSlotToCode())

		context:Destroy()
	end)

	it("rejects loading an unknown code", function()
		local context = setup()
		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode("nope"))

		context:Destroy()
	end)

	it("exports a slot as JSON that decodes back to its data", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		createSelectAndWrite(hasSaveSlots, 2)

		local json = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToJson())
		expect(type(json)).toEqual("string")

		local decoded = HttpService:JSONDecode(json)
		expect(decoded.data.Coins).toEqual(7)
		expect(decoded.data.World_2.Eggs).toEqual(3)

		context:Destroy()
	end)

	it("refuses to export the main slot as JSON", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local mainSlotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(mainSlotId))

		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSaveSlotToJson())

		context:Destroy()
	end)

	it("generates a sanity-checkable default code (date-state-user-token)", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		createSelectAndWrite(hasSaveSlots, 2)

		local code = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToCode())
		-- Date-prefixed, lowercase alphanumeric + hyphens, safe as a datastore key.
		expect(string.match(code, "^%d%d%d%d%d%d%d%d%-") ~= nil).toEqual(true)
		expect(string.match(code, "^[a-z0-9%-]+$") ~= nil).toEqual(true)
		expect(#code <= 50).toEqual(true)

		context:Destroy()
	end)

	it("honors an injected code generator", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		hasSaveSlots:SetCodeGenerator(function(generatorContext)
			return `custom-{generatorContext.slotIndex}`
		end)
		local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

		local code = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToCode(sourceSlotId))
		expect(code).toEqual("custom-2")

		-- The custom code still round-trips through the shared store.
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code))
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)

		context:Destroy()
	end)

	it("rejects export-to-code when the shared store write fails", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		createSelectAndWrite(hasSaveSlots, 2)

		context.sharedMock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseExportSaveSlotToCode())

		context:Destroy()
	end)

	it("rejects load-from-code when the shared store read fails", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		createSelectAndWrite(hasSaveSlots, 2)
		local code = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseExportSaveSlotToCode())

		context.sharedMock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code))

		context:Destroy()
	end)
end)
