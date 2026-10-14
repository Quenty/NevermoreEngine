--!strict
--[[
	Integration coverage for the real HasSaveSlots binder, driven against a mocked datastore. A
	PlayerMock with a seeded UserId stands in for a Player -- the load path only reads the UserId,
	which PlayerDataStoreManager resolves natively from the mock; everything else exercises the
	real code.

	@class HasSaveSlots.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local BindToCloseService = require("BindToCloseService")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local Rx = require("Rx")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup(mock: DataStoreMock.DataStoreMock?)
	local maid = Maid.new()

	mock = mock or DataStoreMock.new()

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

describe("HasSaveSlots against a fake player (healthy datastore)", function()
	it("should construct via the binder and load slots for a fresh player", function()
		local context = setup()
		expect(context.hasSaveSlots).never.toBeNil()

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSlotsLoaded(), 10)

		context:Destroy()
	end)

	it("should create a slot and find it", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)
		expect(type(slotId)).toEqual("string")

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(slotId), 10)).toEqual(true)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSlotIdFromIndex(1), 10)).toEqual(slotId)

		context:Destroy()
	end)

	it("should select a slot and report it active", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectSlot(slotId), 10)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseLastActiveSlotId(), 10)).toEqual(slotId)

		context:Destroy()
	end)

	it("should observe the active slot store after selection", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local capturedStore
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				capturedStore = brio:GetValue()
			end
		end)

		local emitted = PromiseTestUtils.awaitValue(function()
			return capturedStore ~= nil
		end, 10)
		subscription:Destroy()

		expect(emitted).toEqual(true)

		context:Destroy()
	end)

	it("ObserveActiveSlotStoreBrio tears its brio down once the active slot is deselected", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local activeBrio: any = nil
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				activeBrio = brio
			end
		end)

		local emitted = PromiseTestUtils.awaitValue(function()
			return activeBrio ~= nil
		end, 10)
		expect(emitted).toEqual(true)
		expect(activeBrio:IsDead()).toEqual(false)

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()

		expect(activeBrio:IsDead()).toEqual(true)

		subscription:Destroy()
		context:Destroy()
	end)

	it("ObserveActiveSlotStoreBrio swaps its brio when switching to another slot", function()
		local context = setup()

		local firstSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local secondSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2), 10)

		local selectFirst = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		expect(PromiseTestUtils.awaitSettled(selectFirst, 10)).toEqual(true)
		selectFirst:Yield()

		local currentBrio: any = nil
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				currentBrio = brio
			end
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return currentBrio ~= nil
		end, 10)).toEqual(true)
		local firstBrio = currentBrio

		local selectSecond = context.hasSaveSlots:PromiseSelectSlot(secondSlotId)
		expect(PromiseTestUtils.awaitSettled(selectSecond, 10)).toEqual(true)
		selectSecond:Yield()

		expect(PromiseTestUtils.awaitValue(function()
			return currentBrio ~= firstBrio
		end, 10)).toEqual(true)

		expect(firstBrio:IsDead()).toEqual(true)
		expect(currentBrio:IsDead()).toEqual(false)

		subscription:Destroy()
		context:Destroy()
	end)

	it("should reject creating a slot beyond the max slot count", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = 1

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseCreateSlot(2), 10)

		context:Destroy()
	end)

	it("should reject creating a duplicate slot index", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		expect(PromiseTestUtils.awaitSettled(firstPromise, 10)).toEqual(true)
		firstPromise:Yield()

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		context:Destroy()
	end)

	it("should reject deleting the active slot", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseDeleteSlot(slotId), 10)

		context:Destroy()
	end)

	it("should replicate the last active slot after selection", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		context:Destroy()
	end)

	it("PromiseDeselectSlot clears the active slot but remembers the last active", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot(), 10)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseLastActiveSlotId(), 10)).toEqual(slotId)

		context:Destroy()
	end)

	it("deleting the last-active slot clears the continue pointer", function()
		-- Repro for the `saveslot-delete *` bug: deleting the (deselected) active slot left
		-- LastActiveSlotId dangling, so the menu kept offering "Continue" for a slot that was gone.
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(deletePromise, 10)).toEqual(true)
		deletePromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseLastActiveSlotId(), 10)).toBeNil()

		context:Destroy()
	end)

	it("deleting a non-last-active slot leaves the continue pointer intact", function()
		local context = setup()

		local firstSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local secondSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(secondSlotId)
		expect(PromiseTestUtils.awaitSettled(deletePromise, 10)).toEqual(true)
		deletePromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(firstSlotId)

		context:Destroy()
	end)

	it("PromiseDeselectSlot is a no-op when no slot is active", function()
		local context = setup()

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot(), 10)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context:Destroy()
	end)

	it("PromiseDeselectSlot then PromiseSelectLastSaveSlot round-trips back into the slot", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectLastSaveSlot(), 10)).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context:Destroy()
	end)

	it("PromiseSelectLastSaveSlot re-selects the last active slot after the active slot is cleared", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		context.hasSaveSlots.ActiveSlotId.Value = nil
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectLastSaveSlot(), 10)).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context:Destroy()
	end)

	it("PromiseSelectLastSaveSlot resolves nil when there is nothing to continue", function()
		local context = setup()

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectLastSaveSlot(), 10)).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context:Destroy()
	end)

	it("PromiseSelectNewSaveSlot creates and selects a fresh slot each time", function()
		local context = setup()

		local firstSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectNewSaveSlot(), 10)
		expect(type(firstSlotId)).toEqual("string")
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(firstSlotId)

		local secondSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectNewSaveSlot(), 10)
		expect(type(secondSlotId)).toEqual("string")
		expect(secondSlotId ~= firstSlotId).toEqual(true)

		context:Destroy()
	end)

	it("PromiseDeleteAllSlots wipes every slot and clears the selection", function()
		local context = setup()

		local firstSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(2)
		expect(PromiseTestUtils.awaitSettled(secondPromise, 10)).toEqual(true)
		secondPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local wipePromise = context.hasSaveSlots:PromiseDeleteAllSlots()
		expect(PromiseTestUtils.awaitSettled(wipePromise, 10)).toEqual(true)
		wipePromise:Yield()

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(firstSlotId), 10)).toEqual(false)

		context:Destroy()
	end)

	it("PromiseSelectNewSaveSlot reuses the lowest free index after a deletion", function()
		local context = setup()

		local slotIdsByIndex = {}
		for index = 1, 3 do
			local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(index), 10)
			slotIdsByIndex[index] = slotId
		end

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotIdsByIndex[2])
		expect(PromiseTestUtils.awaitSettled(deletePromise, 10)).toEqual(true)
		deletePromise:Yield()

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectNewSaveSlot(), 10)
		expect(type(newSlotId)).toEqual("string")

		expect((PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId), 10)).SlotIndex).toEqual(
			2
		)

		context:Destroy()
	end)

	it("PromiseDuplicateSlot copies saved data into a fresh slot and marks the name", function()
		local context = setup()

		local slotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Adventure" }), 10)

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDuplicateSlot(slotId), 10)
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		local metadata = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId), 10)
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure (Copy)")

		expect(PromiseTestUtils.awaitFulfilled(tracker:_getSlotStore(newSlotId):Load("Coins"), 10)).toEqual(500)

		context:Destroy()
	end)

	it("PromiseDuplicateSlot into the default slot preserves the system store", function()
		local context = setup()

		local slotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Save" }), 10)

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDuplicateSlot(slotId), 10)

		expect((PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId), 10)).SlotIndex).toEqual(
			1
		)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSlotIdFromIndex(2), 10)).toEqual(slotId)

		expect(PromiseTestUtils.awaitFulfilled(tracker:_getSlotStore(newSlotId):Load("Coins"), 10)).toEqual(750)

		context:Destroy()
	end)

	it("PromiseDuplicateSlot rejects when the source slot is missing", function()
		local context = setup()

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseDuplicateSlot("does-not-exist"), 10)

		context:Destroy()
	end)

	it("PromiseResetActiveSlot wipes saved data but keeps the slot's index and name", function()
		local context = setup()

		local slotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" }), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseResetActiveSlot(), 10)
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(newSlotId)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(slotId), 10)).toEqual(false)

		local metadata = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId), 10)
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		expect(PromiseTestUtils.awaitFulfilled(tracker:_getSlotStore(newSlotId):Load("Coins"), 10)).toBeNil()

		context:Destroy()
	end)

	it("PromiseResetActiveSlot resets the default slot in place, preserving the system store", function()
		local context = setup()

		local slotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Save" }), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseResetActiveSlot(), 10)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSlotIdFromIndex(1), 10)).toEqual(newSlotId)

		expect(PromiseTestUtils.awaitFulfilled(tracker:_getSlotStore(newSlotId):Load("Coins"), 10)).toBeNil()

		context:Destroy()
	end)

	it("PromiseResetActiveSlot is a no-op resolving nil when no slot is active", function()
		local context = setup()

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseResetActiveSlot(), 10)).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context:Destroy()
	end)

	it("PromiseResetSlot wipes a non-active slot without touching the active selection", function()
		local context = setup()

		local activeSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(activeSlotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local targetSlotId =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" }), 10)

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_getSlotStore(targetSlotId):Store("Coins", 500)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseResetSlot(targetSlotId), 10)
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= targetSlotId).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(activeSlotId)

		local metadata = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId), 10)
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		expect(PromiseTestUtils.awaitFulfilled(tracker:_getSlotStore(newSlotId):Load("Coins"), 10)).toBeNil()

		context:Destroy()
	end)

	it("PromiseResetSlot keeps the continue pointer on the reset slot when it was last-active", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseResetSlot(slotId), 10)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(newSlotId)

		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseLastActiveSlotId(), 10)).toEqual(newSlotId)

		context:Destroy()
	end)

	it("PromiseResetSlot rejects when the slot is missing", function()
		local context = setup()

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseResetSlot("does-not-exist"), 10)

		context:Destroy()
	end)

	it("allows creating a slot past a finite cap when the count is unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(6), 10)
		expect(type(slotId)).toEqual("string")

		context:Destroy()
	end)

	it("PromiseSelectNewSaveSlot never runs out of slots when unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		for _ = 1, 7 do
			expect(type(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectNewSaveSlot(), 10))).toEqual(
				"string"
			)
		end

		context:Destroy()
	end)
