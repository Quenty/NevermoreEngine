--!strict
--[[
	Integration coverage for the real HasSaveSlots binder, driven against a mocked datastore. A
	PlayerMock with a seeded UserId stands in for a Player -- the load path only reads the UserId,
	which PlayerDataStoreManager resolves natively from the mock; everything else exercises the
	real code.

	@class HasSaveSlots.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Observable = require("Observable")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local Rx = require("Rx")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup(mock: DataStoreMock.DataStoreMock?)
	mock = mock or DataStoreMock.new()

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

describe("HasSaveSlots against a fake player (healthy datastore)", function()
	it("should construct via the binder and load slots for a fresh player", function()
		local context = setup()
		expect(context.hasSaveSlots).never.toBeNil()

		local promise = context.hasSaveSlots:PromiseSlotsLoaded()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("slots load hung").toEqual("slots load settled")
			context.destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		context.destroy()
	end)

	it("should create a slot and find it", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local ok, slotId = createPromise:Yield()
		expect(ok).toEqual(true)
		expect(type(slotId)).toEqual("string")

		local hasPromise = context.hasSaveSlots:PromiseHasSlot(slotId)
		if not PromiseTestUtils.awaitSettled(hasPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasPromise:Wait())).toEqual(true)

		local indexPromise = context.hasSaveSlots:PromiseSlotIdFromIndex(1)
		if not PromiseTestUtils.awaitSettled(indexPromise, 10) then
			expect("slotIdFromIndex hung").toEqual("slotIdFromIndex settled")
			context.destroy()
			return
		end
		expect((indexPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("should select a slot and report it active", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		expect((selectPromise:Yield())).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("should observe the active slot store after selection", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
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

		context.destroy()
	end)

	it("ObserveActiveSlotStoreBrio tears its brio down once the active slot is deselected", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
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
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			subscription:Destroy()
			context.destroy()
			return
		end
		deselectPromise:Yield()

		expect(activeBrio:IsDead()).toEqual(true)

		subscription:Destroy()
		context.destroy()
	end)

	it("ObserveActiveSlotStoreBrio swaps its brio when switching to another slot", function()
		local context = setup()

		local firstCreate = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstCreate, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstCreate:Yield()

		local secondCreate = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondCreate, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		local _, secondSlotId = secondCreate:Yield()

		local selectFirst = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectFirst, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectFirst:Yield()

		local currentBrio: any = nil
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				currentBrio = brio
			end
		end)

		if not PromiseTestUtils.awaitValue(function()
			return currentBrio ~= nil
		end, 10) then
			expect("first brio hung").toEqual("first brio emitted")
			subscription:Destroy()
			context.destroy()
			return
		end
		local firstBrio = currentBrio

		local selectSecond = context.hasSaveSlots:PromiseSelectSlot(secondSlotId)
		if not PromiseTestUtils.awaitSettled(selectSecond, 10) then
			expect("switch hung").toEqual("switch settled")
			subscription:Destroy()
			context.destroy()
			return
		end
		selectSecond:Yield()

		if not PromiseTestUtils.awaitValue(function()
			return currentBrio ~= firstBrio
		end, 10) then
			expect("second brio hung").toEqual("second brio emitted")
			subscription:Destroy()
			context.destroy()
			return
		end

		expect(firstBrio:IsDead()).toEqual(true)
		expect(currentBrio:IsDead()).toEqual(false)

		subscription:Destroy()
		context.destroy()
	end)

	it("should reject creating a slot beyond the max slot count", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = 1

		local promise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		expect((promise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should reject creating a duplicate slot index", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		expect((secondPromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should reject deleting the active slot", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		expect((deletePromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should replicate the last active slot after selection", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseDeselectSlot clears the active slot but remembers the last active", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		expect((deselectPromise:Yield())).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("deleting the last-active slot clears the continue pointer", function()
		-- Repro for the `delete-save-slot *` bug: deleting the (deselected) active slot left
		-- LastActiveSlotId dangling, so the menu kept offering "Continue" for a slot that was gone.
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("deleting a non-last-active slot leaves the continue pointer intact", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		local _, secondSlotId = secondPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(secondSlotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(firstSlotId)

		context.destroy()
	end)

	it("PromiseDeselectSlot is a no-op when no slot is active", function()
		local context = setup()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		expect((deselectPromise:Yield())).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseDeselectSlot then PromiseSelectLastSaveSlot round-trips back into the slot", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseSelectLastSaveSlot re-selects the last active slot after the active slot is cleared", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		context.hasSaveSlots.ActiveSlotId.Value = nil
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseSelectLastSaveSlot resolves nil when there is nothing to continue", function()
		local context = setup()

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot creates and selects a fresh slot each time", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("new game hung").toEqual("new game settled")
			context.destroy()
			return
		end
		local firstSlotId = firstPromise:Wait()
		expect(type(firstSlotId)).toEqual("string")
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(firstSlotId)

		local secondPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second new game hung").toEqual("second new game settled")
			context.destroy()
			return
		end
		local secondSlotId = secondPromise:Wait()
		expect(type(secondSlotId)).toEqual("string")
		expect(secondSlotId ~= firstSlotId).toEqual(true)

		context.destroy()
	end)

	it("PromiseDeleteAllSlots wipes every slot and clears the selection", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		secondPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local wipePromise = context.hasSaveSlots:PromiseDeleteAllSlots()
		if not PromiseTestUtils.awaitSettled(wipePromise, 10) then
			expect("wipe hung").toEqual("wipe settled")
			context.destroy()
			return
		end
		wipePromise:Yield()

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		local hasPromise = context.hasSaveSlots:PromiseHasSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(hasPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasPromise:Wait())).toEqual(false)

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot reuses the lowest free index after a deletion", function()
		local context = setup()

		local slotIdsByIndex = {}
		for index = 1, 3 do
			local createPromise = context.hasSaveSlots:PromiseCreateSlot(index)
			if not PromiseTestUtils.awaitSettled(createPromise, 10) then
				expect("create hung").toEqual("create settled")
				context.destroy()
				return
			end
			local _, slotId = createPromise:Yield()
			slotIdsByIndex[index] = slotId
		end

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotIdsByIndex[2])
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		local newPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(newPromise, 10) then
			expect("new game hung").toEqual("new game settled")
			context.destroy()
			return
		end
		local newSlotId = newPromise:Wait()
		expect(type(newSlotId)).toEqual("string")

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		expect((metadataPromise:Wait()).SlotIndex).toEqual(2)

		context.destroy()
	end)

	it("PromiseDuplicateSlot copies saved data into a fresh slot and marks the name", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(slotId)
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		local newSlotId = duplicatePromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure (Copy)")

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toEqual(500)

		context.destroy()
	end)

	it("PromiseDuplicateSlot into the default slot preserves the system store", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Save" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(slotId)
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		local newSlotId = duplicatePromise:Wait()

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		expect((metadataPromise:Wait()).SlotIndex).toEqual(1)

		local sourceStillThere = context.hasSaveSlots:PromiseSlotIdFromIndex(2)
		if not PromiseTestUtils.awaitSettled(sourceStillThere, 10) then
			expect("lookup hung").toEqual("lookup settled")
			context.destroy()
			return
		end
		expect((sourceStillThere:Wait())).toEqual(slotId)

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toEqual(750)

		context.destroy()
	end)

	it("PromiseDuplicateSlot rejects when the source slot is missing", function()
		local context = setup()

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot("does-not-exist")
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		expect((duplicatePromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("PromiseResetActiveSlot wipes saved data but keeps the slot's index and name", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(newSlotId)
		local hasOldPromise = context.hasSaveSlots:PromiseHasSlot(slotId)
		if not PromiseTestUtils.awaitSettled(hasOldPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasOldPromise:Wait())).toEqual(false)

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetActiveSlot resets the default slot in place, preserving the system store", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Save" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()

		local lookupPromise = context.hasSaveSlots:PromiseSlotIdFromIndex(1)
		if not PromiseTestUtils.awaitSettled(lookupPromise, 10) then
			expect("lookup hung").toEqual("lookup settled")
			context.destroy()
			return
		end
		expect((lookupPromise:Wait())).toEqual(newSlotId)

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetActiveSlot is a no-op resolving nil when no slot is active", function()
		local context = setup()

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		expect((resetPromise:Wait())).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseResetSlot wipes a non-active slot without touching the active selection", function()
		local context = setup()

		local activePromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(activePromise, 10) then
			expect("active create hung").toEqual("active create settled")
			context.destroy()
			return
		end
		local _, activeSlotId = activePromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(activeSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local targetPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(targetPromise, 10) then
			expect("target create hung").toEqual("target create settled")
			context.destroy()
			return
		end
		local _, targetSlotId = targetPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(targetSlotId):Store("Coins", 500)

		local resetPromise = context.hasSaveSlots:PromiseResetSlot(targetSlotId)
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= targetSlotId).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(activeSlotId)

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetSlot keeps the continue pointer on the reset slot when it was last-active", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local resetPromise = context.hasSaveSlots:PromiseResetSlot(slotId)
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(newSlotId)

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(newSlotId)

		context.destroy()
	end)

	it("PromiseResetSlot rejects when the slot is missing", function()
		local context = setup()

		local resetPromise = context.hasSaveSlots:PromiseResetSlot("does-not-exist")
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		expect((resetPromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("allows creating a slot past a finite cap when the count is unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(6)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local ok, slotId = createPromise:Yield()
		expect(ok).toEqual(true)
		expect(type(slotId)).toEqual("string")

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot never runs out of slots when unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		for _ = 1, 7 do
			local newPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
			if not PromiseTestUtils.awaitSettled(newPromise, 10) then
				expect("new game hung").toEqual("new game settled")
				context.destroy()
				return
			end
			expect(type(newPromise:Wait())).toEqual("string")
		end

		context.destroy()
	end)
end)

describe("HasSaveSlots playtime tracking", function()
	local function createAndSelect(context: any, slotIndex: number): any
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(slotIndex)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			return nil
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			return nil
		end
		selectPromise:Yield()

		return slotId
	end

	local function getMetadata(context: any, slotId): any
		local promise = context.hasSaveSlots:PromiseGetSlotMetadata(slotId)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			return nil
		end
		return promise:Wait()
	end

	it("increments PlayCount to 1 the first time a slot is selected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)
		expect(getMetadata(context, slotId).PlayCount).toEqual(1)

		context.destroy()
	end)

	it("counts a fresh session each time a slot is re-selected", function()
		local context = setup()

		local firstSlotId = createAndSelect(context, 1)
		local secondSlotId = createAndSelect(context, 2)

		local reselectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(reselectPromise, 10) then
			expect("reselect hung").toEqual("reselect settled")
			context.destroy()
			return
		end
		reselectPromise:Yield()

		expect(getMetadata(context, firstSlotId).PlayCount).toEqual(2)
		expect(getMetadata(context, secondSlotId).PlayCount).toEqual(1)

		context.destroy()
	end)

	it("accrues elapsed wall time into TimePlayed and LastSessionLength for the active slot", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		-- Rewind the live session's clock so a flush observes ~120s elapsed without waiting on it. The
		-- flush adds now - lastFlush, so the total is >= 120 (real time may nudge it a second higher).
		local tracker: any = context.hasSaveSlots
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local metadata = getMetadata(context, slotId)
		expect(metadata.TimePlayed ~= nil and metadata.TimePlayed >= 120).toEqual(true)
		expect(metadata.LastSessionLength ~= nil and metadata.LastSessionLength >= 120).toEqual(true)

		context.destroy()
	end)

	it("does not accrue time before any slot is selected", function()
		local context = setup()

		local tracker: any = context.hasSaveSlots
		tracker:_flushPlaytime()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		expect(getMetadata(context, slotId).TimePlayed).toBeNil()

		context.destroy()
	end)

	it("stops accruing into a slot once it is deselected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		local tracker: any = context.hasSaveSlots
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		local afterDeselect = getMetadata(context, slotId).TimePlayed

		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()
		expect(getMetadata(context, slotId).TimePlayed).toEqual(afterDeselect)

		context.destroy()
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

		context.destroy()
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

		context.destroy()
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

		context.destroy()
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

		context.destroy()
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

		context.destroy()
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

		context.destroy()
	end)
end)

describe("HasSaveSlots ephemeral slots", function()
	local function resolve(promise, timeout: number?)
		expect(PromiseTestUtils.awaitSettled(promise, timeout or 10)).toEqual(true)
		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		return value
	end

	local function selectEphemeral(context: any, metadata: any?)
		return resolve(context.hasSaveSlots:PromiseSelectEphemeralSlot(metadata))
	end

	local function createAndSelectReal(context: any, slotIndex: number)
		local slotId = resolve(context.hasSaveSlots:PromiseCreateSlot(slotIndex))
		resolve(context.hasSaveSlots:PromiseSelectSlot(slotId))
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
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(slotId))).toEqual(true)

		context.destroy()
	end)

	it("marks the slot with the IsEphemeral property, and real slots without it", function()
		local context = setup()

		local realId = createAndSelectReal(context, 1)
		local ephemeralId = selectEphemeral(context)

		local realMetadata = resolve(context.hasSaveSlots:PromiseGetSlotMetadata(realId))
		local ephemeralMetadata = resolve(context.hasSaveSlots:PromiseGetSlotMetadata(ephemeralId))

		expect(ephemeralMetadata.IsEphemeral).toEqual(true)
		expect(realMetadata.IsEphemeral).never.toEqual(true)

		context.destroy()
	end)

	it("keeps the ephemeral slot out of the replicated slot list", function()
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
		expect(slotContainerHasChild(context, ephemeralId)).toEqual(false)

		context.destroy()
	end)

	it("persists a real slot's data but never an ephemeral slot's", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)
		resolve(context.hasSaveSlots:PromiseActiveSlotStore()):Store("coins", 12321)

		local ephemeralId = selectEphemeral(context)
		resolve(context.hasSaveSlots:PromiseActiveSlotStore()):Store("coins", 98789)

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

		context.destroy()
	end)

	it("destroys the ephemeral slot's in-memory store when it is retired", function()
		local context = setup()

		selectEphemeral(context)
		local store = resolve(context.hasSaveSlots:PromiseActiveSlotStore())
		expect(getmetatable(store)).never.toBeNil()

		resolve(context.hasSaveSlots:PromiseDeselectSlot())

		-- BaseObject.Destroy clears the metatable, so a nil metatable means the store was torn down (and is
		-- now GC-eligible) when the slot was retired, rather than lingering.
		expect(getmetatable(store)).toBeNil()

		context.destroy()
	end)

	it("does not disturb the Continue pointer when an ephemeral slot is selected", function()
		local context = setup()

		local realId = createAndSelectReal(context, 1)
		selectEphemeral(context)

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(realId)

		context.destroy()
	end)

	it("tears the ephemeral slot down once it stops being active", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context)
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(true)

		resolve(context.hasSaveSlots:PromiseDeselectSlot())

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(nil)
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)
		expect(slotContainerHasChild(context, ephemeralId)).toEqual(false)

		context.destroy()
	end)

	it("retires the ephemeral slot when switching to a real slot, keeping the real slots", function()
		local context = setup()

		local slotA = createAndSelectReal(context, 1)
		local slotB = resolve(context.hasSaveSlots:PromiseCreateSlot(2))
		local ephemeralId = selectEphemeral(context)

		resolve(context.hasSaveSlots:PromiseSelectSlot(slotB))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotB)
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(ephemeralId))).toEqual(false)
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(slotA))).toEqual(true)
		expect(resolve(context.hasSaveSlots:PromiseHasSlot(slotB))).toEqual(true)

		context.destroy()
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

		context.destroy()
	end)

	it("refuses to reset or duplicate an ephemeral slot", function()
		local context = setup()

		local ephemeralId = selectEphemeral(context)

		local resetPromise = context.hasSaveSlots:PromiseResetSlot(ephemeralId)
		expect(PromiseTestUtils.awaitSettled(resetPromise, 10)).toEqual(true)
		expect((resetPromise:Yield())).toEqual(false)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(ephemeralId)
		expect(PromiseTestUtils.awaitSettled(duplicatePromise, 10)).toEqual(true)
		expect((duplicatePromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("still resumes the real slot with Continue after an ephemeral session", function()
		local context = setup()

		local realId = createAndSelectReal(context, 2)
		resolve(context.hasSaveSlots:PromiseDeselectSlot())

		selectEphemeral(context)
		resolve(context.hasSaveSlots:PromiseDeselectSlot())

		local continuedId = resolve(context.hasSaveSlots:PromiseSelectLastSaveSlot())
		expect(continuedId).toEqual(realId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(realId)

		context.destroy()
	end)
end)
