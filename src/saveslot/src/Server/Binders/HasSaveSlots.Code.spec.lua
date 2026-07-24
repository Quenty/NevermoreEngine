--!strict
--[[
	Coverage for the code convenience: exporting a slot to a generated code and loading that code into
	a fresh transferable ephemeral slot. Driven against separate player/shared mocked datastores.

	@class HasSaveSlots.code.spec.lua
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

local HttpService = game:GetService("HttpService")
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

	return { hasSaveSlots = hasSaveSlots, destroy = destroy }
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

local function activeSlotData(hasSaveSlots)
	local store = awaitValueOf(hasSaveSlots:PromiseActiveSlotStore())
	return awaitValueOf(store:LoadAll({}))
end

describe("HasSaveSlots export-to-code / load-from-code", function()
	it("round-trips a slot through a code into a fresh ephemeral slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local sourceSlotId = createSelectAndWrite(hasSaveSlots, 2)

			local code = awaitValueOf(hasSaveSlots:PromiseExportSaveSlotToCode(sourceSlotId))
			expect(type(code)).toEqual("string")

			local ephemeralSlotId = awaitValueOf(hasSaveSlots:PromiseLoadEphemeralSaveSlotFromCode(code))
			expect(hasSaveSlots.ActiveSlotId.Value).toEqual(ephemeralSlotId)

			local data = activeSlotData(hasSaveSlots)
			expect(data.Coins).toEqual(7)
			expect(data.World_2.Eggs).toEqual(3)

			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(ephemeralSlotId))
			expect(metadata.IsEphemeral).toEqual(true)
		end)
	end)

	it("defaults the exported slot to the active slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			createSelectAndWrite(hasSaveSlots, 2)

			local code = awaitValueOf(hasSaveSlots:PromiseExportSaveSlotToCode())
			awaitValueOf(hasSaveSlots:PromiseLoadEphemeralSaveSlotFromCode(code))
			expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)
		end)
	end)

	it("refuses to export the main slot to a code", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			awaitValueOf(hasSaveSlots:PromiseSelectSlot(mainSlotId))

			expect(awaitResolved(hasSaveSlots:PromiseExportSaveSlotToCode())).toEqual(false)
		end)
	end)

	it("rejects loading an unknown code", function()
		runWithContext(function(context)
			expect(awaitResolved(context.hasSaveSlots:PromiseLoadEphemeralSaveSlotFromCode("nope"))).toEqual(false)
		end)
	end)

	it("exports a slot as JSON that decodes back to its data", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			createSelectAndWrite(hasSaveSlots, 2)

			local json = awaitValueOf(hasSaveSlots:PromiseExportSaveSlotToJson())
			expect(type(json)).toEqual("string")

			local decoded = HttpService:JSONDecode(json)
			expect(decoded.data.Coins).toEqual(7)
			expect(decoded.data.World_2.Eggs).toEqual(3)
		end)
	end)

	it("refuses to export the main slot as JSON", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local mainSlotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX))
			awaitValueOf(hasSaveSlots:PromiseSelectSlot(mainSlotId))

			expect(awaitResolved(hasSaveSlots:PromiseExportSaveSlotToJson())).toEqual(false)
		end)
	end)
end)