end)

describe("HasSaveSlots playtime tracking", function()
	local function createAndSelect(context: any, slotIndex: number): any
		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(slotIndex), 10)

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(selectPromise, 10)).toEqual(true)
		selectPromise:Yield()

		return slotId
	end

	local function getMetadata(context: any, slotId): any
		local promise = context.hasSaveSlots:PromiseGetSlotMetadata(slotId)
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toEqual(true)
		return promise:Wait()
	end

	it("increments PlayCount to 1 the first time a slot is selected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)
		expect(getMetadata(context, slotId).PlayCount).toEqual(1)

		context:Destroy()
	end)

	it("counts a fresh session each time a slot is re-selected", function()
		local context = setup()

		local firstSlotId = createAndSelect(context, 1)
		local secondSlotId = createAndSelect(context, 2)

		local reselectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		expect(PromiseTestUtils.awaitSettled(reselectPromise, 10)).toEqual(true)
		reselectPromise:Yield()

		expect(getMetadata(context, firstSlotId).PlayCount).toEqual(2)
		expect(getMetadata(context, secondSlotId).PlayCount).toEqual(1)

		context:Destroy()
	end)

	it("accrues elapsed wall time into TimePlayed and LastSessionLength for the active slot", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		-- Rewind the live session's clock so a flush observes ~120s elapsed without waiting on it. The
		-- flush adds now - lastFlush, so the total is >= 120 (real time may nudge it a second higher).
		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local metadata = getMetadata(context, slotId)
		expect(metadata.TimePlayed ~= nil and metadata.TimePlayed >= 120).toEqual(true)
		expect(metadata.LastSessionLength ~= nil and metadata.LastSessionLength >= 120).toEqual(true)

		context:Destroy()
	end)

	it("zeroes LastSessionLength when a session begins, keeping the total minus it as the pre-session time", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)
		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		-- Switching away ends the session with its length recorded; coming back must not carry it over
		createAndSelect(context, 2)
		local reselectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(reselectPromise, 10)).toEqual(true)
		reselectPromise:Yield()

		local metadata = getMetadata(context, slotId)
		expect(metadata.TimePlayed ~= nil and metadata.TimePlayed >= 120).toEqual(true)
		expect(metadata.LastSessionLength).toEqual(0)

		context:Destroy()
	end)

	it("does not accrue time before any slot is selected", function()
		local context = setup()

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker:_flushPlaytime()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		expect(getMetadata(context, slotId).TimePlayed).toBeNil()

		context:Destroy()
	end)

	it("stops accruing into a slot once it is deselected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		expect(PromiseTestUtils.awaitSettled(deselectPromise, 10)).toEqual(true)
		deselectPromise:Yield()

		local afterDeselect = getMetadata(context, slotId).TimePlayed

		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()
		expect(getMetadata(context, slotId).TimePlayed).toEqual(afterDeselect)

		context:Destroy()
	end)

	it("carries the source slot's playtime onto a duplicate, live session included", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		-- Rewind the live session's clock so the duplicate observes ~120s that no flush has written yet.
		local tracker: any = context.hasSaveSlots:GetSlotsDataStore()
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDuplicateSlot(slotId), 10)

		local copied = getMetadata(context, newSlotId).TimePlayed
		expect(copied ~= nil and copied >= 120).toEqual(true)

		context:Destroy()
	end)

	it("leaves a duplicate of a never-played slot without playtime", function()
		local context = setup()

		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(1), 10)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(slotId)
		expect(PromiseTestUtils.awaitSettled(duplicatePromise, 10)).toEqual(true)

		expect(getMetadata(context, duplicatePromise:Wait()).TimePlayed).toBeNil()

		context:Destroy()
	end)
end)

describe("HasSaveSlots summary providers", function()
	local function readSummary(context: any, slotId): any
		local promise = context.hasSaveSlots:PromiseGetSlotMetadata(slotId)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			return nil
		end
		local metadata = promise:Wait()
		return metadata and metadata.Summary
	end

	local function awaitSummary(context: any, slotId, predicate: (any) -> boolean): (boolean, any)
		local last
		local ok = PromiseTestUtils.awaitValue(function()
			last = readSummary(context, slotId)
			return last ~= nil and predicate(last)
		end, 10)
		return ok, last
	end

	local function createAndSelect(context: any): any
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			return nil
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			return nil
		end
		selectPromise:Yield()

		return slotId
	end

	it("aggregates every registered provider into the Summary, keyed by name", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("world", function()
			return Rx.of(3)
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == 3
		end)

		expect(matched).toEqual(true)
		expect(summary.coins).toEqual(100)
		expect(summary.world).toEqual(3)

		context:Destroy()
	end)

	it("drops a provider's key from the Summary once it is unregistered", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)
		local unregisterWorld = context.hasSaveSlots:RegisterSummaryProvider("world", function()
			return Rx.of(3)
		end)

		local slotId = createAndSelect(context)
		expect((awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == 3
		end))).toEqual(true)

		unregisterWorld()

		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == nil
		end)
		expect(matched).toEqual(true)
		expect(summary.world).toBeNil()

		context:Destroy()
	end)

	it("isolates a provider that errors when called so the others still contribute", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("good", function()
			return Rx.of(1)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("bad", function()
			error("provider boom")
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.good == 1
		end)

		expect(matched).toEqual(true)
		expect(summary.bad).toBeNil()

		context:Destroy()
	end)

	it("isolates a provider whose stream fails so the others still contribute", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("good", function()
			return Rx.of(1)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("bad", function()
			return Observable.new(function(sub)
				sub:Fail("stream boom")
				return nil
			end)
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.good == 1
		end)

		expect(matched).toEqual(true)
		expect(summary.bad).toBeNil()

		context:Destroy()
	end)

	it("clears the Summary when every provider is unregistered", function()
		local context = setup()

		local unregister = context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)

		local slotId = createAndSelect(context)
		expect((awaitSummary(context, slotId, function(s)
			return s.coins == 100
		end))).toEqual(true)

		unregister()

		local cleared = PromiseTestUtils.awaitValue(function()
			return readSummary(context, slotId) == nil
		end, 10)
		expect(cleared).toEqual(true)

		context:Destroy()
	end)
end)

describe("HasSaveSlots against a fake player (datastore down)", function()
	it("PromiseSlotsLoaded rejects fast instead of hanging when datastores are down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local context = setup(mock)
		expect(context.hasSaveSlots).never.toBeNil()

		local promise = context.hasSaveSlots:PromiseSlotsLoaded()
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

		if not promise:IsPending() then
			local ok = promise:Yield()
			expect(ok).toEqual(false)
		end

		context:Destroy()
	end)
end)

describe("HasSaveSlots ephemeral slots", function()
	local function selectEphemeral(context: any, metadata: any?)
		return PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectEphemeralSlot(metadata))
	end

	local function createAndSelectReal(context: any, slotIndex: number)
		local slotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(slotIndex))
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectSlot(slotId))
		return slotId
	end

	local function slotContainerHasChild(context: any, slotId): boolean
		local container = context.fakePlayer:FindFirstChild("SaveSlots")
		return container ~= nil and container:FindFirstChild(slotId) ~= nil
	end

	it("selects an ephemeral slot and reports it active", function()
		local context = setup()

		local slotId = selectEphemeral(context)
		expect(type(slotId)).toEqual("string")
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(slotId))).toEqual(true)

		context:Destroy()
	end)

	it("marks the slot with the IsEphemeral property, and real slots without it", function()
		local context = setup()

		local realId = createAndSelectReal(context, 1)
		local ephemeralId = selectEphemeral(context)

		local realMetadata = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(realId))
		local ephemeralMetadata =
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(ephemeralId))

		expect(ephemeralMetadata.IsEphemeral).toEqual(true)
		expect(realMetadata.IsEphemeral).never.toEqual(true)

		context:Destroy()
	end)

	it("keeps the ephemeral slot out of the slot list while still replicating it", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)
		local ephemeralId = selectEphemeral(context)

		local listedIds = {}
		for _, metadata in (SaveSlotDataService :: any):GetSlotList(context.fakePlayer) do
			listedIds[metadata.SlotId] = true
		end

		expect(listedIds[realId]).toEqual(true)
		expect(listedIds[ephemeralId]).toBeNil()
		expect(slotContainerHasChild(context, realId)).toEqual(true)
		expect(slotContainerHasChild(context, ephemeralId)).toEqual(true)

		context:Destroy()
	end)

	it("replicates the ephemeral slot's metadata so it is readable off the instance tree", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context, { SlotName = "Lobby run" })

		local metadata = (SaveSlotDataService :: any):GetSlotMetadata(context.fakePlayer, ephemeralId)
		expect(metadata).never.toBeNil()
		expect(metadata.SlotId).toEqual(ephemeralId)
		expect(metadata.SlotName).toEqual("Lobby run")
		expect(metadata.IsEphemeral).toEqual(true)

		context:Destroy()
	end)

	it("replicates the ephemeral slot's summary as its providers update it", function()
		local context = setup()

		local coins = ValueObject.new(7)
		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return coins:Observe()
		end)

		local ephemeralId = selectEphemeral(context)

		local function summaryCoins(): number?
			local metadata = (SaveSlotDataService :: any):GetSlotMetadata(context.fakePlayer, ephemeralId)
			return metadata and metadata.Summary and metadata.Summary.coins
		end

		expect(PromiseTestUtils.awaitValue(function()
			return summaryCoins() == 7
		end, 10)).toEqual(true)

		coins.Value = 9
		expect(PromiseTestUtils.awaitValue(function()
			return summaryCoins() == 9
		end, 10)).toEqual(true)

		coins:Destroy()
		context:Destroy()
	end)

	it("emits the ephemeral slot through ObserveSlotMetadata, and nil once it is retired", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context, { SlotName = "Lobby run" })

		local maid = Maid.new()
		local observed: any = nil
		maid:GiveTask(
			(SaveSlotDataService :: any)
				:ObserveSlotMetadata(context.fakePlayer, ephemeralId)
				:Subscribe(function(metadata)
					observed = metadata
				end)
		)

		expect(PromiseTestUtils.awaitValue(function()
			return observed ~= nil and observed.SlotName == "Lobby run"
		end, 10)).toEqual(true)

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot())

		expect(PromiseTestUtils.awaitValue(function()
			return observed == nil
		end, 10)).toEqual(true)

		maid:DoCleaning()
		context:Destroy()
	end)

	it("excludes the ephemeral slot from ObserveSlotList without dropping the real slots", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)

		local maid = Maid.new()
		local observedIds: { [string]: boolean } = {}
		maid:GiveTask((SaveSlotDataService :: any):ObserveSlotList(context.fakePlayer):Subscribe(function(slotList: any)
			observedIds = {}
			for _, metadata in (slotList or {}) :: { any } do
				observedIds[metadata.SlotId] = true
			end
		end))

		expect(PromiseTestUtils.awaitValue(function()
			return observedIds[realId] == true
		end, 10)).toEqual(true)

		local ephemeralId = selectEphemeral(context)

		-- Adding a real slot after the ephemeral one forces a re-emission that must have seen both, so the
		-- ephemeral slot's absence below is a filtered list rather than a list that never updated.
		local laterRealId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(3))
		expect(PromiseTestUtils.awaitValue(function()
			return observedIds[laterRealId] == true
		end, 10)).toEqual(true)

		expect(observedIds[ephemeralId]).toBeNil()
		expect(observedIds[realId]).toEqual(true)

		maid:DoCleaning()
		context:Destroy()
	end)

	it("persists a real slot's data but never an ephemeral slot's", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore()):Store("coins", 12321)

		local ephemeralId = selectEphemeral(context)
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore()):Store("coins", 98789)

		local raw = (context.mock :: any):GetRaw(tostring(FAKE_USER_ID))
		local encoded = if raw ~= nil then HttpService:JSONEncode(raw) else ""

		-- string.find returns multiple values, so bind the first before asserting (expect takes one arg).
		local realIdFound = string.find(encoded, realId, 1, true) ~= nil
		local realValueFound = string.find(encoded, "12321", 1, true) ~= nil
		local ephemeralIdFound = string.find(encoded, ephemeralId, 1, true) ~= nil
		local ephemeralValueFound = string.find(encoded, "98789", 1, true) ~= nil

		expect(realIdFound).toEqual(true)
		expect(realValueFound).toEqual(true)
		expect(ephemeralIdFound).toEqual(false)
		expect(ephemeralValueFound).toEqual(false)

		context:Destroy()
	end)

	it("destroys the ephemeral slot's in-memory store when it is retired", function()
		local context = setup()

		selectEphemeral(context)
		local store = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore())
		expect(getmetatable(store)).never.toBeNil()

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot())

		-- BaseObject.Destroy clears the metatable, so a nil metatable means the store was torn down (and is
		-- now GC-eligible) when the slot was retired, rather than lingering.
		expect(getmetatable(store)).toBeNil()

		context:Destroy()
	end)

	it("does not disturb the Continue pointer when an ephemeral slot is selected", function()
		local context = setup()

		local realId = createAndSelectReal(context, 1)
		selectEphemeral(context)

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(realId)

		context:Destroy()
	end)

	it("tears the ephemeral slot down once it stops being active", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(true)

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot())

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(nil)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)
		expect(slotContainerHasChild(context, ephemeralId)).toEqual(false)

		context:Destroy()
	end)

	it("retires the ephemeral slot when switching to a real slot, keeping the real slots", function()
		local context = setup()

		local slotA = createAndSelectReal(context, 1)
		local slotB = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseCreateSlot(2))
		local ephemeralId = selectEphemeral(context)

		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectSlot(slotB))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotB)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(slotA))).toEqual(true)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(slotB))).toEqual(true)

		context:Destroy()
	end)

	it("drives summaries through the ephemeral slot's in-memory store", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(42)
		end)

		local ephemeralId = selectEphemeral(context)

		local matched = PromiseTestUtils.awaitValue(function()
			local metadata = context.hasSaveSlots:PromiseGetSlotMetadata(ephemeralId):Wait()
			return metadata ~= nil and metadata.Summary ~= nil and metadata.Summary.coins == 42
		end, 10)
		expect(matched).toEqual(true)

		context:Destroy()
	end)

	it("refuses to reset an ephemeral slot", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context)

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseResetSlot(ephemeralId), 10)

		context:Destroy()
	end)

	it("duplicates an ephemeral slot into a real slot carrying its live data", function()
		local context = setup()

		createAndSelectReal(context, 1)
		local ephemeralId = selectEphemeral(context, { SlotName = "Lobby run" })
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore()):Store("Coins", 12)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDuplicateSlot(ephemeralId))

		local metadata = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId))
		expect(metadata.IsEphemeral).never.toEqual(true)
		expect(metadata.SlotName).toEqual("Lobby run")

		local export = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseExportSlot(newSlotId))
		expect(export.data.Coins).toEqual(12)

		-- Duplicating leaves the session running on the ephemeral slot, like any other duplicate.
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(ephemeralId)

		context:Destroy()
	end)

	it("persists the ephemeral slot and continues play on the new real slot", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context, { SlotName = "Lobby run" })
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore()):Store("Coins", 12)

		local newSlotId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromisePersistEphemeralSlot())

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(newSlotId)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)

		local listedIds = {}
		for _, metadata in (SaveSlotDataService :: any):GetSlotList(context.fakePlayer) do
			listedIds[metadata.SlotId] = true
		end
		expect(listedIds[newSlotId]).toEqual(true)

		-- The copy landed on the default index, whose store is the player's root: the session's data is
		-- there and the SaveSlots system data alongside it survived the merge.
		local data = PromiseTestUtils.awaitFulfilled(
			PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseActiveSlotStore()):LoadAll({})
		)
		expect(data.Coins).toEqual(12)
		expect(data.SaveSlots).never.toBeNil()

		context:Destroy()
	end)

	it("refuses to persist when the active slot is a real one", function()
		local context = setup()

		createAndSelectReal(context, 1)

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromisePersistEphemeralSlot(), 10)

		context:Destroy()
	end)

	it("ends the session when the ephemeral slot is deleted", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context)
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeleteSlot(ephemeralId))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(nil)
		expect(PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)
		expect(slotContainerHasChild(context, ephemeralId)).toEqual(false)

		context:Destroy()
	end)

	it("still resumes the real slot with Continue after an ephemeral session", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot())

		selectEphemeral(context)
		PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseDeselectSlot())

		local continuedId = PromiseTestUtils.awaitFulfilled(context.hasSaveSlots:PromiseSelectLastSaveSlot())
		expect(continuedId).toEqual(realId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(realId)

		context:Destroy()
	end)
end)
